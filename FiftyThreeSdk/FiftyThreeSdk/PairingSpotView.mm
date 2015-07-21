//
//  PairingSpotView.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "Core/AnimationPump.h"
#import "Core/Easing.hpp"
#import "Core/Eigen.h"
#import "Core/Mathiness.h"
#import "Core/NSTimer+Helpers.h"
#import "Core/Spring.hpp"
#import "FiftyThreeSdk/PairingSpotView.h"

using namespace fiftythree::core;

NSString *const kPairingSpotStateDidChangeNotificationName = @"com.fiftythree.products.pairingSpotState";

typedef NS_ENUM(NSInteger, FTPairingSpotIconType) {
    FTPairingSpotIconTypeUnpaired,
    FTPairingSpotIconTypeConnected,
    FTPairingSpotIconTypeLowBattery,
    FTPairingSpotIconTypeCriticallyLowBattery
};

typedef NS_ENUM(NSInteger, FTPairingSpotIconAnimationState) {
    FTPairingSpotIconAnimationStateWaitingToAnimateIn,
    FTPairingSpotIconAnimationStateAnimatingIn,
    FTPairingSpotIconAnimationStateAnimatedIn
};

NSString *FTPairingSpotIconTypeName(FTPairingSpotIconType value)
{
    switch (value) {
        case FTPairingSpotIconTypeUnpaired:
            return @"Unpaired";
        case FTPairingSpotIconTypeConnected:
            return @"Connected";
        case FTPairingSpotIconTypeLowBattery:
            return @"LowBattery";
        case FTPairingSpotIconTypeCriticallyLowBattery:
            return @"CriticallyLowBattery";
        default:
            FTFail("Fell through case statement");
            return @"Unknown";
    }
}

NSString *FTPairingSpotIconAnimationStateName(FTPairingSpotIconAnimationState value)
{
    switch (value) {
        case FTPairingSpotIconAnimationStateWaitingToAnimateIn:
            return @"FTPairingSpotIconAnimationStateWaitingToAnimateIn";
        case FTPairingSpotIconAnimationStateAnimatingIn:
            return @"FTPairingSpotIconAnimationStateAnimatingIn";
        case FTPairingSpotIconAnimationStateAnimatedIn:
            return @"FTPairingSpotIconAnimationStateAnimatedIn";
        default:
            FTFail("Fell through case statement");
            return @"Unknown";
    }
}

NSString *FTPairingSpotConnectionStateName(FTPairingSpotConnectionState value)
{
    switch (value) {
        case FTPairingSpotConnectionStateUnpaired:
            return @"FTPairingSpotConnectionStateUnpaired";
        case FTPairingSpotConnectionStateConnected:
            return @"FTPairingSpotConnectionStateConnected";
        case FTPairingSpotConnectionStateLowBattery:
            return @"FTPairingSpotConnectionStateLowBattery";
        case FTPairingSpotConnectionStateCriticallyLowBattery:
            return @"FTPairingSpotConnectionStateCriticallyLowBattery";
        default:
            FTFail("Fell through case statement");
            return @"Unknown";
    }
}

NSString *FTPairingSpotCometStateName(FTPairingSpotCometState value)
{
    switch (value) {
        case FTPairingSpotCometStateNone:
            return @"FTPairingSpotCometStateNone";
        case FTPairingSpotCometStateClockwise:
            return @"FTPairingSpotCometStateClockwise";
        case FTPairingSpotCometStateCounterClockwise:
            return @"FTPairingSpotCometStateCounterClockwise";
        default:
            FTFail("Fell through case statement");
            return @"Unknown";
    }
}

#pragma mark -

@interface CometsLayer : CALayer

@property (nonatomic) CGPoint center;
@property (nonatomic) CGFloat radius;
@property (nonatomic) CGFloat width;
@property (nonatomic) CGFloat rotation;

@end

#pragma mark -

@implementation CometsLayer

- (void)drawInContext:(CGContextRef)ctx
    isCounterClockwise:(BOOL)isCounterClockwise
{
    UIGraphicsPushContext(ctx);

    CGContextSaveGState(ctx);

    CGContextClearRect(ctx, CGContextGetClipBoundingBox(ctx));

    CGContextSetBlendMode(ctx, kCGBlendModeCopy);
    [CometsLayer drawCometsToContext:ctx
                          withCenter:self.center
                              radius:self.radius
                               width:self.width
                            rotation:self.rotation
                  isCounterClockwise:isCounterClockwise];

    CGContextRestoreGState(ctx);

    UIGraphicsPopContext();
}

+ (CGRect)ellipseRectForFrac:(float)frac
                  withCenter:(CGPoint)center
                      radius:(CGFloat)radius
                       width:(CGFloat)width
                    rotation:(CGFloat)rotation
{
    const float halfWidth = 0.5f * width;
    const float centerRadius = radius - halfWidth;

    const float theta = (frac + 0.5f) * M_PI + rotation;
    const float x = centerRadius * cos(theta) + center.x;
    const float y = centerRadius * sin(theta) + center.y;

    return CGRectMake(x - halfWidth,
                      y - halfWidth,
                      width,
                      width);
}

+ (void)drawHalfAnnulisToContext:(CGContextRef)context
                      withCenter:(CGPoint)center
                          radius:(CGFloat)radius
                           width:(CGFloat)width
                        rotation:(CGFloat)rotation
              isCounterClockwise:(BOOL)isCounterClockwise
{
    CGContextSaveGState(context);

    static const float lightestWhiteValue = 0.f;

    // Clip to outside the bounds of the a circle that's slightly larger than the first cirlce. The two
    // comets dovetail, so we need to leave some room.
    CGRect firstEllipseRect = [CometsLayer ellipseRectForFrac:0.f
                                                   withCenter:center
                                                       radius:radius
                                                        width:width
                                                     rotation:rotation];

    firstEllipseRect = CGRectInset(firstEllipseRect, -0.5f, -0.5f);
    CGContextAddEllipseInRect(context, firstEllipseRect);
    CGContextAddRect(context, CGContextGetClipBoundingBox(context));
    CGContextEOClip(context);

    const int n = 200;
    for (int i = 0; i < n; i++) {
        const float frac = ((float)i) / (n - 1);

        CGRect ellipseRect = [CometsLayer ellipseRectForFrac:isCounterClockwise ? -frac : +frac
                                                  withCenter:center
                                                      radius:radius
                                                       width:width
                                                    rotation:rotation];

        const float whiteValue = lightestWhiteValue + (1.f - lightestWhiteValue) * frac;
        [[UIColor colorWithWhite:1.f alpha:whiteValue] setFill];

        CGContextFillEllipseInRect(context, ellipseRect);
    }

    CGContextRestoreGState(context);
}

