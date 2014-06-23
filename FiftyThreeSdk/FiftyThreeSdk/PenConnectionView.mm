//
//  PenConnectionView.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include "Core/Eigen.h"
#include "Core/Memory.h"

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

#import "Core/Enum.h"
#import "Core/Touch/TouchTracker.h"
#import "Core/UIView+Helpers.h"
#import "FiftyThreeSdk/FTPenManager+Internal.h"
#import "FiftyThreeSdk/FTPenManager.h"
#import "FiftyThreeSdk/PairingSpotView.h"
#import "FiftyThreeSdk/PenConnectionView.h"
#import "FiftyThreeSdk/TouchClassifier.h"

using namespace fiftythree::core;
using namespace fiftythree::sdk;

DEFINE_ENUM(PairingSpotTouchState,
            Valid,
            Invalid,
            InvalidAndShouldBeIgnored);

NSString * const kPencilConnectionStatusChangedWithPenConnectionViewNotificationName = @"PencilConnectionStatusChangedWithPenConnectionView";

using namespace fiftythree::core;

static const CGFloat kPairingSpotTouchRadius_Began = 35.f;
static const CGFloat kPairingSpotTouchRadius_Moved = 150.f;

// The GreedyGestureRecognizer recognizes every touch, immediately and indiscriminately.
//
// It can be used to prevent other gesture recognizers from recognizing touches that begin inside the pairing
// spot.
@interface GreedyGestureRecognizer : UIGestureRecognizer

- (id)init __unavailable;

@end

#pragma mark -

@implementation GreedyGestureRecognizer

- (id)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    if (self)
    {
        self.delaysTouchesEnded = NO;
    }
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];

    if (self.state == UIGestureRecognizerStatePossible)
    {
        self.state = UIGestureRecognizerStateBegan;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];

    [self touchesEndedOrCancelled:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];

    [self touchesEndedOrCancelled:touches withEvent:event];
}

- (void)touchesEndedOrCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    BOOL hasActiveTouch = NO;
    for (UITouch *touch in [event allTouches])
    {
        if (![touches containsObject:touch] &&
            [touch.gestureRecognizers containsObject:self])
        {
            hasActiveTouch = YES;
            break;
        }
    }

    if (!hasActiveTouch)
    {
        // Cancel once all touches used by this gesture recognizers have ended or cancelled.
        self.state = UIGestureRecognizerStateCancelled;
    }
}

@end

#pragma mark -

@interface PenConnectionView () <UIGestureRecognizerDelegate, PairingSpotViewDelegate>

@property (nonatomic) __weak UITouch *pairingSpotTouch;
@property (nonatomic) PairingSpotView *pairingSpotView;
@property (nonatomic) UIView *tipPressedView;
@property (nonatomic) UIView *eraserPressedView;
@property (nonatomic) UIGestureRecognizer *gestureRecognizer;
@property (nonatomic) EventToObjCAdapter<const std::vector<TouchClassificationChangedEventArgs> & >::Ptr touchClassificationsDidChangeAdapter;

@property (nonatomic) NSNumber *hadLowBatteryWhenLastConnected;
@property (nonatomic) NSNumber *hadCriticallyLowBatteryWhenLastConnected;
@property (nonatomic) FTPairingSpotConnectionState reconnectingPairingSpotConnectionState;
@property (nonatomic) FTPenManagerState lastPenManagerState;
@property (nonatomic) NSMutableSet *ignoredTouchIds;

@end

#pragma mark -

@implementation PenConnectionView

