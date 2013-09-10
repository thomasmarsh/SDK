//
//  FTPenManager.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import <UIKit/UIKit.h>

#import "FTFirmwareManager.h"
#import "FTPen+Private.h"
#import "FTPen.h"
#import "FTPenManager+Private.h"
#import "FTPenManager.h"
#import "FTServiceUUIDs.h"
#import "TIUpdateManager.h"
#import "TransitionKit.h"

NSString * const kFTPenManagerDidUpdateStateNotificationName = @"com.fiftythree.penManager.didUpdateState";
static NSString * const kPairedPeripheralUUIDUserDefaultsKey = @"com.fiftythree.pen.pairedPeripheralUUID";

static const int kInterruptedUpdateDelayMax = 30;

static const NSTimeInterval kEngagedStateTimeout = 0.1;
static const NSTimeInterval kIsScanningForPeripheralsToggleTimerInterval = 0.1;
static const NSTimeInterval kSwingingStateTimeout = 4.0;
static const NSTimeInterval kSeparatedStateTimeout = 10.0 * 60.0;
static const NSTimeInterval kMarriedWaitingForLongPressToDisconnectTimeout = 1.5;
static const NSTimeInterval kAttemptingConnectionStateTimeout = 15.0;

static NSString *const kSingleStateName = @"Single";
static NSString *const kDatingRetrievingConnectedPeripheralsStateName = @"DatingRetrievingConnectedPeripherals";
static NSString *const kDatingScanningStateName = @"DatingScanning";
static NSString *const kDatingAttemptingConnectiongStateName = @"DatingAttemptingConnection";
static NSString *const kEngagedStateName = @"Engaged";
static NSString *const kEngagedWaitingForTipReleaseStateName = @"EngagedWaitingForTipRelease";
static NSString *const kEngagedWaitingForPairingSpotReleaseStateName = @"EngagedWaitingForPairingSpotRelease";
static NSString *const kMarriedStateName = @"Married";
static NSString *const kMarriedWaitingForLongPressToDisconnectStateName = @"MarriedWaitingForLongPressToDisconnect";
static NSString *const kDisconnectingAndBecomingSingleStateName = @"DisconnectingAndBecomingSingle";
static NSString *const kDisconnectingAndBecomingSeparatedStateName = @"DisconnectingAndBecomingSeparated";

static NSString *const kPreparingToSwingStateName = @"PreparingToSwing";
static NSString *const kSwingingStateName = @"Swinging";
static NSString *const kSwingingAttemptingConnectionStateName = @"SwingingAttemptingConnectionStateName";

static NSString *const kSeparatedStateName = @"Separated";
static NSString *const kSeparatedRetrievingConnectedPeripheralsStatename = @"SeparatedRetrievingConnectedPeripherals";
static NSString *const kSeparatedAttemptingConnectionStateName = @"SeparatedAttemptingConnection";

static NSString *const kBeginDatingAndRetrieveConnectedPeripheralsEventName = @"BeginDatingAndRetrieveConnectedPeripherals";
static NSString *const kRetrieveConnectedPeripheralsFromSeparatedEventName = @"RetrieveConnectedPeripheralsFromSeparated";
static NSString *const kBeginDatingScanningEventName = @"BeginDatingScanning";
static NSString *const kBecomeSingleEventName = @"BecomeSingleEventName";
static NSString *const kAttemptConnectionFromDatingEventName = @"AttemptConnectionFromDating";
static NSString *const kBecomeEngagedEventName = @"BecomeEngaged";
static NSString *const kWaitForTipReleaseEventName = @"WaitForTipRelease";
static NSString *const kWaitForPairingSpotReleaseEventName = @"WaitForPairingSpotRelease";
static NSString *const kBecomeMarriedEventName = @"BecomeMarried";
static NSString *const kWaitForLongPressToDisconnect = @"WaitForLongPressToDisconnect";
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

typedef enum
{
    ScanningStateDisabled,
    ScanningStateEnabled,
    ScanningStateEnabledWithPolling
} ScanningState;

