//
//  FTPenManager.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import <UIKit/UIKit.h>

#import "Core/AnimationPump.h"
#import "Core/Asserts.h"
#import "Core/Log.h"
#import "Core/NSString+FTTimeWithInterval.h"
#import "Core/NSTimer+Helpers.h"
#import "Core/Touch/TouchTracker.h"
#import "FiftyThreeSdk/PenConnectionView.h"
#import "FiftyThreeSdk/TouchClassifier.h"
#import "FTEventDispatcher+Private.h"
#import "FTFirmwareManager+Private.h"
#import "FTFirmwareManager.h"
#import "FTLogPrivate.h"
#import "FTPen+Private.h"
#import "FTPen.h"
#import "FTPenManager+Internal.h"
#import "FTPenManager+Private.h"
#import "FTPenManager.h"
#import "FTServiceUUIDs.h"
#import "FTTouchClassifier+Private.h"
#import "FTTrialSeparationMonitor.h"
#import "TIUpdateManager.h"
#import "TransitionKit.h"

static NSString *const kCharcoalPeripheralName = @"Charcoal by 53";
static NSString *const kPencilPeripheralName = @"Pencil";

NSString *const kPairedPeripheralUUIDUserDefaultsKey = @"com.fiftythree.pen.pairedPeripheralUUID";
NSString *const kPairedPeripheralLastActivityTimeUserDefaultsKey = @"com.fiftythree.pen.pairedPeripheralLastActivityTime";

NSString *const kFTPenManagerDidUpdateStateNotificationName = @"com.fiftythree.penManager.didUpdateState";
NSString *const kFTPenManagerDidFailToDiscoverPenNotificationName = @"com.fiftythree.penManager.didFailToDiscoverPen";
NSString *const kFTPenUnexpectedDisconnectNotificationName = @"com.fiftythree.penManager.unexpectedDisconnect";
NSString *const kFTPenUnexpectedDisconnectWhileConnectingNotifcationName = @"com.fiftythree.penManager.unexpectedDisconnectWhileConnecting";
NSString *const kFTPenUnexpectedDisconnectWhileUpdatingFirmwareNotificationName = @"com.fiftythre.penManager.unexpectedDisconnectWhileUpdatingFirmware";

NSString *const kFTPenManagerFirmwareUpdateAvailableDidChange = @"com.fiftythree.penManger.firmwareUpdateAvailable";
NSString *const kFTPenManagerFirmwareUpdateDidPrepare = @"com.fiftythree.penManger.firmwareUpdateDidPrepare";
NSString *const kFTPenManagerFirmwareUpdateWaitingForPencilTipRelease = @"com.fiftythree.penManger.firmwareUpdateWaitingForPencilTipPress";
NSString *const kFTPenManagerFirmwareUpdateDidBegin = @"com.fiftythree.penManger.firmwareUpdateDidBegin";
NSString *const kFTPenManagerFirmwareUpdateDidBeginSendingUpdate = @"com.fiftythree.penManger.firmwareUpdateDidBeginSendingUpdate";
NSString *const kFTPenManagerFirmwareUpdateDidUpdatePercentComplete = @"com.fiftythree.penManger.firmwareUpdateDidUpdatePercentComplete";
NSString *const kFTPenManagerPercentCompleteProperty = @"com.fiftythree.penManager.percentComplete";
NSString *const kFTPenManagerFirmwareUpdateDidFinishSendingUpdate = @"com.fiftythree.penManger.firmwareUpdateDidFinishSendingUpdate";
NSString *const kFTPenManagerFirmwareUpdateDidCompleteSuccessfully = @"com.fiftythree.penManger.firmwareUpdateDidCompleteSuccessfully";
NSString *const kFTPenManagerFirmwareUpdateDidFail = @"com.fiftythree.penManger.firmwareUpdateDidFail";
NSString *const kFTPenManagerFirmwareUpdateWasCancelled = @"com.fiftythree.penManger.firmwareUpdateWasCancelled";

static const NSTimeInterval kInactivityTimeoutMinutes = 10.0;
static const NSTimeInterval kDatingScanningTimeout = 4.f;
static const NSTimeInterval kEngagedStateTimeout = 0.1;
static const NSTimeInterval kIsScanningForPeripheralsToggleTimerInterval = 0.1;
static const NSTimeInterval kSwingingStateTimeout = 4.0;
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
static NSString *const kUpdatingFirmwareStartedStateName = @"StartedUpdatingFirmware";
static NSString *const kUpdatingFirmwareWaitingForTipReleaseStateName = @"WaitingForTipReleaseToStartFirmwareUpdate";

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
static NSString *const kUpdateFirmwareOnTipReleaseEventName = @"UpdateFirmwareOnTipRelease";
static NSString *const kAttemptConnectionFromUpdatingFirmwareEventName = @"AttemptConnectionFromUpdatingFirmware";
static NSString *const kStartUpdatingFirmwareEventName = @"StartUpdatingFirmware";

namespace
{
static FTPenManager *sharedInstance = nil;
}

#pragma mark - Style

@implementation FTPairingUIStyleOverrides

@end

#pragma mark -

