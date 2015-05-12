//
//  TIUpdateManager.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include "Core/Timer.h"

#import <CoreBluetooth/CoreBluetooth.h>

#import "Core/Asserts.h"
#import "Core/Log.h"
#import "Core/NSTimer+Helpers.h"
#import "FTError.h"
#import "FTLogPrivate.h"
#import "TIUpdateManager.h"

using namespace fiftythree::core;

// Time in milliseconds within which the peripherial must process an attribute write by
// this object and respond.
#define BLOCK_TRANSFER_REQUEST_TIMEOUT_MILLIS 15000

static NSString *const kOADServiceUUID = @"F000FFC0-0451-4000-B000-000000000000";
static NSString *const kImageIdentifyUUID = @"F000FFC1-0451-4000-B000-000000000000";
static NSString *const kImageBlockTransferUUID = @"F000FFC2-0451-4000-B000-000000000000";

@interface TIUpdateManager () <CBPeripheralDelegate>

@property (nonatomic, weak) id<TIUpdateManagerDelegate> delegate;
@property (nonatomic, weak) id<CBPeripheralDelegate> oldPeripheralDelegate;

@property (nonatomic) CBPeripheral *peripheral;
@property (nonatomic) CBCharacteristic *imageIdentifyCharacteristic;
@property (nonatomic) CBCharacteristic *imageBlockTransferCharacteristic;

@property (nonatomic, copy) NSString *imagePath;
@property (nonatomic) NSFileHandle *imageHandle;
@property (nonatomic) uint16_t imageBlockCount;
@property (nonatomic) uint16_t lastBlockIndexTransferred;

@property (nonatomic) NSTimer *imageBlockWriteTimer;
@property (nonatomic) uint16_t imageBlocksRemaining;
@property (nonatomic) float lastPercent;

@end

@implementation TIUpdateManager

- (id)initWithPeripheral:(CBPeripheral *)peripheral delegate:(id<TIUpdateManagerDelegate>)delegate;
{
    self = [super init];
    if (self) {
        _state = TIUpdateManagerStateNotStarted;
        _shouldRestorePeripheralDelegate = YES;

        _peripheral = peripheral;
        _delegate = delegate;
    }
    return self;
}

- (void)dealloc
{
    _shouldRestorePeripheralDelegate = NO;
    [self cleanup];
}

- (void)cleanup
{
    _imageIdentifyCharacteristic = nil;
    _imageBlockTransferCharacteristic = nil;
    [self stopImageBlockWrite];

    _imageBlocksRemaining = 0;
    _imagePath = nil;
    [self.imageHandle closeFile];
    _imageHandle = nil;

    _lastPercent = 0;

    if (_shouldRestorePeripheralDelegate) {
        // Restore the original peripheral delegate.
        _peripheral.delegate = _oldPeripheralDelegate;
    }
}

- (void)updateWithImagePath:(NSString *)imagePath
{
    FTAssert(self.state == TIUpdateManagerStateNotStarted,
             @"Firmware may only be updated once using a single update manager.");

    self.state = TIUpdateManagerStateStarting;

    self.oldPeripheralDelegate = self.peripheral.delegate;
    self.peripheral.delegate = self;

    self.imagePath = imagePath;
    self.imageHandle = [NSFileHandle fileHandleForReadingAtPath:self.imagePath];
    if (!self.imageHandle) {
        MLOG_ERROR(FTLogSDK, "Firmware: invalid file path: %s", ObjcDescription(self.imagePath));

        [self doneWithError:[self errorAborted]];
    }

    [self.peripheral discoverServices:@[ [CBUUID UUIDWithString:kOADServiceUUID] ]];
}

- (void)cancelUpdate
{
    switch (self.state) {
        case TIUpdateManagerStateInProgress:
        case TIUpdateManagerStateStarting:
        case TIUpdateManagerStateProbablyDone: {
            self.state = TIUpdateManagerStateCancelled;
            [self cleanup];
            MLOG_INFO(FTLogSDK, "Firmware: update cancelled");
            break;
        }
        default:
            // No effect
            break;
    }
}

