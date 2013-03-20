//
//  FTPenService.m
//  charcoal-prototype
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTPenService.h"
#include "FTPenServiceUUID.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface FTPenService () <CBPeripheralManagerDelegate>
@property (nonatomic) CBPeripheralManager       *peripheralManager;
@property (nonatomic) CBMutableService          *penService;
@property (nonatomic) CBMutableCharacteristic   *tip1Characteristic;
@property (nonatomic) CBMutableCharacteristic   *tip2Characteristic;
@end

@implementation FTPenService

- (id)init
{
    self = [super init];
    if (self) {
        _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    }
    return self;
}

- (void)setSecure:(BOOL)secure
{
    [self registerService:secure];
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    if (peripheral.state != CBPeripheralManagerStatePoweredOn) {
        return;
    }

    NSLog(@"CBPeripheralManager powered on.");

    [self registerService:_secure];
}

- (void)registerService:(BOOL)secure
{
    if (self.penService) {
        [self.peripheralManager removeService:self.penService];
        self.penService = nil;
    }

    NSLog(@"Registering pen service, secure=%d", secure);

    // Register service
    self.penService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:FT_PEN_SERVICE_UUID]
                                                                  primary:YES];

    CBCharacteristicProperties notifyProperty = secure ? CBCharacteristicPropertyNotifyEncryptionRequired : CBCharacteristicPropertyNotify;
    CBAttributePermissions readPermission = secure ? CBAttributePermissionsReadEncryptionRequired : CBAttributePermissionsReadable;

    self.tip1Characteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:FT_PEN_TIP1_STATE_UUID]
                                                                     properties:notifyProperty
                                                                          value:nil                                                                                        permissions:readPermission];

    self.tip2Characteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:FT_PEN_TIP2_STATE_UUID]
                                                                properties:notifyProperty
                                                                    value:nil
                                                                  permissions:readPermission];

    self.penService.characteristics = @[ self.tip1Characteristic, self.tip2Characteristic ];

    [self.peripheralManager addService:self.penService];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error;
{
    NSLog(@"Pen service registered, start advertising...");

    [self.peripheralManager startAdvertising:@{
         CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:FT_PEN_SERVICE_UUID]],
            CBAdvertisementDataLocalNameKey : @"Charcoal Simulator",
     //CBAdvertisementDataManufacturerDataKey : @"FiftyThree, Inc." // Not allowed
     }];
}

/** Catch when someone subscribes to our characteristic, then start sending them data
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central subscribed to characteristic");

    [self.delegate penService:self connectionStateChanged:YES];
}

/** Recognise when the central unsubscribes
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central unsubscribed from characteristic");

    [self.delegate penService:self connectionStateChanged:NO];
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    NSLog(@"read to update");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request;
{
    NSLog(@"Got read request");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests;
{
    NSLog(@"Got write request");
}

- (void)setTip1Pressed:(BOOL)tip1Pressed
{
    char byte = tip1Pressed ? 1 : 0;
    [self.peripheralManager updateValue:[NSData dataWithBytes:&byte length:sizeof(byte)]
                       forCharacteristic:self.tip1Characteristic onSubscribedCentrals:nil];
}

- (void)setTip2Pressed:(BOOL)tip2Pressed
{
    char byte = tip2Pressed ? 1 : 0;
    [self.peripheralManager updateValue:[NSData dataWithBytes:&byte length:sizeof(byte)]
                      forCharacteristic:self.tip2Characteristic onSubscribedCentrals:nil];
}

@end
