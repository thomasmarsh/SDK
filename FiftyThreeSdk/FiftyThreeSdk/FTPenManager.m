//
//  FTPenManager.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import <UIKit/UIKit.h>

#import "Common/NSString+Helpers.h"
#import "FTFirmwareManager.h"
#import "FTLog.h"
#import "FTPen+Private.h"
#import "FTPen.h"
#import "FTPenManager+Private.h"
#import "FTPenManager.h"
#import "FTServiceUUIDs.h"
#import "TIUpdateManager.h"
#import "TransitionKit.h"

NSString * const kPairedPeripheralUUIDUserDefaultsKey = @"com.fiftythree.pen.pairedPeripheralUUID";
NSString * const kPairedPeripheralLastActivityTimeUserDefaultsKey = @"com.fiftythree.pen.pairedPeripheralLastActivityTime";

NSString * const kFTPenManagerDidUpdateStateNotificationName = @"com.fiftythree.penManager.didUpdateState";
NSString * const kFTPenManagerDidFailToDiscoverPenNotificationName = @"com.fiftythree.penManager.didFailToDiscoverPen";
NSString * const kFTPenUnexpectedDisconnectNotificationName = @"com.fiftythree.penManager.unexpectedDisconnect";
NSString * const kFTPenUnexpectedDisconnectWhileConnectingNotifcationName = @"com.fiftythree.penManager.unexpectedDisconnectWhileConnecting";
NSString * const kFTPenUnexpectedDisconnectWhileUpdatingFirmwareNotificationName = @"com.fiftythre.penManager.unexpectedDisconnectWhileUpdatingFirmware";

NSString * const kFTPenManagerFirmwareUpdateDidBegin = @"com.fiftythree.penManger.firmwareUpdateDidBegin";
NSString * const kFTPenManagerFirmwareUpdateDidBeginSendingUpdate = @"com.fiftythree.penManger.firmwareUpdateDidBeginSendingUpdate";
NSString * const kFTPenManagerFirmwareUpdateDidUpdatePercentComplete = @"com.fiftythree.penManger.firmwareUpdateDidUpdatePercentComplete";
NSString * const kFTPenManagerPercentCompleteProperty = @"com.fiftythree.penManager.percentComplete";
NSString * const kFTPenManagerFirmwareUpdateDidFinishSendingUpdate = @"com.fiftythree.penManger.firmwareUpdateDidFinishSendingUpdate";
NSString * const kFTPenManagerFirmwareUpdateDidCompleteSuccessfully = @"com.fiftythree.penManger.firmwareUpdateDidCompleteSuccessfully";
NSString * const kFTPenManagerFirmwareUpdateDidFail = @"com.fiftythree.penManger.firmwareUpdateDidFail";
NSString * const kFTPenManagerFirmwareUpdateWasCancelled = @"com.fiftythree.penManger.firmwareUpdateWasCancelled";

static const int kInterruptedUpdateDelayMax = 30;

static const NSTimeInterval kInactivityTimeout = 10.0 * 60.0;
static const NSTimeInterval kDatingScanningTimeout = 4.f;
static const NSTimeInterval kEngagedStateTimeout = 0.1;
static const NSTimeInterval kIsScanningForPeripheralsToggleTimerInterval = 0.1;
static const NSTimeInterval kSwingingStateTimeout = 4.0;
static const NSTimeInterval kSeparatedStateTimeout = kInactivityTimeout;
static const NSTimeInterval kMarriedWaitingForLongPressToUnpairTimeout = 1.5;
static const NSTimeInterval kSeparatedWaitingForLongPressToUnpairTimeout = 1.5;
static const NSTimeInterval kAttemptingConnectionStateTimeout = 15.0;

#pragma mark - State Names

static NSString *const kWaitingForCentralManagerToPowerOnStateName = @"WaitingForCentralManagerToPowerOn";
static NSString *const kSingleStateName = @"Single";
static NSString *const kDatingRetrievingConnectedPeripheralsStateName = @"DatingRetrievingConnectedPeripherals";
static NSString *const kDatingScanningStateName = @"DatingScanning";
static NSString *const kDatingAttemptingConnectiongStateName = @"DatingAttemptingConnection";
static NSString *const kEngagedStateName = @"Engaged";
static NSString *const kEngagedWaitingForTipReleaseStateName = @"EngagedWaitingForTipRelease";
static NSString *const kEngagedWaitingForPairingSpotReleaseStateName = @"EngagedWaitingForPairingSpotRelease";
static NSString *const kMarriedStateName = @"Married";
static NSString *const kMarriedWaitingForLongPressToUnpairStateName = @"MarriedWaitingForLongPressToUnpair";
static NSString *const kDisconnectingAndBecomingSingleStateName = @"DisconnectingAndBecomingSingle";
static NSString *const kDisconnectingAndBecomingSeparatedStateName = @"DisconnectingAndBecomingSeparated";

static NSString *const kPreparingToSwingStateName = @"PreparingToSwing";
static NSString *const kSwingingStateName = @"Swinging";
static NSString *const kSwingingAttemptingConnectionStateName = @"SwingingAttemptingConnectionStateName";

static NSString *const kSeparatedStateName = @"Separated";
static NSString *const kSeparatedRetrievingConnectedPeripheralsStateName = @"SeparatedRetrievingConnectedPeripherals";
static NSString *const kSeparatedAttemptingConnectionStateName = @"SeparatedAttemptingConnection";
static NSString *const kSeparatedWaitingForLongPressToUnpairStateName = @"SeparatedWaitingForLongPressToUnpair";

static NSString *const kUpdatingFirmwareStateName = @"UpdatingFirmware";
static NSString *const kUpdatingFirmwareAttemptingConnectionStateName = @"UpdatingFirmwareAttemptingConnection";

#pragma mark - Event Names

static NSString *const kWaitForCentralManagerToPowerOnEventName = @"WaitForCentralManagerToPowerOn";
static NSString *const kBeginDatingAndRetrieveConnectedPeripheralsEventName = @"BeginDatingAndRetrieveConnectedPeripherals";
static NSString *const kRetrieveConnectedPeripheralsFromSeparatedEventName = @"RetrieveConnectedPeripheralsFromSeparated";
static NSString *const kBeginDatingScanningEventName = @"BeginDatingScanning";
static NSString *const kBecomeSingleEventName = @"BecomeSingleEventName";
static NSString *const kAttemptConnectionFromDatingEventName = @"AttemptConnectionFromDating";
static NSString *const kBecomeEngagedEventName = @"BecomeEngaged";
static NSString *const kWaitForTipReleaseEventName = @"WaitForTipRelease";
static NSString *const kWaitForPairingSpotReleaseEventName = @"WaitForPairingSpotRelease";
static NSString *const kBecomeMarriedEventName = @"BecomeMarried";
static NSString *const kWaitForLongPressToUnpairFromMarriedEventName = @"WaitForLongPressToUnpairFromMarried";
static NSString *const KkWaitForLongPressToUnpairFromSeparatedEventNameEventName = @"kWaitForLongPressToUnpairFromSeparatedEventName";
static NSString *const kReturnToMarriedEventName = @"ReturnToMarried";
static NSString *const kDisconnectAndBecomeSingleEventName = @"DisconnectAndBecomeSingle";
static NSString *const kDisconnectAndBecomeSeparatedEventName = @"DisconnectAndBecomeSeparated";
static NSString *const kCompleteDisconnectionAndBecomeSingleEventName = @"CompleteDisconnectAndBecomeSingle";
static NSString *const kCompleteDisconnectionAndBecomeSeparatedEventName = @"CompleteDisconnectAndBecomeSeparated";
static NSString *const kPrepareToSwingEventName = @"PrepareToSwing";

static NSString *const kSwingEventName = @"Swing";
static NSString *const kAttemptConnectionFromSwingingEventName = @"AttemptConnectionFromSwinging";

static NSString *const kBecomeSeparatedEventName = @"BecomeSeparated";
static NSString *const kAttemptConnectionFromSeparatedEventName = @"AttemptConnectionFromSeparated";

static NSString *const kUpdateFirmwareEventName = @"UpdateFirmware";
static NSString *const kAttemptConnectionFromUpdatingFirmwareEventName = @"AttemptConnectionFromUpdatingFirmware";

#pragma mark -

typedef enum
{
    ScanningStateDisabled,
    ScanningStateEnabled,
    ScanningStateEnabledWithPolling
} ScanningState;

BOOL FTPenManagerStateIsConnected(FTPenManagerState state)
{
    return (state == FTPenManagerStateConnected ||
            state == FTPenManagerStateConnectedLongPressToUnpair ||
            state == FTPenManagerStateUpdatingFirmware);
}

