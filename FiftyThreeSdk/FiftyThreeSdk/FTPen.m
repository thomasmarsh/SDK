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
#import "FTDeviceInfoServiceClient.h"
#import "FTPeripheralDelegate.h"
#import "FTPenServiceClient.h"
#import "FTPenDebugServiceClient.h"
#import "FTDeviceInfoServiceClient.h"

NSString * const kFTPenDidEncounterErrorNotificationName = @"com.fiftythree.pen.didEncounterError";
NSString * const kFTPenIsReadyDidChangeNotificationName = @"com.fiftythree.pen.isReadyDidChange";
NSString * const kFTPenIsTipPressedDidChangeNotificationName = @"com.fiftythree.pen.isTipPressedDidChange";
NSString * const kFTPenIsEraserPressedDidChangeNotificationName = @"com.fiftythree.pen.isEraserPressedDidChange";

@interface FTPen () <FTPenServiceClientDelegate, FTPenDebugServiceClientDelegate>

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

        // Pen Debug Service client
#ifdef DEBUG
        _penDebugServiceClient = [[FTPenDebugServiceClient alloc] init];
        _penDebugServiceClient.delegate = self;
        [_peripheralDelegate addServiceClient:_penDebugServiceClient];
#endif

        _deviceInfoServiceClient = [[FTDeviceInfoServiceClient alloc] init];
        [_peripheralDelegate addServiceClient:_deviceInfoServiceClient];
    }

    return self;
}

#pragma mark - Properties

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

- (NSDate *)lastTipReleaseTime
{
    return self.penServiceClient.lastTipReleaseTime;
}

- (BOOL)shouldSwing
{
    return self.penServiceClient.shouldSwing;
}

- (void)setShouldSwing:(BOOL)shouldSwing
{
    self.penServiceClient.shouldSwing = shouldSwing;
}

- (BOOL)shouldPowerOff
{
    return self.penServiceClient.shouldPowerOff;
}

- (void)setShouldPowerOff:(BOOL)shouldPowerOff
{
    self.penServiceClient.shouldPowerOff = shouldPowerOff;
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
    NSLog(@"Pen did encounter error: \"%@\".", error.localizedDescription);

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

#pragma mark - FTPenDebugServiceClientDelegate

#pragma mark -

- (void)updateData:(NSDictionary *)data
{
    _name = [data objectForKey:CBAdvertisementDataLocalNameKey];
    _manufacturer = [data objectForKey:CBAdvertisementDataManufacturerDataKey];
}

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