typedef enum {
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

BOOL FTPenManagerStateIsDisconnected(FTPenManagerState state)
{
    return (state == FTPenManagerStateDisconnected ||
            state == FTPenManagerStateDisconnectedLongPressToUnpair ||
            state == FTPenManagerStateReconnecting);
}

NSString *FTPenManagerStateToString(FTPenManagerState state)
{
    switch (state) {
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

@interface FTPenInformation ()
@property (nonatomic, readwrite) NSString *name;
@property (nonatomic, readwrite) NSString *manufacturerName;
@property (nonatomic, readwrite) FTPenBatteryLevel batteryLevel;
@property (nonatomic, readwrite) NSString *firmwareRevision;
@property (nonatomic, readwrite) BOOL isTipPressed;
@property (nonatomic, readwrite) BOOL isEraserPressed;
@end

@protocol FTPenManagerDelegatePrivate <FTPenManagerDelegate>
@optional
// See FTPenManager's automaticUpdates property.
//
// Invoked if we get events that should trigger turning on the display link. You should only need this
// if you're running your own displayLink.
- (void)penManagerNeedsUpdateDidChange;

@end

// Placeholder implementation.
@implementation FTPenInformation
@end

@interface FTPenManager () <CBCentralManagerDelegate, TIUpdateManagerDelegate, PenConnectionViewDelegate, AnimationPumpDelegate>

@property (nonatomic) BOOL isPairingSpotPressed;

@property (nonatomic) CBCentralManager *centralManager;

@property (nonatomic, copy) NSString *firmwareImagePath;
@property (nonatomic) TIUpdateManager *updateManager;

@property (nonatomic) TKStateMachine *stateMachine;

@property (nonatomic, readwrite) FTPenManagerState state;

@property (nonatomic, readwrite) FTPen *pen;

@property (nonatomic) ScanningState scanningState;

@property (nonatomic) BOOL isScanningForPeripherals;
@property (nonatomic) NSTimer *isScanningForPeripheralsToggleTimer;

@property (nonatomic) NSTimer *ensureHasListenerTimer;
@property (nonatomic) NSDate *ensureHasListenerTimerStartTime;

@property (nonatomic) NSDate *lastPairingSpotReleaseTime;

// The UUID of the peripheral with which we are currently paired.
@property (nonatomic) NSUUID *pairedPeripheralUUID;

// The time at which the last tip/eraser press activity that was observed on the paired peripheral.
@property (nonatomic) NSDate *pairedPeripheralLastActivityTime;

@property (nonatomic) NSMutableSet *peripheralsDiscoveredDuringLongPress;

@property (nonatomic) CBPeripheral *onDeckPeripheral;

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;

@property (nonatomic) FTTrialSeparationMonitor *trialSeparationMonitor;

@property (nonatomic) FTPenInformation *info;

@property (nonatomic) FTTouchClassifier *classifier;

@property (nonatomic) NSMutableArray *pairingViews;

@property (nonatomic) CADisplayLink *displayLink;

@property (nonatomic) BOOL didConnectViaWarmStart;

@property (nonatomic) NSInteger originalInactivityTimeout;

@property (nonatomic) BOOL isFetchingLatestFirmware;
@property (nonatomic) NSInteger latestFirmwareVersion;
@property (nonatomic) NSDate *lastFirmwareNetworkCheckTime;

@property (nonatomic, readwrite) NSNumber *firmwareUpdateIsAvailable;

@property (nonatomic) BOOL penHasListener;

@property (nonatomic) BOOL automaticUpdatesEnabled;

@property (nonatomic) BOOL needsUpdate;

@property (nonatomic) BOOL disableLongPressToUnpairIfTipPressed;

@property (nonatomic) BOOL forceFirmwareUpdate;

@property (nonatomic) BOOL tryToAutoStartFirmwareUpdate;

@property (nonatomic) BOOL tipWasPressedAfterInactivityTimeoutWasDisabled;

@end

@implementation FTPenManager

- (void)setPenHasListener:(BOOL)penHasListener
{
    _penHasListener = penHasListener;

    if (self.pen.hasListener != _penHasListener) {
        self.pen.hasListener = _penHasListener;
    }
}

- (id)init
{
    self = [super init];
    if (self) {
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
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(penDidWriteHasListener:)
                                                     name:kFTPenDidWriteHasListenerNotificationName
                                                   object:nil];

        MLOG_INFO(FTLogSDK, "Paired peripheral CentralId: %x", (unsigned int)[self centralIdFromPeripheralId:self.pairedPeripheralUUID]);

        [self initializeStateMachine];

        self.trialSeparationMonitor = [[FTTrialSeparationMonitor alloc] init];
        self.trialSeparationMonitor.penManager = self;

        self.pairingViews = [@[] mutableCopy];

        _shouldCheckForFirmwareUpdates = NO;
        self.firmwareUpdateIsAvailable = nil;
        self.disableLongPressToUnpairIfTipPressed = NO;
    }

    return self;
}

- (void)dealloc
{
    [self reset];

    auto instance = fiftythree::core::spc<AnimationPumpObjC>(AnimationPump::Instance());
    if (instance->GetDelegate() == self) {
        instance->SetDelegate(nil);
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reset
{
    [self resetEnsureHasListenerTimer];
    [self resetBackgroundTask];

    self.firmwareImagePath = nil;
    self.updateManager = nil;

    FTPen *pen = self.pen;
    self.pen = nil;
    [pen peripheralConnectionStatusDidChange];

    self.scanningState = ScanningStateDisabled;

    _centralManager.delegate = nil;
    _centralManager = nil;

    self.trialSeparationMonitor = nil;
    self.originalInactivityTimeout = 0;
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
    if (!_centralManager) {
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    return _centralManager;
}

- (void)setState:(FTPenManagerState)state
{
    if (_state != state) {
        if (_state == FTPenManagerStateUpdatingFirmware) {
            self.tryToAutoStartFirmwareUpdate = NO;
            self.forceFirmwareUpdate = NO;
            self.firmwareImagePath = nil;
        }

        _state = state;

        if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
            self.penHasListener = YES;
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerDidUpdateStateNotificationName
                                                            object:self];

        [self.delegate penManagerStateDidChange:state];
    }
}

- (void)setPen:(FTPen *)pen
{
    _pen = pen;

    [[NSNotificationCenter defaultCenter] removeObserver:kFTPenDidEncounterErrorNotificationName];
    [[NSNotificationCenter defaultCenter] removeObserver:kFTPenIsReadyDidChangeNotificationName];
    [[NSNotificationCenter defaultCenter] removeObserver:kFTPenIsTipPressedDidChangeNotificationName];
    [[NSNotificationCenter defaultCenter] removeObserver:kFTPenDidUpdatePropertiesNotificationName];
    [[NSNotificationCenter defaultCenter] removeObserver:kFTPenBatteryLevelDidChangeNotificationName];
    [[NSNotificationCenter defaultCenter] removeObserver:kFTPenDidUpdatePrivatePropertiesNotificationName];

    if (_pen) {
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

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(penDidUpdatePrivateProperties:)
                                                     name:kFTPenDidUpdatePrivatePropertiesNotificationName
                                                   object:_pen];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(penBatteryLevelDidChange:)
                                                     name:kFTPenBatteryLevelDidChangeNotificationName
                                                   object:_pen];
    }
}

- (void)setPenCentralId:(UInt32)centralId
{
    FTAssert(self.pen, @"Pen is non-nil");
    self.pen.centralId = centralId;
}

- (void)setPairedPeripheralUUID:(NSUUID *)pairedPeripheralUUID
{
    [[NSUserDefaults standardUserDefaults] setValue:pairedPeripheralUUID.UUIDString
                                             forKey:kPairedPeripheralUUIDUserDefaultsKey];

    // Also update the last activity time. Be sure to do this prior to synchronize, since setting last
    // activity time does not call synchronize on its own.
    if (pairedPeripheralUUID != NULL) {
        self.pairedPeripheralLastActivityTime = [NSDate date];
    } else {
        self.pairedPeripheralLastActivityTime = nil;
    }

    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSUUID *)pairedPeripheralUUID
{
    id object = [[NSUserDefaults standardUserDefaults] valueForKey:kPairedPeripheralUUIDUserDefaultsKey];
    if ([object isKindOfClass:NSString.class]) {
        return [[NSUUID alloc] initWithUUIDString:object];
    }
    return nil;
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
            [peripheral.identifier isEqual:self.pairedPeripheralUUID]);
}

- (void)setShouldCheckForFirmwareUpdates:(BOOL)shouldCheck
{
    if (_shouldCheckForFirmwareUpdates != shouldCheck) {
        _shouldCheckForFirmwareUpdates = shouldCheck;
        if (shouldCheck) {
            [self attemptLoadFirmwareFromNetworkForVersionChecking];
        }
    }
}

- (void)penDidEncounterError:(NSNotification *)notification
{
    [self handleError];
}

- (void)handleError
{
    MLOG_INFO(FTLogSDK, "Pen did encounter error. Disconnecting.");

    // Make sure that we favor transitions that go through disconnect over going straight
    // to single. Some states may support both, but if we're connected we need to disconnect
    // first.
    if ([self.stateMachine canFireEvent:kDisconnectAndBecomeSingleEventName]) {
        [self fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    } else if ([self.stateMachine canFireEvent:kDisconnectAndBecomeSeparatedEventName]) {
        [self fireStateMachineEvent:kDisconnectAndBecomeSeparatedEventName];
    } else if ([self.stateMachine canFireEvent:kBecomeSingleEventName]) {
        [self fireStateMachineEvent:kBecomeSingleEventName];
    }
}

- (void)penIsReadyDidChange:(NSNotification *)notification
{
    if (self.pen.isReady) {
        MLOG_INFO(FTLogSDK, "Pen is ready");

        if ([self currentStateHasName:kDatingAttemptingConnectiongStateName]) {
            [self fireStateMachineEvent:kBecomeEngagedEventName];
        } else if ([self currentStateHasName:kSeparatedAttemptingConnectionStateName] ||
                   [self currentStateHasName:kSwingingAttemptingConnectionStateName]) {
            [self fireStateMachineEvent:kBecomeMarriedEventName];
        }
    } else {
        // TODO: Can this ever happen?
    }
}

- (void)penIsTipPressedDidChange:(NSNotification *)notification
{
    if (!self.pen.isTipPressed && self.pen.lastTipReleaseTime) {
        if (self.pen && self.pen.inactivityTimeout == 0) {
            self.tipWasPressedAfterInactivityTimeoutWasDisabled = YES;
            if (self.tryToAutoStartFirmwareUpdate) {
                [self startUpdatingFirmware];
            }
        } else {
            self.tipWasPressedAfterInactivityTimeoutWasDisabled = NO;
        }
        if ([self currentStateHasName:kEngagedStateName]) {
            [self fireStateMachineEvent:kWaitForPairingSpotReleaseEventName];
        } else if ([self currentStateHasName:kEngagedWaitingForTipReleaseStateName]) {
            [self comparePairingSpotAndTipReleaseTimesAndTransitionState];
        } else if ([self currentStateHasName:kUpdatingFirmwareWaitingForTipReleaseStateName]) {
            [self fireStateMachineEvent:kStartUpdatingFirmwareEventName];
        }
    }

    [self updatePenInfoObjectAndInvokeDelegate];

    self.pairedPeripheralLastActivityTime = [NSDate date];
}

- (void)penIsEraserPressedDidChange:(NSNotification *)notification
{
    [self updatePenInfoObjectAndInvokeDelegate];
    self.pairedPeripheralLastActivityTime = [NSDate date];
}

- (void)updatePenInfoObjectAndInvokeDelegate
{
    if (self.pen) {
        if (!self.info) {
            self.info = [[FTPenInformation alloc] init];
        }

        if (self.pen.batteryLevel) {
            int batteryLevel = [self.pen.batteryLevel intValue];

            if (batteryLevel <= 10) {
                self.info.batteryLevel = FTPenBatteryLevelCriticallyLow;
            } else if (batteryLevel <= 25) {
                self.info.batteryLevel = FTPenBatteryLevelLow;
            } else if (batteryLevel <= 50) {
                self.info.batteryLevel = FTPenBatteryLevelMediumLow;
            } else if (batteryLevel <= 75) {
                self.info.batteryLevel = FTPenBatteryLevelMediumHigh;
            } else {
                self.info.batteryLevel = FTPenBatteryLevelHigh;
            }
        } else {
            self.info.batteryLevel = FTPenBatteryLevelUnknown;
        }

        if (self.pen) {
            NSInteger currentVersion = [FTFirmwareManager currentRunningFirmwareVersion:self.pen];
            if (currentVersion > 0) {
                self.info.firmwareRevision = [@(currentVersion) stringValue];
            } else {
                self.info.firmwareRevision = nil;
            }
            if (currentVersion != -1) {
                [self updateFirmwareUpdateIsAvailble];
            }
        }

        if (self.pen.name) {
            self.info.name = self.pen.name;
        }

        if (self.pen.manufacturerName) {
            self.info.manufacturerName = self.pen.manufacturerName;
        }

        self.info.isEraserPressed = self.pen.isEraserPressed;
        self.info.isTipPressed = self.pen.isTipPressed;

        [self ensureNeedsUpdate];

        if ([self.delegate respondsToSelector:@selector(penManagerNeedsUpdateDidChange)]) {
            [((id<FTPenManagerDelegatePrivate>)self.delegate)penManagerNeedsUpdateDidChange];
        }
        if ([self.delegate respondsToSelector:@selector(penInformationDidChange)]) {
            [((id<FTPenManagerDelegatePrivate>)self.delegate)penInformationDidChange];
        }
    }
}
- (void)penBatteryLevelDidChange:(NSNotification *)notification
{
    [self updatePenInfoObjectAndInvokeDelegate];
}

- (void)penDidUpdatePrivateProperties:(NSNotification *)notfication
{
    // This odd bit of code is here for good reason. When apps switch on iOS they are not guarenteed to resign
    // enter background and become active in lock-step order. So, you can get the foreground message on the other
    // apps' delegate *before* the current running application gets background message. If the pen think's
    // hasListener has been set to zero but this app is in the foreground, we need to ensure the hasListener
    // comes into line with the value we expect it to be.
    if (self.pen.hasListener != self.penHasListener) {
        self.pen.hasListener = self.penHasListener;
    }

    BOOL hasInactivityTimeoutUpdated = [notfication.userInfo[kFTPenNotificationPropertiesKey] containsObject:kFTPenInactivityTimeoutPropertyName];
    if (hasInactivityTimeoutUpdated) {
        if ([self currentStateHasName:kUpdatingFirmwareStateName]) {
            FTAssert(self.pen, @"pen is non-nil");
            if (0 == self.pen.inactivityTimeout && self.tryToAutoStartFirmwareUpdate) {
                [self startUpdatingFirmware];
            }
        } else if (self.state != FTPenManagerStateUpdatingFirmware && self.pen.inactivityTimeout == 0) {
            // Make sure inactivity time out is sane except when we're doing FW upgrades.
            self.pen.inactivityTimeout = kInactivityTimeoutMinutes;
        }
    }
}

- (void)penDidUpdateProperties:(NSNotification *)notification
{
    // Firmware update can't proceed until we've refreshed the factory and upgrade firmware
    // versions. (The reason for this is that after the upgrade -> factory reset we need the
    // check that we're running the factory version to be accurate.)
    if ([self currentStateHasName:kUpdatingFirmwareStartedStateName]) {
        FTAssert(self.pen, @"pen is non-nil");
        if (self.pen.firmwareRevision &&
            self.pen.softwareRevision &&
            !self.updateManager) {
            NSInteger runningFirmwareVersion = [FTFirmwareManager currentRunningFirmwareVersion:self.pen];
            if (!self.forceFirmwareUpdate && self.latestFirmwareVersion > 0 && runningFirmwareVersion >= self.latestFirmwareVersion) {
                // we're done!
                MLOG_DEBUG(FTLogSDK, "Successfully completed firmware update to %ld", runningFirmwareVersion);
                [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateDidCompleteSuccessfully
                                                                    object:self];
                [self fireStateMachineEvent:kBecomeMarriedEventName];
            } else {
                if (self.forceFirmwareUpdate) {
                    self.forceFirmwareUpdate = NO;
                    MLOG_INFO(FTLogSDK, "Ignoring current firmware version. Forcing an update.");
                }
                MLOG_INFO(FTLogSDK, "Factory firmware version: %s", ObjcDescription(self.pen.firmwareRevision));
                MLOG_INFO(FTLogSDK, "Upgrade firmware version: %s", ObjcDescription(self.pen.softwareRevision));

                self.updateManager = [[TIUpdateManager alloc] initWithPeripheral:self.pen.peripheral
                                                                        delegate:self];
                if (!self.firmwareImagePath) {
                    [self.updateManager startUpdateFromWeb];
                } else {
                    [self.updateManager startUpdate:self.firmwareImagePath];
                }
            }
        }
    }

    [self ensureCentralId];

    [self updatePenInfoObjectAndInvokeDelegate];
}

- (void)ensureCentralId
{
    if ([self currentStateHasName:kMarriedStateName]) {
        FTAssert(self.pen, @"pen is non-nil");

        // We have to wait until we both know the current firmware version and we can write the central ID
        // before actually writing it. Also, don't write it more than once.
        if (self.pen.centralId == 0x0 &&
            self.pen.canWriteCentralId &&
            self.pen.softwareRevision != nil) {
            self.pen.centralId = ([FTFirmwareManager currentRunningFirmwareVersion:self.pen] > 55 ? [self centralIdFromPeripheralId:self.pen.peripheral.identifier] : 0x1);
        }
    }
}

#pragma mark - State machine

- (void)initializeStateMachine
{
    FTAssert(!self.stateMachine, @"State machine may only be initialized once.");

    __weak FTPenManager *weakSelf = self;

    self.stateMachine = [TKStateMachine new];

    //
    // States
    //

    void (^attemptingConnectionCommon)() = ^() {
        FTAssert(weakSelf.pen, @"pen is non-nil");

        [weakSelf.centralManager connectPeripheral:weakSelf.pen.peripheral options:nil];
    };

    // WaitingForCentralManagerToPowerOn
    TKState *waitingForCentralManagerToPowerOnState = [TKState stateWithName:kWaitingForCentralManagerToPowerOnStateName];
    [waitingForCentralManagerToPowerOnState setDidEnterStateBlock:^(TKState *state,
                                                                    TKStateMachine *stateMachine) {
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
                                                                   TKStateMachine *stateMachine){
    }];

    // Single
    TKState *singleState = [TKState stateWithName:kSingleStateName];
    [singleState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
        FTAssert(!weakSelf.pen, @"Pen is nil");

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
                                                                       TKStateMachine *stateMachine) {
        weakSelf.state = FTPenManagerStateSeeking;

        BOOL hasRecentCoreBluetooth = weakSelf.centralManager && [weakSelf.centralManager respondsToSelector:@selector(retrieveConnectedPeripheralsWithServices:)];

        NSAssert(hasRecentCoreBluetooth, @"iOS 7 or later is required.");

        NSArray *peripherals = [weakSelf.centralManager retrieveConnectedPeripheralsWithServices:@[[FTPenServiceUUIDs penService]]];

        for (CBPeripheral *peripheral in peripherals)
        {
            if ([peripheral.name isEqualToString:kPencilPeripheralName] ||
                [peripheral.name isEqualToString:kCharcoalPeripheralName])
            {
                self.didConnectViaWarmStart = YES;
                FTAssert(!weakSelf.pen, @"pen is nil");
                MLOG_INFO(FTLogSDKVerbose, "Found Peripheral in DatingRetrievingConnectedPeripherals!");
                weakSelf.pen = [[FTPen alloc] initWithPeripheral:peripheral];
                [weakSelf fireStateMachineEvent:kAttemptConnectionFromDatingEventName];
                return;
            }
        }

        MLOG_INFO(FTLogSDKVerbose, "None - DatingRetrievingConnectedPeripherals!");

        [weakSelf fireStateMachineEvent:kBeginDatingScanningEventName];
    }];

    // DatingScanning
    TKState *datingScanningState = [TKState stateWithName:kDatingScanningStateName
                                       andTimeoutDuration:kDatingScanningTimeout];
    [datingScanningState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
        weakSelf.state = FTPenManagerStateSeeking;

        weakSelf.scanningState = ScanningStateEnabled;
    }];
    [datingScanningState setDidExitStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
        weakSelf.scanningState = ScanningStateDisabled;
    }];
    [datingScanningState setTimeoutExpiredBlock:^(TKState *state,
                                                  TKStateMachine *stateMachine) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerDidFailToDiscoverPenNotificationName
                                                            object:self];
        [weakSelf fireStateMachineEvent:kBecomeSingleEventName];
    }];

    // Dating - Attempting Connection
    TKState *datingAttemptingConnectionState = [TKState stateWithName:kDatingAttemptingConnectiongStateName
                                                   andTimeoutDuration:kAttemptingConnectionStateTimeout];
    [datingAttemptingConnectionState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
        weakSelf.state = FTPenManagerStateConnecting;
        attemptingConnectionCommon();
    }];
    [datingAttemptingConnectionState setTimeoutExpiredBlock:^(TKState *state,
                                                              TKStateMachine *stateMachine) {
        [weakSelf fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }];

    // Engaged
    TKState *engagedState = [TKState stateWithName:kEngagedStateName];
    [engagedState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
        weakSelf.state = FTPenManagerStateConnected;
    }];

    // Engaged - Waiting for Tip Release
    TKState *engagedWaitingForTipReleaseState = [TKState stateWithName:kEngagedWaitingForTipReleaseStateName
                                                    andTimeoutDuration:kEngagedStateTimeout];
    [engagedWaitingForTipReleaseState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
        weakSelf.state = FTPenManagerStateConnected;
    }];
    [engagedWaitingForTipReleaseState setTimeoutExpiredBlock:^(TKState *state, TKStateMachine *stateMachine) {
        [weakSelf fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }];

    // Engaged - Waiting for Pairing Spot Release
    TKState *engagedWaitingForPairingSpotReleaseState = [TKState stateWithName:kEngagedWaitingForPairingSpotReleaseStateName
                                                            andTimeoutDuration:kEngagedStateTimeout];
    [engagedWaitingForPairingSpotReleaseState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
        weakSelf.state = FTPenManagerStateConnected;
    }];
    [engagedWaitingForPairingSpotReleaseState setTimeoutExpiredBlock:^(TKState *state,
                                                                       TKStateMachine *stateMachine) {
        [weakSelf fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }];

    // Married
    TKState *marriedState = [TKState stateWithName:kMarriedStateName];
    [marriedState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
        FTAssert(weakSelf.pen != nil, @"pen can't be nil");
        FTAssert(weakSelf.pen.peripheral.state == CBPeripheralStateConnected, @"pen peripheral is connected");
        FTAssert(weakSelf.pen.peripheral.identifier != nil, @"pen peripheral UUID is non-nil");

        weakSelf.pairedPeripheralUUID = weakSelf.pen.peripheral.identifier;
        weakSelf.state = FTPenManagerStateConnected;
        weakSelf.didConnectViaWarmStart = NO;

        [self attemptLoadFirmwareFromNetworkForVersionChecking];
        [self updatePenInfoObjectAndInvokeDelegate];
        [self ensureCentralId];

        [self possiblyStartEnsureHasListenerTimer];
    }];
    [marriedState setDidExitStateBlock:^(TKState *state, TKStateMachine *stateMachine) {

        [self resetEnsureHasListenerTimer];
    }];

    // Married - Waiting for Long Press to Disconnect
    TKState *marriedWaitingForLongPressToUnpairState = [TKState stateWithName:kMarriedWaitingForLongPressToUnpairStateName
                                                           andTimeoutDuration:kMarriedWaitingForLongPressToUnpairTimeout];
    [marriedWaitingForLongPressToUnpairState setDidEnterStateBlock:^(TKState *state,
                                                                     TKStateMachine *stateMachine) {
         FTAssert(weakSelf.pen, @"pen is non-nil");
         FTAssert(weakSelf.pen.peripheral.state == CBPeripheralStateConnected, @"pen peripheral is connected");

         if (self.disableLongPressToUnpairIfTipPressed && weakSelf.pen.isTipPressed)
         {
             [self fireStateMachineEvent:kReturnToMarriedEventName];
         }

         weakSelf.state = FTPenManagerStateConnectedLongPressToUnpair;

         weakSelf.scanningState = ScanningStateEnabledWithPolling;

         weakSelf.peripheralsDiscoveredDuringLongPress = [NSMutableSet set];
    }];
    [marriedWaitingForLongPressToUnpairState setDidExitStateBlock:^(TKState *state,
                                                                    TKStateMachine *stateMachine) {
        weakSelf.scanningState = ScanningStateDisabled;
        weakSelf.peripheralsDiscoveredDuringLongPress = nil;

    }];
    [marriedWaitingForLongPressToUnpairState setTimeoutExpiredBlock:^(TKState *state, TKStateMachine *stateMachine) {
         FTAssert(weakSelf.pen, @"pen is non-nil");
         FTAssert(weakSelf.pen.peripheral.state == CBPeripheralStateConnected, @"pen peripheral is connected");

         if (self.disableLongPressToUnpairIfTipPressed && weakSelf.pen.isTipPressed)
         {
             [self fireStateMachineEvent:kReturnToMarriedEventName];
         }
         else
         {
             [weakSelf.pen powerOff];

             if (weakSelf.peripheralsDiscoveredDuringLongPress.count > 0)
             {
                 weakSelf.onDeckPeripheral = [weakSelf.peripheralsDiscoveredDuringLongPress anyObject];
             }

             [weakSelf fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
         }
    }];

    // Preparing to Swing
    TKState *preparingToSwingState = [TKState stateWithName:kPreparingToSwingStateName];
    [preparingToSwingState setDidEnterStateBlock:^(TKState *state,
                                                   TKStateMachine *stateMachine) {
        FTAssert(weakSelf.pairedPeripheralUUID != NULL, @"paired peripheral UUID is non-nil");

        weakSelf.state = FTPenManagerStateDisconnected;

        [weakSelf.pen startSwinging];
    }];

    // Swinging
    TKState *swingingState = [TKState stateWithName:kSwingingStateName
                                 andTimeoutDuration:kSwingingStateTimeout];
    [swingingState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
        weakSelf.state = FTPenManagerStateDisconnected;

        weakSelf.scanningState = ScanningStateEnabledWithPolling;
    }];
    [swingingState setDidExitStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
        weakSelf.scanningState = ScanningStateDisabled;
    }];
    [swingingState setTimeoutExpiredBlock:^(TKState *state, TKStateMachine *stateMachine) {
        [weakSelf fireStateMachineEvent:kBecomeSingleEventName];
    }];

    // Swinging - Attempting Connection
    TKState *swingingAttemptingConnectionState = [TKState stateWithName:kSwingingAttemptingConnectionStateName
                                                     andTimeoutDuration:kAttemptingConnectionStateTimeout];
    [swingingAttemptingConnectionState setDidEnterStateBlock:^(TKState *state,
                                                               TKStateMachine *stateMachine) {
        weakSelf.state = FTPenManagerStateReconnecting;

        weakSelf.pen.requiresTipBePressedToBecomeReady = NO;

        attemptingConnectionCommon();
    }];
    [swingingAttemptingConnectionState setTimeoutExpiredBlock:^(TKState *state,
                                                                TKStateMachine *stateMachine) {
        [weakSelf fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }];

    // Separated
    TKState *separatedState = [TKState stateWithName:kSeparatedStateName];
    [separatedState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
        weakSelf.state = FTPenManagerStateDisconnected;

        weakSelf.scanningState = ScanningStateEnabled;
    }];
    [separatedState setDidExitStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
        weakSelf.scanningState = ScanningStateDisabled;
    }];

    // Separated - Retrieving Connceted Peripherals
    TKState *separatedRetrievingConnectedPeripheralsState = [TKState stateWithName:kSeparatedRetrievingConnectedPeripheralsStateName];
    [separatedRetrievingConnectedPeripheralsState setDidEnterStateBlock:^(TKState *state,
                                                                          TKStateMachine *stateMachine) {
        weakSelf.state = FTPenManagerStateDisconnected;

        NSArray *peripherals = [weakSelf.centralManager retrieveConnectedPeripheralsWithServices:@[[FTPenServiceUUIDs penService]]];

        for (CBPeripheral *peripheral in peripherals)
        {
            if ([peripheral.name isEqualToString:kPencilPeripheralName] &&
                [weakSelf isPairedPeripheral:peripheral])
            {
                MLOG_INFO(FTLogSDK, "Found! Separated - Retrieving Connceted Peripherals");
                FTAssert(!weakSelf.pen, @"pen is nil");
                weakSelf.pen = [[FTPen alloc] initWithPeripheral:peripheral];
                [weakSelf fireStateMachineEvent:kAttemptConnectionFromSeparatedEventName];
                return;
            }
        }

        [weakSelf fireStateMachineEvent:kBecomeSeparatedEventName];
    }];

    // Separated - Attempting Connection
    TKState *separatedAttemptingConnectionState = [TKState stateWithName:kSeparatedAttemptingConnectionStateName
                                                      andTimeoutDuration:kAttemptingConnectionStateTimeout];
    [separatedAttemptingConnectionState setDidEnterStateBlock:^(TKState *state,
                                                                TKStateMachine *stateMachine) {
        weakSelf.state = FTPenManagerStateReconnecting;

        weakSelf.pen.requiresTipBePressedToBecomeReady = NO;

        attemptingConnectionCommon();
    }];
    [separatedAttemptingConnectionState setTimeoutExpiredBlock:^(TKState *state, TKStateMachine *stateMachine) {
        [weakSelf fireStateMachineEvent:kDisconnectAndBecomeSeparatedEventName];
    }];

    // Separated - Waiting for Pairing Spot to Unpair
    TKState *separatedWaitingForLongPressToUnpairState = [TKState stateWithName:kSeparatedWaitingForLongPressToUnpairStateName
                                                             andTimeoutDuration:kSeparatedWaitingForLongPressToUnpairTimeout];
    [separatedWaitingForLongPressToUnpairState setDidEnterStateBlock:^(TKState *state,
                                                                       TKStateMachine *stateMachine) {
         weakSelf.state = FTPenManagerStateDisconnectedLongPressToUnpair;

         weakSelf.peripheralsDiscoveredDuringLongPress = [NSMutableSet set];

         weakSelf.scanningState = ScanningStateEnabledWithPolling;
    }];
    [separatedWaitingForLongPressToUnpairState setDidExitStateBlock:^(TKState *state,
                                                                      TKStateMachine *stateMachine) {
         weakSelf.scanningState = ScanningStateDisabled;

         weakSelf.peripheralsDiscoveredDuringLongPress = nil;
    }];
    [separatedWaitingForLongPressToUnpairState setTimeoutExpiredBlock:^(TKState *state,
                                                                        TKStateMachine *stateMachine) {
         if (weakSelf.peripheralsDiscoveredDuringLongPress.count > 0)
         {
             FTAssert(!weakSelf.pen, @"pen non-nil");

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
    [disconnectingAndBecomingSingleState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
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
                                                                TKStateMachine *stateMachine) {
        self.onDeckPeripheral = nil;
    }];

    // Disconnecting and Becoming Separated
    TKState *disconnectingAndBecomingSeparatedState = [TKState stateWithName:kDisconnectingAndBecomingSeparatedStateName];
    [disconnectingAndBecomingSeparatedState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
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
    [updatingFirmwareState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
        FTAssert(weakSelf.pen, @"Pen must be non-nil");
        FTAssert(!weakSelf.updateManager, @"Update manager must be nil");

        weakSelf.state = FTPenManagerStateUpdatingFirmware;

        weakSelf.originalInactivityTimeout = weakSelf.pen.inactivityTimeout;
        weakSelf.pen.inactivityTimeout = 0;

        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateDidPrepare
                                                            object:self];
    }];

    // Updating Firmware - Attempting Connection
    TKState *updatingFirmwareAttemptingConnectionState = [TKState stateWithName:kUpdatingFirmwareAttemptingConnectionStateName
                                                             andTimeoutDuration:kAttemptingConnectionStateTimeout];
    [updatingFirmwareAttemptingConnectionState setDidEnterStateBlock:^(TKState *state,
                                                                       TKStateMachine *stateMachine) {
        FTAssert(weakSelf.pen, @"Pen must be non-nil");
        FTAssert(weakSelf.pen.peripheral, @"Pen peripheral is non-nil");
        FTAssert(weakSelf.pen.peripheral.state == CBPeripheralStateDisconnected,
                 @"Pen peripheral is disconnected");
        FTAssert(!weakSelf.updateManager, @"Update manager must be nil");

        weakSelf.state = FTPenManagerStateUpdatingFirmware;

        weakSelf.pen.requiresTipBePressedToBecomeReady = NO;

        attemptingConnectionCommon();
    }];
    [updatingFirmwareAttemptingConnectionState setTimeoutExpiredBlock:^(TKState *state,
                                                                        TKStateMachine *stateMachine) {
        FTAssert(weakSelf.pen, @"Pen must be non-nil");

        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateDidFail
                                                            object:self];

        [weakSelf fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }];

    // v55 firmware bug workaround state.
    TKState *updatingFirmwareWaitingForTipRelease = [TKState stateWithName:kUpdatingFirmwareWaitingForTipReleaseStateName];

    [updatingFirmwareWaitingForTipRelease setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateWaitingForPencilTipRelease
                                                            object:self];
    }];

    // Updating Firmware - Started update
    TKState *updatingFirmwareStartedState = [TKState stateWithName:kUpdatingFirmwareStartedStateName];
    [updatingFirmwareStartedState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
        FTAssert(weakSelf.pen, @"Pen must be non-nil");
        FTAssert(!weakSelf.updateManager, @"Update manager must be nil");

        [self possiblyStartEnsureHasListenerTimer];

        // Discourage the device from going to sleep while the firmware is updating.
        [UIApplication sharedApplication].idleTimerDisabled = YES;

        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateDidBegin
                                                            object:self];

        // Firmware update can't proceed until we've refreshed the factory and upgrade firmware
        // versions. (The reason for this is that after the upgrade -> factory reset we need
        // the check that we're running the factory version to be accurate.)
        [self.pen refreshFirmwareVersionProperties];
    }];
    [updatingFirmwareStartedState setDidExitStateBlock:^(TKState *state, TKStateMachine *stateMachine) {
        // Restore the idle timer disable flag to its original state.
        [UIApplication sharedApplication].idleTimerDisabled = NO;

        [self resetEnsureHasListenerTimer];
        [weakSelf.updateManager cancelUpdate];
        weakSelf.updateManager = nil;

        weakSelf.pen.inactivityTimeout = (weakSelf.originalInactivityTimeout == -1) ? kInactivityTimeoutMinutes : weakSelf.originalInactivityTimeout;
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
        updatingFirmwareAttemptingConnectionState,
        updatingFirmwareStartedState,
        updatingFirmwareWaitingForTipRelease
    ]];

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
                                                                 datingAttemptingConnectionState
                                                             ]
                                                                             toState:datingRetrievingConnectedPeripheralsState];
    TKEvent *beginDatingScanningEvent = [TKEvent eventWithName:kBeginDatingScanningEventName
                                       transitioningFromStates:@[
                                           datingRetrievingConnectedPeripheralsState
                                       ]
                                                       toState:datingScanningState];
    TKEvent *becomeSingleEvent = [TKEvent eventWithName:kBecomeSingleEventName
                                transitioningFromStates:@[
                                    waitingForCentralManagerToPowerOnState,
                                    datingScanningState,
                                    datingRetrievingConnectedPeripheralsState,
                                    separatedState,
                                    separatedWaitingForLongPressToUnpairState,
                                    swingingState,
                                    updatingFirmwareState,
                                    updatingFirmwareStartedState,
                                    updatingFirmwareWaitingForTipRelease
                                ]
                                                toState:singleState];
    TKEvent *attemptConnectionFromDatingEvent = [TKEvent eventWithName:kAttemptConnectionFromDatingEventName
                                               transitioningFromStates:@[ datingScanningState,
                                                                          datingRetrievingConnectedPeripheralsState,
                                                                          separatedWaitingForLongPressToUnpairState,
                                                                          disconnectingAndBecomingSingleState ]
                                                               toState:datingAttemptingConnectionState];
    TKEvent *becomeEngagedEvent = [TKEvent eventWithName:kBecomeEngagedEventName
                                 transitioningFromStates:@[ datingAttemptingConnectionState ]
                                                 toState:engagedState];
    TKEvent *waitForTipReleaseEvent = [TKEvent eventWithName:kWaitForTipReleaseEventName
                                     transitioningFromStates:@[ engagedState ]
                                                     toState:engagedWaitingForTipReleaseState];
    TKEvent *waitForPairingSpotReleaseEvent = [TKEvent eventWithName:kWaitForPairingSpotReleaseEventName
                                             transitioningFromStates:@[ engagedState ]
                                                             toState:engagedWaitingForPairingSpotReleaseState];
    TKEvent *becomeMarriedEvent = [TKEvent eventWithName:kBecomeMarriedEventName
                                 transitioningFromStates:@[
                                     engagedWaitingForPairingSpotReleaseState,
                                     engagedWaitingForTipReleaseState,
                                     swingingAttemptingConnectionState,
                                     separatedAttemptingConnectionState,
                                     updatingFirmwareState,
                                     updatingFirmwareStartedState,
                                     updatingFirmwareWaitingForTipRelease
                                 ]
                                                 toState:marriedState];
    TKEvent *waitForLongPressToUnpairFromMarriedEvent = [TKEvent eventWithName:kWaitForLongPressToUnpairFromMarriedEventName
                                                       transitioningFromStates:@[ marriedState ]
                                                                       toState:marriedWaitingForLongPressToUnpairState];
    TKEvent *kWaitForLongPressToUnpairFromSeparatedEventNameEvent = [TKEvent eventWithName:KkWaitForLongPressToUnpairFromSeparatedEventNameEventName
                                                                   transitioningFromStates:@[ separatedState ]
                                                                                   toState:separatedWaitingForLongPressToUnpairState];
    TKEvent *returnToMarriedEvent = [TKEvent eventWithName:kReturnToMarriedEventName
                                   transitioningFromStates:@[ marriedWaitingForLongPressToUnpairState ]
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
                                                 updatingFirmwareAttemptingConnectionState,
                                                 updatingFirmwareState,
                                                 updatingFirmwareStartedState,
                                                 updatingFirmwareWaitingForTipRelease
                                             ]
                                                             toState:disconnectingAndBecomingSingleState];
    TKEvent *disconnectAndBecomeSeparatedEvent = [TKEvent eventWithName:kDisconnectAndBecomeSeparatedEventName
                                                transitioningFromStates:@[ separatedAttemptingConnectionState ]
                                                                toState:disconnectingAndBecomingSeparatedState];
    TKEvent *completeDisconnectionAndBecomeSingleEvent = [TKEvent eventWithName:kCompleteDisconnectionAndBecomeSingleEventName
                                                        transitioningFromStates:@[ disconnectingAndBecomingSingleState ]
                                                                        toState:singleState];
    TKEvent *completeDisconnectionAndBecomeSeparatedEvent = [TKEvent eventWithName:kCompleteDisconnectionAndBecomeSeparatedEventName
                                                           transitioningFromStates:@[ disconnectingAndBecomingSeparatedState ]
                                                                           toState:separatedState];
    TKEvent *prepareToSwingEvent = [TKEvent eventWithName:kPrepareToSwingEventName
                                  transitioningFromStates:@[ marriedState ]
                                                  toState:preparingToSwingState];
    TKEvent *swingEvent = [TKEvent eventWithName:kSwingEventName
                         transitioningFromStates:@[ preparingToSwingState ]
                                         toState:swingingState];
    TKEvent *attemptConnectionFromSwingingEvent = [TKEvent eventWithName:kAttemptConnectionFromSwingingEventName
                                                 transitioningFromStates:@[ swingingState ]
                                                                 toState:swingingAttemptingConnectionState];
    TKEvent *becomeSeparatedEvent = [TKEvent eventWithName:kBecomeSeparatedEventName
                                   transitioningFromStates:@[
                                       marriedState,
                                       separatedRetrievingConnectedPeripheralsState,
                                       separatedAttemptingConnectionState,
                                       separatedWaitingForLongPressToUnpairState
                                   ]
                                                   toState:separatedState];
    TKEvent *retrieveConnectedPeripheralsFromSeparatedEvent = [TKEvent eventWithName:kRetrieveConnectedPeripheralsFromSeparatedEventName
                                                             transitioningFromStates:@[
                                                                 waitingForCentralManagerToPowerOnState,
                                                                 separatedState
                                                             ]
                                                                             toState:separatedRetrievingConnectedPeripheralsState];
    TKEvent *attemptConnectionFromSeparatedEvent = [TKEvent eventWithName:kAttemptConnectionFromSeparatedEventName
                                                  transitioningFromStates:@[
                                                      separatedState,
                                                      separatedRetrievingConnectedPeripheralsState
                                                  ]
                                                                  toState:separatedAttemptingConnectionState];

    TKEvent *updateFirmwareEvent = [TKEvent eventWithName:kUpdateFirmwareEventName
                                  transitioningFromStates:@[ marriedState ]
                                                  toState:updatingFirmwareState];

    TKEvent *updateFirmwareOnTipReleaseEvent = [TKEvent eventWithName:kUpdateFirmwareOnTipReleaseEventName
                                              transitioningFromStates:@[ updatingFirmwareState ]
                                                              toState:updatingFirmwareWaitingForTipRelease];

    TKEvent *attemptConnectionFromUpdatingFirmwareEvent = [TKEvent eventWithName:kAttemptConnectionFromUpdatingFirmwareEventName
                                                         transitioningFromStates:@[ updatingFirmwareStartedState ]
                                                                         toState:updatingFirmwareAttemptingConnectionState];

    TKEvent *startFirmwareUpdateEvent = [TKEvent eventWithName:kStartUpdatingFirmwareEventName
                                       transitioningFromStates:@[ updatingFirmwareState,
                                                                  updatingFirmwareAttemptingConnectionState,
                                                                  updatingFirmwareWaitingForTipRelease ]
                                                       toState:updatingFirmwareStartedState];

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
        updateFirmwareOnTipReleaseEvent,
        attemptConnectionFromUpdatingFirmwareEvent,
        startFirmwareUpdateEvent,
    ]];

    self.stateMachine.initialState = waitingForCentralManagerToPowerOnState;

    MLOG_INFO(FTLogSDK, "Activating state machine with initial state: %s", ObjcDescription(self.stateMachine.initialState.name));
    [self.stateMachine activate];

    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerDidUpdateStateNotificationName
                                                        object:self];

    [self.delegate penManagerStateDidChange:self.state];

    [self attemptLoadFirmwareFromNetworkForVersionChecking];
}