NSString *FTPenManagerStateToString(FTPenManagerState state)
{
    switch (state)
    {
        case FTPenManagerStateUninitialized:
            return @"FTPenManagerStateUninitialized";
        case FTPenManagerStateUnpaired:
            return @"FTPenManagerStateUnpaired";
        case FTPenManagerStateSeeking:
            return @"FTPenManagerStateSeeking";
        case FTPenManagerStateConnecting:
            return @"FTPenManagerStateConnecting";
        case FTPenManagerStateConnected:
            return @"FTPenManagerStateConnected";
        case FTPenManagerStateConnectedLongPressToUnpair:
            return @"FTPenManagerStateConnectedLongPressToUnpair";
        case FTPenManagerStateDisconnected:
            return @"FTPenManagerStateDisconnected";
        case FTPenManagerStateDisconnectedLongPressToUnpair:
            return @"FTPenManagerStateDisconnectedLongPressToUnpair";
        case FTPenManagerStateReconnecting:
            return @"FTPenManagerStateReconnecting";
        case FTPenManagerStateUpdatingFirmware:
            return @"FTPenManagerStateUpdatingFirmware";
        default:
            assert(0);
            return @"Unknown FTPenManagerState value.";
    }
}

@interface FTPenManager () <CBCentralManagerDelegate, TIUpdateManagerDelegate> {
    CFUUIDRef _pairedPeripheralUUID;
}

@property (nonatomic) CBCentralManager *centralManager;

@property (nonatomic, copy) NSString *firmwareImagePath;
@property (nonatomic) TIUpdateManager *updateManager;

@property (nonatomic) TKStateMachine *stateMachine;

@property (nonatomic, readwrite) FTPenManagerState state;

@property (nonatomic, readwrite) FTPen *pen;

@property (nonatomic) ScanningState scanningState;

@property (nonatomic) BOOL isScanningForPeripherals;
@property (nonatomic) NSTimer *isScanningForPeripheralsToggleTimer;

@property (nonatomic) NSDate *lastPairingSpotReleaseTime;

// The UUID of the peripheral with which we are currently paired.
@property (nonatomic) CFUUIDRef pairedPeripheralUUID;

// The time at which the last tip/eraser press activity that was observed on the paired peripheral.
@property (nonatomic) NSDate *pairedPeripheralLastActivityTime;

@property (nonatomic) NSMutableSet *peripheralsDiscoveredDuringLongPress;

@property (nonatomic) CBPeripheral *onDeckPeripheral;

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;

@end

@implementation FTPenManager

- (id)init
{
    self = [super init];
    if (self)
    {
        _state = FTPenManagerStateUninitialized;

        _scanningState = ScanningStateDisabled;

        _backgroundTaskId = UIBackgroundTaskInvalid;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(stateMachineDidChangeState:)
                                                     name:TKStateMachineDidChangeStateNotification
                                                   object:self.stateMachine];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(stateMachineStateTimeoutDidExpire:)
                                                     name:TKStateMachineStateTimeoutDidExpireNotification
                                                   object:self.stateMachine];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(penDidWriteHasListener:)
                                                     name:kFTPenDidWriteHasListenerNotificationName
                                                   object:nil];

        // If we're currently paired with a peripheral, verify that the time since we lost saw acitivity
        // from this peripheral does not exceed the inactivity timeout of the peripheral. This can happen if,
        // for example, the app was shutdown while paired with the peripheral, then remained closed for
        // longer than the timeout. We don't want to enter the separated state if there's no prior indication
        // that the pen will be attempting to reconcile with us.
        if (self.pairedPeripheralUUID)
        {
            NSTimeInterval timeSinceLastActivity = -[self.pairedPeripheralLastActivityTime timeIntervalSinceNow];

            if (self.pairedPeripheralLastActivityTime)
            {
                [FTLog logWithFormat:@"Time since last paired peripheral activity: %@",
                 [NSString stringWithTimeInterval:timeSinceLastActivity]];
            }

            if (!self.pairedPeripheralLastActivityTime ||
                timeSinceLastActivity <= 0.0 ||
                timeSinceLastActivity > kInactivityTimeout)
            {
                [FTLog log:@"Last activity time exceeds timeout. Severing pairing."];
                self.pairedPeripheralUUID = NULL;
            }
        }

        [self initializeStateMachine];
    }

    return self;
}

- (void)dealloc
{
    [self reset];

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (_pairedPeripheralUUID)
    {
        CFRelease(_pairedPeripheralUUID);
        _pairedPeripheralUUID = NULL;
    }
}

- (void)reset
{
    [self resetBackgroundTask];

    self.firmwareImagePath = nil;
    self.updateManager = nil;

    FTPen *pen = self.pen;
    self.pen = nil;
    [pen peripheralConnectionStatusDidChange];

    self.scanningState = ScanningStateDisabled;

    _centralManager.delegate = nil;
    _centralManager = nil;
}

#pragma mark - Properties

- (CBCentralManager *)centralManager
{
    return [self ensureCentralManager];
}

- (CBCentralManager *)ensureCentralManager
{
    // Lazily initialize the CBCentralManager so that we don't invoke the system Bluetooth alert (if Bluetooth
    // is disabled) until the user presses the pairing spot.
    if (!_centralManager)
    {
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    return _centralManager;
}

- (void)setState:(FTPenManagerState)state
{
    if (_state != state)
    {
        _state = state;

        if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
        {
            self.pen.hasListener = YES;
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerDidUpdateStateNotificationName
                                                            object:self];
    }
}

- (void)setPen:(FTPen *)pen
{
    _pen = pen;

    [[NSNotificationCenter defaultCenter] removeObserver:kFTPenDidEncounterErrorNotificationName];
    [[NSNotificationCenter defaultCenter] removeObserver:kFTPenIsReadyDidChangeNotificationName];
    [[NSNotificationCenter defaultCenter] removeObserver:kFTPenIsTipPressedDidChangeNotificationName];
    [[NSNotificationCenter defaultCenter] removeObserver:kFTPenDidUpdatePropertiesNotificationName];

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
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(penIsEraserPressedDidChange:)
                                                     name:kFTPenIsEraserPressedDidChangeNotificationName
                                                   object:_pen];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(penDidUpdateProperties:)
                                                     name:kFTPenDidUpdatePropertiesNotificationName
                                                   object:_pen];
    }
}

- (void)setPairedPeripheralUUID:(CFUUIDRef)pairedPeripheralUUID
{
    NSString *uuidStr = (pairedPeripheralUUID != NULL ?
                         CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, pairedPeripheralUUID)) :
                         nil);

    [[NSUserDefaults standardUserDefaults] setValue:uuidStr
                                             forKey:kPairedPeripheralUUIDUserDefaultsKey];

    // Also update the last activity time. Be sure to do this prior to synchronize, since setting last
    // activity time does not call synchronize on its own.
    if (pairedPeripheralUUID != NULL)
    {
        self.pairedPeripheralLastActivityTime = [NSDate date];
    }
    else
    {
        self.pairedPeripheralLastActivityTime = nil;
    }

    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (CFUUIDRef)pairedPeripheralUUID
{
    if (_pairedPeripheralUUID)
    {
        CFRelease(_pairedPeripheralUUID);
        _pairedPeripheralUUID = NULL;
    }

    NSString *uuidStr = [[NSUserDefaults standardUserDefaults] valueForKey:kPairedPeripheralUUIDUserDefaultsKey];
    if (uuidStr)
    {
        _pairedPeripheralUUID = CFUUIDCreateFromString(kCFAllocatorDefault, CFBridgingRetain(uuidStr));
    }
    else
    {
        return NULL;
    }

    return _pairedPeripheralUUID;
}

- (void)setPairedPeripheralLastActivityTime:(NSDate *)pairedPeripheralLastActivityTime
{
    [[NSUserDefaults standardUserDefaults] setValue:pairedPeripheralLastActivityTime
                                             forKey:kPairedPeripheralLastActivityTimeUserDefaultsKey];

    // Don't synchronize here. This property is updated far too frequently to incur the cost and the
    // consequences of losing a save to this value are minimal.
}

- (NSDate *)pairedPeripheralLastActivityTime
{
    return [[NSUserDefaults standardUserDefaults] valueForKey:kPairedPeripheralLastActivityTimeUserDefaultsKey];
}

- (BOOL)isPairedPeripheral:(CBPeripheral *)peripheral
{
    return (self.pairedPeripheralUUID != NULL &&
            peripheral.UUID != NULL &&
            CFEqual(self.pairedPeripheralUUID, peripheral.UUID));
}

- (void)penDidEncounterError:(NSNotification *)notification
{
    [self handleError];
}