+ (void)drawCometsToContext:(CGContextRef)context
                 withCenter:(CGPoint)center
                     radius:(CGFloat)radius
                      width:(CGFloat)width
                   rotation:(CGFloat)rotation
         isCounterClockwise:(BOOL)isCounterClockwise
{
    [CometsLayer drawHalfAnnulisToContext:context
                               withCenter:center
                                   radius:radius
                                    width:width
                                 rotation:rotation
                       isCounterClockwise:isCounterClockwise];

    [CometsLayer drawHalfAnnulisToContext:context
                               withCenter:center
                                   radius:radius
                                    width:width
                                 rotation:rotation + M_PI
                       isCounterClockwise:isCounterClockwise];
}

@end

#pragma mark -

@interface PairingSpotIconAnimation : NSObject

@property (nonatomic) BOOL isStarted;
@property (nonatomic) FTPairingSpotIconType iconType;
@property (nonatomic) FTPairingSpotIconAnimationState state;
@property (nonatomic) Easing<float, 1> easing;
@property (nonatomic) BOOL isDisconnected;
@property (nonatomic) PairingSpotViewSettings viewSettings;
@end

#pragma mark -

@implementation PairingSpotIconAnimation

- (id)init
{
    self = [super init];
    if (self) {
        _state = FTPairingSpotIconAnimationStateWaitingToAnimateIn;
        _easing.SnapToValue(MakeArray1f(0.f));
    }
    return self;
}

- (CGFloat)animationDurationSeconds
{
    return (self.viewSettings.IconTransitionAnimationDuration *
            (self.viewSettings.SlowAnimations
                 ? 10.f
                 : 1.f));
}

- (void)animateIn
{
    self.isStarted = YES;
    DebugAssert(self.state == FTPairingSpotIconAnimationStateWaitingToAnimateIn);
    _easing.Begin(EasingFunction::OutBack,
                  MakeArray1f(0.01f),
                  MakeArray1f(1.f),
                  [self animationDurationSeconds]);
    self.state = FTPairingSpotIconAnimationStateAnimatingIn;
}

- (void)snapToAnimatedIn
{
    self.isStarted = YES;
    self.state = FTPairingSpotIconAnimationStateAnimatedIn;
    _easing.SnapToValue(MakeArray1f(1.f));
}

- (void)update:(double)currentTimeSeconds
{
    bool isSettled = !_easing.Update(currentTimeSeconds);

    if (isSettled) {
        if (self.state == FTPairingSpotIconAnimationStateAnimatingIn) {
            self.state = FTPairingSpotIconAnimationStateAnimatedIn;
        }
    }
}

@end

#pragma mark -

static constexpr float kDefaultSpotRadius = 23.f;

@interface PairingSpotView () {
    Easing<float, 1> _wellMarginEasing;
    Easing<float, 1> _flashIconOpacityEasing;
}

@property (nonatomic) FTPairingSpotConnectionState connectionState;
@property (nonatomic) BOOL isDisconnected;

@property (nonatomic) BlockAnimatable *animatable;
@property (nonatomic) CometsLayer *cometsLayer;
@property (nonatomic) CGContextRef cometsBitmapContext;
@property (nonatomic) CGFloat cometRotation;
@property (nonatomic) NSMutableArray *iconAnimations;
@property (nonatomic) BOOL hasAnimation;
@property (nonatomic) NSTimer *flashAnimationTimer;
@property (nonatomic) double lastAnimationFrameTimeInSeconds;
@property (nonatomic) FTPairingSpotCometState lastCometState;

@end

#pragma mark -

///
/// Internal helper to implement properties that initially have a default value which are overridden by
/// any external values supplied to the PairingSpotView instance.
///
@interface OverrideableProperty : NSObject
@property (nonatomic) id defaultValue;
@property (nonatomic) id value;
@property (nonatomic) BOOL hasOverride;

@end

@implementation OverrideableProperty

@synthesize value = _value;

- (id)value
{
    if (_hasOverride) {
        return _value;
    } else {
        return _defaultValue;
    }
}

- (void)setValue:(id)value
{
    self.hasOverride = YES;
    self.defaultValue = nil;
    _value = value;
}

@end

#pragma mark -

@implementation PairingSpotView {
    OverrideableProperty *_selectedColorOverrides;
    OverrideableProperty *_unselectedColorOverrides;
    OverrideableProperty *_unselectedTintColorOverrides;
}

- (id)init
{
    self = [super initWithFrame:CGRectMake(0, 0, kPairingSpotMaxRadius * 2.f, kPairingSpotMaxRadius * 2.f)];
    if (self) {
        _selectedColorOverrides = [[OverrideableProperty alloc] init];
        _unselectedColorOverrides = [[OverrideableProperty alloc] init];
        _unselectedTintColorOverrides = [[OverrideableProperty alloc] init];
        _spotRadius = kDefaultSpotRadius;
        // you must set the ivar or ios will refuse to override the style from an appearance.
        _style = FTPairingSpotStyleInset;
        [self setDefaultsForStyle:_style];

        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];

        PairingSpotIconAnimation *iconAnimation = [[PairingSpotIconAnimation alloc] init];
        iconAnimation.iconType = FTPairingSpotIconTypeUnpaired;
        [iconAnimation snapToAnimatedIn];

        _iconAnimations = [NSMutableArray array];
        [_iconAnimations addObject:iconAnimation];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];

        _flashIconOpacityEasing.SnapToValue(MakeArray1f(0.f));

        [self resetCometRotation];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (_cometsBitmapContext != NULL) {
        CGContextRelease(_cometsBitmapContext);
        _cometsBitmapContext = NULL;
    }

    if (_animatable) {
        AnimationPumpObjC::Instance()->RemoveAnimatableObjC(_animatable);
    }
    [_animatable invalidate];
    _animatable = nil;

    [_flashAnimationTimer invalidate];
    _flashAnimationTimer = nil;
}

#pragma mark - Properties

- (void)updateIconAnimation
{
    FTPairingSpotIconType iconType = FTPairingSpotIconTypeUnpaired;
    switch (_connectionState) {
        case FTPairingSpotConnectionStateUnpaired:
            iconType = FTPairingSpotIconTypeUnpaired;
            break;
        case FTPairingSpotConnectionStateConnected:
            iconType = FTPairingSpotIconTypeConnected;
            break;
        case FTPairingSpotConnectionStateLowBattery:
            iconType = FTPairingSpotIconTypeLowBattery;
            break;
        case FTPairingSpotConnectionStateCriticallyLowBattery:
            iconType = FTPairingSpotIconTypeCriticallyLowBattery;
            break;
        default:
            FTFail("Fell through case statement");
            break;
    }

    if ([self.iconAnimations count] > 0) {
        PairingSpotIconAnimation *lastIconAnimation = [self.iconAnimations lastObject];
        if (lastIconAnimation.iconType == iconType &&
            lastIconAnimation.isDisconnected == self.isDisconnected) {
            // No need to add a new animation.
            return;
        }
    }

    PairingSpotIconAnimation *iconAnimation = [[PairingSpotIconAnimation alloc] init];
    iconAnimation.iconType = iconType;
    iconAnimation.isDisconnected = self.isDisconnected;
    iconAnimation.viewSettings = self.viewSettings;
    [self.iconAnimations addObject:iconAnimation];
    [self.delegate pairingSpotViewAnimationWasEnqueued:self];
    [self setHasAnimation:YES];
    [self setNeedsDisplay];
}

