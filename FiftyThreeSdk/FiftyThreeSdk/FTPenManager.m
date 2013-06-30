//
//  FTPenManager.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTPenManager.h"
#import "FTPenManager+Private.h"
#import <CoreBluetooth/CoreBluetooth.h>
#include "FTServiceUUIDs.h"
#import "FTPen.h"
#import "FTPen+Private.h"
#import "FTDeviceInfoClient.h"
#import "TIUpdateManager.h"
#import "FTFirmwareManager.h"

typedef enum
{
    ConnectionState_Single,
    ConnectionState_Dating,
    ConnectionState_Dating_AttemptingConnection,
    ConnectionState_Engaged_WaitingForTipRelease,
    ConnectionState_Engaged_WaitingForPairingSpotRelease,
    ConnectionState_Engaged,
    ConnectionState_Married,
    ConnectionState_AwaitingDisconnection,
} ConnectionState;

NSString *ConnectionStateString(ConnectionState connectionState)
{
    switch (connectionState)
    {
        case ConnectionState_Single: return @"ConnectionState_Single";
        case ConnectionState_Dating: return @"ConnectionState_Dating";
        case ConnectionState_Dating_AttemptingConnection: return @"ConnectionState_Dating_AttemptingConnection";
        case ConnectionState_Engaged: return @"ConnectionState_Engaged";
        case ConnectionState_Engaged_WaitingForTipRelease: return @"ConnectionState_Engaged_WaitingForTipRelease";
        case ConnectionState_Engaged_WaitingForPairingSpotRelease: return @"ConnectionState_Engaged_WaitingForPairingSpotRelease";
        case ConnectionState_Married: return @"ConnectionState_Married";
        case ConnectionState_AwaitingDisconnection: return @"ConectionState_AwaitingDisconnection";
        default:
            return nil;
    }
}

NSString * const kPairedPenUuidDefaultsKey = @"PairedPenUuid";
static const int kInterruptedUpdateDelayMax = 30;
static const double kPairingReleaseWindowSeconds = 0.100;

@interface FTPenManager () <CBCentralManagerDelegate, FTPenPrivateDelegate, TIUpdateManagerDelegate>

@property (nonatomic) CBCentralManager *centralManager;
@property (nonatomic) TIUpdateManager *updateManager;

@property (nonatomic, readwrite) FTPenManagerState state;
@property (nonatomic) ConnectionState connectionState;

@property (nonatomic) BOOL isScanningForPeripherals;

@property (nonatomic) NSDate *lastPairingSpotReleaseTime;

@property (nonatomic, readwrite) FTPen *pen;

@end

@implementation FTPenManager

- (id)initWithDelegate:(id<FTPenManagerDelegate>)delegate;
{
    self = [super init];
    if (self)
    {
        _delegate = delegate;

        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        _connectionState = ConnectionState_Single;

        _state = FTPenManagerStateUnavailable;
    }

    return self;
}

#pragma mark - Properties

- (void)setPen:(FTPen *)pen
{
    _pen.privateDelegate = nil;
    _pen = pen;
    _pen.privateDelegate = self;

    [[NSNotificationCenter defaultCenter] removeObserver:kFTPenIsTipPressedDidChangeNotificationName];
    if (_pen)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(penIsTipPressedDidChange:)
                                                     name:kFTPenIsTipPressedDidChangeNotificationName
                                                   object:nil];
    }
}

- (void)penIsTipPressedDidChange:(NSNotification *)notification
{
    if (!self.pen.isTipPressed && self.pen.lastTipReleaseTime)
    {
        if (self.connectionState == ConnectionState_Engaged)
        {
            [self transitionConnectionStateToEngaged_WaitingForPairPairingSpotRelease];
        }
        else if (self.connectionState == ConnectionState_Engaged_WaitingForTipRelease)
        {
            [self transitionConnectionStateFromEngagedSubstate];
        }
    }
}

#pragma mark - ConnectionState

- (void)setConnectionState:(ConnectionState)connectionState
{
    printf("\n");
    NSLog(@"State changed: %@ -> %@",
          ConnectionStateString(_connectionState),
          ConnectionStateString(connectionState));

    _connectionState = connectionState;

    [self verifyInternalConsistency];
}

