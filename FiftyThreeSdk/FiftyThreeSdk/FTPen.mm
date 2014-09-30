//
//  FTPen.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>

#import "Core/Asserts.h"
#import "Core/Log.h"
#import "FTDeviceInfoServiceClient.h"
#import "FTLogPrivate.h"
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
NSString * const kFTPenDidUpdatePropertiesNotificationName = @"com.fiftythree.pen.didUpdateProperties";
NSString * const kFTPenDidUpdatePrivatePropertiesNotificationName = @"com.fiftythree.pen.didUpdatePrivateProperties";
NSString * const kFTPenNotificationPropertiesKey = @"kFTPenNotificationPropertiesKey";
NSString * const kFTPenDidWriteHasListenerNotificationName = @"com.fiftythree.pen.didWriteHasListener";

NSString * const kFTPenNamePropertyName = @"name";
NSString * const kFTPenInactivityTimeoutPropertyName = @"inactivityTimeout";
NSString * const kFTPenPressureSetupPropertyName = @"pressureSetup";
NSString * const kFTPenMotionSetupPropertyName = @"motionSetup";
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
NSString * const kFTPenNumResetsPropertyName = @"numResets";
NSString * const kFTPenNumLinkTerminationsPropertyName = @"numLinkTerminations";
NSString * const kFTPenNumDroppedNotificationsPropertyName = @"numDroppedNotifications";
NSString * const kFTPenConnectedSecondsPropertyName = @"numDroppedNotifications";

NSString * const kFTPenManufacturingIDPropertyName = @"manufacturingID";
NSString * const kFTPenLastErrorCodePropertyName = @"lastErrorCode";
NSString * const kFTPenAuthenticationCodePropertyName = @"authenticationCode";
NSString * const kFTPenHasListenerPropertyName = @"hasListener";
NSString * const kFTPenAccelerationPropertyName = @"acceleration";

@implementation FTMotionSetup

- (id)initWithSamplePeriodMilliseconds:(uint8_t)samplePeriodMilliseconds
         notificatinPeriodMilliseconds:(uint8_t)notificatinPeriodMilliseconds
{
    self = [super init];
    if (self)
    {
        _samplePeriodMilliseconds = samplePeriodMilliseconds;
        _notificatinPeriodMilliseconds = notificatinPeriodMilliseconds;
    }
    return self;
}

- (id)initWithNSData:(NSData *)data
{
    FTAssert(data.length == 2, @"FTMotionSetup data is 2 bytes long");

    self = [super init];
    if (self)
    {
        uint8_t *bytes = (uint8_t *)data.bytes;
        _samplePeriodMilliseconds = bytes[0];
        _notificatinPeriodMilliseconds = bytes[1];
    }

    return self;
}

- (void)writeToNSData:(NSData *)data
{
    FTAssert(data.length == 2, @"FTMotionSetup data is 2 bytes long");

    uint8_t *bytes = (uint8_t *)data.bytes;
    bytes[0] = _samplePeriodMilliseconds;
    bytes[1] = _notificatinPeriodMilliseconds;
}

@end

@implementation FTPenPressureSetup

- (id)initWithSamplePeriodMilliseconds:(uint8_t)samplePeriodMilliseconds
         notificatinPeriodMilliseconds:(uint8_t)notificatinPeriodMilliseconds
                     tipFloorThreshold:(uint8_t)tipFloorThreshold
                       tipMinThreshold:(uint8_t)tipMinThreshold
                       tipMaxThreshold:(uint8_t)tipMaxThreshold
                            isTipGated:(BOOL)isTipGated
                  eraserFloorThreshold:(uint8_t)eraserFloorThreshold
                    eraserMinThreshold:(uint8_t)eraserMinThreshold
                    eraserMaxThreshold:(uint8_t)eraserMaxThreshold
                         isEraserGated:(BOOL)isEraserGated
{
    self = [super init];
    if (self)
    {
        _samplePeriodMilliseconds = samplePeriodMilliseconds;
        _notificatinPeriodMilliseconds = notificatinPeriodMilliseconds;
        _tipFloorThreshold = tipFloorThreshold;
        _tipMinThreshold = tipMinThreshold;
        _tipMaxThreshold = tipMaxThreshold;
        _isTipGated = isTipGated;
        _eraserFloorThreshold = eraserFloorThreshold;
        _eraserMinThreshold = eraserMinThreshold;
        _eraserMaxThreshold = eraserMaxThreshold;
        _isEraserGated = isEraserGated;
    }
    return self;
}