- (void)handleError
{
    [FTLog log:@"Pen did encounter error. Disconnecting."];

    // Make sure that we favor transitions that go through disconnect over going straight
    // to single. Some states may support both, but if we're connected we need to disconnect
    // first.
    if ([self.stateMachine canFireEvent:kDisconnectAndBecomeSingleEventName])
    {
        [self fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }
    else if ([self.stateMachine canFireEvent:kDisconnectAndBecomeSeparatedEventName])
    {
        [self fireStateMachineEvent:kDisconnectAndBecomeSeparatedEventName];
    }
    else if ([self.stateMachine canFireEvent:kBecomeSingleEventName])
    {
        [self fireStateMachineEvent:kBecomeSingleEventName];
    }
}

- (void)penIsReadyDidChange:(NSNotification *)notification
{
    if (self.pen.isReady)
    {
        [FTLog log:@"Pen is ready"];

        if ([self currentStateHasName:kDatingAttemptingConnectiongStateName])
        {
            [self fireStateMachineEvent:kBecomeEngagedEventName];
        }
        else if ([self currentStateHasName:kSeparatedAttemptingConnectionStateName] ||
                 [self currentStateHasName:kSwingingAttemptingConnectionStateName])
        {
            [self fireStateMachineEvent:kBecomeMarriedEventName];
        }
    }
    else
    {
        // TODO: Can this ever happen?
    }
}

- (void)penIsTipPressedDidChange:(NSNotification *)notification
{
    if (!self.pen.isTipPressed && self.pen.lastTipReleaseTime)
    {
        if ([self currentStateHasName:kEngagedStateName])
        {
            [self fireStateMachineEvent:kWaitForPairingSpotReleaseEventName];
        }
        else if ([self currentStateHasName:kEngagedWaitingForTipReleaseStateName])
        {
            [self comparePairingSpotAndTipReleaseTimesAndTransitionState];
        }
    }

    self.pairedPeripheralLastActivityTime = [NSDate date];
}

- (void)penIsEraserPressedDidChange:(NSNotification *)notification
{
    self.pairedPeripheralLastActivityTime = [NSDate date];
}

- (void)penDidUpdateProperties:(NSNotification *)notification
{
    // Firmware update can't proceed until we've refreshed the factory and upgrade firmware
    // versions. (The reason for this is that after the upgrade -> factory reset we need the
    // check that we're running the factory version to be accurate.)
    if ([self currentStateHasName:kUpdatingFirmwareStateName])
    {
        NSAssert(self.pen, @"pen is non-nil");
        if (self.pen.firmwareRevision &&
            self.pen.softwareRevision &&
            !self.updateManager)
        {
            [FTLog logWithFormat:@"Factory firmware version: %@", self.pen.firmwareRevision];
            [FTLog logWithFormat:@"Upgrade firmware version: %@", self.pen.softwareRevision];

            self.updateManager = [[TIUpdateManager alloc] initWithPeripheral:self.pen.peripheral
                                                                    delegate:self];
            [self.updateManager updateWithImagePath:self.firmwareImagePath];

            // If the pen is currently running the upgrade firmware, it needs to reset. We
            // don't want to indicate that the update has started until we initate another
            // update *after* the reset has happened.
            if ([FTFirmwareManager imageTypeRunningOnPen:self.pen] == FTFirmwareImageTypeFactory)
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateDidBeginSendingUpdate
                                                                    object:self];
            }
        }
    }
}

#pragma mark - State machine