- (void)verifyInternalConsistency
{
    switch (self.connectionState)
    {
        case ConnectionState_Single:
        case ConnectionState_Dating:
        {
            NSAssert(!self.pen, @"");
            break;
        }
        default:
        {
            NSAssert(self.pen, @"");
        }
    }

    switch (self.connectionState)
    {
        case ConnectionState_Dating:
        {
            NSAssert(self.isScanningForPeripherals, @"");
            break;
        }
        default:
        {
            NSAssert(!self.isScanningForPeripherals, @"");
        }
    }
}

#pragma mark - State Transitions

- (void)transitionConnectionStateToSingle
{
    // TODO: enumerate possible states from which we may be transitioning

    self.connectionState = ConnectionState_Single;
}

- (void)transitionConnectionStateToAwaitingDisconnection
{
    if (self.pen)
    {
        [self.centralManager cancelPeripheralConnection:self.pen.peripheral];

        self.connectionState = ConnectionState_AwaitingDisconnection;
    }
    else
    {
        [self transitionConnectionStateToSingle];
    }
}

- (void)transitionConnectionStateToDating
{
    NSAssert(self.connectionState == ConnectionState_Single, @"");

    self.isScanningForPeripherals = YES;

    self.connectionState = ConnectionState_Dating;
}

- (void)transitionConnectionStateToDating_AttemptingConnection:(CBPeripheral *)peripheral
{
    NSAssert(self.connectionState == ConnectionState_Dating, @"");

    self.isScanningForPeripherals = NO;

    self.pen = [[FTPen alloc] initWithCentralManager:self.centralManager peripheral:peripheral];

    [self.centralManager connectPeripheral:peripheral options:nil];

    self.connectionState = ConnectionState_Dating_AttemptingConnection;
}

- (void)transitionConnectionStateToEngaged
{
    NSAssert(self.connectionState == ConnectionState_Dating_AttemptingConnection, @"");

    self.connectionState = ConnectionState_Engaged;
}

- (void)transitionConnectionStateToEngaged_WaitingForTipRelease
{
    NSAssert(self.connectionState == ConnectionState_Engaged, @"");

    self.connectionState = ConnectionState_Engaged_WaitingForTipRelease;
}

- (void)transitionConnectionStateToEngaged_WaitingForPairPairingSpotRelease
{
    NSAssert(self.connectionState == ConnectionState_Engaged, @"");

    self.connectionState = ConnectionState_Engaged_WaitingForPairingSpotRelease;
}

- (void)transitionConnectionStateFromEngagedSubstate
{
    NSAssert(self.connectionState == ConnectionState_Engaged_WaitingForPairingSpotRelease ||
             self.connectionState == ConnectionState_Engaged_WaitingForTipRelease, @"");
    NSAssert(self.lastPairingSpotReleaseTime && self.pen.lastTipReleaseTime, @"");

    static const NSTimeInterval kTipAndPairingSpotReleaseTimeDifferenceThreshold = 0.1;

    NSDate *t0 = self.lastPairingSpotReleaseTime;
    NSDate *t1 = self.pen.lastTipReleaseTime;
    NSTimeInterval tipAndPairingSpoteReleaseTimeDifference = fabs([t0 timeIntervalSinceDate:t1]);
    NSLog(@"Difference in pairing spot and tip press release times (ms): %f.",
          tipAndPairingSpoteReleaseTimeDifference * 1000.0);

    if (tipAndPairingSpoteReleaseTimeDifference < kTipAndPairingSpotReleaseTimeDifferenceThreshold)
    {
        [self transitionConnectionStateToMarried];
    }
    else
    {
        [self transitionConnectionStateToAwaitingDisconnection];
    }
}

- (void)transitionConnectionStateToMarried
{
    NSAssert(self.connectionState == ConnectionState_Engaged_WaitingForPairingSpotRelease ||
             self.connectionState == ConnectionState_Engaged_WaitingForTipRelease, @"");

    self.connectionState = ConnectionState_Married;
}

#pragma mark - Pairing Spot

- (void)pairingSpotWasPressed
{
    NSLog(@"Pairing spot was pressed.");

    if (self.connectionState == ConnectionState_Single)
    {
        [self transitionConnectionStateToDating];
    }
}