- (void)stateMachineDidChangeState:(NSNotification *)notification
{
    MLOG_INFO(FTLogSDK, "STATE CHANGED: %s", ObjcDescription(self.stateMachine.currentState.name));
}

- (void)stateMachineStateTimeoutDidExpire:(NSNotificationCenter *)notification
{
    MLOG_INFO(FTLogSDK, "STATE TIMEOUT EXPIRED: %s", ObjcDescription(self.stateMachine.currentState.name));
}

- (void)fireStateMachineEvent:(NSString *)eventName
{
    NSError *error = nil;
    if (![self.stateMachine fireEvent:eventName error:&error]) {
        MLOG_ERROR(FTLogSDK, "Failed to fire state machine event (%s): %s", ObjcDescription(eventName), ObjcDescription(error.localizedDescription));
    }
}

- (BOOL)currentStateHasName:(NSString *)stateName
{
    return [self.stateMachine.currentState.name isEqualToString:stateName];
}

#pragma mark - Application lifecycle

- (void)applicationDidBecomeActive:(NSNotificationCenter *)notification
{
    MLOG_INFO(FTLogSDK, "FTPenManager: APP DID BECOME ACTIVE");

    // If we're currently separated, then it's possible that the paired pen was connected in
    // another app on this device. Therefore, do a quick check to see if the paired pen
    // shows up in the connected peripherals.
    if ([self currentStateHasName:kSeparatedStateName]) {
        [self fireStateMachineEvent:kRetrieveConnectedPeripheralsFromSeparatedEventName];
    }

    self.penHasListener = YES;
    [self possiblyStartEnsureHasListenerTimer];
    [self resetBackgroundTask];
    [self updatePenInfoObjectAndInvokeDelegate];
}

