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
#import "FTPenDebugServiceClient.h"
#import "FTPenServiceClient.h"
#import "FTPeripheralDelegate.h"
#import "FTServiceUUIDs.h"

NSString * const kFTPenDidEncounterErrorNotificationName = @"com.fiftythree.pen.didEncounterError";
NSString * const kFTPenIsReadyDidChangeNotificationName = @"com.fiftythree.pen.isReadyDidChange";
NSString * const kFTPenIsTipPressedDidChangeNotificationName = @"com.fiftythree.pen.isTipPressedDidChange";
NSString * const kFTPenIsEraserPressedDidChangeNotificationName = @"com.fiftythree.pen.isEraserPressedDidChange";
NSString * const kFTPenBatteryLevelDidChangeNotificationName = @"com.fiftythree.pen.batteryLevelDidChange";

@interface FTPen () <FTPenServiceClientDelegate, FTPenDebugServiceClientDelegate, FTDeviceInfoServiceClientDelegate>

@property (nonatomic) CBCentralManager *centralManager;
@property (nonatomic) FTPeripheralDelegate *peripheralDelegate;

@property (nonatomic) FTPenServiceClient *penServiceClient;
@property (nonatomic) FTPenDebugServiceClient *penDebugServiceClient;
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
        // Pen Debug Service client
        _penDebugServiceClient = [[FTPenDebugServiceClient alloc] initWithPeripheral:_peripheral];
        _penDebugServiceClient.delegate = self;
        [_peripheralDelegate addServiceClient:_penDebugServiceClient];
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
    return self.penDebugServiceClient.lastErrorCode;
}

- (void)clearLastErrorCode
{
    [self.penDebugServiceClient clearLastErrorCode];
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
    return self.penDebugServiceClient.numTipPresses;
}

- (NSUInteger)numEraserPresses
{
    return self.penDebugServiceClient.numEraserPresses;
}

- (NSUInteger)numFailedConnections
{
    return self.penDebugServiceClient.numFailedConnections;
}

- (NSUInteger)numSuccessfulConnections
{
    return self.penDebugServiceClient.numSuccessfulConnections;
}

- (NSUInteger)totalOnTimeSeconds
{
    return self.penDebugServiceClient.totalOnTimeSeconds;
}

- (NSString *)manufacturingID
{
    return self.penDebugServiceClient.manufacturingID;
}

- (void)setManufacturingID:(NSString *)manufacturingID
{
    self.penDebugServiceClient.manufacturingID = manufacturingID;

    // The model number and serial number charateristics of the device info
    // service change as a result of setting the manufacturing ID, so refresh
    // them now.
    [self.deviceInfoServiceClient refreshModelNumberAndSerialNumber];
}

- (NSUInteger)longPressTimeMilliseconds
{
    return self.penDebugServiceClient.longPressTimeMilliseconds;
}

- (void)setLongPressTimeMilliseconds:(NSUInteger)longPressTimeMilliseconds
{
    self.penDebugServiceClient.longPressTimeMilliseconds = longPressTimeMilliseconds;
}

- (NSUInteger)connectionTimeSeconds
{
    return self.penDebugServiceClient.connectionTimeSeconds;
}

- (void)setConnectionTimeSeconds:(NSUInteger)connectionTimeSeconds
{
    self.penDebugServiceClient.connectionTimeSeconds = connectionTimeSeconds;
}

- (void)readDebugProperties
{
    [self.penDebugServiceClient readDebugProperties];
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

    if ([self.delegate respondsToSelector:@selector(pen:isReadyDidChange:)])
    {
        [self.delegate pen:self isReadyDidChange:isReady];
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

#pragma mark - FTPenDebugServiceClientDelegate

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

- (void)didUpdateDebugProperties
{
    [self.privateDelegate didUpdateDebugProperties];
}

#pragma mark - FTDeviceInfoServiceClientDelegate

- (void)deviceInfoServiceClientDidUpdateDeviceInfo:(FTDeviceInfoServiceClient *)deviceInfoServiceClient
{
    if ([self.delegate respondsToSelector:@selector(penDidUpdateDeviceInfo:)])
    {
        [self.delegate penDidUpdateDeviceInfo:self];
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