- (void)pairingSpotWasReleased
{
    NSLog(@"Pairing spot was released.");

    self.isScanningForPeripherals = NO;

    self.lastPairingSpotReleaseTime = [NSDate date];

    if (self.connectionState == ConnectionState_Dating)
    {
        [self transitionConnectionStateToSingle];
    }
    else if (self.connectionState == ConnectionState_Dating_AttemptingConnection)
    {
        // If we were in the middle of connecting, but the pairing spot was released prematurely, then cancel
        // the connection. The pen must be connected and ready in order to transition to the "engaged" state.
        [self transitionConnectionStateToAwaitingDisconnection];
    }
    else if (self.connectionState == ConnectionState_Engaged)
    {
        [self transitionConnectionStateToEngaged_WaitingForTipRelease];
    }
    else if (self.connectionState == ConnectionState_Engaged_WaitingForPairingSpotRelease)
    {
        [self transitionConnectionStateFromEngagedSubstate];
    }
}

//
//- (void)startFalsePairingTimer
//{
//    if (self.falsePairingTimer)
//    {
//        return;
//    }
//
//    self.falsePairingTimer = [NSTimer scheduledTimerWithTimeInterval:kPairingReleaseWindowSeconds
//                                                              target:self
//                                                            selector:@selector(falsePairingTimerExpired:)
//                                                            userInfo:nil
//                                                             repeats:NO];
//}
//
//- (void)resetFalsePairingInfo
//{
//    if (self.falsePairingTimer)
//    {
//        [self.falsePairingTimer invalidate];
//        self.falsePairingTimer = nil;
//    }
//
//    self.lastReleaseTime = nil;
//    self.stopPairingTime = nil;
//}
//
//- (void)falsePairingTimerExpired:(NSTimer *)timer
//{
//    self.falsePairingTimer = nil;
//
//    NSTimeInterval diff = ABS([self.lastReleaseTime timeIntervalSinceDate:self.stopPairingTime]);
//    NSLog(@"checkForFalsePairing, diff=%g", diff);
//    if (self.lastReleaseTime == 0
//        || self.stopPairingTime == 0
//        || diff > kPairingReleaseWindowSeconds)
//    {
//        if (self.pairedPen)
//        {
//            [self deletePairedPen:self.pairedPen];
//        }
//    }
//
//    [self endPairingProcess];
//}
//
// For clients only, internal code should call endPairingProcess
//- (void)stopPairing
//{
//    self.stopPairingTime = [NSDate date];
//    if (!self.newlyPaired)
//    {
//        [self endPairingProcess];
//    }
//    else
//    {
//        [self startFalsePairingTimer];
//    }
//}
//
//- (void)endPairingProcess
//{
//    NSLog(@"endPairingProcess");
//
//    [self resetFalsePairingInfo];
//
//    [self.pairingTimer invalidate];
//    self.pairingTimer = nil;
//
//    self.pairing = NO;
//    self.newlyPaired = NO;
//    [self.centralManager stopScan];
//
//    [self reconnect];
//}
//
//- (void)pairingTimerExpired:(NSTimer *)timer
//{
//    NSLog(@"pairingTimerExpired");
//
//    self.pairingTimer = nil;
//
//    if (self.trialSeparationTimer)
//    {
//        // We didn't find it, so unpair
//        NSLog(@"Removing paired device");
//
//        [self.trialSeparationTimer invalidate];
//        self.trialSeparationTimer = nil;
//        if (self.pairedPen)
//        {
//            [self deletePairedPen:self.pairedPen];
//        }
//
//        [self endPairingProcess];
//    }
//    else if (self.closestPen)
//    {
//        [self connectPen:self.closestPen];
//    }
//}
//
//- (void)connect
//{
//    if (!self.pen && self.pairedPen)
//    {
//        [self connectPen:self.pairedPen];
//    }
//}
//
//- (void)reconnect
//{
//    if (self.autoConnect
//        && !self.pen
//        && !self.pairing
//        && !self.trialSeparationTimer)
//    {
//        NSLog(@"auto reconnect");
//        [self connect];
//    }
//}