- (CGFloat)wellMarginEasingAnimationDuration
{
    return (self.viewSettings.WellEasingAnimationDuration *
            (self.viewSettings.SlowAnimations
                 ? 10.f
                 : 1.f));
}

- (void)startCometAnimation
{
    fiftythree::core::optional<double> wellMarginEasingLastTimeSeconds = _wellMarginEasing.LastTimeSeconds();
    _wellMarginEasing.Begin(EasingFunction::OutBack,
                            MakeArray1f(Clamped(_wellMarginEasing.GetCurrentValue().x(), 0.f, self.viewSettings.CometMaxThickness)),
                            MakeArray1f(self.viewSettings.CometMaxThickness),
                            [self wellMarginEasingAnimationDuration]);
    // Resume easing if necessary.
    if (wellMarginEasingLastTimeSeconds) {
        _wellMarginEasing.SetFixedStartTimeSeconds(*wellMarginEasingLastTimeSeconds);
    }
    [self setHasAnimation:YES];
}

- (void)endCometAnimation
{
    fiftythree::core::optional<double> wellMarginEasingLastTimeSeconds = _wellMarginEasing.LastTimeSeconds();
    _wellMarginEasing.Begin(EasingFunction::InBack,
                            MakeArray1f(Clamped(_wellMarginEasing.GetCurrentValue().x(), 0.f, self.viewSettings.CometMaxThickness)),
                            MakeArray1f(0.f),
                            [self wellMarginEasingAnimationDuration]);
    // Resume easing if necessary.
    if (wellMarginEasingLastTimeSeconds) {
        _wellMarginEasing.SetFixedStartTimeSeconds(*wellMarginEasingLastTimeSeconds);
    }
}

- (void)setConnectionState:(FTPairingSpotConnectionState)connectionState
            isDisconnected:(BOOL)isDisconnected
{
    if (_connectionState != connectionState ||
        _isDisconnected != isDisconnected) {
        _connectionState = connectionState;
        _isDisconnected = isDisconnected;

        [self updateIconAnimation];

        [self setNeedsDisplay];

        [self notifyStateDidChange];
    }
}

- (void)setShouldSuspendNewAnimations:(BOOL)shouldSuspendNewAnimations
{
    if (_shouldSuspendNewAnimations &&
        !shouldSuspendNewAnimations) {
        // If we are un-suspending the animations, discard all animations _except_ the oldest and the newest,
        // so that don't see an outpouring of "pent up" animations that accumulated while the tray was
        // offscreen.
        while (self.iconAnimations.count > 2) {
            NSInteger secondToLastIdx = [self.iconAnimations count] - (NSInteger)2;
            PairingSpotIconAnimation *secondToLastAnimation = self.iconAnimations[secondToLastIdx];
            if (secondToLastAnimation.state != FTPairingSpotIconAnimationStateWaitingToAnimateIn) {
                // Don't discard any animations that have already begun, or any animations prior to that
                // animation.
                break;
            }
            [self.iconAnimations removeObjectAtIndex:secondToLastIdx];
        }

        if (self.iconAnimations.count > 1) {
            PairingSpotIconAnimation *firstAnimation = self.iconAnimations[0];
            PairingSpotIconAnimation *lastAnimation = [self.iconAnimations lastObject];
            if (lastAnimation.state == FTPairingSpotIconAnimationStateWaitingToAnimateIn &&
                firstAnimation.iconType == lastAnimation.iconType &&
                firstAnimation.isDisconnected == lastAnimation.isDisconnected) {
                // If after discarding the interim animations we're left with an animation between two
                // identical states, skip it.
                [self.iconAnimations removeLastObject];
            }
        }

        [self startAnimation];
    }

    _shouldSuspendNewAnimations = shouldSuspendNewAnimations;
}

#pragma mark - Active/Background

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self ensureAnimation];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    [self stopAnimation];

    [_animatable invalidate];
    _animatable = nil;

    [_flashAnimationTimer invalidate];
    _flashAnimationTimer = nil;
}

#pragma mark - Animation

- (void)setIsActive:(BOOL)isActive
{
    if (_isActive == isActive) {
        return;
    }
    _isActive = isActive;
    [self ensureAnimation];
}

- (void)setCometState:(FTPairingSpotCometState)cometState
{
    if (_cometState == cometState) {
        return;
    }
    self.lastCometState = self.cometState;
    _cometState = cometState;

    if (_wellMarginEasing.GetCurrentValue().x() < 0.1f) {
        [self resetCometRotation];
    }

    if (cometState == FTPairingSpotCometStateClockwise ||
        cometState == FTPairingSpotCometStateCounterClockwise) {
        [self startCometAnimation];
    } else {
        [self endCometAnimation];
    }

    [self notifyStateDidChange];
}

- (void)flashTimerFired:(NSTimer *)timer
{
    _flashIconOpacityEasing.Begin(EasingFunction::Linear,
                                  MakeArray1f(0.1),
                                  MakeArray1f(1.f),
                                  self.viewSettings.FlashDurationSeconds,
                                  false);

    self.hasAnimation = YES;
}

#pragma mark - Animation

- (void)setHasAnimation:(BOOL)hasAnimation
{
    if (_hasAnimation == hasAnimation) {
        return;
    }
    _hasAnimation = hasAnimation;
    [self ensureAnimation];
}

- (void)ensureAnimation
{
    if (self.hasAnimation && self.isActive) {
        [self startAnimation];
    } else {
        [self stopAnimation];
    }
}

- (void)startAnimation
{
    if (self.animatable) {
        [self.animatable invalidate];
        self.animatable = nil;
    }

    if (!self.animatable) {
        __weak PairingSpotView *weakSelf = self;
        self.animatable = [[BlockAnimatable alloc] initWithBlock:^BOOL(double frameTimeInSeconds) {
            PairingSpotView *strongSelf = weakSelf;
            if (strongSelf)
            {
                [strongSelf update:frameTimeInSeconds];
                return strongSelf.hasAnimation;
            }
            return NO;
        }];
        AnimationPumpObjC::Instance()->AddAnimatableObjC(self.animatable);
    }
}

- (void)stopAnimation
{
    if (self.animatable) {
        AnimationPumpObjC::Instance()->RemoveAnimatableObjC(self.animatable);
    }
    [_animatable invalidate];
    _animatable = nil;
    self.lastAnimationFrameTimeInSeconds = 0.f;
}

- (BOOL)isBatteryIconAnimation:(FTPairingSpotIconType)iconType
{
    return (iconType == FTPairingSpotIconTypeLowBattery ||
            iconType == FTPairingSpotIconTypeCriticallyLowBattery);
}

- (void)snapToCurrentState
{
    while (self.iconAnimations.count > 1) {
        [self.iconAnimations removeObjectAtIndex:0];
    }

    PairingSpotIconAnimation *lastIconAnimation = [self.iconAnimations lastObject];
    [lastIconAnimation snapToAnimatedIn];

    self.hasAnimation = NO;
    [self setNeedsDisplay];
}