- (id)init
{
    self = [super init];
    if (self)
    {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.ignoredTouchIds = [NSMutableSet set];

#ifndef DEV_BUILD
        _debugControlsVisibility = VisibilityStateHidden;
#endif

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(isTipOrEraserPressedStateChange:)
                                                     name:kFTPenIsTipPressedDidChangeNotificationName
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(pencilConnectionStatusChangedWithPenConnectionView:)
                                                     name:kPencilConnectionStatusChangedWithPenConnectionViewNotificationName
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(isTipOrEraserPressedStateChange:)
                                                     name:kFTPenIsEraserPressedDidChangeNotificationName
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(batteryLevelDidChange:)
                                                     name:kFTPenBatteryLevelDidChangeNotificationName
                                                   object:nil];

        _pairingSpotView = [[PairingSpotView alloc] init];
        _pairingSpotView.delegate = self;
        [self addSubview:_pairingSpotView];

        [self addSubview:self.tipPressedView];
        [self addSubview:self.eraserPressedView];

        [self updateViews];

        auto classifier = ActiveClassifier::Instance();
        DebugAssert(classifier);
        self.touchClassificationsDidChangeAdapter = EventToObjCAdapter<const std::vector<TouchClassificationChangedEventArgs> & >::Bind(classifier->TouchClassificationsDidChange(),
                                                                                                                                        self,
                                                                                                                                        @selector(touchClassificationsDidChange));

        // Add a gesture recognizer to the view to capture _ANY_ gestures that occur while pressing on the
        // pairing spot. We do this to block the panning of the tray, etc. (We don't want the tray to pan
        // while the pairing spot is being pressed.)
        GreedyGestureRecognizer *greedyGestureRecognizer = [[GreedyGestureRecognizer alloc] initWithTarget:nil
                                                                                                    action:nil];
        greedyGestureRecognizer.delegate = self;
        greedyGestureRecognizer.cancelsTouchesInView = NO;
        self.gestureRecognizer = greedyGestureRecognizer;
        [self addGestureRecognizer:greedyGestureRecognizer];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Properties

- (void)setIsActive:(BOOL)isActive
{
    _isActive = isActive;
    self.pairingSpotView.isActive = isActive;
}

- (void)setDebugControlsVisibility:(VisibilityState)debugControlsVisibility
{
    _debugControlsVisibility = debugControlsVisibility;
    self.tipPressedView.hidden = self.debugControlsVisibility != VisibilityStateVisible;
    self.eraserPressedView.hidden = self.tipPressedView.hidden;
    [self updateLayoutForDebugControls];
}

- (void)updateLayoutForDebugControls
{
    if (self.debugControlsVisibility == VisibilityStateCollapsed)
    {
        // PenConnectionView only has a pairing spot, so is square.
        [self setSize:CGSizeMake(81, 81)];
        _pairingSpotView.y = 0;
    }
    else
    {
        // PenConnectionView has extra space at the top for debug controls (which may be hidden or visible)
        [self setSize:CGSizeMake(81, 101)];
        _pairingSpotView.y = 20;
    }
}

- (void)setPenManager:(FTPenManager *)penManager
{
    if (_penManager != penManager)
    {
        if (_penManager)
        {
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:kFTPenManagerDidUpdateStateNotificationName
                                                          object:_penManager];
        }

        _penManager = penManager;

        if (_penManager)
        {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(penManagerDidUpdateState:)
                                                         name:kFTPenManagerDidUpdateStateNotificationName
                                                       object:penManager];
        }

        [self updatePairingSpotConnectionState];
    }
}

- (BOOL)isPenDisconnected
{
    return FTPenManagerStateIsDisconnected(self.penManager.state);
}

- (BOOL)isPenConnected
{
    return (self.pairingSpotView.connectionState == FTPairingSpotConnectionStateConnected ||
            self.pairingSpotView.connectionState == FTPairingSpotConnectionStateLowBattery ||
            self.pairingSpotView.connectionState == FTPairingSpotConnectionStateCriticallyLowBattery);
}

- (BOOL)isPenBatteryLow
{
    return (self.pairingSpotView.connectionState == FTPairingSpotConnectionStateLowBattery ||
            self.pairingSpotView.connectionState == FTPairingSpotConnectionStateCriticallyLowBattery);
}

- (BOOL)isPenUnpaired
{
    return (self.pairingSpotView.connectionState == FTPairingSpotConnectionStateUnpaired);
}

- (BOOL)isPairingSpotPressed
{
    return self.pairingSpotTouch != nil;
}

- (void)setPairingSpotTouch:(UITouch *)pairingSpotTouch
{
    if (_pairingSpotTouch == pairingSpotTouch)
    {
        return;
    }

    _pairingSpotTouch = pairingSpotTouch;

    BOOL hasPairingSpotTouch = pairingSpotTouch != nil;

    // If the delegate says Pencil can't be connected, then don't report the pairing spot press to the
    // the FTPenManager. We sever at this point, rather than avoiding recording the pairing spot touch at all,
    // so that we can properly report isPairingSpotPressedDidChange:.
    if (![self.delegate respondsToSelector:@selector(canPencilBeConnected)] ||
        [self.delegate canPencilBeConnected])
    {
        self.penManager.isPairingSpotPressed = hasPairingSpotTouch;
    }
    else
    {
        self.penManager.isPairingSpotPressed = nil;
    }

    if ([self.delegate respondsToSelector:@selector(isPairingSpotPressedDidChange:)])
    {
        [self.delegate isPairingSpotPressedDidChange:hasPairingSpotTouch];
    }
}