- (void)disconnect
{
    if (self.pen)
    {
        [self.centralManager cancelPeripheralConnection:self.pen.peripheral];
    }

    // Ensure we don't retry update when disconnect was initiated by the central.
    if (self.updateManager)
    {
        self.updateManager = nil;
    }
}

- (void)updateState:(FTPenManagerState)state
{
    self.state = state;
    [self.delegate penManagerDidUpdateState:self];
}

//- (void)savePairedPen:(FTPen *)pen
//{
//    NSAssert(pen, nil);
//
//    CFUUIDRef uuid = pen.peripheral.UUID;
//    NSString* uuidString = uuid != nil ? CFBridgingRelease(CFUUIDCreateString(NULL, uuid)) : nil;
//
//    [[NSUserDefaults standardUserDefaults] setValue:uuidString
//                                             forKey:kPairedPenUuidDefaultsKey];
//    [[NSUserDefaults standardUserDefaults] synchronize];
//}
//
//- (void)loadPairedPen
//{
//    NSString *uuid = [[NSUserDefaults standardUserDefaults] stringForKey:kPairedPenUuidDefaultsKey];
//    if (uuid) {
//        [self.centralManager retrievePeripherals:@[CFBridgingRelease(CFUUIDCreateFromString(NULL, (CFStringRef)uuid))]];
//    } else {
//        [self updateState:FTPenManagerStateAvailable];
//    }
//}
//
//- (void)deletePairedPen:(FTPen *)pen
//{
//    NSAssert(pen, nil);
//
//    if (self.pen == pen)
//    {
//        [self disconnect];
//    }
//
//    if (self.pairedPen == pen)
//    {
//        self.pairedPen = nil;
//
//        [[NSUserDefaults standardUserDefaults] setValue:nil
//                                                 forKey:kPairedPenUuidDefaultsKey];
//        [[NSUserDefaults standardUserDefaults] synchronize];
//
//        [self.delegate penManager:self didUnpairFromPen:pen];
//    }
//}
//
//- (void)didConnectToPen:(FTPen *)pen
//{
//    NSAssert(pen, nil);
//
//    if (self.pairing)
//    {
//        self.pairedPen = pen;
//        self.newlyPaired = YES;
//
//        [self savePairedPen:pen];
//
//        [self.delegate penManager:self didPairWithPen:self.pairedPen];
//    }
//
//    if (self.updateManager)
//    {
//        if (-[self.updateManager.updateStartTime timeIntervalSinceNow] < kInterruptedUpdateDelayMax)
//        {
//            [self updateFirmwareForPen:self.pen];
//            return;
//        }
//        else
//        {
//            self.updateManager = nil;
//        }
//    }
//
//    [self.delegate penManager:self didConnectToPen:self.pairedPen];
//
//    // Now that we are connected update the device info
//    [self.pen getInfo:^(FTPen *client, NSError *error) {
//        if (error) {
//            // We failed to get info, but that's ok, continue anyway
//            NSLog(@"Failed to get device info, error=%@", [error localizedDescription]);
//        }
//
//        if (!self.pen) return;
//        [self.delegate penManager:self didUpdateDeviceInfo:self.pen];
//
//        [self.pen getBattery:^(FTPen *client, NSError *error) {
//            if (error) {
//                // We failed to get info, but that's ok, continue anyway
//                NSLog(@"Failed to get device info, error=%@", [error localizedDescription]);
//            }
//
//            if (!self.pen) return;
//            [self.delegate penManager:self didUpdateDeviceBatteryLevel:self.pen];
//        }];
//    }];
//}
//
//- (void)cleanup
//{
//    if (!self.pen.peripheral.isConnected)
//    {
//        return;
//    }
//
//    // See if we are subscribed to a characteristic on the peripheral
//    if (self.pen.peripheral.services != nil)
//    {
//        for (CBService *service in self.pen.peripheral.services)
//        {
//            if (service.characteristics != nil)
//            {
//                for (CBCharacteristic *characteristic in service.characteristics)
//                {
//                    if ([characteristic.UUID isEqual:[FTPenServiceUUIDs isTipPressed]] ||
//                        [characteristic.UUID isEqual:[FTPenServiceUUIDs isEraserPressed]])
//                    {
//                        if (characteristic.isNotifying)
//                        {
//                            [self.pen.peripheral setNotifyValue:NO forCharacteristic:characteristic];
//                            return;
//                        }
//                    }
//                }
//            }
//        }
//    }
//
//    // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
//    [self.centralManager cancelPeripheralConnection:self.pen.peripheral];
//}