- (BOOL)shouldSnapFromIconAnimation:(FTPairingSpotIconType)fromIconType
                    toIconAnimation:(FTPairingSpotIconType)toIconType
{
    return (fromIconType == toIconType ||
            ([self isBatteryIconAnimation:fromIconType] &&
             [self isBatteryIconAnimation:toIconType]));
}

- (void)update:(double)frameTimeInSeconds
{
    if (self.viewSettings.DebugAnimations) {
        NSArray *debugIconTypes = @[
            @(FTPairingSpotIconTypeUnpaired),
            @(FTPairingSpotIconTypeConnected),
            @(FTPairingSpotIconTypeLowBattery),
            @(FTPairingSpotIconTypeCriticallyLowBattery),

            @(FTPairingSpotIconTypeConnected),
            @(FTPairingSpotIconTypeConnected),
            @(FTPairingSpotIconTypeLowBattery),
            @(FTPairingSpotIconTypeConnected),
            @(FTPairingSpotIconTypeCriticallyLowBattery),
        ];
        static int count = 0;
        int seedAnimationFrequency = (self.viewSettings.SlowAnimations ? 400 : 100);
        if (count++ % seedAnimationFrequency == 0) {
            PairingSpotIconAnimation *iconAnimation = [[PairingSpotIconAnimation alloc] init];
            static int sIconType = 0;
            NSNumber *debugIconType = debugIconTypes[sIconType % [debugIconTypes count]];
            sIconType++;
            iconAnimation.iconType = (FTPairingSpotIconType)[debugIconType intValue];
            [self.iconAnimations addObject:iconAnimation];
        }
    }

    bool isSettled = true;

    _wellMarginEasing.Update(frameTimeInSeconds);

    if (!_wellMarginEasing.IsComplete() ||
        _wellMarginEasing.GetCurrentValue().x() > 0.f) {
        // If comets are active, we are not settled.
        isSettled = false;
    } else {
        // Clear the comet state.

        self.cometsLayer = nil;
        if (_cometsBitmapContext != NULL) {
            CGContextRelease(_cometsBitmapContext);
            _cometsBitmapContext = NULL;
        }
    }

    {
        CGFloat cometRotationRadiansPerSecond = (self.viewSettings.CometRotationsPerSecond *
                                                 (self.viewSettings.SlowAnimations
                                                      ? 0.02f
                                                      : 1.f)) *
                                                2 * M_PI;
        double frameDurationSeconds = (self.lastAnimationFrameTimeInSeconds > 0
                                           ? frameTimeInSeconds - self.lastAnimationFrameTimeInSeconds
                                           : 0.0);

        CGFloat cometRotationDelta = cometRotationRadiansPerSecond * frameDurationSeconds;
        if ([self isCometRotationCounterClockwise]) {
            cometRotationDelta = -cometRotationDelta;
        }

        self.cometRotation += cometRotationDelta;
    }

    NSMutableArray *finishedAnimations = [NSMutableArray array];

    for (PairingSpotIconAnimation *iconAnimation in self.iconAnimations) {
        [iconAnimation update:frameTimeInSeconds];
    }

    if (self.iconAnimations.count > 1) {
        // When the "next" animation has fully supplanted the "current" animation, discard the "current"
        // animation.
        PairingSpotIconAnimation *firstIconAnimation = self.iconAnimations[0];
        PairingSpotIconAnimation *nextIconAnimation = self.iconAnimations[1];
        if (firstIconAnimation.state == FTPairingSpotIconAnimationStateAnimatedIn &&
            nextIconAnimation.state == FTPairingSpotIconAnimationStateAnimatedIn) {
            [finishedAnimations addObject:firstIconAnimation];
            isSettled = false;
        }
    }

    [self.iconAnimations removeObjectsInArray:finishedAnimations];

    DebugAssert(self.iconAnimations.count > 0);
    PairingSpotIconAnimation *firstIconAnimation = self.iconAnimations[0];
    DebugAssert(firstIconAnimation.state == FTPairingSpotIconAnimationStateAnimatedIn);

    if (self.iconAnimations.count > 1) {
        PairingSpotIconAnimation *nextIconAnimation = self.iconAnimations[1];
        if (nextIconAnimation.state == FTPairingSpotIconAnimationStateWaitingToAnimateIn &&
            !self.shouldSuspendNewAnimations) {
            // Another icon animation is waiting...

            if ([self shouldSnapFromIconAnimation:firstIconAnimation.iconType
                                  toIconAnimation:nextIconAnimation.iconType]) {
                // Snap to the next icon.
                [self.iconAnimations removeObjectAtIndex:0];
                [nextIconAnimation snapToAnimatedIn];
            } else {
                // Start animating in the next icon.
                [nextIconAnimation animateIn];
            }
        }

        isSettled = false;
    }

    if (self.iconAnimations.count > 0) {
        BOOL shouldFlashIcon = (firstIconAnimation.state == FTPairingSpotIconAnimationStateAnimatedIn &&
                                [self.iconAnimations count] == 1 &&
                                (firstIconAnimation.iconType == FTPairingSpotIconTypeCriticallyLowBattery ||
                                 firstIconAnimation.isDisconnected));
        if (!shouldFlashIcon && self.flashAnimationTimer) {
            [self.flashAnimationTimer invalidate];
            self.flashAnimationTimer = nil;
        } else if (shouldFlashIcon && !self.flashAnimationTimer) {
            self.flashAnimationTimer = [NSTimer weakScheduledTimerWithTimeInterval:self.viewSettings.FlashFrequencySeconds
                                                                            target:self
                                                                          selector:@selector(flashTimerFired:)
                                                                          userInfo:nil
                                                                           repeats:YES];
            // Flash immediately as well.
            [self flashTimerFired:nil];
            isSettled = false;
        }
    }

    if (!self.flashAnimationTimer) {
        _flashIconOpacityEasing.SnapToValue(MakeArray1f(0.f));
    }

    _flashIconOpacityEasing.Update(frameTimeInSeconds);
    isSettled &= _flashIconOpacityEasing.IsComplete();

    if (isSettled &&
        !self.viewSettings.DebugAnimations) {
        self.hasAnimation = NO;
    }

    self.lastAnimationFrameTimeInSeconds = frameTimeInSeconds;

    [self setNeedsDisplay];
}

- (BOOL)isCometRotationCounterClockwise
{
    return (self.cometState == FTPairingSpotCometStateCounterClockwise ||
            (self.cometState == FTPairingSpotCometStateNone &&
             self.lastCometState == FTPairingSpotCometStateCounterClockwise));
}

- (void)resetCometRotation
{
    self.cometRotation = 0.f;
}

#pragma mark - Drawing