- (void)penManagerDidUpdateState:(NSNotification *)notification
{
    DebugAssert(self.penManager);

    [self updatePairingSpotConnectionState];
}

- (void)setShouldSuspendNewAnimations:(BOOL)shouldSuspendNewAnimations
{
    _shouldSuspendNewAnimations = shouldSuspendNewAnimations;
    self.pairingSpotView.shouldSuspendNewAnimations = shouldSuspendNewAnimations;
}

- (void)updatePairingSpotConnectionState
{
    DebugAssert(self.penManager);

    switch (self.penManager.state)
    {
        case FTPenManagerStateSeeking:
        case FTPenManagerStateConnecting:
            self.pairingSpotView.cometState = FTPairingSpotCometStateClockwise;
            break;

        case FTPenManagerStateDisconnectedLongPressToUnpair:
        case FTPenManagerStateConnectedLongPressToUnpair:
            self.pairingSpotView.cometState = FTPairingSpotCometStateCounterClockwise;
            break;

        default:
            self.pairingSpotView.cometState = FTPairingSpotCometStateNone;
            break;
    }

    switch (self.penManager.state)
    {
        case FTPenManagerStateUninitialized:
        case FTPenManagerStateUnpaired:
            [self.pairingSpotView setConnectionState:FTPairingSpotConnectionStateUnpaired
                                      isDisconnected:NO];
            self.hadLowBatteryWhenLastConnected = nil;
            self.hadCriticallyLowBatteryWhenLastConnected = nil;
            break;

        case FTPenManagerStateSeeking:
        case FTPenManagerStateConnecting:
            [self.pairingSpotView setConnectionState:FTPairingSpotConnectionStateUnpaired
                                      isDisconnected:NO];
            break;

        case FTPenManagerStateReconnecting:
            [self.pairingSpotView setConnectionState:self.reconnectingPairingSpotConnectionState
                                      isDisconnected:YES];
            break;

        case FTPenManagerStateDisconnected:
        case FTPenManagerStateDisconnectedLongPressToUnpair:

            if (self.hadCriticallyLowBatteryWhenLastConnected &&
                [self.hadCriticallyLowBatteryWhenLastConnected boolValue])
            {
                [self.pairingSpotView setConnectionState:FTPairingSpotConnectionStateCriticallyLowBattery
                                          isDisconnected:YES];
            }
            else if (self.hadLowBatteryWhenLastConnected &&
                     [self.hadLowBatteryWhenLastConnected boolValue])
            {
                [self.pairingSpotView setConnectionState:FTPairingSpotConnectionStateLowBattery
                                          isDisconnected:YES];
            }
            else
            {
                [self.pairingSpotView setConnectionState:FTPairingSpotConnectionStateConnected
                                          isDisconnected:YES];
            }
            break;

        case FTPenManagerStateConnected:
        case FTPenManagerStateConnectedLongPressToUnpair:
        case FTPenManagerStateUpdatingFirmware:
        {
            BOOL hasLowBattery =  self.penManager &&
                                  self.penManager.pen &&
                                  self.penManager.pen.batteryLevel &&
                                  (self.penManager.info.batteryLevel == FTPenBatteryLevelLow
                                   || self.penManager.info.batteryLevel == FTPenBatteryLevelCriticallyLow);

            BOOL hasCriticallyLowBattery = (hasLowBattery && self.penManager.info.batteryLevel == FTPenBatteryLevelCriticallyLow);

            self.hadLowBatteryWhenLastConnected = nil;
            self.hadCriticallyLowBatteryWhenLastConnected = nil;

            // Preserve the last battery state unless we've just reconnected.
            //
            // TODO: Dawn will modify the logic here.
            BOOL wasDisplayingLowBattery = (self.pairingSpotView.connectionState == FTPairingSpotConnectionStateLowBattery &&
                                            self.lastPenManagerState != FTPenManagerStateReconnecting);
            BOOL wasDisplayingCriticallyLowBattery = (self.pairingSpotView.connectionState == FTPairingSpotConnectionStateCriticallyLowBattery &&
                                                      self.lastPenManagerState != FTPenManagerStateReconnecting);

            if (hasCriticallyLowBattery || wasDisplayingCriticallyLowBattery)
            {
                [self.pairingSpotView setConnectionState:FTPairingSpotConnectionStateCriticallyLowBattery
                                          isDisconnected:NO];
                self.hadLowBatteryWhenLastConnected = @(YES);
                self.hadCriticallyLowBatteryWhenLastConnected = @(YES);
            }
            else if (hasLowBattery || wasDisplayingLowBattery)
            {
                [self.pairingSpotView setConnectionState:FTPairingSpotConnectionStateLowBattery
                                          isDisconnected:NO];
                self.hadLowBatteryWhenLastConnected = @(YES);
            }
            else
            {
                [self.pairingSpotView setConnectionState:FTPairingSpotConnectionStateConnected
                                          isDisconnected:NO];
            }

            break;
        }

        default:
            DebugAssert(0);
            [self.pairingSpotView setConnectionState:FTPairingSpotConnectionStateUnpaired
                                      isDisconnected:NO];
            break;
    }

    BOOL hasPairingSpotTouch = self.pairingSpotTouch != nil;
    if (self.penManager.state != self.lastPenManagerState &&
        hasPairingSpotTouch)
    {
        // Notify all other instances of PenConnectionView that we initiated the change of status.
        [[NSNotificationCenter defaultCenter] postNotificationName:kPencilConnectionStatusChangedWithPenConnectionViewNotificationName
                                                            object:self];
    }

    self.reconnectingPairingSpotConnectionState = self.pairingSpotView.connectionState;
    self.lastPenManagerState = self.penManager.state;

    [self updateViews];
    [self setNeedsDisplay];
}

