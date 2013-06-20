//
//  FTPenService.m
//  FiftyThreeSdkTestApp
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import "FTPenService.h"
#import "FiftyThreeSdk/FTPenServiceUUID.h"

@interface FTPenService () <CBPeripheralManagerDelegate>
@property (nonatomic) CBPeripheralManager *peripheralManager;
@property (nonatomic) CBMutableService *penService;
@property (nonatomic) CBMutableCharacteristic *isTipPressedCharacteristic;
@property (nonatomic) CBMutableCharacteristic *isEraserPressedCharacteristic;
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
    self.penService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_UUID]
                                                     primary:YES];

    CBCharacteristicProperties notifyProperty = secure ? CBCharacteristicPropertyNotifyEncryptionRequired : CBCharacteristicPropertyNotify;
    CBAttributePermissions readPermission = secure ? CBAttributePermissionsReadEncryptionRequired : CBAttributePermissionsReadable;

    self.isTipPressedCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_IS_TIP_PRESSED_UUID]
                                                                         properties:notifyProperty
                                                                              value:nil
                                                                        permissions:readPermission];

    self.isEraserPressedCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_IS_ERASER_PRESSED_UUID]
                                                                            properties:notifyProperty
                                                                                 value:nil
                                                                           permissions:readPermission];

    self.penService.characteristics = @[ self.isTipPressedCharacteristic, self.isEraserPressedCharacteristic ];

    [self.peripheralManager addService:self.penService];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error;
{
    NSLog(@"Pen service registered, start advertising...");

    [self.peripheralManager startAdvertising:@{
         CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithCFUUID:FT_PEN_SERVICE_UUID]],
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

- (void)setIsTipPressed:(BOOL)isTipPressed
{
    char byte = isTipPressed ? 1 : 0;
    [self.peripheralManager updateValue:[NSData dataWithBytes:&byte length:sizeof(byte)]
                       forCharacteristic:self.isTipPressedCharacteristic
                   onSubscribedCentrals:nil];
}

- (void)setIsEraserPressed:(BOOL)isEraserPressed
{
    char byte = isEraserPressed ? 1 : 0;
    [self.peripheralManager updateValue:[NSData dataWithBytes:&byte length:sizeof(byte)]
                      forCharacteristic:self.isEraserPressedCharacteristic
                   onSubscribedCentrals:nil];
}

@end