- (float)flashOpacityPhase:(float)flashPhase
{
    // Transform the linear flash phase using Hauke's unusual easing.
    const float kFadeDownDurationSeconds = 0.8f;
    const float kDelayDurationSeconds = 0.6f;
    const float kFadeUpDurationSeconds = 1.2f;
    const float kTotalDurationSeconds = kFadeDownDurationSeconds + kDelayDurationSeconds + kFadeUpDurationSeconds;

    const float kFadeDownSubphaseFraction = kFadeDownDurationSeconds / kTotalDurationSeconds;
    const float kDelaySubphaseFraction = kDelayDurationSeconds / kTotalDurationSeconds;
    const float kFadeUpSubphaseFraction = kFadeUpDurationSeconds / kTotalDurationSeconds;
    if (flashPhase < kFadeDownSubphaseFraction) {
        float subphase = Clamped(flashPhase / kFadeDownSubphaseFraction, 0.f, 1.f);
        return Easing<float, 1>::CalculateEasingFunction(EasingFunction::InOutQuadratic,
                                                         subphase,
                                                         1.f,
                                                         0.f,
                                                         false);
    }
    flashPhase -= kFadeDownSubphaseFraction;
    if (flashPhase < kDelaySubphaseFraction) {
        return 0.f;
    }
    flashPhase -= kDelaySubphaseFraction;
    if (flashPhase < kFadeUpSubphaseFraction) {
        float subphase = Clamped(flashPhase / kFadeUpSubphaseFraction, 0.f, 1.f);
        return Easing<float, 1>::CalculateEasingFunction(EasingFunction::InOutQuadratic,
                                                         subphase,
                                                         0.f,
                                                         1.f,
                                                         false);
    }
    return 1.f;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextClearRect(context, self.bounds);

    const CGPoint wellCenter = CGPointMake(41.5f, 41.5f);

    static const float minWellRadius = self.spotRadius;

    // We use a single timer & easy to control "disconnected" and "critically low battery" flash animations.
    const float flashPhase = _flashIconOpacityEasing.GetCurrentValue().x();
    const float flashOpacityPhase = [self flashOpacityPhase:flashPhase];

    const float iconScale = minWellRadius / kDefaultSpotRadius;
    // wellMargin is the distance from the outside edge of the "disc" icon to inside (TODO: or outside?) edge of the
    // "well", or embossed edge.
    const float wellMargin = _wellMarginEasing.GetCurrentValue().x();
    // We expand the well to fit the current "disc" icon (which may at times grow beyond its rest
    // size) or the comets (if active), whichever is larger.
    const float wellRadius = fmax(iconScale * minWellRadius,
                                  minWellRadius + wellMargin);

    UIColor *tint;
    if (FTPairingSpotStyleFlat == self.style) {
        tint = self.tintColor;
    } else {
        tint = [UIColor colorWithHue:0.f saturation:0.f brightness:1.f alpha:1.f];
    }

    if (!self.useThinComets) {
        // No well underlay if we're using thin comets.
        if (FTPairingSpotStyleInset == self.style) {
            [PairingSpotView drawWellUnderlayToContext:context
                                            withCenter:wellCenter
                                                radius:wellRadius
                                    andBackgroundColor:self.unselectedTintColor];
        }
    }

    for (PairingSpotIconAnimation *iconAnimation in self.iconAnimations) {
        if (!iconAnimation.isStarted) {
            continue;
        }

        const float currentIconScale = iconAnimation.easing.GetCurrentValue().x() * iconScale;
        CGFloat iconOpacity = 1.f;

        // Disconnected flash animation.
        if (iconAnimation.isStarted && iconAnimation.isDisconnected) {
            iconOpacity *= Lerp(self.viewSettings.DisconnectedFlashOpacityFactor,
                                1.f,
                                flashOpacityPhase);
        }

        Clamp<CGFloat>(iconOpacity, 0.f, 1.f);

        UIColor *iconColor;
        UIColor *figureColor;

        switch (iconAnimation.iconType) {
            case FTPairingSpotIconTypeUnpaired: {
                iconColor = self.unselectedTintColor;
                CGFloat hue, saturation, brightness, alpha, unselectedBrightness;
                if (![iconColor getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
                    FTFail("on iOS7 some colors cannot be converted to HSB. Use UIColor colorWithHue to ensure this failure doesn't happen.");
                }
                if (![self.unselectedColor getHue:NULL saturation:NULL brightness:&unselectedBrightness alpha:NULL]) {
                    FTFail("on iOS7 some colors cannot be converted to HSB. Use UIColor colorWithHue to ensure this failure doesn't happen.");
                }
                brightness = Lerp<CGFloat>(unselectedBrightness, brightness, iconOpacity);
                iconColor = [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];

                // Color for "figure" elements (i.e. figure/ground) when in a disconnected state.
                figureColor = self.unselectedColor;
                break;
            }
            case FTPairingSpotIconTypeConnected:
            case FTPairingSpotIconTypeLowBattery:
            case FTPairingSpotIconTypeCriticallyLowBattery:
            default: {
                CGFloat hue, saturation, selectedBrightness, iconBrightness;
                if (![tint getHue:&hue saturation:&saturation brightness:NULL alpha:NULL]) {
                    FTFail("on iOS7 some colors cannot be converted to HSB. Use UIColor colorWithHue to ensure this failure doesn't happen.");
                }
                if (![self.selectedColor getHue:NULL saturation:NULL brightness:&selectedBrightness alpha:NULL]) {
                    FTFail("on iOS7 some colors cannot be converted to HSB. Use UIColor colorWithHue to ensure this failure doesn't happen.");
                }
                if (selectedBrightness > 0.5f) {
                    // bright to dark interpolation.
                    iconBrightness = Lerp<CGFloat>(0.f, selectedBrightness, iconOpacity);
                } else {
                    // dark to bright interpolation.
                    iconBrightness = Lerp<CGFloat>(selectedBrightness, 1.f, iconOpacity);
                }
                iconColor = [UIColor colorWithHue:hue saturation:saturation brightness:iconBrightness alpha:1.f];

                // Color for "figure" elements (i.e. figure/ground) when in a connected state.
                figureColor = self.selectedColor;
                break;
            }
        }

        switch (iconAnimation.iconType) {
            case FTPairingSpotIconTypeLowBattery:
            case FTPairingSpotIconTypeCriticallyLowBattery: {
                UIColor *batterySegmentColor = figureColor;
                // Battery segment flash animation.
                if (iconAnimation.isStarted &&
                    iconAnimation.iconType == FTPairingSpotIconTypeCriticallyLowBattery &&
                    !iconAnimation.isDisconnected) {
                    CGFloat batterySegmentOpacity = iconOpacity * Lerp(self.viewSettings.BatteryFlashOpacityFactor,
                                                                       1.f,
                                                                       flashOpacityPhase);
                    batterySegmentOpacity = Clamp<CGFloat>(batterySegmentOpacity, 0.f, 1.f);

                    if (FTPairingSpotStyleFlat == self.style) {
                        CGFloat red, green, blue;
                        [batterySegmentColor getRed:&red green:&green blue:&blue alpha:NULL];
                        batterySegmentColor = [UIColor colorWithRed:red green:green blue:blue alpha:batterySegmentOpacity];
                    } else {
                        CGFloat figureColorBrightness;
                        if (![figureColor getHue:NULL saturation:NULL brightness:&figureColorBrightness alpha:NULL]) {
                            FTFail("on iOS7 some colors cannot be converted to HSB. Use UIColor colorWithHue to ensure this failure doesn't happen.");
                        }

                        CGFloat batterySegmentAlpha = Lerp<CGFloat>(1.f, figureColorBrightness, batterySegmentOpacity);

                        if (self.useThinComets) {
                            // When using thin comets, the battery is knocked out, so the battery segment
                            // should flash over the background. Mix it with the background color here.
                            batterySegmentColor = [iconColor colorWithAlphaComponent:batterySegmentAlpha];
                        } else {
                            batterySegmentColor = [UIColor colorWithWhite:batterySegmentAlpha
                                                                    alpha:1.f];
                        }
                    }
                }
                [PairingSpotView drawBatteryIconToContext:context
                                               withCenter:wellCenter
                                                    scale:currentIconScale
                                      batterySegmentColor:batterySegmentColor
                                          foregroundColor:(self.useThinComets ? nil : figureColor)
                                       andBackgroundColor:iconColor];
                break;
            }
            case FTPairingSpotIconTypeUnpaired:
            case FTPairingSpotIconTypeConnected:
            default:
                [PairingSpotView drawPencilIconToContext:context
                                              withCenter:wellCenter
                                                   scale:currentIconScale
                                         foregroundColor:(self.useThinComets ? nil : figureColor)
                                      andBackgroundColor:iconColor];
                break;
        }
    }

    if (!self.useThinComets) {
        // No well overlay if we're using thin comets.
        if (FTPairingSpotStyleInset == self.style) {
            [PairingSpotView drawWellOverlayToContext:context
                                           withCenter:wellCenter
                                               radius:wellRadius];
        }
    }

    if (wellMargin > 0.f) {
        if (!self.cometsLayer) {
            self.cometsLayer = [[CometsLayer alloc] initWithLayer:self.layer];
            self.cometsLayer.frame = self.bounds;
            self.cometsLayer.opaque = NO;

            const CGFloat scale = [UIScreen mainScreen].scale;
            const CGSize size = CGSizeMake(CGContextGetClipBoundingBox(context).size.width * scale,
                                           CGContextGetClipBoundingBox(context).size.height * scale);
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
            self.cometsBitmapContext = CGBitmapContextCreate(NULL,
                                                             size.width,
                                                             size.height,
                                                             8,
                                                             NULL,
                                                             colorSpace,
                                                             NULL);
            CGContextScaleCTM(self.cometsBitmapContext, scale, scale);
            CGColorSpaceRelease(colorSpace);
        }

        self.cometsLayer.center = CGPointMake(wellCenter.x, wellCenter.y);

        CGFloat alphaLerpMax = 0.f;

        if (self.useThinComets) {
            alphaLerpMax = 6.f;
            self.cometsLayer.radius = wellRadius - 4.f;
            self.cometsLayer.width = wellMargin - 10.f;
        } else {
            alphaLerpMax = 13.f;
            self.cometsLayer.radius = wellRadius - 2.f;
            self.cometsLayer.width = wellMargin - 3.f;
        }

        self.cometsLayer.rotation = self.cometRotation;

        [self.cometsLayer drawInContext:self.cometsBitmapContext
                     isCounterClockwise:[self isCometRotationCounterClockwise]];

        CGImageRef maskImage = CGBitmapContextCreateImage(self.cometsBitmapContext);
        CGContextClipToMask(context, CGContextGetClipBoundingBox(context), maskImage);
        CGImageRelease(maskImage);

        const CGFloat cometsAlpha = Clamped<CGFloat>(InverseLerp<CGFloat>(3.f, alphaLerpMax, self.cometsLayer.width), 0.f, 1.f);

        UIColor *cometsColor = [self getCometsColorWithAlpha:cometsAlpha];
        [cometsColor setFill];

        CGContextFillRect(context, CGContextGetClipBoundingBox(context));
    }
}

#pragma mark - Appearance

- (UIColor *)getCometsColorWithAlpha:(CGFloat)alpha
{
    UIColor *color = nil;
    if (self.highlightColor) {
        color = self.highlightColor;
    } else if (FTPairingSpotStyleFlat == self.style) {
        color = self.unselectedColor;
    }

    if (color) {
        CGFloat r, g, b;
        [color getRed:&r green:&g blue:&b alpha:NULL];
        return [UIColor colorWithRed:r green:g blue:b alpha:alpha];
    } else {
        return [UIColor colorWithWhite:1.f alpha:alpha];
    }
}

///
/// Reset OverridableProperty defaults for data members based on the supplied style.
///
- (void)setDefaultsForStyle:(FTPairingSpotStyle)style
{
    // setup defaults for each style
    switch (style) {
        case FTPairingSpotStyleFlat: {
            [_selectedColorOverrides setDefaultValue:[UIColor colorWithHue:0.f saturation:0.f brightness:1.f alpha:1.f]];
            [_unselectedColorOverrides setDefaultValue:[PairingSpotView grayPairingColor]];
            [_unselectedTintColorOverrides setDefaultValue:[UIColor colorWithHue:0.f saturation:0.f brightness:1.f alpha:.25f]];
            break;
        }
        case FTPairingSpotStyleInset:
        default: {
            [_selectedColorOverrides setDefaultValue:[PairingSpotView grayPairingColor]];
            [_unselectedColorOverrides setDefaultValue:[PairingSpotView grayPairingColor]];
            [_unselectedTintColorOverrides setDefaultValue:[UIColor colorWithHue:0.f saturation:0.f brightness:0.f alpha:1.f]];
            break;
        }
    }
}

- (void)setStyle:(FTPairingSpotStyle)style
{
    [self setDefaultsForStyle:style];
    _style = style;
}

+ (UIColor *)grayPairingColor
{
    return [UIColor colorWithRed:0.20392157f
                           green:0.19215687f
                            blue:0.1882353f
                           alpha:1.0f];
}

- (void)setSelectedColor:(UIColor *)selectedColor
{
    _selectedColorOverrides.value = selectedColor;
}

- (UIColor *)selectedColor
{
    return _selectedColorOverrides.value;
}

- (void)setUnselectedColor:(UIColor *)unselectedColor
{
    _unselectedColorOverrides.value = unselectedColor;
}

- (UIColor *)unselectedColor
{
    return _unselectedColorOverrides.value;
}

- (void)setUnselectedTintColor:(UIColor *)unselectedTintColor
{
    _unselectedTintColorOverrides.value = unselectedTintColor;
}

- (UIColor *)unselectedTintColor
{
    return _unselectedTintColorOverrides.value;
}

#pragma mark - Graphics

+ (void)drawWellUnderlayToContext:(CGContextRef)context
                       withCenter:(CGPoint)center
                           radius:(CGFloat)radius
               andBackgroundColor:(UIColor *)bgColor
{
    const CGFloat innerDiameter = 2.f * radius;
    const CGFloat outerRadius = radius + 1.f;
    const CGFloat outerCenter = outerRadius;
    const CGFloat outerDiameter = 2.f * outerRadius;

    const CGPoint modelCenter = CGPointMake(outerRadius, outerRadius);

    CGContextSaveGState(context);

    CGContextTranslateCTM(context,
                          center.x - modelCenter.x,
                          center.y - modelCenter.y);

    // General Declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    // Color Declarations
    UIColor *shadowGradient = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
    UIColor *whiteGradient = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.2];

    // Gradient background
    {
        NSArray *bezelColors = [NSArray arrayWithObjects:
                                            (id)shadowGradient.CGColor,
                                            (id)[UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.35].CGColor,
                                            (id)whiteGradient.CGColor,
                                            nil];
        CGFloat bezelLocations[] = {0.25, 0.75, 1};
        CGGradientRef bezel = CGGradientCreateWithColors(colorSpace,
                                                         (__bridge CFArrayRef)bezelColors,
                                                         bezelLocations);
        UIBezierPath *oval2Path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, outerDiameter, outerDiameter)];
        CGContextSaveGState(context);
        [oval2Path addClip];
        CGContextDrawLinearGradient(context,
                                    bezel,
                                    CGPointMake(outerCenter, 0),
                                    CGPointMake(outerCenter, outerDiameter),
                                    0);
        CGContextRestoreGState(context);

        CGGradientRelease(bezel);
    }

    // Oval 7 Drawing
    UIBezierPath *oval7Path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(1, 1, innerDiameter, innerDiameter)];
    [bgColor setFill];
    [oval7Path fill];

    // Cleanup
    CGColorSpaceRelease(colorSpace);

    CGContextRestoreGState(context);
}