#pragma mark - Pen Notifications

- (void)isTipOrEraserPressedStateChange:(NSNotification *)notification
{
    [self updateViews];
}

- (void)batteryLevelDidChange:(NSNotification *)notification
{
    [self updatePairingSpotConnectionState];
}

#pragma mark - Notifications

- (void)pencilConnectionStatusChangedWithPenConnectionView:(NSNotification *)notification
{
    // If there is more than one PenConnectionView in play and the user has connected or disconnected using a
    // one PenConnectionView, the others snap to their new state and not animate the transition.
    //
    // There's no guarantee about what order NSNotifications are received in, so we perform the snap later on
    // the main queue.  By posting to the main queue, we ensure that all instances of the PenConnectionView
    // (especially this one) have updated their pairing spot view's state before we snap them to their current
    // state.
    PenConnectionView *sender = notification.object;
    if (sender != self)
    {
        __weak PairingSpotView *weakPairingSpotView = self.pairingSpotView;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakPairingSpotView snapToCurrentState];
        });
    }
}

#pragma mark -

- (void)updateViews
{
    if (self.penManager && self.debugControlsVisibility == VisibilityStateVisible)
    {
        self.tipPressedView.hidden = NO;
        self.eraserPressedView.hidden = NO;
    }
    else
    {
        self.tipPressedView.hidden = YES;
        self.eraserPressedView.hidden = YES;
    }
    [self updateLayoutForDebugControls];

    UIColor *pressedColor = [UIColor colorWithRed:103/255.0f green:136/255.0f blue:67/255.0f alpha:1.0f];
    UIColor *notPressedColor = [UIColor colorWithRed:197/255.0f green:62/255.0f blue:14/255.0f alpha:1.0f];
    self.tipPressedView.backgroundColor = (self.penManager.pen.isTipPressed
                                           ? pressedColor
                                           : notPressedColor);
    self.eraserPressedView.backgroundColor = (self.penManager.pen.isEraserPressed
                                              ? pressedColor
                                              : notPressedColor);

    [self setNeedsDisplay];
}

#pragma mark - Subviews

- (CGPoint)pairingSpotCenter
{
    return self.pairingSpotView.center;
}

- (CGRect)penFrame
{
    return self.bounds;
}

- (CGRect)eraseFrame
{
    static const int kEraseButtonHeight = 115;
    return CGRectMake(0,
                      self.bounds.size.height - kEraseButtonHeight,
                      self.bounds.size.width,
                      kEraseButtonHeight);
}

- (CGRect)penFrameWithFractionShowing:(CGFloat)fractionShowing
{
    CGRect frame = self.penFrame;
    frame.origin.y = frame.origin.y + (1.f - fractionShowing) * frame.size.height;
    return frame;
}

- (CGRect)eraseFrameWithFractionShowing:(CGFloat)fractionShowing
{
    CGRect frame = self.eraseFrame;
    frame.origin.y = frame.origin.y + (1.f - fractionShowing) * frame.size.height;
    return frame;
}

- (UIView *)tipPressedView
{
    if (!_tipPressedView)
    {
        _tipPressedView = [self tipOrEraserPressedView];
        _tipPressedView.userInteractionEnabled = NO;
    }

    return _tipPressedView;
}