- (void)initializeStateMachine
{
    NSAssert(!self.stateMachine, @"State machine may only be initialized once.");

    __weak FTPenManager *weakSelf = self;

    self.stateMachine = [TKStateMachine new];

    //
    // States
    //

    void (^attemptingConnectionCommon)() = ^()
    {
        NSAssert(weakSelf.pen, @"pen is non-nil");

        [weakSelf.centralManager connectPeripheral:weakSelf.pen.peripheral options:nil];
    };

    // WaitingForCentralManagerToPowerOn
    TKState *waitingForCentralManagerToPowerOnState = [TKState stateWithName:kWaitingForCentralManagerToPowerOnStateName];
    [waitingForCentralManagerToPowerOnState setDidEnterStateBlock:^(TKState *state,
                                                                    TKStateMachine *stateMachine)
    {
        [weakSelf reset];

        // Generally we wait until the user presses the pairing spot before initializing the CBCentralManager.
        // However, if we have a paired peripheral, than we need to fire up the CBCentralManager in order to
        // see if it's trying to reconcile with us.
        if (weakSelf.pairedPeripheralUUID)
        {
            [weakSelf ensureCentralManager];
        }

        weakSelf.state = FTPenManagerStateUninitialized;
    }];
    [waitingForCentralManagerToPowerOnState setDidExitStateBlock:^(TKState *state,
                                                                     TKStateMachine *stateMachine)
    {
        NSAssert(weakSelf.centralManager, @"CentralManager non-nil");
        NSAssert(weakSelf.centralManager.state == CBCentralManagerStatePoweredOn, @"State is PoweredOn");
    }];

    // Single
    TKState *singleState = [TKState stateWithName:kSingleStateName];
    [singleState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        NSAssert(!weakSelf.pen, @"Pen is nil");

        weakSelf.state = FTPenManagerStateUnpaired;

        weakSelf.pairedPeripheralUUID = NULL;

        // If we enter the single state and discover that the pairing spot is currently
        // pressed, then proceed directly to the dating state.
//        if (weakSelf.isPairingSpotPressed)
//        {
//            [weakSelf fireStateMachineEvent:kBeginDatingEventName];
//        }
    }];

    // DatingRetrievingConnectedPeripherals
    TKState *datingRetrievingConnectedPeripheralsState = [TKState stateWithName:kDatingRetrievingConnectedPeripheralsStateName];
    [datingRetrievingConnectedPeripheralsState setDidEnterStateBlock:^(TKState *state,
                                                                       TKStateMachine *stateMachine)
    {
        weakSelf.state = FTPenManagerStateSeeking;

        [weakSelf.centralManager retrieveConnectedPeripherals];
    }];

    // DatingScanning
    TKState *datingScanningState = [TKState stateWithName:kDatingScanningStateName
                                       andTimeoutDuration:kDatingScanningTimeout];
    [datingScanningState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        weakSelf.state = FTPenManagerStateSeeking;

        weakSelf.scanningState = ScanningStateEnabled;
    }];
    [datingScanningState setDidExitStateBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        weakSelf.scanningState = ScanningStateDisabled;
    }];
    [datingScanningState setTimeoutExpiredBlock:^(TKState *state,
                                                  TKStateMachine *stateMachine)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerDidFailToDiscoverPenNotificationName
                                                            object:self];
        [weakSelf fireStateMachineEvent:kBecomeSingleEventName];
    }];

    // Dating - Attempting Connection
    TKState *datingAttemptingConnectionState = [TKState stateWithName:kDatingAttemptingConnectiongStateName
                                                   andTimeoutDuration:kAttemptingConnectionStateTimeout];
    [datingAttemptingConnectionState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        weakSelf.state = FTPenManagerStateConnecting;

        attemptingConnectionCommon();
    }];
    [datingAttemptingConnectionState setTimeoutExpiredBlock:^(TKState *state,
                                                              TKStateMachine *stateMachine)
    {
        [weakSelf fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }];

    // Engaged
    TKState *engagedState = [TKState stateWithName:kEngagedStateName];
    [engagedState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        weakSelf.state = FTPenManagerStateConnected;
    }];

    // Engaged - Waiting for Tip Release
    TKState *engagedWaitingForTipReleaseState = [TKState stateWithName:kEngagedWaitingForTipReleaseStateName
                                                    andTimeoutDuration:kEngagedStateTimeout];
    [engagedWaitingForTipReleaseState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
        weakSelf.state = FTPenManagerStateConnected;
    }];
    [engagedWaitingForTipReleaseState setTimeoutExpiredBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        [weakSelf fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }];

    // Engaged - Waiting for Pairing Spot Release
    TKState *engagedWaitingForPairingSpotReleaseState = [TKState stateWithName:kEngagedWaitingForPairingSpotReleaseStateName
                                                            andTimeoutDuration:kEngagedStateTimeout];
    [engagedWaitingForPairingSpotReleaseState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        weakSelf.state = FTPenManagerStateConnected;
    }];
    [engagedWaitingForPairingSpotReleaseState setTimeoutExpiredBlock:^(TKState *state,
                                                                       TKStateMachine *stateMachine)
    {
        [weakSelf fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }];

    // Married
    TKState *marriedState = [TKState stateWithName:kMarriedStateName];
    [marriedState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        NSAssert(weakSelf.pen.peripheral.isConnected, @"pen peripheral is connected");
        NSAssert(weakSelf.pen.peripheral.UUID != NULL, @"pen peripheral UUID is non-nil");

        weakSelf.pairedPeripheralUUID = weakSelf.pen.peripheral.UUID;
        weakSelf.state = FTPenManagerStateConnected;
    }];

    // Married - Waiting for Long Press to Disconnect
    TKState *marriedWaitingForLongPressToUnpairState = [TKState stateWithName:kMarriedWaitingForLongPressToUnpairStateName
                                                           andTimeoutDuration:kMarriedWaitingForLongPressToUnpairTimeout];
    [marriedWaitingForLongPressToUnpairState setDidEnterStateBlock:^(TKState *state,
                                                                     TKStateMachine *stateMachine)
     {
         NSAssert(weakSelf.pen, @"pen is non-nil");
         NSAssert(weakSelf.pen.peripheral.isConnected, @"pen peripheral is connected");

         weakSelf.state = FTPenManagerStateConnectedLongPressToUnpair;

         weakSelf.scanningState = ScanningStateEnabledWithPolling;

         weakSelf.peripheralsDiscoveredDuringLongPress = [NSMutableSet set];
     }];
    [marriedWaitingForLongPressToUnpairState setDidExitStateBlock:^(TKState *state,
                                                                        TKStateMachine *stateMachine)
    {
        weakSelf.scanningState = ScanningStateDisabled;
        weakSelf.peripheralsDiscoveredDuringLongPress = nil;
    }];
    [marriedWaitingForLongPressToUnpairState setTimeoutExpiredBlock:^(TKState *state, TKStateMachine *stateMachine)
     {
         NSAssert(weakSelf.pen, @"pen is non-nil");
         NSAssert(weakSelf.pen.peripheral.isConnected, @"pen peripheral is connected");

         [weakSelf.pen powerOff];

         if (weakSelf.peripheralsDiscoveredDuringLongPress.count > 0)
         {
             weakSelf.onDeckPeripheral = [weakSelf.peripheralsDiscoveredDuringLongPress anyObject];
         }

         [weakSelf fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
     }];

    // Preparing to Swing
    TKState *preparingToSwingState = [TKState stateWithName:kPreparingToSwingStateName];
    [preparingToSwingState setDidEnterStateBlock:^(TKState *state,
                                                   TKStateMachine *stateMachine)
    {
        NSAssert(weakSelf.pairedPeripheralUUID != NULL, @"paired peripheral UUID is non-nil");

        weakSelf.state = FTPenManagerStateDisconnected;

        [weakSelf.pen startSwinging];
    }];

    // Swinging
    TKState *swingingState = [TKState stateWithName:kSwingingStateName
                                 andTimeoutDuration:kSwingingStateTimeout];
    [swingingState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        weakSelf.state = FTPenManagerStateDisconnected;

        weakSelf.scanningState = ScanningStateEnabledWithPolling;
    }];
    [swingingState setDidExitStateBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        weakSelf.scanningState = ScanningStateDisabled;
    }];
    [swingingState setTimeoutExpiredBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        [weakSelf fireStateMachineEvent:kBecomeSingleEventName];
    }];

    // Swinging - Attempting Connection
    TKState *swingingAttemptingConnectionState = [TKState stateWithName:kSwingingAttemptingConnectionStateName
                                                     andTimeoutDuration:kAttemptingConnectionStateTimeout];
    [swingingAttemptingConnectionState setDidEnterStateBlock:^(TKState *state,
                                                               TKStateMachine *stateMachine)
    {
        weakSelf.state = FTPenManagerStateReconnecting;

        weakSelf.pen.requiresTipBePressedToBecomeReady = NO;

        attemptingConnectionCommon();
    }];
    [swingingAttemptingConnectionState setTimeoutExpiredBlock:^(TKState *state,
                                                               TKStateMachine *stateMachine)
    {
        [weakSelf fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }];

    // Separated
    TKState *separatedState = [TKState stateWithName:kSeparatedStateName
                                  andTimeoutDuration:kSeparatedStateTimeout];
    [separatedState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        weakSelf.state = FTPenManagerStateDisconnected;

        weakSelf.scanningState = ScanningStateEnabled;
    }];
    [separatedState setDidExitStateBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        weakSelf.scanningState = ScanningStateDisabled;
    }];
    [separatedState setTimeoutExpiredBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        [weakSelf fireStateMachineEvent:kBecomeSingleEventName];
    }];

    // Separated - Retrieving Connceted Peripherals
    TKState *separatedRetrievingConnectedPeripheralsState = [TKState stateWithName:kSeparatedRetrievingConnectedPeripheralsStateName];
    [separatedRetrievingConnectedPeripheralsState setDidEnterStateBlock:^(TKState *state,
                                                                          TKStateMachine *stateMachine)
    {
        weakSelf.state = FTPenManagerStateDisconnected;

        [weakSelf.centralManager retrieveConnectedPeripherals];
    }];

    // Separated - Attempting Connection
    TKState *separatedAttemptingConnectionState = [TKState stateWithName:kSeparatedAttemptingConnectionStateName
                                                      andTimeoutDuration:kAttemptingConnectionStateTimeout];
    [separatedAttemptingConnectionState setDidEnterStateBlock:^(TKState *state,
                                                                TKStateMachine *stateMachine)
    {
        weakSelf.state = FTPenManagerStateReconnecting;

        weakSelf.pen.requiresTipBePressedToBecomeReady = NO;

        attemptingConnectionCommon();
    }];
    [separatedAttemptingConnectionState setTimeoutExpiredBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        [weakSelf fireStateMachineEvent:kDisconnectAndBecomeSeparatedEventName];
    }];

    // Separated - Waiting for Pairing Spot to Unpair
    TKState *separatedWaitingForLongPressToUnpairState = [TKState stateWithName:kSeparatedWaitingForLongPressToUnpairStateName
                                                             andTimeoutDuration:kSeparatedWaitingForLongPressToUnpairTimeout];
    [separatedWaitingForLongPressToUnpairState setDidEnterStateBlock:^(TKState *state,
                                                                       TKStateMachine *stateMachine)
     {
         weakSelf.state = FTPenManagerStateDisconnectedLongPressToUnpair;

         weakSelf.peripheralsDiscoveredDuringLongPress = [NSMutableSet set];

         weakSelf.scanningState = ScanningStateEnabledWithPolling;
     }];
    [separatedWaitingForLongPressToUnpairState setDidExitStateBlock:^(TKState *state,
                                                                      TKStateMachine *stateMachine)
     {
         weakSelf.scanningState = ScanningStateDisabled;

         weakSelf.peripheralsDiscoveredDuringLongPress = nil;
     }];
    [separatedWaitingForLongPressToUnpairState setTimeoutExpiredBlock:^(TKState *state,
                                                                        TKStateMachine *stateMachine)
     {
         if (weakSelf.peripheralsDiscoveredDuringLongPress.count > 0)
         {
             NSAssert(!weakSelf.pen, @"pen non-nil");

             weakSelf.pen = [[FTPen alloc] initWithPeripheral:[weakSelf.peripheralsDiscoveredDuringLongPress anyObject]];

             [weakSelf fireStateMachineEvent:kAttemptConnectionFromDatingEventName];
         }
         else
         {
             [weakSelf fireStateMachineEvent:kBecomeSingleEventName];
         }
     }];

    // Disconnecting and Becoming Single
    TKState *disconnectingAndBecomingSingleState = [TKState stateWithName:kDisconnectingAndBecomingSingleStateName];
    [disconnectingAndBecomingSingleState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        weakSelf.state = FTPenManagerStateUnpaired;

        if (weakSelf.pen)
        {
            if (!weakSelf.pen.isPoweringOff)
            {
                [weakSelf.centralManager cancelPeripheralConnection:weakSelf.pen.peripheral];
            }
        }
        else
        {
            [weakSelf fireStateMachineEvent:kCompleteDisconnectionAndBecomeSingleEventName];
        }
    }];
    [disconnectingAndBecomingSingleState setDidExitStateBlock:^(TKState *state,
                                                                TKStateMachine *stateMachine)
    {
        self.onDeckPeripheral = nil;
    }];

    // Disconnecting and Becoming Separated
    TKState *disconnectingAndBecomingSeparatedState = [TKState stateWithName:kDisconnectingAndBecomingSeparatedStateName];
    [disconnectingAndBecomingSeparatedState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine)
     {
         weakSelf.state = FTPenManagerStateDisconnected;

         if (weakSelf.pen)
         {
             if (!weakSelf.pen.isPoweringOff)
             {
                 [weakSelf.centralManager cancelPeripheralConnection:weakSelf.pen.peripheral];
             }
         }
         else
         {
             [weakSelf fireStateMachineEvent:kCompleteDisconnectionAndBecomeSeparatedEventName];
         }
     }];

    // Updating Firmware
    TKState *updatingFirmwareState = [TKState stateWithName:kUpdatingFirmwareStateName];
    [updatingFirmwareState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        NSAssert(weakSelf.pen, @"Pen must be non-nil");
        NSAssert(weakSelf.firmwareImagePath, @"firmwareImagePath must be non-nil");
        NSAssert(!weakSelf.updateManager, @"Update manager must be nil");

        weakSelf.state = FTPenManagerStateUpdatingFirmware;

        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateDidBegin
                                                            object:self];

        // Discourage the device from going to sleep while the firmware is updating.
        [UIApplication sharedApplication].idleTimerDisabled = YES;

        // Firmware update can't proceed until we've refreshed the factory and upgrade firmware
        // versions. (The reason for this is that after the upgrade -> factory reset we need
        // the check that we're running the factory version to be accurate.)
        [self.pen refreshFirmwareVersionProperties];
    }];
    [updatingFirmwareState setDidExitStateBlock:^(TKState *state,
                                                  TKStateMachine *stateMachine)
    {
        [weakSelf.updateManager cancelUpdate];
        weakSelf.updateManager = nil;

        // Restore the idle timer disable flag to its original state.
        [UIApplication sharedApplication].idleTimerDisabled = NO;
    }];

    // Updating Firmware - Attempting Connection
    TKState *updatingFirmwareAttemptingConnectionState = [TKState stateWithName:kUpdatingFirmwareAttemptingConnectionStateName
                                                             andTimeoutDuration:kAttemptingConnectionStateTimeout];
    [updatingFirmwareAttemptingConnectionState setDidEnterStateBlock:^(TKState *state,
                                                                       TKStateMachine *stateMachine)
    {
        NSAssert(weakSelf.pen, @"Pen must be non-nil");
        NSAssert(weakSelf.pen.peripheral, @"Pen peripheral is non-nil");
        NSAssert(!weakSelf.pen.peripheral.isConnected, @"Pen peripheral is not connected");
        NSAssert(!weakSelf.updateManager, @"Update manager must be nil");

        weakSelf.state = FTPenManagerStateUpdatingFirmware;

        weakSelf.pen.requiresTipBePressedToBecomeReady = NO;

        attemptingConnectionCommon();
    }];
    [updatingFirmwareAttemptingConnectionState setTimeoutExpiredBlock:^(TKState *state,
                                                                        TKStateMachine *stateMachine)
    {
        NSAssert(weakSelf.pen, @"Pen must be non-nil");

        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateDidFail
                                                            object:self];

        [weakSelf fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }];

    [self.stateMachine addStates:@[
     waitingForCentralManagerToPowerOnState,
     singleState,
     datingRetrievingConnectedPeripheralsState,
     datingScanningState,
     datingAttemptingConnectionState,
     engagedState,
     engagedWaitingForTipReleaseState,
     engagedWaitingForPairingSpotReleaseState,
     marriedState,
     marriedWaitingForLongPressToUnpairState,
     preparingToSwingState,
     swingingState,
     swingingAttemptingConnectionState,
     separatedState,
     separatedRetrievingConnectedPeripheralsState,
     separatedAttemptingConnectionState,
     separatedWaitingForLongPressToUnpairState,
     disconnectingAndBecomingSingleState,
     disconnectingAndBecomingSeparatedState,
     updatingFirmwareState,
     updatingFirmwareAttemptingConnectionState]];

    //
    // Events
    //

    TKEvent *waitForCentralManagerToPowerOn = [TKEvent eventWithName:kWaitForCentralManagerToPowerOnEventName
                                             transitioningFromStates:[self.stateMachine.states allObjects]
                                                             toState:waitingForCentralManagerToPowerOnState];

    TKEvent *beginDatingRetrievingConnectedPeripheralsEvent = [TKEvent eventWithName:kBeginDatingAndRetrieveConnectedPeripheralsEventName
                                                             transitioningFromStates:@[
                                                               waitingForCentralManagerToPowerOnState,
                                                               singleState,
                                                               separatedState,
                                                               marriedState,
                                                               datingAttemptingConnectionState]
                                                                             toState:datingRetrievingConnectedPeripheralsState];
    TKEvent *beginDatingScanningEvent = [TKEvent eventWithName:kBeginDatingScanningEventName
                                       transitioningFromStates:@[
                                         datingRetrievingConnectedPeripheralsState]
                                                       toState:datingScanningState];
    TKEvent *becomeSingleEvent = [TKEvent eventWithName:kBecomeSingleEventName
                                transitioningFromStates:@[
                                  waitingForCentralManagerToPowerOnState,
                                  datingScanningState,
                                  datingRetrievingConnectedPeripheralsState,
                                  separatedState,
                                  separatedWaitingForLongPressToUnpairState,
                                  swingingState]
                                                toState:singleState];
    TKEvent *attemptConnectionFromDatingEvent = [TKEvent eventWithName:kAttemptConnectionFromDatingEventName
                                               transitioningFromStates:@[datingScanningState,
                                                 datingRetrievingConnectedPeripheralsState,
                                                 separatedWaitingForLongPressToUnpairState,
                                                 disconnectingAndBecomingSingleState]
                                                               toState:datingAttemptingConnectionState];
    TKEvent *becomeEngagedEvent = [TKEvent eventWithName:kBecomeEngagedEventName
                                 transitioningFromStates:@[datingAttemptingConnectionState]
                                                 toState:engagedState];
    TKEvent *waitForTipReleaseEvent = [TKEvent eventWithName:kWaitForTipReleaseEventName
                                     transitioningFromStates:@[engagedState]
                                                     toState:engagedWaitingForTipReleaseState];
    TKEvent *waitForPairingSpotReleaseEvent = [TKEvent eventWithName:kWaitForPairingSpotReleaseEventName
                                             transitioningFromStates:@[engagedState]
                                                             toState:engagedWaitingForPairingSpotReleaseState];
    TKEvent *becomeMarriedEvent = [TKEvent eventWithName:kBecomeMarriedEventName
                                 transitioningFromStates:@[
                                   engagedWaitingForPairingSpotReleaseState,
                                   engagedWaitingForTipReleaseState,
                                   swingingAttemptingConnectionState,
                                   separatedAttemptingConnectionState,
                                   updatingFirmwareState]
                                                 toState:marriedState];
    TKEvent *waitForLongPressToUnpairFromMarriedEvent = [TKEvent eventWithName:kWaitForLongPressToUnpairFromMarriedEventName
                                                           transitioningFromStates:@[marriedState]
                                                                           toState:marriedWaitingForLongPressToUnpairState];
    TKEvent *kWaitForLongPressToUnpairFromSeparatedEventNameEvent = [TKEvent eventWithName:KkWaitForLongPressToUnpairFromSeparatedEventNameEventName
                                                         transitioningFromStates:@[separatedState]
                                                                         toState:separatedWaitingForLongPressToUnpairState];
    TKEvent *returnToMarriedEvent = [TKEvent eventWithName:kReturnToMarriedEventName
                                   transitioningFromStates:@[marriedWaitingForLongPressToUnpairState]
                                                   toState:marriedState];
    TKEvent *disconnectAndBecomeSingleEvent = [TKEvent eventWithName:kDisconnectAndBecomeSingleEventName
                                             transitioningFromStates:@[
                                               datingAttemptingConnectionState,
                                               separatedAttemptingConnectionState,
                                               engagedState,
                                               engagedWaitingForPairingSpotReleaseState,
                                               engagedWaitingForTipReleaseState,
                                               marriedState,
                                               marriedWaitingForLongPressToUnpairState,
                                               swingingAttemptingConnectionState,
                                               updatingFirmwareAttemptingConnectionState]
                                                             toState:disconnectingAndBecomingSingleState];
    TKEvent *disconnectAndBecomeSeparatedEvent = [TKEvent eventWithName:kDisconnectAndBecomeSeparatedEventName
                                                transitioningFromStates:@[separatedAttemptingConnectionState]
                                                                toState:disconnectingAndBecomingSeparatedState];
    TKEvent *completeDisconnectionAndBecomeSingleEvent = [TKEvent eventWithName:kCompleteDisconnectionAndBecomeSingleEventName
                                                        transitioningFromStates:@[disconnectingAndBecomingSingleState]
                                                                        toState:singleState];
    TKEvent *completeDisconnectionAndBecomeSeparatedEvent = [TKEvent eventWithName:kCompleteDisconnectionAndBecomeSeparatedEventName
                                                           transitioningFromStates:@[disconnectingAndBecomingSeparatedState]
                                                                           toState:separatedState];
    TKEvent *prepareToSwingEvent = [TKEvent eventWithName:kPrepareToSwingEventName
                                  transitioningFromStates:@[marriedState]
                                                  toState:preparingToSwingState];
    TKEvent *swingEvent = [TKEvent eventWithName:kSwingEventName
                         transitioningFromStates:@[preparingToSwingState]
                                         toState:swingingState];
    TKEvent *attemptConnectionFromSwingingEvent = [TKEvent eventWithName:kAttemptConnectionFromSwingingEventName
                                                 transitioningFromStates:@[swingingState]
                                                                 toState:swingingAttemptingConnectionState];
    TKEvent *becomeSeparatedEvent = [TKEvent eventWithName:kBecomeSeparatedEventName
                                   transitioningFromStates:@[
                                     marriedState,
                                     separatedRetrievingConnectedPeripheralsState,
                                     separatedAttemptingConnectionState,
                                     separatedWaitingForLongPressToUnpairState,
                                     updatingFirmwareState
                                     ]
                                                   toState:separatedState];
    TKEvent *retrieveConnectedPeripheralsFromSeparatedEvent = [TKEvent eventWithName:kRetrieveConnectedPeripheralsFromSeparatedEventName
                                                             transitioningFromStates:@[
                                                               waitingForCentralManagerToPowerOnState,
                                                               separatedState]
                                                                             toState:separatedRetrievingConnectedPeripheralsState];
    TKEvent *attemptConnectionFromSeparatedEvent = [TKEvent eventWithName:kAttemptConnectionFromSeparatedEventName
                                                  transitioningFromStates:@[
                                                    separatedState,
                                                    separatedRetrievingConnectedPeripheralsState]
                                                                  toState:separatedAttemptingConnectionState];

    TKEvent *updateFirmwareEvent = [TKEvent eventWithName:kUpdateFirmwareEventName
                                  transitioningFromStates:@[ marriedState,
                                    updatingFirmwareAttemptingConnectionState]
                                                  toState:updatingFirmwareState];
    TKEvent *attemptConnectionFromUpdatingFirmwareEvent = [TKEvent eventWithName:kAttemptConnectionFromUpdatingFirmwareEventName
                                                         transitioningFromStates:@[updatingFirmwareState]
                                                                         toState:updatingFirmwareAttemptingConnectionState];

    [self.stateMachine addEvents:@[
     waitForCentralManagerToPowerOn,
     beginDatingRetrievingConnectedPeripheralsEvent,
     beginDatingScanningEvent,
     becomeSingleEvent,
     attemptConnectionFromDatingEvent,
     becomeEngagedEvent,
     waitForTipReleaseEvent,
     waitForPairingSpotReleaseEvent,
     becomeMarriedEvent,
     waitForLongPressToUnpairFromMarriedEvent,
     kWaitForLongPressToUnpairFromSeparatedEventNameEvent,
     returnToMarriedEvent,
     disconnectAndBecomeSingleEvent,
     disconnectAndBecomeSeparatedEvent,
     completeDisconnectionAndBecomeSingleEvent,
     completeDisconnectionAndBecomeSeparatedEvent,
     prepareToSwingEvent,
     swingEvent,
     attemptConnectionFromSwingingEvent,
     becomeSeparatedEvent,
     attemptConnectionFromSeparatedEvent,
     retrieveConnectedPeripheralsFromSeparatedEvent,
     updateFirmwareEvent,
     attemptConnectionFromUpdatingFirmwareEvent,
     ]];

    self.stateMachine.initialState = waitingForCentralManagerToPowerOnState;

    [FTLog logWithFormat:@"Activating state machine with initial state: %@",
     self.stateMachine.initialState.name];
    [self.stateMachine activate];

    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerDidUpdateStateNotificationName
                                                        object:self];
}