+ (void)drawWellOverlayToContext:(CGContextRef)context
                      withCenter:(CGPoint)center
                          radius:(CGFloat)radius
{
    // This draws the top, inner shadow of the pairing inset UI.

    CGContextSaveGState(context);

    const CGFloat innerDiameter = 2.f * radius;
    const CGFloat outerRadius = radius + 1.f;

    const CGPoint modelCenter = CGPointMake(outerRadius, outerRadius);

    CGContextTranslateCTM(context,
                          center.x - modelCenter.x,
                          center.y - modelCenter.y);

    UIColor *black20Shadow = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.1];

    // Shadow Declarations
    UIColor *shadow = black20Shadow;
    CGSize shadowOffset = CGSizeMake(0.1, 2.1);
    CGFloat shadowBlurRadius = 0;

    // Oval 8 Inner Shadow
    UIBezierPath *oval8Path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(1, 1, innerDiameter, innerDiameter)];

    CGRect oval8BorderRect = CGRectInset([oval8Path bounds], -shadowBlurRadius, -shadowBlurRadius);
    oval8BorderRect = CGRectOffset(oval8BorderRect, -shadowOffset.width, -shadowOffset.height);
    oval8BorderRect = CGRectInset(CGRectUnion(oval8BorderRect, [oval8Path bounds]), -1, -1);

    UIBezierPath *oval8NegativePath = [UIBezierPath bezierPathWithRect:oval8BorderRect];
    [oval8NegativePath appendPath:oval8Path];
    oval8NegativePath.usesEvenOddFillRule = YES;

    {
        CGFloat xOffset = shadowOffset.width + round(oval8BorderRect.size.width);
        CGFloat yOffset = shadowOffset.height;
        CGContextSetShadowWithColor(context,
                                    CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
                                    shadowBlurRadius,
                                    shadow.CGColor);

        [oval8Path addClip];
        CGAffineTransform transform = CGAffineTransformMakeTranslation(-round(oval8BorderRect.size.width), 0);
        [oval8NegativePath applyTransform:transform];
        [[UIColor grayColor] setFill];
        [oval8NegativePath fill];
    }

    CGContextRestoreGState(context);
}