@interface FTPenManager () <CBCentralManagerDelegate, TIUpdateManagerDelegate> {
    CFUUIDRef _pairedPeripheralUUID;
}

@property (nonatomic) CBCentralManager *centralManager;
@property (nonatomic) TIUpdateManager *updateManager;

@property (nonatomic) TKStateMachine *stateMachine;

@property (nonatomic, readwrite) FTPenManagerState state;

@property (nonatomic, readwrite) FTPen *pen;

@property (nonatomic) ScanningState scanningState;

@property (nonatomic) BOOL isScanningForPeripherals;
@property (nonatomic) NSTimer *isScanningForPeripheralsToggleTimer;

@property (nonatomic) NSDate *lastPairingSpotReleaseTime;

@property (nonatomic) CFUUIDRef pairedPeripheralUUID;

@property (nonatomic) NSTimer *stateTimeoutTimer;

@end

@implementation FTPenManager

- (id)initWithDelegate:(id<FTPenManagerDelegate>)delegate;
{
    self = [super init];
    if (self)
    {
        _delegate = delegate;

        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];

        _state = FTPenManagerStateUninitialized;

        _scanningState = ScanningStateDisabled;

        [self initializeStateMachine];

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
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (_pairedPeripheralUUID)
    {
        CFRelease(_pairedPeripheralUUID);
        _pairedPeripheralUUID = NULL;
    }
}

#pragma mark - Properties

