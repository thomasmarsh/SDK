//
//  FTPen.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>

#import "FTDeviceInfoServiceClient.h"
#import "FTPen+Private.h"
#import "FTPen.h"
#import "FTPenServiceClient.h"
#import "FTPenUsageServiceClient.h"
#import "FTPeripheralDelegate.h"
#import "FTServiceUUIDs.h"

NSString * const kFTPenDidEncounterErrorNotificationName = @"com.fiftythree.pen.didEncounterError";
NSString * const kFTPenIsReadyDidChangeNotificationName = @"com.fiftythree.pen.isReadyDidChange";
NSString * const kFTPenIsTipPressedDidChangeNotificationName = @"com.fiftythree.pen.isTipPressedDidChange";
NSString * const kFTPenIsEraserPressedDidChangeNotificationName = @"com.fiftythree.pen.isEraserPressedDidChange";
NSString * const kFTPenBatteryLevelDidChangeNotificationName = @"com.fiftythree.pen.batteryLevelDidChange";
NSString * const kFTPenDidUpdateDeviceInfoPropertiesNotificationName = @"com.fiftythree.pen.didUpdateDeviceInfoProperties";
NSString * const kFTPenDidUpdateUsagePropertiesNotificationName = @"com.fiftythree.pen.didUpdateUsageProperties";
NSString * const kFTPenNotificationPropertiesKey = @"kFTPenNotificationPropertiesKey";

NSString * const kFTPenNamePropertyName = @"name";
NSString * const kFTPenManufacturerNamePropertyName = @"manufacturerName";
NSString * const kFTPenModelNumberPropertyName = @"modelNumber";
NSString * const kFTPenSerialNumberPropertyName = @"serialNumber";
NSString * const kFTPenFirmwareRevisionPropertyName = @"firmwareRevision";
NSString * const kFTPenHardwareRevisionPropertyName = @"hardwareRevision";
NSString * const kFTPenSoftwareRevisionPropertyName = @"softwareRevision";
NSString * const kFTPenSystemIDPropertyName = @"systemID";
NSString * const kFTPenIEEECertificationDataPropertyName = @"IEEECertificationData";
NSString * const kFTPenPnPIDCertificationDataPropertyName = @"PnpIDCertificationData";

NSString * const kFTPenIsTipPressPropertyName = @"isTipPressed";
NSString * const kFTPenIsEraserPressedPropertyName = @"isEraserPressed";
NSString * const kFTPenBatteryLevelPropertyName = @"batteryLevel";

NSString * const kFTPenNumTipPressesPropertyName = @"numTipPresses";
NSString * const kFTPenNumEraserPressesPropertyName = @"numEraserPresses";
NSString * const kFTPenNumFailedConnectionsPropertyName = @"numFailedConnections";
NSString * const kFTPenNumSuccessfulConnectionsPropertyName = @"numSuccessfulConnections";
NSString * const kFTPenTotalOnTimeSecondsPropertyName = @"totalOnTimeSeconds";
NSString * const kFTPenManufacturingIDPropertyName = @"manufacturingID";
NSString * const kFTPenLastErrorCodePropertyName = @"lastErrorCode";
NSString * const kFTPenLongPressTimeMillisecondsPropertyName = @"longPressTimeMilliseconds";
NSString * const kFTPenConnectionTimeSecondsPropertyName = @"connectionTimeSeconds";

@interface FTPen () <FTPenServiceClientDelegate, FTPenUsageServiceClientDelegate, FTDeviceInfoServiceClientDelegate>

@property (nonatomic) CBCentralManager *centralManager;
@property (nonatomic) FTPeripheralDelegate *peripheralDelegate;

@property (nonatomic) FTPenServiceClient *penServiceClient;
@property (nonatomic) FTPenUsageServiceClient *penUsageServiceClient;
@property (nonatomic) FTDeviceInfoServiceClient *deviceInfoServiceClient;

@property (nonatomic, readwrite) NSString *name;
@property (nonatomic, readwrite) NSString *manufacturer;

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
        _penServiceClient = [[FTPenServiceClient alloc] initWithPeripheral:_peripheral];
        _penServiceClient.delegate = self;
        [_peripheralDelegate addServiceClient:_penServiceClient];

