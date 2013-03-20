//
//  TIUpdateManager.m
//  charcoal-prototype
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
//@property (nonatomic) NSDate *lastBlockReceiveTime;
@property (nonatomic) boost::shared_ptr<Timer> lastBlockTimer;

@end

@implementation TIUpdateManager
{
    CBPeripheral *_peripheral;
    void (^_complete)(TIUpdateManager *client, NSError *error);
    id<CBPeripheralDelegate> _oldDelegate;
}

- (id)initWithPeripheral:(CBPeripheral *)peripheral
{
    self = [super init];
    if (self) {
        _peripheral = peripheral;
    }
    return self;
}

- (void)updateImage:(NSString *)filePath complete:(void(^)(TIUpdateManager *client, NSError *error))complete
{
    _complete = complete;
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
        NSLog(@"Sending image header");
        
        NSData *data = [self.imageHandle readDataOfLength:14];
        [peripheral writeValue:data forCharacteristic:self.imageIdentify type:CBCharacteristicWriteWithoutResponse];
        self.imageSizeRemaining -= data.length;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kImageIdentifyUUID]]) {
        NSLog(@"Update not required, existing version = %d", ((uint16_t *)characteristic.value.bytes)[1]);
        
        [self done:[[NSError alloc] initWithDomain:@"TiUpdateManager" code:FTErrorAborted userInfo:nil]];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kImageBlockTransferUUID]]) {
        // perform block transfer
        uint16_t index = ((uint16_t *)characteristic.value.bytes)[0];
        NSLog(@"block index = %d", index);
        
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
            if (self.imageSizeRemaining == 0)
            {
                NSLog(@"100%% complete");
                self.imageHandle = 0;
                [self done:nil];
                return;
            }
        }
    }
}

- (void)done:(NSError *)error
{
    _peripheral.delegate = _oldDelegate;
    _oldDelegate = nil;
    _complete(self, error);
}

@end