- (void)setState:(FTPenManagerState)state
{
    if (_state != state)
    {
        _state = state;

        [self.delegate penManager:self didUpdateState:state];

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

- (void)setPairedPeripheralUUID:(CFUUIDRef)pairedPeripheralUUID
{
    NSString *uuidStr = (pairedPeripheralUUID != NULL ?
                         CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, pairedPeripheralUUID)) :
                         nil);

    [[NSUserDefaults standardUserDefaults] setValue:uuidStr
                                             forKey:kPairedPeripheralUUIDUserDefaultsKey];
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
    NSLog(@"Pen did encounter error. Disconnecting.");

    if ([self.stateMachine canFireEvent:kBecomeSingleEventName])
    {
        [self fireStateMachineEvent:kBecomeSingleEventName];
    }
    else if ([self.stateMachine canFireEvent:kDisconnectAndBecomeSingleEventName])
    {
        [self fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }
    else if ([self.stateMachine canFireEvent:kDisconnectAndBecomeSeparatedEventName])
    {
        [self fireStateMachineEvent:kDisconnectAndBecomeSeparatedEventName];
    }
}

- (void)penIsReadyDidChange:(NSNotification *)notification
{
    if (self.pen.isReady)
    {
        NSLog(@"Pen is ready");

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
        NSAssert(weakSelf.pen, @"pen is non-null");

        [weakSelf.centralManager connectPeripheral:weakSelf.pen.peripheral options:nil];
    };

    // Single
    TKState *singleState = [TKState stateWithName:kSingleStateName];
    [singleState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        NSAssert(!self.pen, @"Pen is nil");

        weakSelf.state = FTPenManagerStateUnpaired;

        self.pairedPeripheralUUID = NULL;

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
        weakSelf.state = FTPenManagerStateUnpaired;

        [weakSelf.centralManager retrieveConnectedPeripherals];
    }];

    // DatingScanning
    TKState *datingScanningState = [TKState stateWithName:kDatingScanningStateName];
    [datingScanningState setDidEnterStateBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        weakSelf.state = FTPenManagerStateUnpaired;

        weakSelf.scanningState = ScanningStateEnabled;
    }];
    [datingScanningState setDidExitStateBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        weakSelf.scanningState = ScanningStateDisabled;
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
    TKState *marriedWaitingForLongPressToDisconnectState = [TKState stateWithName:kMarriedWaitingForLongPressToDisconnectStateName
                                                               andTimeoutDuration:kMarriedWaitingForLongPressToDisconnectTimeout];
    [marriedWaitingForLongPressToDisconnectState setTimeoutExpiredBlock:^(TKState *state, TKStateMachine *stateMachine)
    {
        NSAssert(weakSelf.pen, @"pen is non-nil");
        NSAssert(weakSelf.pen.peripheral.isConnected, @"pen peripheral is connected");

        [weakSelf.pen powerOff];

        [weakSelf fireStateMachineEvent:kDisconnectAndBecomeSingleEventName];
    }];
    [marriedWaitingForLongPressToDisconnectState setDidEnterStateBlock:^(TKState *state,
                                                                         TKStateMachine *stateMachine)
    {
        NSAssert(weakSelf.pen, @"pen is non-nil");
        NSAssert(weakSelf.pen.peripheral.isConnected, @"pen peripheral is connected");

        weakSelf.state = FTPenManagerStateConnected;
    }];

    // Preparing to Swing
    TKState *preparingToSwingState = [TKState stateWithName:kPreparingToSwingStateName];
    [preparingToSwingState setDidEnterStateBlock:^(TKState *state,
                                                   TKStateMachine *stateMachine)
    {
        NSAssert(self.pairedPeripheralUUID != NULL, @"paired peripheral UUID is non-nil");

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
    TKState *separatedRetrievingConnectedPeripheralsState = [TKState stateWithName:kSeparatedRetrievingConnectedPeripheralsStatename];
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
        [self fireStateMachineEvent:kDisconnectAndBecomeSeparatedEventName];
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

    [self.stateMachine addStates:@[
     singleState,
     datingRetrievingConnectedPeripheralsState,
     datingScanningState,
     datingAttemptingConnectionState,
     engagedState,
     engagedWaitingForTipReleaseState,
     engagedWaitingForPairingSpotReleaseState,
     marriedState,
     marriedWaitingForLongPressToDisconnectState,
     preparingToSwingState,
     swingingState,
     swingingAttemptingConnectionState,
     separatedState,
     separatedRetrievingConnectedPeripheralsState,
     separatedAttemptingConnectionState,
     disconnectingAndBecomingSingleState,
     disconnectingAndBecomingSeparatedState]];

    //
    // Events
    //

    TKEvent *beginDatingRetrievingConnectedPeripheralsEvent = [TKEvent eventWithName:kBeginDatingAndRetrieveConnectedPeripheralsEventName
                                                             transitioningFromStates:@[singleState,
                                                               separatedState,
                                                               marriedState,
                                                               datingAttemptingConnectionState]
                                                                             toState:datingRetrievingConnectedPeripheralsState];
    TKEvent *beginDatingScanningEvent = [TKEvent eventWithName:kBeginDatingScanningEventName
                                       transitioningFromStates:@[datingRetrievingConnectedPeripheralsState]
                                                       toState:datingScanningState];
    TKEvent *becomeSingleEvent = [TKEvent eventWithName:kBecomeSingleEventName
                                transitioningFromStates:@[ datingScanningState,
                                  datingRetrievingConnectedPeripheralsState,
                                  separatedState,
                                  swingingState]
                                                toState:singleState];
    TKEvent *attemptConnectionFromDatingEvent = [TKEvent eventWithName:kAttemptConnectionFromDatingEventName
                                               transitioningFromStates:@[datingScanningState,
                                                 datingRetrievingConnectedPeripheralsState]
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
                                   separatedAttemptingConnectionState]
                                                 toState:marriedState];
    TKEvent *waitForLongPressToDisconnectEvent = [TKEvent eventWithName:kWaitForLongPressToDisconnect
                                                transitioningFromStates:@[marriedState]
                                                                toState:marriedWaitingForLongPressToDisconnectState];
    TKEvent *returnToMarriedEvent = [TKEvent eventWithName:kReturnToMarriedEventName
                                   transitioningFromStates:@[marriedWaitingForLongPressToDisconnectState]
                                                   toState:marriedState];
    TKEvent *disconnectAndBecomeSingleEvent = [TKEvent eventWithName:kDisconnectAndBecomeSingleEventName
                                             transitioningFromStates:@[
                                               datingAttemptingConnectionState,
                                               separatedAttemptingConnectionState,
                                               engagedWaitingForPairingSpotReleaseState,
                                               engagedWaitingForTipReleaseState,
                                               marriedState,
                                               marriedWaitingForLongPressToDisconnectState,
                                               swingingAttemptingConnectionState]
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
                                     separatedAttemptingConnectionState]
                                                   toState:separatedState];
    TKEvent *retrieveConnectedPeripheralsFromSeparatedEvent = [TKEvent eventWithName:kRetrieveConnectedPeripheralsFromSeparatedEventName
                                                             transitioningFromStates:@[separatedState]
                                                                             toState:separatedRetrievingConnectedPeripheralsState];
    TKEvent *attemptConnectionFromSeparatedEvent = [TKEvent eventWithName:kAttemptConnectionFromSeparatedEventName
                                                  transitioningFromStates:@[
                                                    separatedState,
                                                    separatedRetrievingConnectedPeripheralsState]
                                                                  toState:separatedAttemptingConnectionState];

    [self.stateMachine addEvents:@[
     beginDatingRetrievingConnectedPeripheralsEvent,
     beginDatingScanningEvent,
     becomeSingleEvent,
     attemptConnectionFromDatingEvent,
     becomeEngagedEvent,
     waitForTipReleaseEvent,
     waitForPairingSpotReleaseEvent,
     becomeMarriedEvent,
     waitForLongPressToDisconnectEvent,
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
     retrieveConnectedPeripheralsFromSeparatedEvent
     ]];

    // If we're already paired with a peripheral, then start in the separted state so that we
    // may reconnect it automatically.
    self.stateMachine.initialState = (self.pairedPeripheralUUID ?
                                      separatedRetrievingConnectedPeripheralsState :
                                      singleState);
}