- (void)applicationWillResignActive:(NSNotification *)notificaton
{
    MLOG_INFO(FTLogSDK, "FTPenManager: APP WILL RESIGN ACTIVE");

    [self resetEnsureHasListenerTimer];

    // Reset the background task (if it has not yet been ended) prior to starting a new one. One would think
    // that we wouldn't need to do this if there were a strict pairing of applicationDidBecomeActive and
    // applicationDidEnterBackground, but in practice that does not appear to be the case.
    [self resetBackgroundTask];

    __weak __typeof(&*self) weakSelf = self;
    self.backgroundTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [weakSelf resetBackgroundTask];
    }];

    // Set HasListener NO regardless of whatever the current state of penHasListener is. We depend on the
    // write notification to end the background task.
    if (self.penHasListener) {
        self.penHasListener = NO;
    } else {
        self.pen.hasListener = NO;
    }
}

- (void)resetBackgroundTask
{
    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        MLOG_INFO(FTLogSDK, "FTPenManager did end background task");

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

    if (isPairingSpotPressed) {
        [self pairingSpotWasPressed];
    } else {
        [self pairingSpotWasReleased];
    }
}

- (void)pairingSpotWasPressed
{
    MLOG_INFO(FTLogSDK, "Pairing spot was pressed.");

    // When the user presses the pairing spot is often the first time we'll create the CBCentralManager and
    // possibly provoke the system Bluetooth alert if Bluetooth is not enabled.
    [self ensureCentralManager];

    if (![self currentStateHasName:kWaitingForCentralManagerToPowerOnStateName]) {
        if ([self currentStateHasName:kSingleStateName]) {
            [self fireStateMachineEvent:kBeginDatingAndRetrieveConnectedPeripheralsEventName];
        } else if ([self currentStateHasName:kSeparatedStateName]) {
            [self fireStateMachineEvent:KkWaitForLongPressToUnpairFromSeparatedEventNameEventName];
        } else if ([self currentStateHasName:kMarriedStateName]) {
            FTAssert(self.pen.peripheral.state == CBPeripheralStateConnected, @"Pen peripheral is connected");

            [self fireStateMachineEvent:kWaitForLongPressToUnpairFromMarriedEventName];
        }
    }
}

