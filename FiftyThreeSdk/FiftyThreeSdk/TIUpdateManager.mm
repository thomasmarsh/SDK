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

@property (nonatomic) NSString *imagePath;
@property (nonatomic) NSFileHandle *imageHandle;
@property (nonatomic) unsigned long long imageSize;

@property (nonatomic) NSTimer *imageBlockWriteTimer;
@property (nonatomic) NSInteger currentBlock;
@property (nonatomic) unsigned long long imageSizeRemaining;

@property (nonatomic, readwrite) NSDate *updateStartTime;
@property (nonatomic) float lastPercent;

@end

@implementation TIUpdateManager

- (id)initWithPeripheral:(CBPeripheral *)peripheral delegate:(id<TIUpdateManagerDelegate>)delegate;
{
    self = [super init];
    if (self)
    {
        _peripheral = peripheral;
        _delegate = delegate;
    }
    return self;
}

- (void)updateImage:(NSString *)filePath
{
    self.waitingForReboot = NO;

    self.oldPeripheralDelegate = self.peripheral.delegate;
    self.peripheral.delegate = self;

    self.imagePath = [filePath copy];
    self.imageHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    if (!self.imageHandle)
    {
        NSLog(@"invalid file path");
        [self done:nil];
    }

    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.imagePath
                                                                                error:NULL];
    self.imageSize = attributes.fileSize;
    self.imageSizeRemaining = self.imageSize;
    self.currentBlock = 0;

    [self.peripheral discoverServices:@[[CBUUID UUIDWithString:kOADServiceUUID]]];
}

- (void)done:(NSError *)error
{
    if (error)
    {
        NSLog(@"Done, with error: %@", error.localizedDescription);
    }
    else
    {
        NSLog(@"Done.");
    }

    self.imageIdentifyCharacteristic = nil;
    self.imageBlockTransferCharacteristic = nil;
    [self stopImageBlockWrite];
    self.currentBlock = 0;
    self.imageSizeRemaining = 0;

    self.imagePath = nil;
    [self.imageHandle closeFile];
    self.imageHandle = nil;
    self.imageSize = 0;

    self.updateStartTime = nil;
    self.lastPercent = 0;

    self.peripheral.delegate = self.oldPeripheralDelegate;
    self.oldPeripheralDelegate = nil;

    [self.delegate updateManager:self didFinishUpdate:error];
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error || !peripheral.services || peripheral.services.count == 0)
    {
        NSLog(@"Error discovering device info service: %@", error.localizedDescription);
        [self done:error];
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
        NSLog(@"Error discovering device info characteristics: %@",
              error.localizedDescription);
        [self done:error];
        return;
    }

    for (CBCharacteristic *characteristic in service.characteristics)
    {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kImageIdentifyUUID]])
        {
            self.imageIdentifyCharacteristic = characteristic;
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
        else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kImageBlockTransferUUID]])
        {
            self.imageBlockTransferCharacteristic = characteristic;
        }
    }

    [self maybeStartImageBlockWrite];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error updating notification state for characteristic: %@",
              error.localizedDescription);
        [self done:error];
        return;
    }

    [self maybeStartImageBlockWrite];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error updating value for descriptor: %@", error.localizedDescription);
        [self done:error];
        return;
    }

    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kImageIdentifyUUID]])
    {
        uint16_t version = ((uint16_t *)characteristic.value.bytes)[0];
        if (version == 0)
        {
            NSLog(@"Device is rebooting, reconnect and attempt again");
            self.waitingForReboot = YES;
            [self done:[[NSError alloc] initWithDomain:@"TiUpdateManager"
                                                  code:FTErrorAborted
                                              userInfo:nil]];
        }
        else
        {
            NSLog(@"Update rejected, existing version = %d", version);
            [self done:[[NSError alloc] initWithDomain:@"TiUpdateManager"
                                                  code:FTErrorAborted
                                              userInfo:nil]];
        }
    }
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kImageBlockTransferUUID]])
    {
        uint16_t index = ((uint16_t *)characteristic.value.bytes)[0];
        NSLog(@"Block index = %d", index);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error writing value for characteristic: %@",
              error.localizedDescription);
        [self done:error];
        return;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor
             error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error writing value for descriptor: %@",
              error.localizedDescription);
        [self done:error];
        return;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor
             error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error updating value for descriptor: %@",
              error.localizedDescription);
        [self done:error];
        return;
    }
}

#pragma mark - Image block write

- (void)maybeStartImageBlockWrite
{
    if (self.imageIdentifyCharacteristic.isNotifying &&
        self.imageBlockTransferCharacteristic)
    {
        [self startImageBlockWrite];
    }
}

- (void)startImageBlockWrite
{
    self.updateStartTime = [NSDate date];

    NSLog(@"Sending image header");

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
    self.imageBlockWriteTimer = [NSTimer scheduledTimerWithTimeInterval:0.20
                                                                 target:self
                                                               selector:@selector(imageBlockWriteTimerFired:)
                                                               userInfo:nil
                                                                repeats:NO];
}

- (void)imageBlockWriteTimerFired:(NSTimer *)writeTimer
{
    if (!self.peripheral.isConnected)
    {
        [self done:[[NSError alloc] initWithDomain:@"TiUpdateManager"
                                              code:FTErrorAborted
                                          userInfo:nil]];
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
            [self done:nil];
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

@end