- (void)stateMachineDidChangeState:(NSNotification *)notification
{
    printf("\n");
    NSLog(@"State changed: %@", self.stateMachine.currentState.name);
}

- (void)stateMachineStateTimeoutDidExpire:(NSNotificationCenter *)notification
{
    printf("\n");
    NSLog(@"State timeout expired: %@", self.stateMachine.currentState.name);
}

- (void)fireStateMachineEvent:(NSString *)eventName
{
    NSError *error = nil;
    if (![self.stateMachine fireEvent:eventName error:&error])
    {
        NSLog(@"Failed to fire state machine event (%@): %@",
              eventName,
              error.localizedDescription);
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
    NSLog(@"Pairing spot was pressed.");

    if (!self.stateMachine.isActive)
    {
        return;
    }

    if ([self currentStateHasName:kSingleStateName])
    {
        [self fireStateMachineEvent:kBeginDatingAndRetrieveConnectedPeripheralsEventName];
    }
    else if ([self currentStateHasName:kSeparatedStateName])
    {
        [self fireStateMachineEvent:kBeginDatingAndRetrieveConnectedPeripheralsEventName];
    }
    else if ([self currentStateHasName:kMarriedStateName])
    {
        NSAssert(self.pen.peripheral.isConnected, @"Pen peripheral is connected");

        [self fireStateMachineEvent:kWaitForLongPressToDisconnect];
    }
}

- (void)pairingSpotWasReleased
{
    NSLog(@"Pairing spot was released.");

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
    else if ([self currentStateHasName:kMarriedWaitingForLongPressToDisconnectStateName])
    {
        [self fireStateMachineEvent:kReturnToMarriedEventName];
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
    NSLog(@"Difference in pairing spot and tip press release times (ms): %f",
          tipAndPairingSpoteReleaseTimeDifference * 1000.0);

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

    NSLog(@"Retrieving paired peripherals.");
    NSArray *peripheralUUIDs = @[(__bridge id)self.pairedPeripheralUUID];
    [self.centralManager retrievePeripherals:peripheralUUIDs];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn)
    {
        if (!self.stateMachine.isActive)
        {
            NSLog(@"Activating state machine with initial state: %@",
                  self.stateMachine.initialState.name);
            [self.stateMachine activate];
        }
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
    NSLog(@"Discovered peripheral with name: \"%@\" IsReconciling: %d RSSI: %d.",
          peripheral.name,
          [self isPeripheralReconciling:advertisementData],
          [RSSI integerValue]);

    BOOL isPeripheralReconciling = [self isPeripheralReconciling:advertisementData];

    if ([self currentStateHasName:kDatingScanningStateName])
    {
        NSAssert(!self.pen, @"pen is nil");

        if (!isPeripheralReconciling)
        {
            self.pen = [[FTPen alloc] initWithCentralManager:self.centralManager
                                                  peripheral:peripheral];

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
                self.pen = [[FTPen alloc] initWithCentralManager:self.centralManager
                                                      peripheral:peripheral];
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
            self.pen = [[FTPen alloc] initWithCentralManager:self.centralManager
                                                  peripheral:peripheral];
            [self fireStateMachineEvent:kAttemptConnectionFromSeparatedEventName];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error
{
    NSLog(@"Failed to connect to peripheral: %@. (%@).", peripheral, [error localizedDescription]);

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
            NSLog(@"Disconnected peripheral with error: %@", error.localizedDescription);
        }

        FTPen *pen = self.pen;
        self.pen = nil;

        [pen peripheralConnectionStatusDidChange];

        self.state = FTPenManagerStateDisconnected;

        if ([self currentStateHasName:kDisconnectingAndBecomingSingleStateName])
        {
            [self fireStateMachineEvent:kCompleteDisconnectionAndBecomeSingleEventName];
        }
        else if ([self currentStateHasName:kDisconnectingAndBecomingSeparatedStateName])
        {
            [self fireStateMachineEvent:kCompleteDisconnectionAndBecomeSeparatedEventName];
        }
        else if ([self currentStateHasName:kPreparingToSwingStateName])
        {
            [self fireStateMachineEvent:kSwingEventName];
        }
        else if ([self currentStateHasName:kMarriedStateName] ||
                 [self currentStateHasName:kMarriedWaitingForLongPressToDisconnectStateName] ||
                 [self currentStateHasName:kSeparatedAttemptingConnectionStateName])
        {
            [self fireStateMachineEvent:kBecomeSeparatedEventName];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals
{
    static NSString * const kPencilPeripheralName = @"Charcoal by 53";

    if ([self currentStateHasName:kDatingRetrievingConnectedPeripheralsStateName])
    {
        for (CBPeripheral *peripheral in peripherals)
        {
            if ([peripheral.name isEqualToString:kPencilPeripheralName])
            {
                NSAssert(!self.pen, @"pen is nil");
                self.pen = [[FTPen alloc] initWithCentralManager:self.centralManager
                                                      peripheral:peripheral];
                [self fireStateMachineEvent:kAttemptConnectionFromDatingEventName];
                return;
            }
        }

        [self fireStateMachineEvent:kBeginDatingScanningEventName];
    }
    else if ([self currentStateHasName:kSeparatedRetrievingConnectedPeripheralsStatename])
    {
        for (CBPeripheral *peripheral in peripherals)
        {
            if ([peripheral.name isEqualToString:kPencilPeripheralName] &&
                [self isPairedPeripheral:peripheral])
            {
                NSAssert(!self.pen, @"pen is nil");
                self.pen = [[FTPen alloc] initWithCentralManager:self.centralManager
                                                      peripheral:peripheral];
                [self fireStateMachineEvent:kAttemptConnectionFromSeparatedEventName];
                return;
            }
        }

        [self fireStateMachineEvent:kBecomeSeparatedEventName];
    }
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

- (void)updateFirmwareForPen:(NSString *)firmwareImagePath;
{
    NSAssert(firmwareImagePath, @"firmwareImagePath must be non-nil");
    NSAssert(self.pen, @"pen must be non-nill");

    self.updateManager = [[TIUpdateManager alloc] initWithPeripheral:self.pen.peripheral
                                                            delegate:self]; // BUGBUG - ugly cast

    [self.updateManager updateImage:firmwareImagePath];
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