- (id)initWithNSData:(NSData *)data
{
    FTAssert(data.length == 10, @"PressureSetup data is 10 bytes long");

    self = [super init];
    if (self)
    {
        uint8_t *bytes = (uint8_t *)data.bytes;
        _samplePeriodMilliseconds = bytes[0];
        _notificatinPeriodMilliseconds = bytes[1];
        _tipFloorThreshold = bytes[2];
        _tipMinThreshold = bytes[3];
        _tipMaxThreshold = bytes[4];
        _isTipGated = bytes[5] ? YES : NO;
        _eraserFloorThreshold = bytes[6];
        _eraserMinThreshold = bytes[7];
        _eraserMaxThreshold = bytes[8];
        _isEraserGated = bytes[9] ? YES : NO;
    }
    return self;
}

- (void)writeToNSData:(NSData *)data
{
    FTAssert(data.length == 10, @"PressureSetup data is 10 bytes long");

    uint8_t *bytes = (uint8_t *)data.bytes;
    bytes[0] = _samplePeriodMilliseconds;
    bytes[1] = _notificatinPeriodMilliseconds;
    bytes[2] = _tipFloorThreshold;
    bytes[3] = _tipMinThreshold;
    bytes[4] = _tipMaxThreshold;
    bytes[5] = _isTipGated ? 1 : 0;
    bytes[6] = _eraserFloorThreshold;
    bytes[7] = _eraserMinThreshold;
    bytes[8] = _eraserMaxThreshold;
    bytes[9] = _isEraserGated ? 1 : 0;
}

@end

@implementation FTPenLastErrorCode
- (id)initWithErrorID:(int)errorID andErrorValue:(int)errorValue
{
    self = [super init];
    if (self)
    {
        _lastErrorID = errorID;
        _lastErrorValue = errorValue;
    }
    return self;
}
@end

@interface FTPen () <FTPenServiceClientDelegate, FTPenUsageServiceClientDelegate, FTDeviceInfoServiceClientDelegate>

@property (nonatomic) FTPeripheralDelegate *peripheralDelegate;

@property (nonatomic) FTPenServiceClient *penServiceClient;
@property (nonatomic) FTPenUsageServiceClient *penUsageServiceClient;
@property (nonatomic) FTDeviceInfoServiceClient *deviceInfoServiceClient;

@property (nonatomic, readwrite) NSString *name;
@property (nonatomic, readwrite) NSString *manufacturer;

@end

@implementation FTPen

#pragma mark - Initialization

- (id)initWithPeripheral:(CBPeripheral *)peripheral
{
    FTAssert(peripheral, @"peripheral non-nil");
    FTAssert(peripheral.state == CBPeripheralStateDisconnected, @"peripheral is disconnected");

    self = [super init];
    if (self)
    {
        _peripheral = peripheral;

        _peripheralDelegate = [[FTPeripheralDelegate alloc] init];
        _peripheral.delegate = _peripheralDelegate;

        // Pen Service client
        _penServiceClient = [[FTPenServiceClient alloc] initWithPeripheral:_peripheral];
        _penServiceClient.delegate = self;
        [_peripheralDelegate addServiceClient:_penServiceClient];
    }

    return self;
}

#pragma mark - Properties

- (BOOL)readManufacturingIDAndAuthCode
{
    return [self.penServiceClient readManufacturingIDAndAuthCode];
}

- (NSInteger)inactivityTimeout
{
    return [self.penServiceClient inactivityTimeout];
}

- (FTPenPressureSetup *)pressureSetup
{
    return [self.penServiceClient pressureSetup];
}

- (void)setPressureSetup:(FTPenPressureSetup *)pressureSetup
{
    self.penServiceClient.pressureSetup = pressureSetup;
}

- (FTMotionSetup *)motionSetup
{
    return [self.penServiceClient motionSetup];
}

- (void)setMotionSetup:(FTMotionSetup *)motionSetup
{
    self.penServiceClient.motionSetup = motionSetup;
}

- (void)setInactivityTimeout:(NSInteger)inactivityTimeout
{
    [self.penServiceClient setInactivityTimeout:inactivityTimeout];
}

- (FTPenLastErrorCode *)lastErrorCode
{
    return self.penServiceClient.lastErrorCode;
}

- (void)clearLastErrorCode
{
    [self.penServiceClient clearLastErrorCode];
}

- (NSData *)authenticationCode
{
    return self.penServiceClient.authenticationCode;
}

- (void)setAuthenticationCode:(NSData *)authenticationCode
{
    self.penServiceClient.authenticationCode = authenticationCode;
}

- (BOOL)canWriteCentralId
{
    return self.penServiceClient.canWriteCentralId;
}