- (void)stateMachineDidChangeState:(NSNotification *)notification
{
    [FTLog log:@" "];
    [FTLog logWithFormat:@"State changed: %@", self.stateMachine.currentState.name];
}

- (void)stateMachineStateTimeoutDidExpire:(NSNotificationCenter *)notification
{
    [FTLog log:@" "];
    [FTLog logWithFormat:@"State timeout expired: %@", self.stateMachine.currentState.name];
}

- (void)fireStateMachineEvent:(NSString *)eventName
{
    NSError *error = nil;
    if (![self.stateMachine fireEvent:eventName error:&error])
    {
        [FTLog logWithFormat:@"Failed to fire state machine event (%@): %@",
         eventName,
         error.localizedDescription];
    }
}

- (BOOL)currentStateHasName:(NSString *)stateName
{
    return [self.stateMachine.currentState.name isEqualToString:stateName];
}

#pragma mark - Application lifecycle

- (void)applicationDidBecomeActive:(NSNotificationCenter *)notification
{
    // If we're currently separated, then it's possible that the paired pen was connected in
    // another app on this device. Therefore, do a quick check to see if the paired pen
    // shows up in the connected peripherals.
    if ([self currentStateHasName:kSeparatedStateName])
    {
        [self fireStateMachineEvent:kRetrieveConnectedPeripheralsFromSeparatedEventName];
    }

    self.pen.hasListener = YES;
    [self resetBackgroundTask];
}

