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
#import "TIUpdateManager.h"
#import "FTFirmwareManager.h"

static const int kInterruptedUpdateDelayMax = 30;

static const NSTimeInterval kTipAndPairingSpotReleaseTimeDifferenceThreshold = 0.5;
static const NSTimeInterval kSwingingPeripheralPollingTimeInterval = 0.1;
static const NSTimeInterval kSeparatedPeripheralInactivityTimeInterval = 1.0 * 60.0;

typedef enum
{
    ConnectionState_Single,
    ConnectionState_Dating,
    ConnectionState_Dating_AttemptingConnection,
    ConnectionState_Engaged_WaitingForTipRelease,
    ConnectionState_Engaged_WaitingForPairingSpotRelease,
    ConnectionState_Engaged,
    ConnectionState_Married,
    ConnectionState_Swinging,
    ConnectionState_Reconciling,
    ConnectionState_Separated,
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
        case ConnectionState_Swinging: return @"ConnectionState_Swinging";
        case ConnectionState_Reconciling: return @"ConnectionState_Reconciling";
        case ConnectionState_Separated: return @"ConnectionState_Separated";
        case ConnectionState_AwaitingDisconnection: return @"ConectionState_AwaitingDisconnection";
        default:
            return nil;
    }
}

//NSString * const kPairedPenUuidDefaultsKey = @"PairedPenUuid";
//static const double kPairingReleaseWindowSeconds = 0.100;

@interface FTPenManager () <CBCentralManagerDelegate, TIUpdateManagerDelegate>

@property (nonatomic) CBCentralManager *centralManager;
@property (nonatomic) TIUpdateManager *updateManager;

@property (nonatomic, readwrite) FTPenManagerState state;
@property (nonatomic) ConnectionState connectionState;

@property (nonatomic) BOOL isScanningForPeripherals;

@property (nonatomic) NSTimer *maxEngagedSubstateDurationTimer;

@property (nonatomic) NSDate *lastPairingSpotReleaseTime;

@property (nonatomic, readwrite) FTPen *pen;

@property (nonatomic) CBUUID *swingingPeripheralUUID;
@property (nonatomic) NSTimer *swingingPeripheralPollingTimer;

@property (nonatomic) CBUUID *separatedPeripheralUUID;
@property (nonatomic) NSTimer *separatedPeripheralInactivityTimer;

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
    _pen = pen;

    [[NSNotificationCenter defaultCenter] removeObserver:kFTPenDidEncounterErrorNotificationName];
    [[NSNotificationCenter defaultCenter] removeObserver:kFTPenIsReadyDidChangeNotificationName];
    [[NSNotificationCenter defaultCenter] removeObserver:kFTPenIsTipPressedDidChangeNotificationName];

    if (_pen)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(penDidEncounterError:)
                                                     name:kFTPenDidEncounterErrorNotificationName
                                                   object:_pen];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(penIsReadyDidChange:)
                                                     name:kFTPenIsReadyDidChangeNotificationName
                                                   object:_pen];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(penIsTipPressedDidChange:)
                                                     name:kFTPenIsTipPressedDidChangeNotificationName
                                                   object:_pen];
    }
}

- (void)penDidEncounterError:(NSNotification *)notification
{
    [self handleError];
}

- (void)handleError
{
    NSLog(@"Pen did encounter error. Disconnecting.");

    if (self.connectionState == ConnectionState_Single)
    {

    }
    else if (self.connectionState == ConnectionState_AwaitingDisconnection)
    {

    }
    else if (self.connectionState == ConnectionState_Dating)
    {
        [self transitionConnectionStateToSingle];
    }
    else
    {
        [self transitionConnectionStateToAwaitingDisconnection];
    }
}

