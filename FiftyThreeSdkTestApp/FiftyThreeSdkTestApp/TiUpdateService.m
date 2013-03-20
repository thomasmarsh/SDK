//
//  TiUpdateService.m
//  charcoal-prototype
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "TiUpdateService.h"
#import <CoreBluetooth/CoreBluetooth.h>

static NSString *const kOADServiceUUID = @"F000FFC0-0451-4000-B000-000000000000";
static NSString *const kImageIdentifyUUID = @"F000FFC1-0451-4000-B000-000000000000";
static NSString *const kImageBlockTransferUUID = @"F000FFC2-0451-4000-B000-000000000000";

@interface TiUpdateService () <CBPeripheralManagerDelegate>
@property (nonatomic) CBPeripheralManager       *peripheralManager;
@property (nonatomic) CBMutableCharacteristic   *imageIdentify;
@property (nonatomic) CBMutableCharacteristic   *imageBlockTransfer;
@property (nonatomic) NSInteger currentBlock;
@property (nonatomic) NSInteger totalBlocks;
@end

@implementation TiUpdateService

- (id)init {
    self = [super init];
    if (self) {
        _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    }

    return self;
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    if (peripheral.state != CBPeripheralManagerStatePoweredOn) {
        return;
    }

    NSLog(@"CBPeripheralManager powered on.");

    // Characteristics
    self.imageIdentify = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kImageIdentifyUUID]
                                                                     properties:CBCharacteristicPropertyNotify | CBCharacteristicPropertyWriteWithoutResponse
                                                                          value:nil
                                                                    permissions:CBAttributePermissionsWriteable];

    self.imageBlockTransfer = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kImageBlockTransferUUID]
                                                            properties:CBCharacteristicPropertyNotify | CBCharacteristicPropertyWriteWithoutResponse
                                                                 value:nil
                                                           permissions:CBAttributePermissionsWriteable];

    // Service
    CBMutableService *oadService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:kOADServiceUUID]
                                                                       primary:YES];

    oadService.characteristics = @[self.imageIdentify, self.imageBlockTransfer];

    [self.peripheralManager addService:oadService];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error;
{
    NSLog(@"Firmware update service registered");
    //[self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:kOADServiceUUID]] }];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central subscribed to characteristic");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central unsubscribed from characteristic");
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    NSLog(@"read to update");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request;
{
    NSLog(@"Got read request");
}

- (void)requestNextBlock
{
    char bytes[2];
    ((uint16_t *)bytes)[0] = CFSwapInt16HostToLittle(self.currentBlock);
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)]; // bugbug - dummy data
    
    [self.peripheralManager updateValue:data forCharacteristic:self.imageBlockTransfer onSubscribedCentrals:nil];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests;
{
    NSLog(@"Got write request");
    
    for (CBATTRequest *request in requests)
    {
        if ([request.characteristic.UUID isEqual:[CBUUID UUIDWithString:kImageIdentifyUUID]])
        {
            uint16_t imageLen = CFSwapInt16HostToLittle(((char *)request.value.bytes)[4]);
            NSLog(@"imageLen = %d", imageLen);
            self.totalBlocks = imageLen / (16 / 4);
            self.currentBlock = 0;
            [self requestNextBlock];
        }
        else if ([request.characteristic.UUID isEqual:[CBUUID UUIDWithString:kImageBlockTransferUUID]])
        {
            if (request.value.length < 2)
            {
                NSLog(@"Invalid block size, aborting transfer");
                return;
            }
            
            uint16_t blockNum = CFSwapInt16LittleToHost(((uint16_t *)request.value.bytes)[0]);
            NSLog(@"received block %d", blockNum);
            
            if (blockNum != self.currentBlock)
            {
                NSLog(@"Invalid block number, aborting");
                return;
            }
            
            self.currentBlock++;
            if (self.currentBlock == self.totalBlocks)
            {
                NSLog(@"Last block received");
                return;
            }
            
            [self requestNextBlock];
        }
    }
}

@end