- (void)applicationDidEnterBackground:(NSNotification *)notificaton
{
    [FTLog log:@"FTPenManager did enter background"];

    // Reset the background task (if it has not yet been ended) prior to starting a new one. One would think
    // that we wouldn't need to do this if there were a strict pairing of applicationDidBecomeActive and
    // applicationDidEnterBackground, but in practice that does not appear to be the case.
    [self resetBackgroundTask];
    
    __weak __typeof(&*self)weakSelf = self;
    self.backgroundTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [weakSelf resetBackgroundTask];
    }];

    self.pen.hasListener = NO;
}

- (void)resetBackgroundTask
{
    if (self.backgroundTaskId != UIBackgroundTaskInvalid)
    {
        [FTLog log:@"FTPenManger did end background task"];

        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }
}

#pragma mark - Notifications

- (void)penDidWriteHasListener:(NSNotification *)notification
{
    [self resetBackgroundTask];
}

#pragma mark - Pairing Spot

- (void)setIsPairingSpotPressed:(BOOL)isPairingSpotPressed
{
    _isPairingSpotPressed = isPairingSpotPressed;

    if (isPairingSpotPressed)
    {
        [self pairingSpotWasPressed];
    }
    else
    {
        [self pairingSpotWasReleased];
    }
}

- (void)pairingSpotWasPressed
{
    [FTLog log:@"Pairing spot was pressed."];

    // When the user presses the pairing spot is often the first time we'll create the CBCentralManager and
    // possibly provoke the system Bluetooth alert if Bluetooth is not enabled.
    [self ensureCentralManager];

    if (![self currentStateHasName:kWaitingForCentralManagerToPowerOnStateName])
    {
        if ([self currentStateHasName:kSingleStateName])
        {
            [self fireStateMachineEvent:kBeginDatingAndRetrieveConnectedPeripheralsEventName];
        }
        else if ([self currentStateHasName:kSeparatedStateName])
        {
            [self fireStateMachineEvent:KkWaitForLongPressToUnpairFromSeparatedEventNameEventName];
        }
        else if ([self currentStateHasName:kMarriedStateName])
        {
            NSAssert(self.pen.peripheral.isConnected, @"Pen peripheral is connected");

            [self fireStateMachineEvent:kWaitForLongPressToUnpairFromMarriedEventName];
        }
    }
}