- (void)doneWithError:(NSError *)error
{
    if (!error) {
        error = [self errorAborted];
    }

    MLOG_INFO(FTLogSDK, "Firmware: update done with error: %s", ObjcDescription(error.localizedDescription));

    self.state = TIUpdateManagerStateFailed;

    [self cleanup];

    [self.delegate updateManager:self didFinishUpdate:error];
}

// Do not call any other methods on self after this one as this object may be deallocated when this method
// exits.
- (void)probablyDone
{
    MLOG_INFO(FTLogSDK, "Firmware: update is probably done");

    self.state = TIUpdateManagerStateProbablyDone;

    [self.delegate updateManager:self didFinishUpdate:nil];
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error || !peripheral.services || peripheral.services.count == 0) {
        MLOG_ERROR(FTLogSDK, "Firmware: error discovering device info service: %s", ObjcDescription(error.localizedDescription));

        [self doneWithError:error];
        return;
    }

    NSArray *characteristics = @[ [CBUUID UUIDWithString:kImageIdentifyUUID],
                                  [CBUUID UUIDWithString:kImageBlockTransferUUID] ];

    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:characteristics forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service
                                   error:(NSError *)error
{
    if (error) {
        MLOG_ERROR(FTLogSDK, "Firmware: error discovering device info characteristics: %s", ObjcDescription(error.localizedDescription));

        [self doneWithError:error];
        return;
    }

    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kImageIdentifyUUID]]) {
            self.imageIdentifyCharacteristic = characteristic;
        } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kImageBlockTransferUUID]]) {
            self.imageBlockTransferCharacteristic = characteristic;
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }

    [self maybeStartImageBlockWrite];
}

