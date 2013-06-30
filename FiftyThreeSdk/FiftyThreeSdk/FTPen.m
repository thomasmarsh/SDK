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
#import "FTPeripheralDelegate.h"
#import "FTPenServiceClient.h"
#import "FTPenDebugServiceClient.h"

@interface FTPen () <FTPenServiceClientDelegate, FTPenDebugServiceClientDelegate>

@property (nonatomic) CBCentralManager *centralManager;
@property (nonatomic) FTPeripheralDelegate *peripheralDelegate;

@property (nonatomic) FTPenServiceClient *penServiceClient;
@property (nonatomic) FTPenDebugServiceClient *penDebugServiceClient;

@property (nonatomic, readwrite) BOOL isReady;

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

        _peripheralDelegate = [[FTPeripheralDelegate alloc] init];
        _peripheral.delegate = _peripheralDelegate;

        // Pen Service client
        _penServiceClient = [[FTPenServiceClient alloc] init];
        _penServiceClient.delegate = self;
        [_peripheralDelegate addServiceClient:_penServiceClient];

        // Pen Debug Service client
#ifdef DEBUG
        _penDebugServiceClient = [[FTPenDebugServiceClient alloc] init];
        _penDebugServiceClient.delegate = self;
        [_peripheralDelegate addServiceClient:_penDebugServiceClient];
#endif

    }

    return self;
}

#pragma mark - Properties

- (BOOL)isTipPressed
{
    return self.penServiceClient.isTipPressed;
}

- (BOOL)isEraserPressed
{
    return self.penServiceClient.isEraserPressed;
}

- (NSDate *)lastTipReleaseTime
{
    return self.penServiceClient.lastTipReleaseTime;
}

#pragma mark -

- (void)peripheralConnectionStatusDidChange
{
    NSArray *servicesToBeDiscovered = [self.peripheralDelegate peripheral:self.peripheral
                                                     isConnectedDidChange:self.peripheral.isConnected];

    if (self.peripheral.isConnected)
    {
        NSLog(@"Peripheral is connected.");

        [self.peripheral discoverServices:servicesToBeDiscovered];
    }
    else
    {
        NSLog(@"Peripheral was disconnected.");

        NSAssert(servicesToBeDiscovered.count == 0,
                 @"Should not attempt to discover services if not connected");
    }
}

#pragma mark - FTPenServiceClientDelegate

- (void)penServiceClient:(FTPenServiceClient *)penServiceClient isReadyDidChange:(BOOL)isReady
{
    [self.privateDelegate pen:self isReadyDidChange:isReady];
}

- (void)penServiceClient:(FTPenServiceClient *)penServiceClient isTipPressedDidChange:(BOOL)isTipPressed
{
    [self.delegate pen:self isTipPressedDidChange:isTipPressed];
}

- (void)penServiceClient:(FTPenServiceClient *)penServiceClient isEraserPressedDidChange:(BOOL)isEraserPressed
{
    [self.delegate pen:self isEraserPressedDidChange:isEraserPressed];
}

#pragma mark - FTPenDebugServiceClientDelegate

#pragma mark -

- (void)setIsReady:(BOOL)isReady
{
    _isReady = isReady;

    [self.privateDelegate pen:self isReadyDidChange:isReady];
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