- (void)pairingSpotWasReleased
{
    MLOG_INFO(FTLogSDK, "Pairing spot was released.");

    self.lastPairingSpotReleaseTime = [NSDate date];

    if ([self currentStateHasName:kDatingRetrievingConnectedPeripheralsStateName] ||
        [self currentStateHasName:kDatingScanningStateName]) {
        [self fireStateMachineEvent:kBecomeSingleEventName];
    } else if ([self currentStateHasName:kDatingAttemptingConnectiongStateName]) {
        // If we were in the middle of connecting, but the pairing spot was released
        // prematurely, then cancel the connection. The pen must be connected and ready in
        // order to transition to the "engaged" state.
        [self fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    } else if ([self currentStateHasName:kEngagedStateName]) {
        [self fireStateMachineEvent:kWaitForTipReleaseEventName];
    } else if ([self currentStateHasName:kEngagedWaitingForPairingSpotReleaseStateName]) {
        [self comparePairingSpotAndTipReleaseTimesAndTransitionState];
    } else if ([self currentStateHasName:kMarriedWaitingForLongPressToUnpairStateName]) {
        [self fireStateMachineEvent:kReturnToMarriedEventName];
    } else if ([self currentStateHasName:kSeparatedWaitingForLongPressToUnpairStateName]) {
        [self fireStateMachineEvent:kBecomeSeparatedEventName];
    }
}

- (void)comparePairingSpotAndTipReleaseTimesAndTransitionState
{
    FTAssert([self currentStateHasName:kEngagedWaitingForTipReleaseStateName] ||
                 [self currentStateHasName:kEngagedWaitingForPairingSpotReleaseStateName],
             @"");
    FTAssert(self.lastPairingSpotReleaseTime && self.pen.lastTipReleaseTime, @"");

    NSDate *t0 = self.lastPairingSpotReleaseTime;
    NSDate *t1 = self.pen.lastTipReleaseTime;
    NSTimeInterval tipAndPairingSpoteReleaseTimeDifference = fabs([t0 timeIntervalSinceDate:t1]);

    MLOG_INFO(FTLogSDK, "Difference in pairing spot and tip press release times (ms): %f", tipAndPairingSpoteReleaseTimeDifference * 1000.0);

    if (tipAndPairingSpoteReleaseTimeDifference < kEngagedStateTimeout) {
        [self fireStateMachineEvent:kBecomeMarriedEventName];
    } else {
        [self fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }
}

#pragma mark -

- (void)disconnectOrBecomeSingle
{
    [self disconnect];

    if ([self.stateMachine canFireEvent:kBecomeSingleEventName]) {
        [self fireStateMachineEvent:kBecomeSingleEventName];
    }
}

- (void)disconnect
{
    if ([self.stateMachine canFireEvent:kDisconnectAndBecomeSingleEventName]) {
        [self fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }
}

- (void)startTrialSeparation
{
    MLOG_INFO(FTLogSDK, "Start Trial Separation");

    if ([self.stateMachine canFireEvent:kPrepareToSwingEventName]) {
        [self fireStateMachineEvent:kPrepareToSwingEventName];
    }
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)centralManager
{
    FTAssert(self.centralManager == centralManager, @"centralManager matches expected");

    if (centralManager.state == CBCentralManagerStatePoweredOn) {
        if ([self currentStateHasName:kWaitingForCentralManagerToPowerOnStateName]) {
            if (self.pairedPeripheralUUID) {
                [self fireStateMachineEvent:kRetrieveConnectedPeripheralsFromSeparatedEventName];
            } else {
                if (self.isPairingSpotPressed) {
                    [self fireStateMachineEvent:kBeginDatingAndRetrieveConnectedPeripheralsEventName];
                } else {
                    [self fireStateMachineEvent:kBecomeSingleEventName];
                }
            }
        }
    } else {
        if ([self currentStateHasName:kWaitingForCentralManagerToPowerOnStateName]) {
            [self reset];
        } else {
            if ([self currentStateHasName:kUpdatingFirmwareStateName] ||
                [self currentStateHasName:kUpdatingFirmwareAttemptingConnectionStateName] ||
                [self currentStateHasName:kUpdatingFirmwareStartedStateName] ||
                [self currentStateHasName:kUpdatingFirmwareWaitingForTipReleaseStateName]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateWasCancelled
                                                                    object:self];
            }

            [self fireStateMachineEvent:kWaitForCentralManagerToPowerOnEventName];
        }

        // If the state of the CBCentralManager is ever anything than PoweredOn, sever the pairing to the
        // peripheral.
        self.pairedPeripheralUUID = NULL;
    }
}
- (UInt32)advertisementCentralId:(NSDictionary *)advertisementData forPeripheral:(CBPeripheral *)peripheral
{
    NSData *manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey];

    if (manufacturerData.length > 0) {
        if (manufacturerData.length == 4) {
            UInt32 valueSwapped;
            [manufacturerData getBytes:&valueSwapped length:4];
            UInt32 value = CFSwapInt32(valueSwapped);
            return value;
        } else {
            unsigned char value = ((unsigned char *)manufacturerData.bytes)[0];
            return value;
        }
    } else {
        MLOG_ERROR(FTLogSDK, "Device %s did not have any manufacturing data.", [peripheral.identifier.UUIDString UTF8String]);

        NSArray *serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey];
        CBUUID *penSvcUUID = [FTPenServiceUUIDs penService];
        BOOL foundPenSvc = NO;
        for (id uuid in serviceUUIDs) {
            if ((foundPenSvc = [penSvcUUID isEqual:uuid])) {
                break;
            }
        }

        // Assert that if we didn't have manufacturing data we also shouldn't be looking at a pen.
        // If this fails we either have a rogue peripheral or iOS isn't giving us this data for some reason.
        if (foundPenSvc) {
            FTFail("No manufacturer's data for a device claiming to support the pen service.");
        }

        // If we get here then iOS has returned a peripheral that did not match the filter provided
        // to scanForPeripheralsWithServices which is total pants if that's what's going on!
        FTFail("scanForPeripheralsWithServices seems to have discovered a device that did not support the pen service.");
    }
    return 0x0;
}

- (BOOL)isPeripheral:(CBPeripheral *)peripheral reconcilingUsing:(NSDictionary *)advertisementData
{
    UInt32 centralId = [self advertisementCentralId:advertisementData forPeripheral:peripheral];

    return (centralId != 0x0);
}

// If for what ever reason we get a peripheral UUID with 0x0 0x0 0x0, we need to use a non-zero value. Otherwise
// the pen looks like it's not reconciling but a new connection.
- (UInt32)centralIdFromPeripheralId:(NSUUID *)uuid
{
    uuid_t bytes;
    [uuid getUUIDBytes:bytes];

    if (bytes[0] == 0x0 && bytes[1] == 0x0 && bytes[2] == 0x0 && bytes[3] == 0x0) {
        return 0x2;
    } else {
        return bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
    }
}

- (BOOL)isPeripheralReconcilingWithUs:(CBPeripheral *)peripheral
                withAdvertisementData:(NSDictionary *)advertisementData
                requireCentralIdMatch:(BOOL)requireCentralIdMatch
{
    UInt32 advertisedCentralId = [self advertisementCentralId:advertisementData forPeripheral:peripheral];

    UInt32 peripheralCentralId = [self centralIdFromPeripheralId:peripheral.identifier];

    MLOG_INFO(FTLogSDKVerbose, "advertisedCentralId %ld  peripheralCentralId %ld", (long)advertisedCentralId, (long)peripheralCentralId);

    // There are two cases here.
    // We're looking at an older v55 firmware that only has 1 byte of advertising data, or newer firmware.
    // We assume it's reconciling with us if the advertising data is 1 byte.

    if (advertisedCentralId == 0x1 && !requireCentralIdMatch) {
        return YES;
    } else if (peripheralCentralId != 0x0) {
        // It's looking for us, as we previously set the charateristic.
        return peripheralCentralId == advertisedCentralId;
    } else {
        return NO;
    }
}

