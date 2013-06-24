//
//  FTPen.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTPen.h"
#import "FTPen+Private.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "FTServiceUUIDs.h"
#import "FTDeviceInfoClient.h"
#import "FTBatteryClient.h"

static NSString * const kPeripheralIsConnectedKeyPath = @"isConnected";

@interface FTPen () <CBPeripheralDelegate>

@property (nonatomic) CBCentralManager *centralManager;

@property (nonatomic, readwrite) BOOL isReady;

@property (nonatomic) CBCharacteristic *isTipPressedCharacteristic;
@property (nonatomic) CBCharacteristic *isEraserPressedCharacteristic;
@property (nonatomic) CBCharacteristic *deviceStateCharacteristic;

@property (nonatomic, readwrite) NSString *name;
@property (nonatomic, readwrite) NSString *manufacturer;

@property (nonatomic) FTDeviceInfoClient *deviceInfoClient;
@property (nonatomic) FTBatteryClient *batteryClient;

@end

@implementation FTPen

#pragma mark - Initialization

- (id)initWithCentralManager:(CBCentralManager *)centralManager
                  peripheral:(CBPeripheral *)peripheral
{
    NSAssert(centralManager, @"central manager non-nil");
    NSAssert(peripheral, @"peripheral non-nil");
    NSAssert(!peripheral.isConnected, @"peripheral is not connected");

    self = [super init];
    if (self)
    {
        _centralManager = centralManager;

        _peripheral = peripheral;
        _peripheral.delegate = self;
    }

    return self;
}

#pragma mark - Properties

- (BOOL)isTipPressed
{
    if (self.isTipPressedCharacteristic)
    {
        return ((const char *)self.isTipPressedCharacteristic.value.bytes)[0] != 0;
    }

    return NO;
}

- (BOOL)isEraserPressed
{
    if (self.isEraserPressedCharacteristic)
    {
        return ((const char *)self.isEraserPressedCharacteristic.value.bytes)[0] != 0;
    }

    return NO;
}

#pragma mark -

- (void)peripheralConnectionStatusDidChange
{
    if (self.peripheral.isConnected)
    {
        NSLog(@"Peripheral is connected.");

        [self discoverPeripheralServices];
    }
    else
    {
        NSLog(@"peripheral disconnected");

        [self handleDisconnection];
    }
}

// Initiates the discovery of services on the peripheral. Only discovers debug services in the debug build
// configuration.
- (void)discoverPeripheralServices
{
    NSAssert(self.peripheral, @"Peripheral is non-nil");

    NSLog(@"Attempting to discover services for peripheral.");

    NSMutableArray *serviceUUIDs = [NSMutableArray array];
    [serviceUUIDs addObject:[FTPenServiceUUIDs penService]];

#ifdef DEBUG
    [serviceUUIDs addObject:[FTPenDebugServiceUUIDs penDebugService]];
#endif

    [self.peripheral discoverServices:serviceUUIDs];
}