- (UIView *)eraserPressedView
{
    if (!_eraserPressedView)
    {
        _eraserPressedView = [self tipOrEraserPressedView];
        _eraserPressedView.x += 15;
        _eraserPressedView.userInteractionEnabled = NO;
    }

    return _eraserPressedView;
}

- (UIView *)tipOrEraserPressedView
{
    static const CGFloat width = 10.f;

    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(27, 0,
                                                            width,
                                                            width)];
    view.layer.cornerRadius = 0.5f * width;

    return view;
}

#pragma mark - Touches

- (BOOL)touchIntersectsPairingSpot:(UITouch *)touch
                            radius:(CGFloat)radius
{
    CGFloat dx = self.pairingSpotCenter.x - [touch locationInView:self].x;
    CGFloat dy = self.pairingSpotCenter.y - [touch locationInView:self].y;

    float d = (float)sqrtf(dx * dx + dy * dy);

    return d < radius;
}

- (PairingSpotTouchState)evaludatePairingSpotTouch:(UITouch *)uiTouch
{
    Touch::Ptr touch = static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->TouchForUITouch(uiTouch);
    DebugAssert(touch);

    if ([uiTouch.gestureRecognizers count] < 1 ||
        ![uiTouch.gestureRecognizers containsObject:self.gestureRecognizer])
    {
        return PairingSpotTouchState::InvalidAndShouldBeIgnored;
    }

    if (touch &&
        ([self.ignoredTouchIds containsObject:@((int) touch->Id())] ||
         ![self touchIntersectsPairingSpot:uiTouch
                                    radius:(touch->Phase() == TouchPhase::Began
                                            ? kPairingSpotTouchRadius_Began
                                            : kPairingSpotTouchRadius_Moved)]))
    {
        return PairingSpotTouchState::InvalidAndShouldBeIgnored;
    }

    if (touch &&
        ((touch->Phase() != TouchPhase::Began &&
          touch->Phase() != TouchPhase::Moved) ||
         touch->LongPressClassification()() == TouchClassification::Palm))
    {
        return PairingSpotTouchState::Invalid;
    }

    return PairingSpotTouchState::Valid;
}

- (void)ignoreAllLiveTouches
{
    [self.ignoredTouchIds removeAllObjects];

    for (const Touch::cPtr & touch : TouchTracker::Instance()->LiveTouches())
    {
        [self.ignoredTouchIds addObject:@((int) touch->Id())];
    }
}

#pragma mark - PairingSpotTouch

- (void)updatePairingSpotTouch
{
    BOOL shouldIgnore = NO;

    // Determine if there's a valid pairing spot touch.
    NSArray *allUITouches = static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->AllUITouches();
    NSMutableArray *validPairingSpotTouches = [NSMutableArray array];
    if (allUITouches.count == 1)
    {
        UITouch *touch = allUITouches[0];

        switch ([self evaludatePairingSpotTouch:touch]) {
            case PairingSpotTouchState::Valid:
                [validPairingSpotTouches addObject:touch];
                break;
            case PairingSpotTouchState::Invalid:
                break;
            case PairingSpotTouchState::InvalidAndShouldBeIgnored:
                shouldIgnore = YES;
                break;
            default:
                DebugAssert(0);
                break;
        }
    }

    if (validPairingSpotTouches.count == 1)
    {
        self.pairingSpotTouch = validPairingSpotTouches[0];
    }
    else
    {
        self.pairingSpotTouch = nil;

        if (shouldIgnore ||
            allUITouches.count > 1)
        {
            // If we're clearing the pairing touch because there was more than one live touch, ignore all live
            // touches for the duration of their existence.
            [self ignoreAllLiveTouches];
        }
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self updatePairingSpotTouch];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self updatePairingSpotTouch];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self updatePairingSpotTouch];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self updatePairingSpotTouch];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return [self touchIntersectsPairingSpot:touch
                                     radius:kPairingSpotTouchRadius_Began];
}

#pragma mark - PairingSpotViewDelegate

- (void)pairingSpotViewAnimationWasEnqueued:(PairingSpotView *)pairingSpotView
{
    if ([self.delegate respondsToSelector:@selector(penConnectionViewAnimationWasEnqueued:)])
    {
        [self.delegate penConnectionViewAnimationWasEnqueued:self];
    }
}

#pragma mark - Touch Classification

- (void)touchClassificationsDidChange
{
    // The touches may have been reclassified, so update the pairing spot touch.
    [self updatePairingSpotTouch];
}

@end