- (BOOL)isPeripheral:(CBPeripheral *)peripheral advertisingInBackground:(NSDictionary *)advertisementData
{
    NSArray *backgroundServices = advertisementData[@"kCBAdvDataHashedServiceUUIDs"];
    return (backgroundServices != nil);
}

- (void)centralManager:(CBCentralManager *)central
    didDiscoverPeripheral:(CBPeripheral *)peripheral
        advertisementData:(NSDictionary *)advertisementData
                     RSSI:(NSNumber *)RSSI
{
    if ([self isPeripheral:peripheral advertisingInBackground:advertisementData]) {
        MLOG_DEBUG(FTLogSDK,
                   "Peripheral %s is advertising FiftyThree services while in background. Our "
                   "peripherals don't run on iOS so this has to be a rouge BLE service.",
                   [advertisementData[CBAdvertisementDataLocalNameKey] UTF8String]);
        return;
    }
    BOOL isPeripheralReconciling = [self isPeripheral:peripheral reconcilingUsing:advertisementData];
    BOOL isPeripheralReconcilingWithUs = [self isPeripheralReconcilingWithUs:peripheral
                                                       withAdvertisementData:advertisementData
                                                       requireCentralIdMatch:NO];
    BOOL isPeripheralReconcilingSpecificallyWithUs = [self isPeripheralReconcilingWithUs:peripheral
                                                                   withAdvertisementData:advertisementData
                                                                   requireCentralIdMatch:YES];

    MLOG_INFO(FTLogSDK, "Discovered peripheral with name: \"%s\" PotentialCentralId: %x CentralId: %x", ObjcDescription(peripheral.name), (unsigned int)[self centralIdFromPeripheralId:peripheral.identifier], (unsigned int)[self advertisementCentralId:advertisementData forPeripheral:peripheral]);

    if ([self currentStateHasName:kDatingScanningStateName]) {
        FTAssert(!self.pen, @"pen is nil");

        // When single, we only connect with Pencil's that are not currently reconciling, since they may
        // be reconciling with another central. We make an exception for Pencil's that are specifically trying
        // to reconcile with us. This shouldn't generally happen, since we would typically be in Separated
        // in that case. However, this makes us robust to edge cases.
        if (!isPeripheralReconciling || isPeripheralReconcilingSpecificallyWithUs) {
            self.pen = [[FTPen alloc] initWithPeripheral:peripheral];
            [self fireStateMachineEvent:kAttemptConnectionFromDatingEventName];
        } else {
            self.scanningState = ScanningStateEnabledWithPolling;
        }
    } else if ([self currentStateHasName:kSwingingStateName]) {
        if ([self isPairedPeripheral:peripheral]) {
            if (isPeripheralReconciling && isPeripheralReconcilingWithUs) {
                FTAssert(!self.pen, @"pen is nil");
                self.pen = [[FTPen alloc] initWithPeripheral:peripheral];
                [self fireStateMachineEvent:kAttemptConnectionFromSwingingEventName];
            } else {
                [self.stateMachine resetStateTimeoutTimer];
            }
        }
    } else if ([self currentStateHasName:kSeparatedStateName]) {
        if (isPeripheralReconciling) {
            if ([self isPairedPeripheral:peripheral] &&
                isPeripheralReconcilingWithUs) {
                FTAssert(!self.pen, @"pen is nil");

                FTPen *pen = [[FTPen alloc] initWithPeripheral:peripheral];
                if (pen.isTipPressed == YES && fiftythree::core::TouchTracker::Instance()->LiveTouchCount() == 0) {
                    // if there's no touch on this iPad, we need to tell the pen to transition to the swinging state as
                    // it may be trying to connect to another iPad. This is because if the pen wakes up it's
                    // in the reconciling state but may need to pair with a new device instead of us.

                    self.pen = pen;
                    [self startTrialSeparation];
                } else {
                    // [FTLog logVerboseWithFormat:@"Pencil kAttemptConnectionFromSeparatedEventName"];
                    self.pen = pen;
                    [self fireStateMachineEvent:kAttemptConnectionFromSeparatedEventName];
                }
            } else if ([self isPairedPeripheral:peripheral] &&
                       !isPeripheralReconcilingWithUs) {
                // [FTLog logVerboseWithFormat:@"Explict Single"];
                [self fireStateMachineEvent:kBecomeSingleEventName];
            }
        }
    } else if ([self currentStateHasName:kMarriedWaitingForLongPressToUnpairStateName]) {
        // Reject the paired peripheral. We don't want to reconnect to the peripheral we may be using
        // to press the pairing spot to sever the pairing right now.
        if (![self isPairedPeripheral:peripheral] && !isPeripheralReconciling) {
            [self.peripheralsDiscoveredDuringLongPress addObject:peripheral];
        }
    } else if ([self currentStateHasName:kSeparatedWaitingForLongPressToUnpairStateName]) {
        // Unlike in kMarriedWaitingForLongPressToDisconnectStateName, we will accept the paired peripheral
        // when separated. It might just be trying to reconnect!
        if (!isPeripheralReconciling) {
            [self.peripheralsDiscoveredDuringLongPress addObject:peripheral];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral
                         error:(NSError *)error
{
    MLOG_ERROR(FTLogSDK, "Failed to connect to peripheral: %s. (%s).", ObjcDescription(peripheral), ObjcDescription(error.localizedDescription));

    [self handleError];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    if (self.pen.peripheral == peripheral &&
        ([self currentStateHasName:kDatingAttemptingConnectiongStateName] ||
         [self currentStateHasName:kSwingingAttemptingConnectionStateName] ||
         [self currentStateHasName:kSeparatedAttemptingConnectionStateName])) {
        [self.pen peripheralConnectionStatusDidChange];
    } else if ([self currentStateHasName:kUpdatingFirmwareAttemptingConnectionStateName]) {
        [self.pen peripheralConnectionStatusDidChange];
        [self fireStateMachineEvent:kStartUpdatingFirmwareEventName];
    } else {
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral
                      error:(NSError *)error
{
    FTAssert(self.pen.peripheral == peripheral, @"Peripheral matches pen peripheral.");

    if (self.pen.peripheral == peripheral) {
        if (error) {
            MLOG_INFO(FTLogSDK, "Disconnected peripheral with error: %s", ObjcDescription(error.localizedDescription));

            if ([error.localizedDescription isEqualToString:@"The connection has timed out unexpectedly."]) {
                //[FTLog logVerboseWithFormat:@"timed out--<"];
            }
        }

        if ([self currentStateHasName:kUpdatingFirmwareStartedStateName]) {
            MLOG_INFO(FTLogSDK, "Peripheral did disconnect while updating firmware. Reconnecting.");
            FTFirmwareImageType type;
            BOOL result = [FTFirmwareManager imageTypeRunningOnPen:self.pen andType:&type];
            if (result && type == FTFirmwareImageTypeFactory && self.updateManager.state != TIUpdateManagerStateProbablyDone) {
                [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenUnexpectedDisconnectWhileUpdatingFirmwareNotificationName
                                                                    object:self.pen];
            }

            // which restores the peripheral delegate. In this case since we've created a new FTPen, we
            // *don't* want the old delegate.
            self.updateManager.shouldRestorePeripheralDelegate = NO;
            self.pen = [[FTPen alloc] initWithPeripheral:self.pen.peripheral];
            [self fireStateMachineEvent:kAttemptConnectionFromUpdatingFirmwareEventName];
        } else if ([self currentStateHasName:kUpdatingFirmwareAttemptingConnectionStateName] ||
                   [self currentStateHasName:kDatingAttemptingConnectiongStateName] ||
                   [self currentStateHasName:kSeparatedAttemptingConnectionStateName] ||
                   [self currentStateHasName:kSwingingAttemptingConnectionStateName]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenUnexpectedDisconnectWhileConnectingNotifcationName
                                                                object:self.pen];

            MLOG_INFO(FTLogSDKVerbose, "Trying connectPeripheral again...");
            // Try again. Eventually the state will timeout.
            [self.centralManager connectPeripheral:self.pen.peripheral options:nil];
        } else {
            FTPen *pen = self.pen;
            self.pen = nil;

            [pen peripheralConnectionStatusDidChange];

            if ([self currentStateHasName:kDisconnectingAndBecomingSingleStateName]) {
                if (self.onDeckPeripheral) {
                    self.pen = [[FTPen alloc] initWithPeripheral:self.onDeckPeripheral];
                    [self fireStateMachineEvent:kAttemptConnectionFromDatingEventName];
                } else {
                    [self fireStateMachineEvent:kCompleteDisconnectionAndBecomeSingleEventName];
                }
            } else if ([self currentStateHasName:kDisconnectingAndBecomingSeparatedStateName]) {
                [self fireStateMachineEvent:kCompleteDisconnectionAndBecomeSeparatedEventName];
            } else if ([self currentStateHasName:kPreparingToSwingStateName]) {
                [self fireStateMachineEvent:kSwingEventName];
            } else {
                // Estimate whether the peripheral disconnected due to inactivity timeout by comparing
                // the time since last activity to the inactivity timeout duration.
                //
                // TODO: The peripheral should report this to us in a robust fashion, either by setting a
                // charachteristic or returning an error code in the disconnect.
                BOOL didDisconnectDueToInactivityTimeout = NO;
                if ([self currentStateHasName:kMarriedStateName]) {
                    static const NSTimeInterval kInactivityTimeoutMargin = kInactivityTimeoutMinutes * 2.0;
                    NSTimeInterval timeSinceLastActivity = -[self.pairedPeripheralLastActivityTime timeIntervalSinceNow];
                    MLOG_INFO(FTLogSDK, "Did disconnect, time since last activity: %f", timeSinceLastActivity);

                    const NSTimeInterval inactivityTimeout = (pen.inactivityTimeout == -1 ? (kInactivityTimeoutMinutes * 60.0) : pen.inactivityTimeout * 60.0);

                    if (timeSinceLastActivity - inactivityTimeout >= -kInactivityTimeoutMargin) {
                        didDisconnectDueToInactivityTimeout = YES;
                        MLOG_INFO(FTLogSDK, "Did disconnect due to peripheral inactivity timeout.");
                    }
                }

                // Fire notifications to report that we've had an unexpected disconnect. Make sure to do this
                // prior to transitioning states.
                if (!didDisconnectDueToInactivityTimeout &&
                    ([self currentStateHasName:kMarriedStateName] ||
                     [self currentStateHasName:kMarriedWaitingForLongPressToUnpairStateName] ||
                     [self currentStateHasName:kEngagedStateName] ||
                     [self currentStateHasName:kEngagedWaitingForPairingSpotReleaseStateName] ||
                     [self currentStateHasName:kEngagedWaitingForTipReleaseStateName] ||
                     [self currentStateHasName:kUpdatingFirmwareWaitingForTipReleaseStateName] ||
                     [self currentStateHasName:kUpdatingFirmwareStateName])) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenUnexpectedDisconnectNotificationName
                                                                        object:pen];
                }

                if ([self currentStateHasName:kUpdatingFirmwareWaitingForTipReleaseStateName] ||
                    [self currentStateHasName:kUpdatingFirmwareStateName]) {
                    [self cancelFirmwareUpdate];
                } else if ([self currentStateHasName:kMarriedStateName]) {
                    [self fireStateMachineEvent:kBecomeSeparatedEventName];
                    [self fireStateMachineEvent:kRetrieveConnectedPeripheralsFromSeparatedEventName];
                } else if ([self currentStateHasName:kMarriedWaitingForLongPressToUnpairStateName]) {
                    [self fireStateMachineEvent:kBecomeSeparatedEventName];
                } else if ([self currentStateHasName:kEngagedStateName] ||
                           [self currentStateHasName:kEngagedWaitingForPairingSpotReleaseStateName] ||
                           [self currentStateHasName:kEngagedWaitingForTipReleaseStateName]) {
                    [self fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
                }
            }
        }
    }
}

#pragma mark - Firmware

- (void)setFirmwareUpdateIsAvailable:(NSNumber *)firmwareUpdateIsAvailable
{
    NSNumber *oldValue = self.firmwareUpdateIsAvailable;
    _firmwareUpdateIsAvailable = firmwareUpdateIsAvailable;
    if (oldValue != firmwareUpdateIsAvailable) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateAvailableDidChange
                                                            object:self];
        // OK let the outside world know
        if ([self.delegate respondsToSelector:@selector(penManagerFirmwareUpdateIsAvailableDidChange)]) {
            [self.delegate penManagerFirmwareUpdateIsAvailableDidChange];
        }
    }
}

// Although we don't want to do network checks constantly, we do want to update our firmware state if we've
// updated and returned to a partner application.
- (void)updateFirmwareUpdateIsAvailble
{
    BOOL isConnected = FTPenManagerStateIsConnected(self.state);
    if (isConnected && self.pen && self.latestFirmwareVersion > 0) {
        NSInteger currentVersion = [FTFirmwareManager currentRunningFirmwareVersion:self.pen];
        if (currentVersion > 0) {
            self.firmwareUpdateIsAvailable = @(self.latestFirmwareVersion > currentVersion);
        }
    }
}

// This is used by the SDK during connection to see if we should notify SDK users that a firmware update
// is availble.
- (void)attemptLoadFirmwareFromNetworkForVersionChecking
{
    if (FTPenManagerStateIsConnected(self.state) && self.pen && self.state != FTPenManagerStateUpdatingFirmware) {
        BOOL checkedRecently = (self.lastFirmwareNetworkCheckTime &&
                                fabs([self.lastFirmwareNetworkCheckTime timeIntervalSinceNow]) > 60.0 * 5); // 5 minutes.

        if (self.shouldCheckForFirmwareUpdates && !self.isFetchingLatestFirmware && !checkedRecently) {
            self.isFetchingLatestFirmware = YES;

            __weak FTPenManager *weakSelf = self;

            [FTFirmwareManager fetchLatestFirmwareWithCompletionHandler:^(NSData *data) {
                 FTPenManager *strongSelf = weakSelf;
                 if (strongSelf)
                 {
                     strongSelf.isFetchingLatestFirmware = NO;
                     BOOL connected = FTPenManagerStateIsConnected(strongSelf.state);
                     if (data && connected && strongSelf.pen)
                     {
                         NSInteger version = [FTFirmwareManager versionOfImage:data];
                         NSInteger currentVersion = [FTFirmwareManager currentRunningFirmwareVersion:strongSelf.pen];

                         if (currentVersion == -1)
                         {
                             strongSelf.latestFirmwareVersion = version;
                             strongSelf.firmwareUpdateIsAvailable = nil;
                             return;
                         }

                         if (version > currentVersion)
                         {
                             strongSelf.latestFirmwareVersion = version;
                             strongSelf.lastFirmwareNetworkCheckTime = [NSDate date];
                             strongSelf.firmwareUpdateIsAvailable = @(YES);
                         }
                         else
                         {
                             strongSelf.firmwareUpdateIsAvailable = @(NO);
                         }
                     }
                 }
            }];
        }
    }
}

- (void)ensureRecentInMemoryFirmware
{
    BOOL isOlderThanADay = self.lastFirmwareNetworkCheckTime && fabs([self.lastFirmwareNetworkCheckTime timeIntervalSinceNow]) > 60.0 * 60.0 * 24.0; // 1 day.

    if (isOlderThanADay) {
        self.lastFirmwareNetworkCheckTime = nil;
        self.latestFirmwareVersion = -1;
    }
}

- (NSNumber *)isFirmwareUpdateAvailable:(NSInteger *)currentVersion
                          updateVersion:(NSInteger *)updateVersion
{
    [self ensureRecentInMemoryFirmware];

    *currentVersion = [FTFirmwareManager currentRunningFirmwareVersion:self.pen];

    if (*currentVersion != -1) {
        *updateVersion = self.latestFirmwareVersion;
        return @(*updateVersion > *currentVersion);
    }
    return @NO;
}

- (BOOL)prepareFirmwareUpdate
{
    return [self prepareFirmwareUpdateInternal:nil
                                   forceUpdate:NO
                               autoStartUpdate:NO];
    return NO;
}

- (BOOL)prepareFirmwareUpdate:(NSString *)firmwareImagePath
{
    FTAssert(firmwareImagePath, @"firmwareImagePath must be non-nil");

    return [self prepareFirmwareUpdateInternal:firmwareImagePath
                                   forceUpdate:YES
                               autoStartUpdate:NO];
}

- (BOOL)updateFirmware
{
    return [self prepareFirmwareUpdateInternal:nil
                                   forceUpdate:NO
                               autoStartUpdate:YES];
    return NO;
}

- (BOOL)updateFirmware:(NSString *)firmwareImagePath
{
    FTAssert(firmwareImagePath, @"firmwareImagePath must be non-nil");

    return [self prepareFirmwareUpdateInternal:firmwareImagePath
                                   forceUpdate:YES
                               autoStartUpdate:YES];
}

- (BOOL)prepareFirmwareUpdateInternal:(NSString *)firmwareImagePath
                          forceUpdate:(BOOL)forced
                      autoStartUpdate:(BOOL)autoStart
{
    
    if (([self currentStateHasName:kUpdatingFirmwareStartedStateName] ||
         [self currentStateHasName:kUpdatingFirmwareStateName] ||
         [self currentStateHasName:kUpdatingFirmwareAttemptingConnectionStateName] ||
         [self currentStateHasName:kUpdatingFirmwareWaitingForTipReleaseStateName])
        &&
        ((!firmwareImagePath && !self.firmwareImagePath) || (firmwareImagePath && [self.firmwareImagePath isEqualToString:firmwareImagePath]))
        &&
        self.forceFirmwareUpdate == forced && self.tryToAutoStartFirmwareUpdate == autoStart)
    {
        MLOG_DEBUG(FTLogSDK, "Firmware update already prepared.");
        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateDidPrepare
                                                            object:self];
        return YES;
    }
    
    if (![self.stateMachine canFireEvent:kUpdateFirmwareEventName]) {
        MLOG_WARN(FTLogSDK, "Attempt to prepare firmware update failed. The manager was not ready and might already be updating firmware.");
        return NO;
    }

    self.firmwareImagePath = firmwareImagePath;
    
    if (self.firmwareImagePath) {
        self.latestFirmwareVersion = [FTFirmwareManager versionOfImageAtPath:self.firmwareImagePath];
    }
    
    self.forceFirmwareUpdate = forced;
    self.tryToAutoStartFirmwareUpdate = autoStart;

    [self fireStateMachineEvent:kUpdateFirmwareEventName];
    return YES;
}

