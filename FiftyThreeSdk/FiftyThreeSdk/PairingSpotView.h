//
//  PairingSpotView.h
//  FiftyThreeSdk
//
//  Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <UIKit/UIKit.h>

const CGFloat kPairingSpotTouchRadius_Began = 35.f;
const CGFloat kPairingSpotMinRadius = 23.f;
const CGFloat kPairingSpotMaxRadius = 41.f;

struct PairingSpotViewSettings {
    float BatteryFlashOpacityFactor = 0.25f;
    float CometMaxThickness = 16.0f;
    float CometRotationsPerSecond = 1.5f;
    bool DebugAnimations = false;
    float DisconnectedFlashOpacityFactor = 0.5f;
    float FlashDurationSeconds = 2.6f;
    float FlashFrequencySeconds = 2.8f;
    float IconTransitionAnimationDuration = 0.2f;
    bool SlowAnimations = false;
    float WellEasingAnimationDuration = 0.2f;
};

typedef NS_ENUM(NSInteger, FTPairingSpotConnectionState) {
    FTPairingSpotConnectionStateUnpaired,
    FTPairingSpotConnectionStateConnected,
    FTPairingSpotConnectionStateLowBattery,
    FTPairingSpotConnectionStateCriticallyLowBattery,
};

typedef NS_ENUM(NSInteger, FTPairingSpotCometState) {
    FTPairingSpotCometStateNone,
    FTPairingSpotCometStateClockwise,
    FTPairingSpotCometStateCounterClockwise,
};

///
/// General styling options for the pairing spot UI.
///
typedef NS_ENUM(NSInteger, FTPairingSpotStyle) {

    /// Show the pairing UI using a flattened appearance.
    FTPairingSpotStyleFlat = 0,

    /// Show the pairing UI as being inset into the glass.
    FTPairingSpotStyleInset = 1,
};

extern NSString *const kPairingSpotStateDidChangeNotificationName;

@class PairingSpotView;

@protocol PairingSpotViewDelegate <NSObject>

- (void)pairingSpotViewAnimationWasEnqueued:(PairingSpotView *)pairingSpotView;

@end

#pragma mark -

@interface PairingSpotView : UIView

+ (UIColor *)grayPairingColor;

@property (nonatomic, weak) id<PairingSpotViewDelegate> delegate;

@property (nonatomic, readonly) FTPairingSpotConnectionState connectionState;

@property (nonatomic, readonly) BOOL isDisconnected;

@property (nonatomic) BOOL isActive;

@property (nonatomic) FTPairingSpotCometState cometState;

@property (nonatomic) BOOL shouldSuspendNewAnimations;

///
/// Controls different styles for the pairing spot. See
/// FTPairingSpotStyle enum for supported values.
///
@property (nonatomic) FTPairingSpotStyle style UI_APPEARANCE_SELECTOR;

///
/// Sets the color used when drawing "highlights" for the pairing view.
///
@property (nonatomic) UIColor *highlightColor UI_APPEARANCE_SELECTOR;

///
/// Sets the color used when drawing "selected" elements for the pairing view.
///
@property (nonatomic) UIColor *selectedColor UI_APPEARANCE_SELECTOR;

///
/// Sets the color used when drawing elements for the pairing view that are not selected.
///
@property (nonatomic) UIColor *unselectedColor UI_APPEARANCE_SELECTOR;

///
/// Sets the tint color used when the pairing spot is "deselected".
///
@property (nonatomic) UIColor *unselectedTintColor UI_APPEARANCE_SELECTOR;

@property (nonatomic) PairingSpotViewSettings viewSettings;

- (void)setConnectionState:(FTPairingSpotConnectionState)connectionState
            isDisconnected:(BOOL)isDisconnected;

- (void)snapToCurrentState;

@end
