//
//  TIUpdateManager.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "TIUpdateManager.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "FTError.h"

#include "Common/Timer.h"

static NSString *const kOADServiceUUID = @"F000FFC0-0451-4000-B000-000000000000";
static NSString *const kImageIdentifyUUID = @"F000FFC1-0451-4000-B000-000000000000";
static NSString *const kImageBlockTransferUUID = @"F000FFC2-0451-4000-B000-000000000000";

@interface TIUpdateManager () <CBPeripheralDelegate>
{
}

@property (nonatomic) CBCharacteristic *imageIdentify;
@property (nonatomic) CBCharacteristic *imageBlockTransfer;
@property (nonatomic) NSInteger currentBlock;
@property (nonatomic) NSString *imagePath;
@property (nonatomic) NSFileHandle *imageHandle;
@property (nonatomic) unsigned long long imageSizeRemaining;
@property (nonatomic) unsigned long long imageSize;
@property (nonatomic) boost::shared_ptr<Timer> lastBlockTimer;
@property (nonatomic, weak) id<TIUpdateManagerDelegate> delegate;
@property (nonatomic) float lastPercent;
@property (nonatomic, readwrite) NSDate *updateStartTime;

@end

@implementation TIUpdateManager
{
    CBPeripheral *_peripheral;
    id<CBPeripheralDelegate> _oldDelegate;
}

- (id)initWithPeripheral:(CBPeripheral *)peripheral delegate:(id<TIUpdateManagerDelegate>)delegate;
{
    self = [super init];
    if (self) {
        _peripheral = peripheral;
        _delegate = delegate;
    }
    return self;
}

- (void)updateImage:(NSString *)filePath
{
    self.waitingForReboot = NO;

    _oldDelegate = _peripheral.delegate;
    _peripheral.delegate = self;

    self.currentBlock = 0;
    self.imagePath = filePath;
    self.imageHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    if (!self.imageHandle)
    {
        NSLog(@"invalid file path");
        [self done:nil];
    }

    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.imagePath error:NULL];
    self.imageSizeRemaining = [attributes fileSize];
    self.imageSize = [attributes fileSize];

    [_peripheral discoverServices:@[[CBUUID UUIDWithString:kOADServiceUUID]]];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error || !peripheral.services || peripheral.services.count == 0) {
        NSLog(@"Error discovering device info service: %@", [error localizedDescription]);
        [self done:error];
        return;
    }

    NSArray* characteristics = @[
                                 [CBUUID UUIDWithString:kImageIdentifyUUID],
                                 [CBUUID UUIDWithString:kImageBlockTransferUUID]
                                 ];

    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:characteristics forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering device info characteristics: %@", [error localizedDescription]);
        [self done:error];
        return;
    }

    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kImageIdentifyUUID]]) {
            self.imageIdentify = characteristic;
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kImageBlockTransferUUID]]) {
            self.imageBlockTransfer = characteristic;
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (self.imageBlockTransfer.isNotifying && self.imageIdentify.isNotifying) {
        self.updateStartTime = [NSDate date];

        NSLog(@"Sending image header");

        [self.imageHandle seekToFileOffset:4]; // skip CRC + shadow CRC

        NSData *data = [self.imageHandle readDataOfLength:12];
        [peripheral writeValue:data forCharacteristic:self.imageIdentify type:CBCharacteristicWriteWithoutResponse];

        [self.imageHandle seekToFileOffset:0];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kImageIdentifyUUID]]) {
        uint16_t version = ((uint16_t *)characteristic.value.bytes)[0];
        if (version == 0)
        {
            NSLog(@"Device is rebooting, reconnect and attempt again");
            self.waitingForReboot = YES;
            [self done:[[NSError alloc] initWithDomain:@"TiUpdateManager" code:FTErrorAborted userInfo:nil]];
        }
        else
        {
            NSLog(@"Update rejected, existing version = %d", version);
            [self done:[[NSError alloc] initWithDomain:@"TiUpdateManager" code:FTErrorAborted userInfo:nil]];
        }
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kImageBlockTransferUUID]]) {
        // perform block transfer
        uint16_t index = ((uint16_t *)characteristic.value.bytes)[0];
        //NSLog(@"block index = %d", index);

        if (index != self.currentBlock) {
            NSLog(@"Unexpected block index, aborting.");
            [self done:[[NSError alloc] initWithDomain:@"TiUpdateManager" code:FTErrorAborted userInfo:nil]];
        } else {
            if (self.lastBlockTimer) {
                NSLog(@"RTT = %g seconds", self.lastBlockTimer->ElapsedTimeSeconds());
                NSLog(@"%g%% complete", (double)(self.imageSize - self.imageSizeRemaining) / (double)self.imageSize * 100);
            } else {
                self.lastBlockTimer = Timer::New();
            }

            uint16_t indexHeader = CFSwapInt16HostToLittle(self.currentBlock);
            NSMutableData *data = [NSMutableData dataWithBytes:&indexHeader length:sizeof(indexHeader)];
            NSData *block = [self.imageHandle readDataOfLength:16];

            NSAssert(block.length != 0, nil);

            [data appendData:block];

            NSLog(@"sending block %d", self.currentBlock);

            self.lastBlockTimer->Reset();

            [peripheral writeValue:data forCharacteristic:self.imageBlockTransfer type:CBCharacteristicWriteWithoutResponse];
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
                NSLog(@"100%% complete");

                [self.imageHandle closeFile];
                self.imageHandle = nil;

                [self done:nil];
            }
        }
    }
}

- (void)done:(NSError *)error
{
    _peripheral.delegate = _oldDelegate;
    _oldDelegate = nil;

    [self.delegate updateManager:self didFinishUpdate:error];
}

@end