- (BOOL)startUpdatingFirmware
{
    if ([self.stateMachine canFireEvent:kStartUpdatingFirmwareEventName]) {
        if (!self.pen) {
            if ([self currentStateHasName:kUpdateFirmwareEventName]) {
                [self cancelFirmwareUpdate];
            }
        } else {
            NSInteger runningFirmwareVersion = [FTFirmwareManager currentRunningFirmwareVersion:self.pen];
            if (runningFirmwareVersion > 55 || self.tipWasPressedAfterInactivityTimeoutWasDisabled) {
                [self fireStateMachineEvent:kStartUpdatingFirmwareEventName];
            } else {
                [self fireStateMachineEvent:kUpdateFirmwareOnTipReleaseEventName];
            }
        }
        self.tryToAutoStartFirmwareUpdate = NO;
        return YES;
    } else {
        MLOG_INFO(FTLogSDK, "prepareFirmwareUpdate must be successfully called first.");
    }

    return NO;
}

- (void)cancelFirmwareUpdate
{
    if (self.state == FTPenManagerStateUpdatingFirmware) {
        self.pen.inactivityTimeout = (self.originalInactivityTimeout == -1) ? kInactivityTimeoutMinutes : self.originalInactivityTimeout;

        if (self.pen && [self.stateMachine canFireEvent:kBecomeMarriedEventName]) {
            [self fireStateMachineEvent:kBecomeMarriedEventName];
        } else {
            [self fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateWasCancelled
                                                            object:self];
    }
}

#pragma mark - TIUpdateManagerDelegate

- (void)updateManager:(TIUpdateManager *)manager didLoadFirmwareFromWeb:(NSInteger)firmwareVersion
{
    if (!self.forceFirmwareUpdate && firmwareVersion < [FTFirmwareManager currentRunningFirmwareVersion:self.pen]) {
        [manager cancelUpdate];
    } else if (self.latestFirmwareVersion != firmwareVersion) {
        self.latestFirmwareVersion = firmwareVersion;
        self.firmwareUpdateIsAvailable = @(YES);
    }
}

- (void)updateManager:(TIUpdateManager *)manager didBeginUpdateToVersion:(uint16_t)firmwareUpdateVersion
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateDidBeginSendingUpdate
                                                        object:self];
}

- (void)updateManager:(TIUpdateManager *)manager didFinishUpdate:(NSError *)error
{
    FTAssert([self currentStateHasName:kUpdatingFirmwareStartedStateName], @"in updating firmware state");
    FTAssert(self.updateManager, @"update manager non-nil");
    FTAssert(manager, nil);

    if (error) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateDidFail
                                                            object:self];

        [self handleError];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateDidFinishSendingUpdate
                                                            object:self];
        // we are 99% certain that the upgrade ultimatly worked at this point. Because of this
        // and because of the complexity inherent in verifying the firmware update after a reconnect
        // we are going to just be optimistic and message success.
        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateDidCompleteSuccessfully
                                                            object:self];
        [self fireStateMachineEvent:kBecomeMarriedEventName];
    }
}

- (void)updateManager:(TIUpdateManager *)manager didUpdatePercentComplete:(float)percentComplete
{
    FTAssert(manager, nil);

    FTFirmwareImageType type;
    BOOL result = [FTFirmwareManager imageTypeRunningOnPen:self.pen andType:&type];
    if (result && type == FTFirmwareImageTypeFactory) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenManagerFirmwareUpdateDidUpdatePercentComplete
                                                            object:self
                                                          userInfo:@{ kFTPenManagerPercentCompleteProperty : @(percentComplete) }];
    }
}

#pragma mark - Scanning