- (void)pairingSpotWasReleased
{
    [FTLog log:@"Pairing spot was released."];

    self.lastPairingSpotReleaseTime = [NSDate date];

    if ([self currentStateHasName:kDatingRetrievingConnectedPeripheralsStateName] ||
        [self currentStateHasName:kDatingScanningStateName])
    {
        [self fireStateMachineEvent:kBecomeSingleEventName];
    }
    else if ([self currentStateHasName:kDatingAttemptingConnectiongStateName])
    {
        // If we were in the middle of connecting, but the pairing spot was released
        // prematurely, then cancel the connection. The pen must be connected and ready in
        // order to transition to the "engaged" state.
        [self fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }
    else if ([self currentStateHasName:kEngagedStateName])
    {
        [self fireStateMachineEvent:kWaitForTipReleaseEventName];
    }
    else if ([self currentStateHasName:kEngagedWaitingForPairingSpotReleaseStateName])
    {
        [self comparePairingSpotAndTipReleaseTimesAndTransitionState];
    }
    else if ([self currentStateHasName:kMarriedWaitingForLongPressToUnpairStateName])
    {
        [self fireStateMachineEvent:kReturnToMarriedEventName];
    }
    else if ([self currentStateHasName:kSeparatedWaitingForLongPressToUnpairStateName])
    {
        [self fireStateMachineEvent:kBecomeSeparatedEventName];
    }
}

- (void)comparePairingSpotAndTipReleaseTimesAndTransitionState
{
    NSAssert([self currentStateHasName:kEngagedWaitingForTipReleaseStateName] ||
             [self currentStateHasName:kEngagedWaitingForPairingSpotReleaseStateName], @"");
    NSAssert(self.lastPairingSpotReleaseTime && self.pen.lastTipReleaseTime, @"");

    NSDate *t0 = self.lastPairingSpotReleaseTime;
    NSDate *t1 = self.pen.lastTipReleaseTime;
    NSTimeInterval tipAndPairingSpoteReleaseTimeDifference = fabs([t0 timeIntervalSinceDate:t1]);

    [FTLog logWithFormat:@"Difference in pairing spot and tip press release times (ms): %f",
     tipAndPairingSpoteReleaseTimeDifference * 1000.0];

    if (tipAndPairingSpoteReleaseTimeDifference < kEngagedStateTimeout)
    {
        [self fireStateMachineEvent:kBecomeMarriedEventName];
    }
    else
    {
        [self fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }
}

#pragma mark -

- (void)disconnect
{
    if ([self.stateMachine canFireEvent:kDisconnectAndBecomeSingleEventName])
    {
        [self fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }
}

- (void)startTrialSeparation
{
    if ([self.stateMachine canFireEvent:kPrepareToSwingEventName])
    {
        [self fireStateMachineEvent:kPrepareToSwingEventName];
    }
}

- (void)retrievePairedPeripheral
{
    NSAssert(self.pairedPeripheralUUID, @"paired peripheral UUID non-nil");

    [FTLog log:@"Retrieving paired peripherals"];

    NSArray *peripheralUUIDs = @[(__bridge id)self.pairedPeripheralUUID];
    [self.centralManager retrievePeripherals:peripheralUUIDs];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)centralManager
{
    NSAssert(self.centralManager == centralManager, @"centralManager matches expected");

    if (centralManager.state == CBCentralManagerStatePoweredOn)
    {
        if ([self currentStateHasName:kWaitingForCentralManagerToPowerOnStateName])
        {
            if (self.pairedPeripheralUUID)
            {
                [self fireStateMachineEvent:kRetrieveConnectedPeripheralsFromSeparatedEventName];
            }
            else
            {
                if (self.isPairingSpotPressed)
                {
                    [self fireStateMachineEvent:kBeginDatingAndRetrieveConnectedPeripheralsEventName];
                }
                else
                {
                    [self fireStateMachineEvent:kBecomeSingleEventName];
                }
            }
        }
    }
    else
    {
        if ([self currentStateHasName:kWaitingForCentralManagerToPowerOnStateName])
        {
            [self reset];
        }
        else
        {
            [self fireStateMachineEvent:kWaitForCentralManagerToPowerOnEventName];
        }

        // If the state of the CBCentralManager is ever anything than PoweredOn, sever the pairing to the
        // peripheral.
        self.pairedPeripheralUUID = NULL;
    }
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
    [FTLog logWithFormat:@"Discovered peripheral with name: \"%@\" IsReconciling: %d RSSI: %d.",
     peripheral.name,
     [self isPeripheralReconciling:advertisementData],
     [RSSI integerValue]];

    BOOL isPeripheralReconciling = [self isPeripheralReconciling:advertisementData];

    if ([self currentStateHasName:kDatingScanningStateName])
    {
        NSAssert(!self.pen, @"pen is nil");

        if (!isPeripheralReconciling)
        {
            self.pen = [[FTPen alloc] initWithPeripheral:peripheral];

            [self fireStateMachineEvent:kAttemptConnectionFromDatingEventName];
        }
        else
        {
            self.scanningState = ScanningStateEnabledWithPolling;
        }
    }
    else if ([self currentStateHasName:kSwingingStateName])
    {
        if ([self isPairedPeripheral:peripheral])
        {
            if (isPeripheralReconciling)
            {
                NSAssert(!self.pen, @"pen is nil");
                self.pen = [[FTPen alloc] initWithPeripheral:peripheral];
                [self fireStateMachineEvent:kAttemptConnectionFromSwingingEventName];
            }
            else
            {
                [self.stateMachine resetStateTimeoutTimer];
            }
        }
    }
    else if ([self currentStateHasName:kSeparatedStateName])
    {
        if ([self isPairedPeripheral:peripheral] &&
            isPeripheralReconciling)
        {
            NSAssert(!self.pen, @"pen is nil");
            self.pen = [[FTPen alloc] initWithPeripheral:peripheral];
            [self fireStateMachineEvent:kAttemptConnectionFromSeparatedEventName];
        }
    }
    else if ([self currentStateHasName:kMarriedWaitingForLongPressToUnpairStateName])
    {
        // Reject the paired peripheral. We don't want to reconnect to the peripheral we may be using
        // to press the pairing spot to sever the pairing right now.
        if (![self isPairedPeripheral:peripheral] &&
            !isPeripheralReconciling)
        {
            [self.peripheralsDiscoveredDuringLongPress addObject:peripheral];
        }
    }
    else if ([self currentStateHasName:kSeparatedWaitingForLongPressToUnpairStateName])
    {
        // Unlike in kMarriedWaitingForLongPressToDisconnectStateName, we will accept the paired peripheral
        // when separated. It might just be trying to reconnect!
        if (!isPeripheralReconciling)
        {
            [self.peripheralsDiscoveredDuringLongPress addObject:peripheral];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error
{
    [FTLog logWithFormat:@"Failed to connect to peripheral: %@. (%@).",
     peripheral,
     error.localizedDescription];

    [self handleError];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    if (self.pen.peripheral == peripheral &&
        ([self currentStateHasName:kDatingAttemptingConnectiongStateName] ||
         [self currentStateHasName:kSwingingAttemptingConnectionStateName] ||
         [self currentStateHasName:kSeparatedAttemptingConnectionStateName]))
    {
        [self.pen peripheralConnectionStatusDidChange];
    }
    else if ([self currentStateHasName:kUpdatingFirmwareAttemptingConnectionStateName])
    {
        [self.pen peripheralConnectionStatusDidChange];
        [self fireStateMachineEvent:kUpdateFirmwareEventName];
    }
    else
    {
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error
{
    NSAssert(self.pen.peripheral == peripheral, @"Peripheral matches pen peripheral.");

    if (self.pen.peripheral == peripheral)
    {
        if (error)
        {
            [FTLog logWithFormat:@"Disconnected peripheral with error: %@", error.localizedDescription];
        }

        if ([self currentStateHasName:kUpdatingFirmwareStateName])
        {
            if (self.updateManager.state == TIUpdateManagerStateSucceeded)
            {
                FTPen *pen = self.pen;
                self.pen = nil;
                [pen peripheralConnectionStatusDidChange];

                // TODO: Should this wait until reconnect?
                [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateDidCompleteSuccessfully
                                                                    object:self];

                [self fireStateMachineEvent:kBecomeSeparatedEventName];
            }
            else
            {
                [FTLog log:@"Peripheral did disconnect while updating firmware. Reconnecting."];

                if ([FTFirmwareManager imageTypeRunningOnPen:self.pen] == FTFirmwareImageTypeFactory)
                {
                    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenUnexpectedDisconnectWhileUpdatingFirmwareNotificationName
                                                                        object:self.pen];
                }

                // Normally when we transition from the UpdatingFirmware state we cancel the firmware update,
                // which restores the peripheral delegate. In this case since we've created a new FTPen, we
                // *don't* want the old delegate.
                self.updateManager.shouldRestorePeripheralDelegate = NO;
                self.pen = [[FTPen alloc] initWithPeripheral:self.pen.peripheral];
                [self fireStateMachineEvent:kAttemptConnectionFromUpdatingFirmwareEventName];
            }
        }
        else if ([self currentStateHasName:kUpdatingFirmwareAttemptingConnectionStateName] ||
                 [self currentStateHasName:kDatingAttemptingConnectiongStateName] ||
                 [self currentStateHasName:kSeparatedAttemptingConnectionStateName] ||
                 [self currentStateHasName:kSwingingAttemptingConnectionStateName])
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenUnexpectedDisconnectWhileConnectingNotifcationName
                                                                object:self.pen];

            // Try again. Eventually the state will timeout.
            [self.centralManager connectPeripheral:self.pen.peripheral options:nil];
        }
        else
        {
            FTPen *pen = self.pen;
            self.pen = nil;

            [pen peripheralConnectionStatusDidChange];

            if ([self currentStateHasName:kDisconnectingAndBecomingSingleStateName])
            {
                if (self.onDeckPeripheral)
                {
                    self.pen = [[FTPen alloc] initWithPeripheral:self.onDeckPeripheral];
                    [self fireStateMachineEvent:kAttemptConnectionFromDatingEventName];
                }
                else
                {
                    [self fireStateMachineEvent:kCompleteDisconnectionAndBecomeSingleEventName];
                }
            }
            else if ([self currentStateHasName:kDisconnectingAndBecomingSeparatedStateName])
            {
                [self fireStateMachineEvent:kCompleteDisconnectionAndBecomeSeparatedEventName];
            }
            else if ([self currentStateHasName:kPreparingToSwingStateName])
            {
                [self fireStateMachineEvent:kSwingEventName];
            }
            else
            {
                // Estimate whether the peripheral disconnected due to inactivity timeout by comparing
                // the time since last activity to the inactivity timeout duration.
                //
                // TODO: The peripheral should report this to us in a robust fashion, either by setting a
                // charachteristic or returning an error code in the disconnect.
                BOOL didDisconnectDueToInactivityTimeout = NO;
                if ([self currentStateHasName:kMarriedStateName])
                {
                    static const NSTimeInterval kInactivityTimeoutMargin = 20.0;
                    NSTimeInterval timeSinceLastActivity = -[self.pairedPeripheralLastActivityTime timeIntervalSinceNow];
                    [FTLog logWithFormat:@"Did disconnect, time since last activity: %f", timeSinceLastActivity];

                    const NSTimeInterval inactivityTimeout = (pen.inactivityTimeout == -1 ?
                                                              kInactivityTimeout :
                                                              pen.inactivityTimeout * 60.0);

                    if (timeSinceLastActivity - inactivityTimeout >= -kInactivityTimeoutMargin)
                    {
                        didDisconnectDueToInactivityTimeout = YES;
                        [FTLog log:@"Did disconnect due to peripheral inactivity timeout."];
                    }
                }

                // Fire notifications to report that we've had an unexpected disconnect. Make sure to do this
                // prior to transitioning states.
                if (!didDisconnectDueToInactivityTimeout &&
                    ([self currentStateHasName:kMarriedStateName] ||
                     [self currentStateHasName:kMarriedWaitingForLongPressToUnpairStateName] ||
                     [self currentStateHasName:kEngagedStateName] ||
                     [self currentStateHasName:kEngagedWaitingForPairingSpotReleaseStateName] ||
                     [self currentStateHasName:kEngagedWaitingForTipReleaseStateName]))
                {
                    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenUnexpectedDisconnectNotificationName
                                                                        object:pen];
                }

                if ([self currentStateHasName:kMarriedStateName] ||
                    [self currentStateHasName:kMarriedWaitingForLongPressToUnpairStateName])
                {
                    // If the peripheral disconnected due to inactivity timeout, it won't go to separated,
                    // and therefore won't be available to reconnect. Therefore, go to single, not separated.
                    if (didDisconnectDueToInactivityTimeout)
                    {
                        [self fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
                    }
                    else
                    {
                        [self fireStateMachineEvent:kBecomeSeparatedEventName];
                    }
                }
                else if ([self currentStateHasName:kEngagedStateName] ||
                         [self currentStateHasName:kEngagedWaitingForPairingSpotReleaseStateName] ||
                         [self currentStateHasName:kEngagedWaitingForTipReleaseStateName])
                {
                    [self fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
                }
            }
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals
{
    static NSString * const kCharcoalPeripheralName = @"Charcoal by 53";
    static NSString * const kPencilPeripheralName = @"Pencil";

    if ([self currentStateHasName:kDatingRetrievingConnectedPeripheralsStateName])
    {
        for (CBPeripheral *peripheral in peripherals)
        {
            if ([peripheral.name isEqualToString:kPencilPeripheralName] ||
                [peripheral.name isEqualToString:kCharcoalPeripheralName])
            {
                NSAssert(!self.pen, @"pen is nil");
                self.pen = [[FTPen alloc] initWithPeripheral:peripheral];
                [self fireStateMachineEvent:kAttemptConnectionFromDatingEventName];
                return;
            }
        }

        [self fireStateMachineEvent:kBeginDatingScanningEventName];
    }
    else if ([self currentStateHasName:kSeparatedRetrievingConnectedPeripheralsStateName])
    {
        for (CBPeripheral *peripheral in peripherals)
        {
            if ([peripheral.name isEqualToString:kPencilPeripheralName] &&
                [self isPairedPeripheral:peripheral])
            {
                NSAssert(!self.pen, @"pen is nil");
                self.pen = [[FTPen alloc] initWithPeripheral:peripheral];
                [self fireStateMachineEvent:kAttemptConnectionFromSeparatedEventName];
                return;
            }
        }

        [self fireStateMachineEvent:kBecomeSeparatedEventName];
    }
}

#pragma mark - Firmware

- (NSNumber *)isFirmwareUpdateAvailable:(NSInteger *)currentVersion
                          updateVersion:(NSInteger *)updateVersion
{
    return [FTFirmwareManager isVersionAtPath:[FTFirmwareManager imagePath]
                        newerThanVersionOnPen:self.pen
                               currentVersion:currentVersion
                                updateVersion:updateVersion];
}

- (BOOL)updateFirmware
{
    return [self updateFirmware:[FTFirmwareManager imagePath]];
}

- (BOOL)updateFirmware:(NSString *)firmwareImagePath;
{
    NSAssert(firmwareImagePath, @"firmwareImagePath must be non-nil");

    if ([self.stateMachine canFireEvent:kUpdateFirmwareEventName])
    {
        self.firmwareImagePath = firmwareImagePath;
        [self fireStateMachineEvent:kUpdateFirmwareEventName];
        return YES;
    }

    return NO;
}

- (void)cancelFirmwareUpdate
{
    BOOL didCancel = NO;

    if ([self currentStateHasName:kUpdatingFirmwareStateName])
    {
        [self fireStateMachineEvent:kBecomeMarriedEventName];
        didCancel = YES;
    }
    else if ([self currentStateHasName:kUpdatingFirmwareAttemptingConnectionStateName])
    {
        [self fireStateMachineEvent:kDisconnectAndBecomeSeparatedEventName];
        didCancel = YES;
    }

    if (didCancel)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateWasCancelled
                                                            object:self];
    }
}

#pragma mark - TIUpdateManagerDelegate

- (void)updateManager:(TIUpdateManager *)manager didFinishUpdate:(NSError *)error
{
    NSAssert([self currentStateHasName:kUpdatingFirmwareStateName], @"in updating firmware state");
    NSAssert(self.updateManager, @"update manager non-nil");
    NSAssert(manager, nil);

    if (error)
    {
        // TODO: Should retry...
    }
    else
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateDidFinishSendingUpdate
                                                            object:self];
    }
}

- (void)updateManager:(TIUpdateManager *)manager didUpdatePercentComplete:(float)percentComplete
{
    NSAssert(manager, nil);

    if ([FTFirmwareManager imageTypeRunningOnPen:self.pen] == FTFirmwareImageTypeFactory)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateDidUpdatePercentComplete
                                                            object:self
                                                          userInfo:@{ kFTPenManagerPercentCompleteProperty : @(percentComplete) }];
    }
}

#pragma mark - Scanning

- (void)setScanningState:(ScanningState)scanningState
{
    if (_scanningState != scanningState)
    {
        _scanningState = scanningState;

        if (scanningState == ScanningStateDisabled)
        {
            self.isScanningForPeripherals = NO;
            [self invalidateIsScanningForPeripheralsToggleTimer];
        }
        else if (scanningState == ScanningStateEnabled)
        {
            self.isScanningForPeripherals = YES;
            [self invalidateIsScanningForPeripheralsToggleTimer];
        }
        else if (scanningState == ScanningStateEnabledWithPolling)
        {
            self.isScanningForPeripherals = YES;
            [self startIsScanningForPeripheralsToggleTimer];
        }
        else
        {
            NSAssert(NO, @"Unexpected scanning state");
        }
    }
}

- (void)invalidateIsScanningForPeripheralsToggleTimer
{
    [self.isScanningForPeripheralsToggleTimer invalidate];
    self.isScanningForPeripheralsToggleTimer = nil;
}

- (void)startIsScanningForPeripheralsToggleTimer
{
    self.isScanningForPeripheralsToggleTimer = [NSTimer scheduledTimerWithTimeInterval:kIsScanningForPeripheralsToggleTimerInterval
                                                                                target:self
                                                                              selector:@selector(isScanningForPeripheralsToggleTimerFired:)
                                                                              userInfo:nil
                                                                               repeats:YES];
}

- (void)isScanningForPeripheralsToggleTimerFired:(NSTimer *)timer
{
    // TODO: This means the peripheral has not yet been disconnected. We should handle this more gracefully.
    if (!self.pen)
    {
        self.isScanningForPeripherals = !self.isScanningForPeripherals;
    }
}

- (void)setIsScanningForPeripherals:(BOOL)isScanningForPeripherals
{
    if (_isScanningForPeripherals != isScanningForPeripherals)
    {
        _isScanningForPeripherals = isScanningForPeripherals;

        if (_isScanningForPeripherals)
        {
            [FTLog log:@"Begin scan for peripherals."];

            NSDictionary *options = @{ CBCentralManagerScanOptionAllowDuplicatesKey : @NO };
            [self.centralManager scanForPeripheralsWithServices:@[[FTPenServiceUUIDs penService]]
                                                        options:options];
        }
        else
        {
            [FTLog log:@"End scan for peripherals."];

            [self.centralManager stopScan];
        }
    }
}

@end
