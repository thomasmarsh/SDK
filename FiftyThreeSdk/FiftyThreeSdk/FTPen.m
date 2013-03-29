//
//  FTPen.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTPen.h"
#import "FTPen+Private.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "FTPenServiceUUID.h"
#import "FTDeviceInfoClient.h"
#import "FTBatteryClient.h"

@interface FTPen ()
{
}

@property (nonatomic, readwrite) NSString *name;
@property (nonatomic, readwrite) BOOL isConnected;
@property (nonatomic, readwrite) NSString *manufacturer;

@property (nonatomic) FTDeviceInfoClient *deviceInfoClient;
@property (nonatomic) FTBatteryClient *batteryClient;

@end

@implementation FTPen

@synthesize delegate = _delegate;

- (id)initWithPeripheral:(CBPeripheral *)peripheral data:(NSDictionary *)data {
    self = [super init];
    if (self) {
        _peripheral = peripheral;
        [self updateData:data];
    }
    return self;
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

- (BOOL)isConnected
{
    return self.peripheral.isConnected;
}

- (NSString *)name
{
    return _name ? _name : self.peripheral.name;
}

- (BOOL)isTipPressed:(FTPenTip)tip
{
    return _tipPressed[tip];
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

- (NSString *)certificationData
{
    return _deviceInfoClient.certificationData;
}

- (NSString *)pnpId
{
    return _deviceInfoClient.pnpId;
}

- (NSInteger)batteryLevel
{
    return _batteryClient.batteryLevel;
}

@end