#ifdef DEBUG
        // Pen Usage Service client
        _penUsageServiceClient = [[FTPenUsageServiceClient alloc] initWithPeripheral:_peripheral];
        _penUsageServiceClient.delegate = self;
        [_peripheralDelegate addServiceClient:_penUsageServiceClient];
#endif

        // Device Info Service client
        _deviceInfoServiceClient = [[FTDeviceInfoServiceClient alloc] initWithPeripheral:_peripheral];
        _deviceInfoServiceClient.delegate = self;
        [_peripheralDelegate addServiceClient:_deviceInfoServiceClient];
    }

    return self;
}

#pragma mark - Properties

- (FTPenLastErrorCode)lastErrorCode
{
    return self.penUsageServiceClient.lastErrorCode;
}

- (void)clearLastErrorCode
{
    [self.penUsageServiceClient clearLastErrorCode];
}

- (BOOL)isReady
{
    return self.penServiceClient.isReady;
}

- (BOOL)isTipPressed
{
    return self.penServiceClient.isTipPressed;
}

- (BOOL)isEraserPressed
{
    return self.penServiceClient.isEraserPressed;
}

- (NSInteger)batteryLevel
{
    return self.penServiceClient.batteryLevel;
}

- (BOOL)isPoweringOff
{
    return self.penServiceClient.isPoweringOff;
}

- (NSDate *)lastTipReleaseTime
{
    return self.penServiceClient.lastTipReleaseTime;
}

- (BOOL)requiresTipBePressedToBecomeReady
{
    return self.penServiceClient.requiresTipBePressedToBecomeReady;
}

- (void)setRequiresTipBePressedToBecomeReady:(BOOL)requiresTipBePressedToBecomeReady
{
    self.penServiceClient.requiresTipBePressedToBecomeReady = requiresTipBePressedToBecomeReady;
}

- (void)startSwinging
{
    [self.penServiceClient startSwinging];
}

- (void)powerOff
{
    [self.penServiceClient powerOff];
}

#pragma mark - Debug properties

- (NSUInteger)numTipPresses
{
    return self.penUsageServiceClient.numTipPresses;
}

- (NSUInteger)numEraserPresses
{
    return self.penUsageServiceClient.numEraserPresses;
}

- (NSUInteger)numFailedConnections
{
    return self.penUsageServiceClient.numFailedConnections;
}

- (NSUInteger)numSuccessfulConnections
{
    return self.penUsageServiceClient.numSuccessfulConnections;
}

- (NSUInteger)totalOnTimeSeconds
{
    return self.penUsageServiceClient.totalOnTimeSeconds;
}

- (NSString *)manufacturingID
{
    return self.penUsageServiceClient.manufacturingID;
}

- (void)setManufacturingID:(NSString *)manufacturingID
{
    self.penUsageServiceClient.manufacturingID = manufacturingID;

    // The model number and serial number charateristics of the device info
    // service change as a result of setting the manufacturing ID, so refresh
    // them now.
    [self.deviceInfoServiceClient refreshModelNumberAndSerialNumber];
}

- (NSUInteger)longPressTimeMilliseconds
{
    return self.penUsageServiceClient.longPressTimeMilliseconds;
}

- (void)setLongPressTimeMilliseconds:(NSUInteger)longPressTimeMilliseconds
{
    self.penUsageServiceClient.longPressTimeMilliseconds = longPressTimeMilliseconds;
}

- (NSUInteger)connectionTimeSeconds
{
    return self.penUsageServiceClient.connectionTimeSeconds;
}

- (void)setConnectionTimeSeconds:(NSUInteger)connectionTimeSeconds
{
    self.penUsageServiceClient.connectionTimeSeconds = connectionTimeSeconds;
}

- (void)readUsageProperties
{
    [self.penUsageServiceClient readUsageProperties];
}

- (void)refreshFirmwareVersionProperties
{
    [self.deviceInfoServiceClient refreshFirmwareRevisions];
}

#pragma mark -