- (void)handleDisconnection
{
    self.isTipPressedCharacteristic = nil;
    self.isEraserPressedCharacteristic = nil;
    self.deviceStateCharacteristic = nil;
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        // TODO: Report failed state
        return;
    }

    NSMutableString *serviceNames = [NSMutableString string];

    // Discover the characteristics of each discovered service.
    // TODO: Is it more efficient to discover these incrementally, only discovering the required ones
    // initially?
    for (CBService *service in peripheral.services)
    {
        NSArray *characteristics;

        if ([service.UUID isEqual:[FTPenServiceUUIDs penService]])
        {
            characteristics = @[
                                [FTPenServiceUUIDs isTipPressed],
                                [FTPenServiceUUIDs isEraserPressed],
                                [FTPenServiceUUIDs shouldSwing],
                                [FTPenServiceUUIDs shouldPowerOff],
                                [FTPenServiceUUIDs batteryVoltage],
                                [FTPenServiceUUIDs inactivityTime]
                                ];

            [peripheral discoverCharacteristics:characteristics forService:service];
        }
        else if ([service.UUID isEqual:[FTPenDebugServiceUUIDs penDebugService]])
        {
#ifndef DEBUG
            NSAssert(NO, @"Should not discover debug service in non-debug builds.");
#endif

            characteristics = @[
                                [FTPenDebugServiceUUIDs deviceState],
                                [FTPenDebugServiceUUIDs tipPressure],
                                [FTPenDebugServiceUUIDs erasurePressure],
                                [FTPenDebugServiceUUIDs longPressTime],
                                [FTPenDebugServiceUUIDs connectionTime]
                                ];
        }

        if (characteristics)
        {
            [peripheral discoverCharacteristics:characteristics forService:service];
        }
        else
        {
            NSAssert(NO, @"Discovered only expected services.");
        }
    }

    for (int i = 0; i < peripheral.services.count; i++)
    {
        NSString *serviceName = FTNameForServiceUUID(((CBService *)peripheral.services[i]).UUID);

        if (i == peripheral.services.count - 1)
        {
            [serviceNames appendString:serviceName];
        }
        else
        {
            [serviceNames appendFormat:@"%@, ", serviceName];
        }
    }

    NSLog(@"Did discover service(s): %@.", serviceNames);
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error
{
    NSLog(@"Pen did discover characterisitics for service: %@", FTNameForServiceUUID(service.UUID));

    if (error || service.characteristics.count == 0)
    {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        // TODO: Report failed state
        return;
    }

    for (CBCharacteristic *characteristic in service.characteristics)
    {
        // IsTipPressed
        if (!self.isTipPressedCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs isTipPressed]])
        {
            self.isTipPressedCharacteristic = characteristic;
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }

        // IsEraserPressed
        if (!self.isEraserPressedCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs isEraserPressed]])
        {
            self.isEraserPressedCharacteristic = characteristic;
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }

        // DeviceState
        if (!self.deviceStateCharacteristic &&
            [characteristic.UUID isEqual:[FTPenDebugServiceUUIDs deviceState]])
        {
            self.deviceStateCharacteristic = characteristic;
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error discovering characteristics: %@.", [error localizedDescription]);
        // TODO: Report failed state
        return;
    }

    if ([characteristic.UUID isEqual:[FTPenServiceUUIDs isTipPressed]])
    {
        BOOL isTipPressed = self.isTipPressed;
        [self.delegate pen:self isTipPressedDidChange:isTipPressed];

        NSLog(@"IsTipPressed characteristic changed: %d.", isTipPressed);
    }
    else if ([characteristic.UUID isEqual:[FTPenServiceUUIDs isEraserPressed]])
    {
        BOOL isEraserPressed = self.isEraserPressed;
        [self.delegate pen:self isEraserPressedDidChange:isEraserPressed];

        NSLog(@"IsEraserPressed characteristic changed: %d.", isEraserPressed);
    }
    else if ([characteristic.UUID isEqual:[FTPenDebugServiceUUIDs deviceState]])
    {
        const int state = ((const char *)characteristic.value.bytes)[0];
        NSLog(@"Device State Changed: %d.", state);
    }
    else
    {
        NSAssert(NO, @"Should only see updates for expected characteristics.");
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error changing notification state: %@.", error.localizedDescription);
        // TODO: Report failed state
        return;
    }

    if (![characteristic.UUID isEqual:[FTPenServiceUUIDs isTipPressed]] &&
        ![characteristic.UUID isEqual:[FTPenServiceUUIDs isEraserPressed]])
    {
        return;
    }

    if (characteristic.isNotifying)
    {
        NSLog(@"Notification began on charateristic: %@.", FTNameForServiceUUID(characteristic.UUID));

        if ([characteristic.UUID isEqual:[FTPenServiceUUIDs isTipPressed]])
        {
            self.isReady = YES;
        }
    }
    else
    {
        NSLog(@"Notification stopped on characteristic: %@. Disconnecting.",
              FTNameForServiceUUID(characteristic.UUID));

        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    NSLog(@"CBPeripheral didWriteValueForCharacteristic");
}

#pragma mark -

- (void)setIsReady:(BOOL)isReady
{
    _isReady = isReady;

    [self.privateDelegate pen:self didChangeIsReadyState:isReady];
}

- (void)updateData:(NSDictionary *)data
{
    _name = [data objectForKey:CBAdvertisementDataLocalNameKey];
    _manufacturer = [data objectForKey:CBAdvertisementDataManufacturerDataKey];
}

- (void)getInfo:(void(^)(FTPen *client, NSError *error))complete;
{
    _deviceInfoClient = [[FTDeviceInfoClient alloc] initWithPeripheral:_peripheral];
    [_deviceInfoClient getInfo:^(FTDeviceInfoClient *client, NSError *error) {
        complete(self, error);
    }];
}

- (void)getBattery:(void(^)(FTPen *client, NSError *error))complete;
{
    _batteryClient = [[FTBatteryClient alloc] initWithPeripheral:_peripheral];
    [_batteryClient getBatteryLevel:^(FTBatteryClient *client, NSError *error) {
        complete(self, error);
    }];
}

- (NSString *)name
{
    return _name ? _name : self.peripheral.name;
}

- (NSString *)manufacturerName
{
    return _deviceInfoClient.manufacturerName ? _deviceInfoClient.manufacturerName : _manufacturer;
}

- (NSString *)modelNumber
{
    return _deviceInfoClient.modelNumber;
}

- (NSString *)serialNumber
{
    return _deviceInfoClient.serialNumber;
}

- (NSString *)firmwareRevision
{
    return _deviceInfoClient.firmwareRevision;
}

- (NSString *)hardwareRevision
{
    return _deviceInfoClient.hardwareRevision;
}

- (NSString *)softwareRevision
{
    return _deviceInfoClient.softwareRevision;
}

- (NSString *)systemId
{
    return _deviceInfoClient.systemId;
}

- (NSData *)certificationData
{
    return _deviceInfoClient.certificationData;
}

- (PnPID)pnpId
{
    return _deviceInfoClient.pnpId;
}

- (NSInteger)batteryLevel
{
    return _batteryClient.batteryLevel;
}

@end

