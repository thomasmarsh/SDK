//
//  PairingSpotView.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <UIKit/UIKit.h>

struct PairingSpotViewSettings
{
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

typedef NS_ENUM(NSInteger, FTPairingSpotConnectionState)
{
    FTPairingSpotConnectionStateUnpaired,
    FTPairingSpotConnectionStateConnected,
    FTPairingSpotConnectionStateLowBattery,
    FTPairingSpotConnectionStateCriticallyLowBattery,
};

typedef NS_ENUM(NSInteger, FTPairingSpotCometState)
{
    FTPairingSpotCometStateNone,
    FTPairingSpotCometStateClockwise,
    FTPairingSpotCometStateCounterClockwise,
};

extern NSString * const kPairingSpotStateDidChangeNotificationName;

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

@property (nonatomic) PairingSpotViewSettings visualSettings;

- (void)setConnectionState:(FTPairingSpotConnectionState)connectionState
            isDisconnected:(BOOL)isDisconnected;

- (void)snapToCurrentState;

@end