- (void)peripheralConnectionStatusDidChange
{
    NSArray *servicesToBeDiscovered = [self.peripheralDelegate peripheral:self.peripheral
                                                     isConnectedDidChange:self.peripheral.isConnected];

    if (self.peripheral.isConnected)
    {
        NSAssert(self.peripheral.delegate == self.peripheralDelegate,
                 @"peripheral delegate is installed");

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

- (void)penServiceClient:(FTPenServiceClient *)penServiceClient didEncounterError:(NSError *)error
{
    NSLog(@"Pen did encounter error: \"%@\"", error.localizedDescription);

    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenDidEncounterErrorNotificationName
                                                        object:self];

}

- (void)penServiceClient:(FTPenServiceClient *)penServiceClient isReadyDidChange:(BOOL)isReady
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenIsReadyDidChangeNotificationName
                                                        object:self];

    if ([self.privateDelegate respondsToSelector:@selector(pen:isReadyDidChange:)])
    {
        [self.privateDelegate pen:self isReadyDidChange:isReady];
    }
}

- (void)penServiceClient:(FTPenServiceClient *)penServiceClient isTipPressedDidChange:(BOOL)isTipPressed
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenIsTipPressedDidChangeNotificationName
                                                        object:self];

    if ([self.delegate respondsToSelector:@selector(pen:isTipPressedDidChange:)])
    {
        [self.delegate pen:self isTipPressedDidChange:isTipPressed];
    }
}

- (void)penServiceClient:(FTPenServiceClient *)penServiceClient isEraserPressedDidChange:(BOOL)isEraserPressed
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenIsEraserPressedDidChangeNotificationName
                                                        object:self];

    if ([self.delegate respondsToSelector:@selector(pen:isEraserPressedDidChange:)])
    {
        [self.delegate pen:self isEraserPressedDidChange:isEraserPressed];
    }
}

- (void)penServiceClient:(FTPenServiceClient *)penServiceClient batteryLevelDidChange:(NSInteger)batteryLevel
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenBatteryLevelDidChangeNotificationName
                                                        object:self];

    if ([self.delegate respondsToSelector:@selector(pen:batteryLevelDidChange:)])
    {
        [self.delegate pen:self batteryLevelDidChange:batteryLevel];
    }
}

#pragma mark - FTPenUsageServiceClientDelegate

- (void)didWriteManufacturingID
{
    [self.privateDelegate didWriteManufacturingID];
}

- (void)didFailToWriteManufacturingID
{
    [self.privateDelegate didFailToWriteManufacturingID];
}

- (void)didReadManufacturingID:(NSString *)manufacturingID
{
    [self.privateDelegate didReadManufacturingID:manufacturingID];
}

- (void)didUpdateUsageProperties:(NSSet *)updatedProperties
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenDidUpdateUsagePropertiesNotificationName
                                                        object:self
                                                      userInfo:@{ kFTPenNotificationPropertiesKey:updatedProperties }];
    [self.privateDelegate didUpdateUsageProperties:updatedProperties];
}

#pragma mark - FTDeviceInfoServiceClientDelegate

- (void)deviceInfoServiceClientDidUpdateDeviceInfo:(FTDeviceInfoServiceClient *)deviceInfoServiceClient
                                 updatedProperties:(NSSet *)updatedProperties
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenDidUpdateDeviceInfoPropertiesNotificationName
                                                        object:self
                                                      userInfo:@{ kFTPenNotificationPropertiesKey:updatedProperties }];
    if ([self.delegate respondsToSelector:@selector(penDidUpdateDeviceInfoProperty:)])
    {
        [self.delegate penDidUpdateDeviceInfoProperty:self];
    }
}

#pragma mark -

- (NSString *)name
{
    return _name ? _name : self.peripheral.name;
}

- (NSString *)manufacturerName
{
    return (self.deviceInfoServiceClient.manufacturerName ?
            self.deviceInfoServiceClient.manufacturerName :
            _manufacturer);
}

- (NSString *)modelNumber
{
    return self.deviceInfoServiceClient.modelNumber;
}

- (NSString *)serialNumber
{
    return self.deviceInfoServiceClient.serialNumber;
}

- (NSString *)firmwareRevision
{
    return self.deviceInfoServiceClient.firmwareRevision;
}

- (NSString *)hardwareRevision
{
    return self.deviceInfoServiceClient.hardwareRevision;
}

- (NSString *)softwareRevision
{
    return self.deviceInfoServiceClient.softwareRevision;
}

- (NSString *)systemID
{
    return self.deviceInfoServiceClient.systemID;
}

- (NSData *)IEEECertificationData
{
    return self.deviceInfoServiceClient.IEEECertificationData;
}

- (PnPID)pnpId
{
    return self.deviceInfoServiceClient.PnPID;
}

@end