- (UInt32)centralId
{
    return self.penServiceClient.centralId;
}

- (void)setCentralId:(UInt32)centralId
{
    self.penServiceClient.centralId = centralId;
}

- (BOOL)isTipPressed
{
    return self.penServiceClient.isTipPressed;
}

- (BOOL)isEraserPressed
{
    return self.penServiceClient.isEraserPressed;
}

- (BOOL)isReady
{
    return self.penServiceClient.isReady;
}

- (float)tipPressure
{
    return self.penServiceClient.tipPressure;
}

- (float)eraserPressure
{
    return self.penServiceClient.eraserPressure;
}

- (NSNumber *)batteryLevel
{
    return self.penServiceClient.batteryLevel;
}
- (FTMotionSample)motion
{
    return self.penServiceClient.motion;
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

- (NSString *)manufacturingID
{
    return self.penServiceClient.manufacturingID;
}

- (BOOL)canWriteHasListener
{
    return self.penServiceClient.canWriteHasListener;
}

- (BOOL)hasListenerSupportsNotifications
{
    return self.penServiceClient.hasListenerSupportsNotifications;
}

- (BOOL)hasListener
{
    return self.penServiceClient.hasListener;
}

- (void)setHasListener:(BOOL)hasListener
{
    self.penServiceClient.hasListener = hasListener;
}

- (void)setManufacturingID:(NSString *)manufacturingID
{
    self.penServiceClient.manufacturingID = manufacturingID;

    // The model number and serial number charateristics of the device info service change as a result of
    // setting the manufacturing ID, so refresh them now.
    [self.deviceInfoServiceClient refreshModelNumberAndSerialNumber];
}

#pragma mark - Usage properties

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

- (NSUInteger)numResets
{
    return self.penUsageServiceClient.numResets;
}

- (NSUInteger)numLinkTerminations
{
    return self.penUsageServiceClient.numLinkTerminations;
}

- (NSUInteger)numDroppedNotifications
{
    return self.penUsageServiceClient.numDroppedNotifications;
}

- (NSUInteger)connectedSeconds
{
    return self.penUsageServiceClient.connectedSeconds;
}

- (void)readUsageProperties
{
    [self.penUsageServiceClient readUsageProperties];

    if (!self.penUsageServiceClient)
    {
        self.penUsageServiceClient = [[FTPenUsageServiceClient alloc] initWithPeripheral:_peripheral];
        self.penUsageServiceClient.delegate = self;
        [self.peripheralDelegate addServiceClient:_penUsageServiceClient];

        [self ensureServicesDiscovered];
    }
}

- (void)refreshFirmwareVersionProperties
{
    [self.deviceInfoServiceClient refreshFirmwareRevisions];
}

#pragma mark -

- (void)peripheralConnectionStatusDidChange
{
    if (self.peripheral.state == CBPeripheralStateConnected)
    {
        FTAssert(self.peripheral.delegate == self.peripheralDelegate,
                 @"peripheral delegate is installed");

        MLOG_INFO(FTLogSDK, "Peripheral is connected.");
    }
    else
    {
        MLOG_INFO(FTLogSDK, "Peripheral was disconnected.");
    }

    [self ensureServicesDiscovered];
}

- (void)ensureServicesDiscovered
{
    BOOL peripheralIsConnected = (self.peripheral.state == CBPeripheralStateConnected);

    NSArray *servicesToBeDiscovered = [self.peripheralDelegate ensureServicesForConnectionState:peripheralIsConnected];

    if (peripheralIsConnected)
    {
        FTAssert(self.peripheral.delegate == self.peripheralDelegate,
                 @"peripheral delegate is installed");

        [self.peripheral discoverServices:servicesToBeDiscovered];
    }
    else
    {
        FTAssert(servicesToBeDiscovered.count == 0,
                 @"Should not attempt to discover services if not connected");
    }
}

#pragma mark - FTPenServiceClientDelegate

- (void)penServiceClient:(FTPenServiceClient *)penServiceClient didUpdatePenProperties:(NSSet *)updatedProperties
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenDidUpdatePrivatePropertiesNotificationName
                                                        object:self
                                                      userInfo:@{ kFTPenNotificationPropertiesKey : updatedProperties }];
}

- (void)penServiceClient:(FTPenServiceClient *)penServiceClient didEncounterError:(NSError *)error
{
    MLOG_ERROR(FTLogSDK, "Pen did encounter error: \"%s\"", ObjcDescription(error.localizedDescription));

    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenDidEncounterErrorNotificationName
                                                        object:self];

}