+ (void)drawPencilIconToContext:(CGContextRef)context
                     withCenter:(CGPoint)center
                          scale:(CGFloat)scale
                foregroundColor:(UIColor *)fgColor
             andBackgroundColor:(UIColor *)bgColor
{
    const CGFloat radius = 22.5f;
    const CGPoint modelCenter = CGPointMake(radius, radius);

    // Background circle
    UIBezierPath *backgroundPath = [UIBezierPath bezierPathWithArcCenter:modelCenter
                                                                  radius:radius
                                                              startAngle:0.f
                                                                endAngle:M_PI * 2.f
                                                               clockwise:NO];

    UIBezierPath *pencilPath = [UIBezierPath bezierPath];

    // Pen tip
    [pencilPath moveToPoint:CGPointMake(29.91, 9.57)];
    [pencilPath addCurveToPoint:CGPointMake(28.59, 10.18)
                  controlPoint1:CGPointMake(29.31, 9.7)
                  controlPoint2:CGPointMake(28.81, 10)];
    [pencilPath addLineToPoint:CGPointMake(36, 17.64)];
    [pencilPath addCurveToPoint:CGPointMake(35.98, 14)
                  controlPoint1:CGPointMake(36.39, 17.19)
                  controlPoint2:CGPointMake(37.38, 15.41)];
    [pencilPath addLineToPoint:CGPointMake(32.2, 10.23)];
    [pencilPath addCurveToPoint:CGPointMake(29.91, 9.57)
                  controlPoint1:CGPointMake(31.46, 9.49)
                  controlPoint2:CGPointMake(30.61, 9.41)];
    [pencilPath closePath];

    // Pen body
    [pencilPath moveToPoint:CGPointMake(27.51, 11.26)];
    [pencilPath addLineToPoint:CGPointMake(16.51, 22.26)];
    [pencilPath addLineToPoint:CGPointMake(16.51, 27.68)];
    [pencilPath addCurveToPoint:CGPointMake(18.42, 29.59)
                  controlPoint1:CGPointMake(16.51, 28.74)
                  controlPoint2:CGPointMake(17.36, 29.59)];
    [pencilPath addLineToPoint:CGPointMake(24.04, 29.59)];
    [pencilPath addLineToPoint:CGPointMake(34.95, 18.69)];
    [pencilPath addLineToPoint:CGPointMake(27.51, 11.26)];
    [pencilPath closePath];

    // Pen tip
    [pencilPath moveToPoint:CGPointMake(15.08, 23.71)];
    [pencilPath addLineToPoint:CGPointMake(11.32, 31.66)];
    [pencilPath addCurveToPoint:CGPointMake(11.58, 34.58)
                  controlPoint1:CGPointMake(10.98, 32.38)
                  controlPoint2:CGPointMake(10.69, 33.7)];
    [pencilPath addCurveToPoint:CGPointMake(14.48, 34.84)
                  controlPoint1:CGPointMake(12.46, 35.47)
                  controlPoint2:CGPointMake(13.77, 35.18)];
    [pencilPath addCurveToPoint:CGPointMake(22.61, 31.02)
                  controlPoint1:CGPointMake(14.87, 34.65)
                  controlPoint2:CGPointMake(19.96, 32.45)];
    [pencilPath addLineToPoint:CGPointMake(18.42, 31.02)];
    [pencilPath addCurveToPoint:CGPointMake(15.08, 27.69)
                  controlPoint1:CGPointMake(16.58, 31.02)
                  controlPoint2:CGPointMake(15.08, 29.53)];
    [pencilPath addLineToPoint:CGPointMake(15.08, 23.71)];
    [pencilPath closePath];

    pencilPath.miterLimit = 4;

    CGContextSaveGState(context);

    CGContextTranslateCTM(context, center.x, center.y);
    CGContextScaleCTM(context, scale, scale);
    CGContextTranslateCTM(context, -modelCenter.x, -modelCenter.y);

    if (!fgColor) {
        // If no foreground color is specified, knock out the path
        // so that you can see through the pencil to the background.
        UIBezierPath *clipPath = [UIBezierPath bezierPathWithRect:CGRectInfinite];
        [clipPath appendPath:pencilPath];
        clipPath.usesEvenOddFillRule = YES;

        // The PaintCode battery isn't properly centered,
        CGContextTranslateCTM(context, -.5f, -.5f);
        [clipPath addClip];

        CGContextTranslateCTM(context, 0.5f, 0.5f);
        [bgColor setFill];
        [backgroundPath fill];
    } else {
        [bgColor setFill];
        [backgroundPath fill];

        // The PaintCode battery isn't properly centered,
        CGContextTranslateCTM(context, -0.5f, -0.5f);
        [fgColor setFill];
        [pencilPath fill];
    }

    CGContextRestoreGState(context);
}