- (void)setScanningState:(ScanningState)scanningState
{
    if (_scanningState != scanningState) {
        _scanningState = scanningState;

        if (scanningState == ScanningStateDisabled) {
            self.isScanningForPeripherals = NO;
            [self invalidateIsScanningForPeripheralsToggleTimer];
        } else if (scanningState == ScanningStateEnabled) {
            self.isScanningForPeripherals = YES;
            [self invalidateIsScanningForPeripheralsToggleTimer];
        } else if (scanningState == ScanningStateEnabledWithPolling) {
            self.isScanningForPeripherals = YES;
            [self startIsScanningForPeripheralsToggleTimer];
        } else {
            FTAssert(NO, @"Unexpected scanning state");
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
    self.isScanningForPeripheralsToggleTimer = [NSTimer weakScheduledTimerWithTimeInterval:kIsScanningForPeripheralsToggleTimerInterval
                                                                                    target:self
                                                                                  selector:@selector(isScanningForPeripheralsToggleTimerFired:)
                                                                                  userInfo:nil
                                                                                   repeats:YES];
}

- (void)isScanningForPeripheralsToggleTimerFired:(NSTimer *)timer
{
    // TODO: This means the peripheral has not yet been disconnected. We should handle this more gracefully.
    if (!self.pen) {
        self.isScanningForPeripherals = !self.isScanningForPeripherals;
    }
}

- (void)setIsScanningForPeripherals:(BOOL)isScanningForPeripherals
{
    if (_isScanningForPeripherals != isScanningForPeripherals) {
        _isScanningForPeripherals = isScanningForPeripherals;

        if (_isScanningForPeripherals) {
            MLOG_INFO(FTLogSDK, "Begin scan for peripherals.");

            NSDictionary *options = @{ CBCentralManagerScanOptionAllowDuplicatesKey : @NO };
            [self.centralManager scanForPeripheralsWithServices:@[ [FTPenServiceUUIDs penService] ]
                                                        options:options];
        } else {
            MLOG_INFO(FTLogSDK, "End scan for peripherals.");

            [self.centralManager stopScan];
        }
    }
}

- (void)ensureNeedsUpdate
{
    self.needsUpdate = YES;
    self.displayLink.paused = NO;

    if ([self.delegate respondsToSelector:@selector(penManagerNeedsUpdateDidChange)]) {
        [((id<FTPenManagerDelegatePrivate>)self.delegate)penManagerNeedsUpdateDidChange];
    }
}

#pragma mark - Ensure HasListener Timer

// This odd bit of code is here for good reason. When apps switch on iOS they are not guarenteed to resign
// enter background and become active in lock-step order. So, you can get the foreground message on the other
// apps' delegate *before* the current running application gets background message. If the pen think's
// hasListener has been set to zero but this app is in the foreground, we need to ensure the hasListener
// comes into line with the value we expect it to be.
- (void)ensureHasListenerTimerDidFire:(NSTimer *)timer
{
    if (-[self.ensureHasListenerTimerStartTime timeIntervalSinceNow] > 2.0) {
        [self resetEnsureHasListenerTimer];
    }
    self.pen.hasListener = self.penHasListener;
}

- (void)possiblyStartEnsureHasListenerTimer
{
    // We only need to use the timer on firmware that does not support notifications on the
    // HasListener characteristic.
    if (([self currentStateHasName:kMarriedStateName] ||
         [self currentStateHasName:kUpdatingFirmwareStartedStateName]) &&
        (!self.pen.canWriteHasListener || !self.pen.hasListenerSupportsNotifications)) {
        [self resetEnsureHasListenerTimer];

        self.ensureHasListenerTimer = [NSTimer weakScheduledTimerWithTimeInterval:0.2f
                                                                           target:self
                                                                         selector:@selector(ensureHasListenerTimerDidFire:)
                                                                         userInfo:nil
                                                                          repeats:YES];
        self.ensureHasListenerTimerStartTime = [NSDate date];
    }
}

- (void)resetEnsureHasListenerTimer
{
    self.ensureHasListenerTimerStartTime = nil;
    [self.ensureHasListenerTimer invalidate];
    self.ensureHasListenerTimer = nil;
}

#pragma mark - AnimationPumpDelegate
- (void)animationPumpActivated
{
    [self ensureNeedsUpdate];
}

#pragma mark - PenConnectionViewDelegate

- (void)penConnectionViewAnimationWasEnqueued:(PenConnectionView *)penConnectionView
{
    [self ensureNeedsUpdate];
}

- (BOOL)canPencilBeConnected
{
    //TODO:
    return YES;
}

- (void)isPairingSpotPressedDidChange:(BOOL)isPairingSpotPressed
{
    [self ensureNeedsUpdate];
}
+ (FTPenManager *)sharedInstanceWithoutInitialization
{
    return sharedInstance;
}

- (void)pen:(FTPen *)pen tipPressureDidChange:(float)tipPressure
{
    MLOG_INFO(FTLogSDKVerbose, "tipPressureDid Chage %f", tipPressure);
}

- (void)setAutomaticUpdatesEnabled:(BOOL)useDisplayLink
{
    if (useDisplayLink) {
        self.displayLink = [CADisplayLink displayLinkWithTarget:sharedInstance selector:@selector(update)];
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    } else {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
    _automaticUpdatesEnabled = useDisplayLink;
    [self ensureNeedsUpdate];
}

- (void)update
{
    NSAssert([NSThread isMainThread], @"update must be called on the UI thread.");
    [self.classifier update];

    NSTimeInterval time = [[NSProcessInfo processInfo] systemUptime];

    AnimationPump::Instance()->UpdateAnimations(time);

    bool oldValue = self.needsUpdate;
    self.needsUpdate = AnimationPump::Instance()->HasActiveAnimations();

    if (oldValue != self.needsUpdate) {
        if ([self.delegate respondsToSelector:@selector(penManagerNeedsUpdateDidChange)]) {
            [((id<FTPenManagerDelegatePrivate>)self.delegate)penManagerNeedsUpdateDidChange];
        }
    }

    if (!self.needsUpdate) {
        self.displayLink.paused = YES;
    }
}

#pragma mark - Public API

+ (FTPenManager *)sharedInstance
{
    NSAssert([NSThread isMainThread], @"sharedInstance must be called on the UI thread.");
    BOOL isOS7 = (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1);
    NSAssert(isOS7, @"iOS 7 or greater is required.");

    if (!sharedInstance) {
        [FTEventDispatcher sharedInstance].classifier = fiftythree::sdk::TouchClassifier::New();

        sharedInstance = [[FTPenManager alloc] init];
        sharedInstance.classifier = [[FTTouchClassifier alloc] init];
        sharedInstance.automaticUpdatesEnabled = YES;
    }
    return sharedInstance;
}

- (UIView *)pairingButtonWithStyle:(FTPairingUIStyle)style
{
    return [self pairingButtonWithStyle:style andStyleOverrides:nil];
}

- (UIView *)pairingButtonWithStyle:(FTPairingUIStyle)style andStyleOverrides:(FTPairingUIStyleOverrides *)styleOverrides
{
    NSAssert([NSThread isMainThread], @"This must be called on the UI thread.");

    PenConnectionView *penConnectionView = [[PenConnectionView alloc] init];
    if (style == FTPairingUIStyleFlat) {
        UIColor *const tintColor = styleOverrides.tintColor;
        if (tintColor) {
            penConnectionView.pairingSpotView.tintColor = tintColor;
        }

        UIColor *const unselectedTintColor = styleOverrides.unselectedTintColor;
        if (unselectedTintColor) {
            penConnectionView.pairingSpotView.unselectedTintColor = unselectedTintColor;
        }

        UIColor *const selectedColor = styleOverrides.selectedColor;
        if (selectedColor) {
            penConnectionView.pairingSpotView.selectedColor = selectedColor;
        }

        UIColor *const unselectedColor = styleOverrides.unselectedColor;
        if (unselectedColor) {
            penConnectionView.pairingSpotView.unselectedColor = unselectedColor;
        }

    } else if (styleOverrides) {
        // Don't allow modification of the default UI. Only the flat UI can be tinted.
        MLOG_WARN(FTLogSDK, "Style overrides are not supported for the given FTPairingUIStyle: %d", (int)style);
    }

    penConnectionView.penManager = self;
    penConnectionView.suppressDialogs = YES;
    penConnectionView.isActive = true;
    penConnectionView.delegate = self;
    penConnectionView.style = style;

    auto instance = fiftythree::core::spc<AnimationPumpObjC>(AnimationPump::Instance());
    DebugAssert(instance->GetDelegate() == nil || instance->GetDelegate() == self);

    instance->SetDelegate(self);

    [self.pairingViews addObject:penConnectionView];

    return penConnectionView;
}

- (void)shutdown
{
    NSAssert([NSThread isMainThread], @"shutdown must be called on the UI thread.");
    self.delegate = nil;
    self.classifier.delegate = nil;

    for (UIView *view in self.pairingViews) {
        [view removeFromSuperview];
    }

    [self.pairingViews removeAllObjects];

    [self reset];

    [self.displayLink invalidate];
    self.displayLink = nil;

    auto instance = fiftythree::core::spc<AnimationPumpObjC>(AnimationPump::Instance());
    if (instance->GetDelegate() == self) {
        instance->SetDelegate(nil);
    }

    [[FTEventDispatcher sharedInstance] clearClassifierAndPenState];

    sharedInstance = nil;
}

#pragma mark - Surface pressure iOS8 APIs
- (NSNumber *)normalizedRadiusForTouch:(UITouch *)uiTouch
{
    BOOL connected = FTPenManagerStateIsConnected(self.state);
    auto ftTouch = fiftythree::core::spc<fiftythree::core::TouchTrackerObjC>(fiftythree::core::TouchTracker::Instance())->TouchForUITouch(uiTouch);
    if (connected && ftTouch && ftTouch->CurrentSample().TouchRadius()) {
        float r = *(ftTouch->CurrentSample().TouchRadius());
        return @(r);
    }
    return nil;
}

- (NSNumber *)smoothedRadiusForTouch:(UITouch *)uiTouch
{
    BOOL connected = FTPenManagerStateIsConnected(self.state);
    auto ftTouch = fiftythree::core::spc<fiftythree::core::TouchTrackerObjC>(fiftythree::core::TouchTracker::Instance())->TouchForUITouch(uiTouch);
    if (connected && ftTouch && ftTouch->SmoothedRadius()) {
        float r = *(ftTouch->SmoothedRadius());
        return @(r);
    }
    return nil;
}

- (NSNumber *)smoothedRadiusInCGPointsForTouch:(UITouch *)uiTouch
{
    BOOL connected = FTPenManagerStateIsConnected(self.state);
    auto ftTouch = fiftythree::core::spc<fiftythree::core::TouchTrackerObjC>(fiftythree::core::TouchTracker::Instance())->TouchForUITouch(uiTouch);
    if (connected && ftTouch && ftTouch->SmoothedCGPointRadius()) {
        float r = *(ftTouch->SmoothedCGPointRadius());
        return @(r);
    }
    return nil;
}

#pragma mark - Firmware Upgrade Inter app Communication
// Internal. TODO: once hotfix is RI-ed back to develop move PaperAppDelegate to use this for scheme tests.
- (FTXCallbackURL *)pencilFirmwareUpgradeURL
{
    return [FTXCallbackURL URLWithScheme:@"PencilByFiftyThree"
                                    host:@"x-callback-url"
                                  action:@"firmwareupgrade"
                                  source:nil
                              successUrl:nil
                                errorUrl:nil
                               cancelUrl:nil];
}

// Returns NO if you're on an iphone or a device with out Paper installed. (Or an older build of Paper that
// doesn't support the firmware upgrades of Pencil.
- (BOOL)canInvokePaperToUpdatePencilFirmware
{
    return [[UIApplication sharedApplication] canOpenURL:self.pencilFirmwareUpgradeURL];
}

- (BOOL)invokePaperToUpdatePencilFirmware:(NSString *)source
                                  success:(NSURL *)successCallbackUrl
                                    error:(NSURL *)errorCallbackUrl
                                   cancel:(NSURL *)cancelCallbackUrl
{
    FTXCallbackURL *baseUrl = self.pencilFirmwareUpgradeURL;
    if ([[UIApplication sharedApplication] canOpenURL:baseUrl]) {
        FTXCallbackURL *urlWithCallbacks = [FTXCallbackURL URLWithScheme:baseUrl.scheme
                                                                    host:baseUrl.host
                                                                  action:baseUrl.action
                                                                  source:source
                                                              successUrl:successCallbackUrl
                                                                errorUrl:errorCallbackUrl
                                                               cancelUrl:cancelCallbackUrl];

        BOOL result = [[UIApplication sharedApplication] openURL:urlWithCallbacks];
        return result;
    }
    return NO;
}

- (NSURL *)firmwareUpdateReleaseNotesLink
{
    return [NSURL URLWithString:@"https://www.fiftythree.com/link/support/pencil-firmware-release-notes"];
}

- (NSURL *)firmwareUpdateSupportLink
{
    return [NSURL URLWithString:@"http://www.fiftythree.com/link/support/pencil-firmware-upgrade"];
}

- (NSURL *)learnMoreURL
{
    return [NSURL URLWithString:@"https://www.fiftythree.com/pencil/via/sdk"];
}
- (NSURL *)pencilSupportURL
{
    return [NSURL URLWithString:@"https://www.fiftythree.com/link/support/pencil-via-sdk"];
}
@end