- (void)peripheral:(CBPeripheral*)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic*)characteristic
             error:(NSError *)error
{
    if (error) {
        MLOG_ERROR(FTLogSDK, "Firmware: error updating notification state for characteristic: %s", ObjcDescription(error.localizedDescription));
        
        [self doneWithError:error];
        return;
    }
    
    [self maybeStartImageBlockWrite];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
                              error:(NSError *)error
{
    if (error) {
        MLOG_ERROR(FTLogSDK, "Firmware: error updating value for descriptor: %s", ObjcDescription(error.localizedDescription));

        [self doneWithError:error];
        return;
    }
    
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kImageBlockTransferUUID]]) {
        NSData* value = characteristic.value;
        if (!value.length) {
            MLOG_ERROR(FTLogSDK, "0 length write to the Image Block Transfer characteristic?");
        } else {
            uint16_t blockIndex = CFSwapInt16LittleToHost(((uint16_t*)value.bytes)[0]);
            MLOG_DEBUG(FTLogSDK, "Target requested block %u be written.", blockIndex);
            [self writeImageBlock:blockIndex toPeripheral:peripheral];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
                             error:(NSError *)error
{
    if (error) {
        MLOG_ERROR(FTLogSDK, "Firmware: error writing value for characteristic: %s", ObjcDescription(error.localizedDescription));

        [self doneWithError:error];
        return;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor
                         error:(NSError *)error
{
    if (error) {
        MLOG_ERROR(FTLogSDK, "Firmware: error writing value for descriptor: %s", ObjcDescription(error.localizedDescription));

        [self doneWithError:error];
        return;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor
                          error:(NSError *)error
{
    if (error) {
        MLOG_ERROR(FTLogSDK, "Firmware: error updating value for descriptor: %s", ObjcDescription(error.localizedDescription));

        [self doneWithError:error];
        return;
    }
}

#pragma mark - Image block write

- (void)maybeStartImageBlockWrite
{
    if (self.imageIdentifyCharacteristic &&
        self.imageBlockTransferCharacteristic &&
        self.imageBlockTransferCharacteristic.isNotifying &&
        self.state == TIUpdateManagerStateStarting)
    {
        [self startImageBlockWrite];
        self.state = TIUpdateManagerStateInProgress;
    }
}

- (void)startImageBlockWrite
{
    MLOG_INFO(FTLogSDK, "Firmware: sending image header");

    [self.imageHandle seekToFileOffset:4]; // skip CRC + shadow CRC

    NSData *data = [self.imageHandle readDataOfLength:12];
    
    uint16_t updateVersion = (CFSwapInt16LittleToHost(((uint16_t*)data.bytes)[0]) >> 1);

    // From oad.h
    // OAD_BLOCK_SIZE = 16
    // HAL_FLASH_WORD_SIZE = 4
    // imageBlockCount = imageHeader.len / (OAD_BLOCK_SIZE / HAL_FLASH_WORD_SIZE);
    self.imageBlocksRemaining = self.imageBlockCount = (CFSwapInt16LittleToHost(((uint16_t*)data.bytes)[1]) / 4);

    [self.peripheral writeValue:data
              forCharacteristic:self.imageIdentifyCharacteristic
                           type:CBCharacteristicWriteWithoutResponse];

    self.lastBlockIndexTransferred = 0;
    self.imageBlocksRemaining--;

    MLOG_DEBUG(FTLogSDK, "Starting update to firmware version %u", updateVersion);

    [self resetWriteTimer];

    [self.delegate updateManager:self didBeginUpdateToVersion:updateVersion];
}

- (void)stopImageBlockWrite
{
    [self.imageBlockWriteTimer invalidate];
    self.imageBlockWriteTimer = nil;
}

- (void)resetWriteTimer
{
    [self.imageBlockWriteTimer invalidate];
    self.imageBlockWriteTimer = [NSTimer weakScheduledTimerWithTimeInterval:(double)BLOCK_TRANSFER_REQUEST_TIMEOUT_MILLIS/1000.00
                                                                     target:self
                                                                   selector:@selector(imageBlockWriteTimerFired:)
                                                                   userInfo:nil
                                                                    repeats:NO];
}

- (void)imageBlockWriteTimerFired:(NSTimer *)writeTimer
{
    MLOG_ERROR(FTLogSDK, "Timeout waiting for the peripherial to respond.");
    [self doneWithError:[[NSError alloc] initWithDomain:@"TiUpdateManager"
                                                   code:FTErrorConnectionTimeout
                                               userInfo:nil]];
}

- (void)writeImageBlock:(uint16_t)blockIndex toPeripheral:(CBPeripheral *)peripheral
{
    [self.imageBlockWriteTimer invalidate];
    
    if (peripheral.state != CBPeripheralStateConnected || !self.imageBlockWriteTimer) {
        [self doneWithError:[self errorAborted]];
        return;
    }

    uint16_t indexHeader = CFSwapInt16HostToLittle(blockIndex);
    NSMutableData *data = [NSMutableData dataWithBytes:&indexHeader length:sizeof(indexHeader)];
    [self.imageHandle seekToFileOffset:blockIndex * 16];
    NSData *block = [self.imageHandle readDataOfLength:16];

    [data appendData:block];

    [self.peripheral writeValue:data forCharacteristic:self.imageBlockTransferCharacteristic
                           type:CBCharacteristicWriteWithoutResponse];

    if (blockIndex != self.lastBlockIndexTransferred) {
        if (self.imageBlocksRemaining) {
            // This is sort of an estimate since we don't track every block request individually.
            // Be sure to keep the unsigned value from rolling over here.
            self.imageBlocksRemaining--;
        }
        self.lastBlockIndexTransferred = blockIndex;
    }
    
    float percent = (1.f - ((float)self.imageBlocksRemaining / (float)self.imageBlockCount)) * 100.f;

    // only send integral updates
    if (self.state == TIUpdateManagerStateInProgress && (percent - self.lastPercent) > 0.1f) {
        [self.delegate updateManager:self didUpdatePercentComplete:percent];
        self.lastPercent = percent;
    }

    [self resetWriteTimer];

    if (self.imageBlocksRemaining == 0) {
        [self probablyDone];
    }
    
}

- (NSError *)errorAborted
{
    return [[NSError alloc] initWithDomain:@"TiUpdateManager"
                                      code:FTErrorAborted
                                  userInfo:nil];
}

@end
