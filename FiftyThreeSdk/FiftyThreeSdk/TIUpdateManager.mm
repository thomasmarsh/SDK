//
//  TIUpdateManager.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#include "Common/Timer.h"

#import <CoreBluetooth/CoreBluetooth.h>

#import "FTError.h"
#import "TIUpdateManager.h"

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
@property (nonatomic) unsigned long long imageSize;

@property (nonatomic) NSTimer *imageBlockWriteTimer;
@property (nonatomic) NSInteger currentBlock;
@property (nonatomic) unsigned long long imageSizeRemaining;
@property (nonatomic) float lastPercent;

@end

@implementation TIUpdateManager

- (id)initWithPeripheral:(CBPeripheral *)peripheral delegate:(id<TIUpdateManagerDelegate>)delegate;
{
    self = [super init];
    if (self)
    {
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
    _currentBlock = 0;
    _imageSizeRemaining = 0;

    _imagePath = nil;
    [self.imageHandle closeFile];
    _imageHandle = nil;
    _imageSize = 0;

    _lastPercent = 0;

    if (_shouldRestorePeripheralDelegate)
    {
        // Restore the original peripheral delegate.
        _peripheral.delegate = _oldPeripheralDelegate;
    }
}

- (void)updateWithImagePath:(NSString *)imagePath
{
    NSAssert(self.state == TIUpdateManagerStateNotStarted,
             @"Firmware may only be updated once using a single update manager.");

    self.state = TIUpdateManagerStateInProgress;

    self.oldPeripheralDelegate = self.peripheral.delegate;
    self.peripheral.delegate = self;

    self.imagePath = imagePath;
    self.imageHandle = [NSFileHandle fileHandleForReadingAtPath:self.imagePath];
    if (!self.imageHandle)
    {
        NSLog(@"Firmware: invalid file path: %@", self.imagePath);
        [self doneWithError:[self errorAborted]];
    }

    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.imagePath
                                                                                error:NULL];
    self.imageSize = attributes.fileSize;
    self.imageSizeRemaining = self.imageSize;
    self.currentBlock = 0;

    [self.peripheral discoverServices:@[[CBUUID UUIDWithString:kOADServiceUUID]]];
}

- (void)cancelUpdate
{
    if (self.state == TIUpdateManagerStateInProgress)
    {
        NSLog(@"Firmware: update cancelled");
        self.state = TIUpdateManagerStateCancelled;
        [self cleanup];
    }
}

- (void)doneWithError:(NSError *)error
{
    if (!error)
    {
        error = [self errorAborted];
    }
    NSLog(@"Firmware: update done with error: %@", error.localizedDescription);

    self.state = TIUpdateManagerStateFailed;

    [self.delegate updateManager:self didFinishUpdate:error];

    [self cleanup];
}

- (void)done
{
    NSLog(@"Firmware: update done");

    self.state = TIUpdateManagerStateSucceeded;

    [self.delegate updateManager:self didFinishUpdate:nil];

    [self cleanup];
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error || !peripheral.services || peripheral.services.count == 0)
    {
        NSLog(@"Firmware: error discovering device info service: %@", error.localizedDescription);
        [self doneWithError:error];
        return;
    }

    NSArray* characteristics = @[[CBUUID UUIDWithString:kImageIdentifyUUID],
                                 [CBUUID UUIDWithString:kImageBlockTransferUUID]
                                 ];

    for (CBService *service in peripheral.services)
    {
        [peripheral discoverCharacteristics:characteristics forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Firmware: error discovering device info characteristics: %@",
              error.localizedDescription);
        [self doneWithError:error];
        return;
    }

    for (CBCharacteristic *characteristic in service.characteristics)
    {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kImageIdentifyUUID]])
        {
            self.imageIdentifyCharacteristic = characteristic;
        }
        else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kImageBlockTransferUUID]])
        {
            self.imageBlockTransferCharacteristic = characteristic;
        }
    }

    [self maybeStartImageBlockWrite];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Firmware: error updating value for descriptor: %@", error.localizedDescription);
        [self doneWithError:error];
        return;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Firmware: error writing value for characteristic: %@",
              error.localizedDescription);
        [self doneWithError:error];
        return;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor
             error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Firmware: error writing value for descriptor: %@",
              error.localizedDescription);
        [self doneWithError:error];
        return;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor
             error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Firmware: error updating value for descriptor: %@",
              error.localizedDescription);
        [self doneWithError:error];
        return;
    }
}

#pragma mark - Image block write

- (void)maybeStartImageBlockWrite
{
    if (self.imageIdentifyCharacteristic &&
        self.imageBlockTransferCharacteristic)
    {
        [self startImageBlockWrite];
    }
}

- (void)startImageBlockWrite
{
    NSLog(@"Firmware: sending image header");

    [self.imageHandle seekToFileOffset:4]; // skip CRC + shadow CRC

    NSData *data = [self.imageHandle readDataOfLength:12];
    [self.peripheral writeValue:data
              forCharacteristic:self.imageIdentifyCharacteristic
                           type:CBCharacteristicWriteWithoutResponse];

    [self.imageHandle seekToFileOffset:0];

    [self scheduleWriteTimer];
}

- (void)stopImageBlockWrite
{
    [self.imageBlockWriteTimer invalidate];
    self.imageBlockWriteTimer = nil;
}

- (void)scheduleWriteTimer
{
    NSAssert(!self.imageBlockWriteTimer, @"write timer nil");
    self.imageBlockWriteTimer = [NSTimer scheduledTimerWithTimeInterval:0.25
                                                                 target:self
                                                               selector:@selector(imageBlockWriteTimerFired:)
                                                               userInfo:nil
                                                                repeats:NO];
}

- (void)imageBlockWriteTimerFired:(NSTimer *)writeTimer
{
    if (!self.peripheral.isConnected)
    {
        [self doneWithError:[self errorAborted]];
        return;
    }

    const int numBlocksToWrite = 4;
    for (int i = 0; i < numBlocksToWrite; i++)
    {
        uint16_t indexHeader = CFSwapInt16HostToLittle(self.currentBlock);
        NSMutableData *data = [NSMutableData dataWithBytes:&indexHeader length:sizeof(indexHeader)];
        NSData *block = [self.imageHandle readDataOfLength:16];

        NSAssert(block.length != 0, nil);

        [data appendData:block];

        [self.peripheral writeValue:data forCharacteristic:self.imageBlockTransferCharacteristic
                               type:CBCharacteristicWriteWithoutResponse];
        self.currentBlock++;

        self.imageSizeRemaining -= block.length;

        float percent = (float)(self.imageSize - self.imageSizeRemaining) / (float)self.imageSize * 100;

        // only send integral updates
        if ((percent - self.lastPercent) > 0.1)
        {
            [self.delegate updateManager:self didUpdatePercentComplete:percent];
            self.lastPercent = percent;
        }

        if (self.imageSizeRemaining == 0)
        {
            [self done];
            break;
        }
        else
        {
            if (i == numBlocksToWrite - 1)
            {
                self.imageBlockWriteTimer = nil;
                [self scheduleWriteTimer];
            }
        }
    }
}

- (NSError *)errorAborted
{
    return [[NSError alloc] initWithDomain:@"TiUpdateManager"
                                      code:FTErrorAborted
                                  userInfo:nil];
}

@end