+ (void)drawBatteryIconToContext:(CGContextRef)context
                      withCenter:(CGPoint)center
                           scale:(CGFloat)scale
             batterySegmentColor:(UIColor *)batterySegmentColor
                 foregroundColor:(UIColor *)color
              andBackgroundColor:(UIColor *)bgColor
{
    const CGFloat radius = 22.5f;
    const CGPoint modelCenter = CGPointMake(radius, radius);

    // Background circle
    UIBezierPath *backgroundPath = [UIBezierPath bezierPathWithArcCenter:modelCenter
                                                                  radius:radius
                                                              startAngle:0.f
                                                                endAngle:M_PI * 2.f
                                                               clockwise:NO];

    UIBezierPath *batteryBodyPath = [UIBezierPath bezierPath];

    [batteryBodyPath moveToPoint:CGPointMake(32.56, 18)];
    [batteryBodyPath addLineToPoint:CGPointMake(12.97, 18)];
    [batteryBodyPath addCurveToPoint:CGPointMake(11, 20)
                       controlPoint1:CGPointMake(11.88, 18)
                       controlPoint2:CGPointMake(11, 18.89)];
    [batteryBodyPath addLineToPoint:CGPointMake(11, 28)];
    [batteryBodyPath addCurveToPoint:CGPointMake(12.97, 30)
                       controlPoint1:CGPointMake(11, 29.11)
                       controlPoint2:CGPointMake(11.88, 30)];
    [batteryBodyPath addLineToPoint:CGPointMake(32.56, 30)];
    [batteryBodyPath addCurveToPoint:CGPointMake(34.53, 28)
                       controlPoint1:CGPointMake(33.65, 30)
                       controlPoint2:CGPointMake(34.53, 29.11)];
    [batteryBodyPath addLineToPoint:CGPointMake(34.53, 26)];
    [batteryBodyPath addLineToPoint:CGPointMake(35.02, 26)];
    [batteryBodyPath addCurveToPoint:CGPointMake(36, 25)
                       controlPoint1:CGPointMake(35.56, 26)
                       controlPoint2:CGPointMake(36, 25.56)];
    [batteryBodyPath addLineToPoint:CGPointMake(36, 23)];
    [batteryBodyPath addCurveToPoint:CGPointMake(35.02, 22)
                       controlPoint1:CGPointMake(36, 22.45)
                       controlPoint2:CGPointMake(35.56, 22)];
    [batteryBodyPath addLineToPoint:CGPointMake(34.53, 22)];
    [batteryBodyPath addLineToPoint:CGPointMake(34.53, 20)];
    [batteryBodyPath addCurveToPoint:CGPointMake(32.56, 18)
                       controlPoint1:CGPointMake(34.53, 18.89)
                       controlPoint2:CGPointMake(33.65, 18)];
    [batteryBodyPath closePath];
    [batteryBodyPath appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(12.5, 19.5, 20.5, 9)
                                                           cornerRadius:2]];
    batteryBodyPath.miterLimit = 4;

    UIBezierPath *batterySegmentPath = [UIBezierPath bezierPath];

    [batterySegmentPath moveToPoint:CGPointMake(17.5, 27)];
    [batterySegmentPath addLineToPoint:CGPointMake(14.43, 27)];
    [batterySegmentPath addCurveToPoint:CGPointMake(14, 26.5)
                          controlPoint1:CGPointMake(14.16, 27)
                          controlPoint2:CGPointMake(14, 26.78)];
    [batterySegmentPath addLineToPoint:CGPointMake(14, 21.5)];
    [batterySegmentPath addCurveToPoint:CGPointMake(14.43, 21)
                          controlPoint1:CGPointMake(14, 21.23)
                          controlPoint2:CGPointMake(14.16, 21)];
    [batterySegmentPath addLineToPoint:CGPointMake(17.5, 21)];
    [batterySegmentPath addLineToPoint:CGPointMake(18.5, 21)];
    [batterySegmentPath addLineToPoint:CGPointMake(18.5, 27)];
    [batterySegmentPath addLineToPoint:CGPointMake(17.5, 27)];

    [batterySegmentPath closePath];
    batterySegmentPath.miterLimit = 4;

    CGContextSaveGState(context);

    CGContextTranslateCTM(context, center.x, center.y);
    CGContextScaleCTM(context, scale, scale);
    CGContextTranslateCTM(context, -modelCenter.x, -modelCenter.y);

    CGContextSaveGState(context);

    if (!color) {
        // If no foreground color is specified, knock out the path
        // so that you can see through the battery to the background.
        UIBezierPath *clipPath = [UIBezierPath bezierPathWithRect:CGRectInfinite];
        [clipPath appendPath:batteryBodyPath];
        [clipPath appendPath:batterySegmentPath];
        clipPath.usesEvenOddFillRule = YES;

        // The PaintCode battery isn't properly centered,
        CGContextTranslateCTM(context, -1, -1);
        [clipPath addClip];

        // Revert change to translation for background fill.
        CGContextTranslateCTM(context, 1, 1);
        [bgColor setFill];
        [backgroundPath fill];
    } else {
        [bgColor setFill];
        [backgroundPath fill];

        // The PaintCode battery isn't properly centered,
        CGContextTranslateCTM(context, -1, -1);

        [color setFill];
        [batteryBodyPath fill];
    }

    CGContextRestoreGState(context);

    // The battery segment animates, so we should always draw it.
    // It may draw over the clipped battery mask.
    CGContextTranslateCTM(context, -1, -1);
    [batterySegmentColor setFill];
    [batterySegmentPath fill];

    CGContextRestoreGState(context);
}

- (void)notifyStateDidChange
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kPairingSpotStateDidChangeNotificationName
                                                        object:nil];
}

@end