- (void)penServiceClient:(FTPenServiceClient *)penServiceClient isReadyDidChange:(BOOL)isReady
{
    if ([self.privateDelegate respondsToSelector:@selector(pen:isReadyDidChange:)])
    {
        [self.privateDelegate pen:self isReadyDidChange:isReady];
    }

    if (!self.deviceInfoServiceClient)
    {
        self.deviceInfoServiceClient = [[FTDeviceInfoServiceClient alloc] initWithPeripheral:_peripheral];
        self.deviceInfoServiceClient.delegate = self;
        [self.peripheralDelegate addServiceClient:_deviceInfoServiceClient];
        [self ensureServicesDiscovered];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenIsReadyDidChangeNotificationName
                                                        object:self];
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

- (void)penServiceClient:(FTPenServiceClient *)penServiceClient didUpdateTipPressure:(float)tipPressure
{
    if ([self.delegate respondsToSelector:@selector(pen:tipPressureDidChange:)])
    {
        [self.delegate pen:self tipPressureDidChange:tipPressure];
    }
}

- (void)penServiceClient:(FTPenServiceClient *)penServiceClient didUpdateEraserPressure:(float)eraserPressure
{
    if ([self.delegate respondsToSelector:@selector(pen:eraserPressureDidChange:)])
    {
        [self.delegate pen:self eraserPressureDidChange:eraserPressure];
    }
}

- (void)penServiceClient:(FTPenServiceClient *)penServiceClient didUpdateMotion:(FTMotionSample)motion
{
    if ([self.delegate respondsToSelector:@selector(pen:motionDidChange:)])
    {
        [self.delegate pen:self motionDidChange:motion];
    }
}

- (void)penServiceClient:(FTPenServiceClient *)penServiceClient batteryLevelDidChange:(NSNumber *)batteryLevel
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenBatteryLevelDidChangeNotificationName
                                                        object:self];

    if ([self.delegate respondsToSelector:@selector(pen:batteryLevelDidChange:)])
    {
        [self.delegate pen:self batteryLevelDidChange:batteryLevel];
    }
}

- (void)penServiceClientDidWriteManufacturingID:(FTPenServiceClient *)serviceClient
{
    [self.privateDelegate didWriteManufacturingID];
}

- (void)penServiceClientDidFailToWriteManufacturingID:(FTPenServiceClient *)serviceClient
{
    [self.privateDelegate didFailToWriteManufacturingID];
}

- (void)penServiceClient:(FTPenServiceClient *)serviceClient didReadManufacturingID:(NSString *)manufacturingID
{
    [self.privateDelegate didReadManufacturingID:manufacturingID];
}

- (void)penServiceClientDidWriteAuthenticationCode:(FTPenServiceClient *)serviceClient
{
    [self.privateDelegate didWriteAuthenticationCode];
}

- (void)penServiceClientDidFailToWriteAuthenticationCode:(FTPenServiceClient *)serviceClient
{
    [self.privateDelegate didFailToWriteAuthenticationCode];
}

- (void)penServiceClient:(FTPenServiceClient *)serviceClient didReadAuthenticationCode:(NSData *)authenticationCode
{
    [self.privateDelegate didReadAuthenticationCode:authenticationCode];
}

- (void)penServiceClientDidFailToWriteCentralId:(FTPenServiceClient *)serviceClient
{
}
- (void)penServiceClientDidWriteCentralId:(FTPenServiceClient *)serviceClient
{
}

#pragma mark - FTPenUsageServiceClientDelegate

- (void)didUpdateUsageProperties:(NSSet *)updatedProperties
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenDidUpdatePrivatePropertiesNotificationName
                                                        object:self
                                                      userInfo:@{ kFTPenNotificationPropertiesKey:updatedProperties }];
    [self.privateDelegate didUpdateUsageProperties:updatedProperties];
}

#pragma mark - FTDeviceInfoServiceClientDelegate

- (void)deviceInfoServiceClientDidUpdateDeviceInfo:(FTDeviceInfoServiceClient *)deviceInfoServiceClient
                                 updatedProperties:(NSSet *)updatedProperties
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenDidUpdatePropertiesNotificationName
                                                        object:self
                                                      userInfo:@{ kFTPenNotificationPropertiesKey : updatedProperties }];
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

#pragma mark - Model

- (NSNumber *)isAluminumPencil
{
    if (!self.modelNumber)
    {
        return nil;
    }
    // Example modelNumber: 53PA02
    NSString *modelNumber = self.modelNumber;
    NSString *metalModelNumberPrefix = @"53PA";
    return @([modelNumber hasPrefix:metalModelNumberPrefix]);
}

@end