- (void)startTrialSeparation
{
    NSLog(@"Start trial separation.");

    [self writeBoolValue:YES forCharacteristicWithUUID:[FTPenServiceUUIDs shouldSwing]];
}

- (void)stopTrialSeparation:(NSTimer *)timer
{
    NSLog(@"Stop trial separation.");
}

#pragma mark - FTPenPrivateDelegate

- (void)pen:(FTPen *)pen isReadyDidChange:(BOOL)isReady
{
    if (isReady)
    {
        NSLog(@"Pen is ready.");

        [self.delegate penManager:self didConnectToPen:self.pen];
        [self transitionConnectionStateToEngaged];
    }
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    // TODO: Handle the other cases gracefully.
    NSAssert(central.state == CBCentralManagerStatePoweredOn, @"Assume central manager state = powered on");
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    NSLog(@"Discovered peripheral with name: \"%@\" and RSSI: %d.", peripheral.name, [RSSI integerValue]);

    if (self.connectionState == ConnectionState_Dating)
    {
        [self transitionConnectionStateToDating_AttemptingConnection:peripheral];
    }

//    int rssiValue = [RSSI integerValue];
//    if (self.trialSeparationTimer && self.pairedPen)
//    {
//        self.trialSeparationTimer = nil;
//
//        [self endPairingProcess];
//        return;
//    }
//
//    if (self.closestPen.peripheral == peripheral)
//    {
//        [self.closestPen updateData:advertisementData];
//    }
//    else if (rssiValue > self.maxRSSI || self.maxRSSI == 0)
//    {
//        self.maxRSSI = rssiValue;
//        self.closestPen = [[FTPen alloc] initWithPeripheral:peripheral data:advertisementData];
//    }
//
//    if (self.pairing && !self.pairingTimer)
//    {
//        // Timer already expired without finding a pen, so connect immediately.
//        [self connectPen:self.closestPen];
//    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error
{
    NSAssert(self.connectionState == ConnectionState_Dating_AttemptingConnection, @"");

    NSLog(@"Failed to connect to peripheral: %@. (%@).", peripheral, [error localizedDescription]);

    [self.delegate penManager:self didFailConnectToPen:self.pen];

    self.pen = nil;
    self.state = ConnectionState_Single;
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSAssert(self.connectionState == ConnectionState_Dating_AttemptingConnection, @"");

    if (self.pen.peripheral == peripheral)
    {
        [self.pen peripheralConnectionStatusDidChange];
    }
    else
    {
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error
{
    NSAssert(peripheral == self.pen.peripheral, @"");

    if (self.updateManager)
    {
        if (-[self.updateManager.updateStartTime timeIntervalSinceNow] < kInterruptedUpdateDelayMax)
        {
            NSLog(@"Disconnected while performing update, attempting reconnect");

            [self performSelectorOnMainThread:@selector(connect) withObject:nil waitUntilDone:NO];
        }
        else
        {
            self.updateManager = nil;
        }
    }

    FTPen *pen = self.pen;
    self.pen = nil;

    [pen peripheralConnectionStatusDidChange];

    [self.delegate penManager:self didDisconnectFromPen:pen];

    [self transitionConnectionStateToSingle];
}

- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals
{
}

#pragma mark - Firmware

- (BOOL)isUpdateAvailableForPen:(FTPen *)pen
{
    NSAssert(pen, nil);

    return ([self isUpdateAvailableForPen:pen imageType:Factory] ||
            [self isUpdateAvailableForPen:pen imageType:Upgrade]);
}

- (BOOL)isUpdateAvailableForPen:(FTPen *)pen imageType:(FTFirmwareImageType)imageType
{
    NSAssert(pen, nil);

    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle:NSNumberFormatterDecimalStyle];

    NSInteger availableVersion = [FTFirmwareManager versionForModel:pen.modelNumber imageType:imageType];
    NSInteger existingVersion;
    if (imageType == Factory)
    {
        existingVersion = [f numberFromString:[pen.firmwareRevision componentsSeparatedByString:@" "][0]].integerValue;

        NSLog(@"Factory version: Available = %d, Existing = %d", availableVersion, existingVersion);
    }
    else
    {
        existingVersion = [f numberFromString:[pen.softwareRevision componentsSeparatedByString:@" "][0]].integerValue;

        NSLog(@"Upgrade version: Available = %d, Existing = %d", availableVersion, existingVersion);
    }

    return availableVersion > existingVersion;
}

- (void)updateFirmwareForPen:(FTPen *)pen
{
    NSAssert(pen, nil);

    FTFirmwareImageType imageType;
    if ([self isUpdateAvailableForPen:pen imageType:Factory])
    {
        imageType = Factory;
    }
    else if ([self isUpdateAvailableForPen:pen imageType:Upgrade])
    {
        imageType = Upgrade;
    }
    else
    {
        return;
    }

    NSString *filePath = [FTFirmwareManager filePathForModel:pen.modelNumber imageType:imageType];
    self.updateManager = [[TIUpdateManager alloc] initWithPeripheral:pen.peripheral delegate:self]; // BUGBUG - ugly cast

    [self.updateManager updateImage:filePath];
}

#pragma mark - TIUpdateManagerDelegate

- (void)updateManager:(TIUpdateManager *)manager didFinishUpdate:(NSError *)error
{
    NSAssert(manager, nil);

    self.updateManager = nil;

    if ([self.delegate conformsToProtocol:@protocol(FTPenManagerDelegatePrivate)])
    {
        id<FTPenManagerDelegatePrivate> d = (id<FTPenManagerDelegatePrivate>)self.delegate;
        [d penManager:self didFinishUpdate:error];
    }
}

- (void)updateManager:(TIUpdateManager *)manager didUpdatePercentComplete:(float)percent
{
    NSAssert(manager, nil);

    if ([self.delegate conformsToProtocol:@protocol(FTPenManagerDelegatePrivate)])
    {
        id<FTPenManagerDelegatePrivate> d = (id<FTPenManagerDelegatePrivate>)self.delegate;
        [d penManager:self didUpdatePercentComplete:percent];
    }
}

#pragma mark - Characteristics

// Finds the characteristic with the given UUID on the connected pen.
- (CBCharacteristic *)findCharacteristicWithUUID:(CBUUID *)characteristicUUID
{
    if (self.pen && self.pen.peripheral)
    {
        CBPeripheral *peripheral = self.pen.peripheral;

        for (CBService *service in peripheral.services)
        {
            for (CBCharacteristic *characteristic in service.characteristics)
            {
                if ([characteristic isEqual:characteristicUUID])
                {
                    return characteristic;
                }
            }
        }
    }

    return nil;
}

// Writes a boolean value to the connected pen for the characteristic with the given UUID.
- (void)writeBoolValue:(BOOL)value forCharacteristicWithUUID:(CBUUID *)characteristicUUID
{
    if (self.pen && self.pen.peripheral)
    {
        CBPeripheral *peripheral = self.pen.peripheral;

        CBCharacteristic *characteristic = [self findCharacteristicWithUUID:characteristicUUID];
        if (characteristic)
        {
            NSLog(@"CBPeripheral writeValue:forCharacterisitic");
            NSData *data = [NSData dataWithBytes:value ? "1" : "0" length:1];
            [peripheral writeValue:data
                 forCharacteristic:characteristic
                              type:CBCharacteristicWriteWithResponse];
        }
    }
}

#pragma mark - Peripheral Scanning

- (void)setIsScanningForPeripherals:(BOOL)isScanningForPeripherals
{
    if (_isScanningForPeripherals != isScanningForPeripherals)
    {
        _isScanningForPeripherals = isScanningForPeripherals;

        if (_isScanningForPeripherals)
        {
            NSLog(@"Begin scan for peripherals.");

            NSDictionary *options = @{ CBCentralManagerScanOptionAllowDuplicatesKey : @NO };
            [self.centralManager scanForPeripheralsWithServices:@[[FTPenServiceUUIDs penService]]
                                                        options:options];
        }
        else
        {
            NSLog(@"End scan for peripherals.");

            [self.centralManager stopScan];
        }
    }
}

@end