- (void)penIsReadyDidChange:(NSNotification *)notification
{
    if (self.pen.isReady)
    {
        NSLog(@"Pen is ready");

        if (self.connectionState == ConnectionState_Dating_AttemptingConnection)
        {
            [self transitionConnectionStateToEngaged];
        }
        else if (self.connectionState == ConnectionState_Reconciling ||
                 self.connectionState == ConnectionState_Separated)
        {
            [self transitionConnectionStateToMarried];
        }
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

    switch (self.connectionState)
    {
        case ConnectionState_Engaged_WaitingForPairingSpotRelease:
        case ConnectionState_Engaged_WaitingForTipRelease:
        {
            [self.maxEngagedSubstateDurationTimer invalidate];
            self.maxEngagedSubstateDurationTimer = nil;

            break;
        }
        case ConnectionState_Swinging:
        {
            [self.swingingPeripheralPollingTimer invalidate];
            self.swingingPeripheralPollingTimer = nil;
            self.swingingPeripheralUUID = nil;

            break;
        }
        case ConnectionState_Separated:
        {
            [self.separatedPeripheralInactivityTimer invalidate];
            self.separatedPeripheralInactivityTimer = nil;
            self.separatedPeripheralUUID = nil;

            self.isScanningForPeripherals = NO;

            break;
        }
        default:
            break;
    }

    _connectionState = connectionState;

    [self verifyInternalConsistency];
}

- (void)verifyInternalConsistency
{
    switch (self.connectionState)
    {
        case ConnectionState_Single:
        case ConnectionState_Dating:
        case ConnectionState_Separated:
        {
            NSAssert(!self.pen, @"");
            break;
        }
        default:
        {
            NSAssert(self.pen, @"");
            break;
        }
    };

    switch (self.connectionState)
    {
        case ConnectionState_Dating:
        case ConnectionState_Separated:
        {
            NSAssert(self.isScanningForPeripherals, @"");
            break;
        }
        case ConnectionState_Reconciling:
        {
            // isScanningForPeripherals can be either true or false
            break;
        }
        default:
        {
            NSAssert(!self.isScanningForPeripherals, @"");
            break;
        }
    };

    switch (self.connectionState)
    {
        case ConnectionState_Engaged_WaitingForPairingSpotRelease:
        case ConnectionState_Engaged_WaitingForTipRelease:
        {
            NSAssert(self.maxEngagedSubstateDurationTimer, @"");
            break;
        }
        default:
        {
            NSAssert(!self.maxEngagedSubstateDurationTimer, @"");
            break;
        }
    };

    switch (self.connectionState)
    {
        case ConnectionState_Swinging:
        {
            NSAssert(self.swingingPeripheralUUID, @"");
            NSAssert(self.swingingPeripheralPollingTimer, @"");
            break;
        }
        default:
        {
            NSAssert(!self.swingingPeripheralUUID, @"");
            NSAssert(!self.swingingPeripheralPollingTimer, @"");
            break;
        }
    };

    switch (self.connectionState)
    {
        case ConnectionState_Separated:
        {
            NSAssert(self.separatedPeripheralInactivityTimer, @"");
            NSAssert(self.separatedPeripheralUUID, @"");
            break;
        }
        default:
        {
            NSAssert(!self.separatedPeripheralInactivityTimer, @"");
            NSAssert(!self.separatedPeripheralUUID, @"");
            break;
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
    NSAssert(self.connectionState == ConnectionState_Single ||
             self.connectionState == ConnectionState_Separated, @"");

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

    [self startMaxEngagedSubstateDurationTimer];

    self.connectionState = ConnectionState_Engaged_WaitingForTipRelease;
}

- (void)transitionConnectionStateToEngaged_WaitingForPairPairingSpotRelease
{
    NSAssert(self.connectionState == ConnectionState_Engaged, @"");

    [self startMaxEngagedSubstateDurationTimer];

    self.connectionState = ConnectionState_Engaged_WaitingForPairingSpotRelease;
}

- (void)transitionConnectionStateFromEngagedSubstate
{
    NSAssert(self.connectionState == ConnectionState_Engaged_WaitingForPairingSpotRelease ||
             self.connectionState == ConnectionState_Engaged_WaitingForTipRelease, @"");
    NSAssert(self.lastPairingSpotReleaseTime && self.pen.lastTipReleaseTime, @"");

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
             self.connectionState == ConnectionState_Engaged_WaitingForTipRelease ||
             self.connectionState == ConnectionState_Reconciling, @"");

    [self.delegate penManager:self didConnectToPen:self.pen];

    self.connectionState = ConnectionState_Married;
}

- (void)transitionConnectionStateToSwinging
{
    NSAssert(self.connectionState == ConnectionState_Married, @"");
    NSAssert(self.pen.peripheral.isConnected, @"Peripheral is connected");
    NSAssert(self.pen.peripheral.UUID, @"Peripheral has non-null UUID");

    self.swingingPeripheralUUID = [CBUUID UUIDWithCFUUID:self.pen.peripheral.UUID];
    self.pen.shouldSwing = YES;

    self.swingingPeripheralPollingTimer = [NSTimer scheduledTimerWithTimeInterval:kSwingingPeripheralPollingTimeInterval
                                                                           target:self
                                                                         selector:@selector(swingingPeripheralPollingTimerFired:)
                                                                         userInfo:nil
                                                                          repeats:YES];

    self.connectionState = ConnectionState_Swinging;
}

- (void)swingingPeripheralPollingTimerFired:(NSTimer *)timer
{
    // TODO: This means the peripheral has not yet been disconnected. We should handle this more gracefully.
    if (!self.pen)
    {
        self.isScanningForPeripherals = !self.isScanningForPeripherals;
    }
}

- (void)transitionConnectionStateToReconciling:(CBPeripheral *)peripheral
{
    NSAssert(self.connectionState == ConnectionState_Swinging ||
             self.connectionState == ConnectionState_Separated, @"");

    self.isScanningForPeripherals = NO;

    self.pen = [[FTPen alloc] initWithCentralManager:self.centralManager peripheral:peripheral];
    self.pen.requiresTipBePressedToBecomeReady = NO;

    [self.centralManager connectPeripheral:peripheral options:nil];

    self.connectionState = ConnectionState_Reconciling;
}

- (void)transitionConnectionStateToSeparated
{
    NSAssert(self.connectionState == ConnectionState_Married ||
             self.connectionState == ConnectionState_Reconciling, @"");

    self.isScanningForPeripherals = YES;

    self.separatedPeripheralInactivityTimer = [NSTimer scheduledTimerWithTimeInterval:kSeparatedPeripheralInactivityTimeInterval
                                                                               target:self
                                                                             selector:@selector(separatedPeripheralInactivityTimerFired:)
                                                                             userInfo:nil
                                                                              repeats:NO];

    self.connectionState = ConnectionState_Separated;
}

- (void)separatedPeripheralInactivityTimerFired:(NSTimer *)timer
{
    NSAssert(self.connectionState == ConnectionState_Separated, @"");

    [self transitionConnectionStateToSingle];
}

#pragma mark - Max engaged substate duration timer

// Start a timer that fires if the amount of time spent in one of the engaged substates ("waiting for pairing
// spot release" or "waiting for tip release") exceeds the threshold. The idea is that we never want to wait
// indefinitely for a tip or pairing spot release that may never come. Better to boot out early if we know
// that even if it did come, it would be too late.
- (void)startMaxEngagedSubstateDurationTimer
{
    self.maxEngagedSubstateDurationTimer = [NSTimer scheduledTimerWithTimeInterval:kTipAndPairingSpotReleaseTimeDifferenceThreshold
                                                                            target:self
                                                                          selector:@selector(maxEngagedSubstateDurationTimerFired:)
                                                                          userInfo:nil
                                                                           repeats:NO];
}

- (void)maxEngagedSubstateDurationTimerFired:(NSTimer *)timer
{
    NSAssert(self.connectionState == ConnectionState_Engaged_WaitingForPairingSpotRelease ||
             self.connectionState == ConnectionState_Engaged_WaitingForTipRelease, @"");

    NSLog(@"Max duration in engaged substate exceeded. Disconnecting.");

    [self transitionConnectionStateToAwaitingDisconnection];
}

#pragma mark - Pairing Spot

- (void)pairingSpotWasPressed
{
    NSLog(@"Pairing spot was pressed.");

    if (self.connectionState == ConnectionState_Single)
    {
        [self transitionConnectionStateToDating];
    }
    else if (self.connectionState == ConnectionState_Separated)
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

- (void)startTrialSeparation
{
    if (self.connectionState == ConnectionState_Married)
    {
        [self transitionConnectionStateToSwinging];
    }
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    // TODO: Handle the other cases gracefully.
    NSAssert(central.state == CBCentralManagerStatePoweredOn, @"Assume central manager state = powered on");
}

- (BOOL)isPeripheralReconciling:(NSDictionary *)advertisementData
{
    // TODO: Should we explicitly only consider the least significant bit?
    NSData *manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey];
    for (int i = 0; i < manufacturerData.length; i++)
    {
        if (((char *)manufacturerData.bytes)[i])
        {
            return YES;
        }
    }
    return NO;
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    NSLog(@"Discovered peripheral with name: \"%@\" IsReconciling: %d RSSI: %d.",
          peripheral.name,
          [self isPeripheralReconciling:advertisementData],
          [RSSI integerValue]);
//    NSLog(@"Advertisement data: %@", advertisementData);

    if (self.connectionState == ConnectionState_Dating)
    {
        [self transitionConnectionStateToDating_AttemptingConnection:peripheral];
    }
    else if (self.connectionState == ConnectionState_Swinging)
    {
        if (peripheral.UUID &&
            [[CBUUID UUIDWithCFUUID:peripheral.UUID] isEqual:self.swingingPeripheralUUID] &&
            [self isPeripheralReconciling:advertisementData])
        {
            [self transitionConnectionStateToReconciling:peripheral];
        }
    }
    else if (self.connectionState == ConnectionState_Separated)
    {
        if (peripheral.UUID &&
            [[CBUUID UUIDWithCFUUID:peripheral.UUID] isEqual:self.separatedPeripheralUUID] &&
            [self isPeripheralReconciling:advertisementData])
        {
            [self transitionConnectionStateToReconciling:peripheral];
        }
    }
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
    NSAssert(self.connectionState == ConnectionState_Dating_AttemptingConnection ||
             self.connectionState == ConnectionState_Reconciling, @"");

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
    NSAssert(self.pen.peripheral.UUID, @"Peripheral UUID non-null.");

    if (peripheral == self.pen.peripheral)
    {
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

        if (self.connectionState != ConnectionState_Swinging)
        {
            if (self.connectionState == ConnectionState_Married)
            {
                self.separatedPeripheralUUID = [CBUUID UUIDWithCFUUID:pen.peripheral.UUID];
                [self transitionConnectionStateToSeparated];
            }
            else if (self.connectionState == ConnectionState_Reconciling)
            {
                self.separatedPeripheralUUID = [CBUUID UUIDWithCFUUID:pen.peripheral.UUID];
                [self transitionConnectionStateToSeparated];
            }
            else
            {
                [self transitionConnectionStateToSingle];
            }
        }
    }
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
