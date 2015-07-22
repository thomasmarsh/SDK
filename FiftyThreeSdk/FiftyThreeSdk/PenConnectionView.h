//
//  PenConnectionView.h
//  FiftyThreeSdk
//
//  Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <UIKit/UIKit.h>

#import "FiftyThreeSdk/FTPenManager.h"
#import "FiftyThreeSdk/PairingSpotView.h"

typedef NS_ENUM(NSInteger, VisibilityState) {
    VisibilityStateVisible,  // Visible
    VisibilityStateHidden,   // Not visible, but space is still reserved for the element in the layout
    VisibilityStateCollapsed // Not visible and the element is collapsed away, not taking up space in the layout
};

@class PenConnectionView;

@protocol PenConnectionViewDelegate <NSObject>

@optional

- (void)penConnectionViewAnimationWasEnqueued:(PenConnectionView *)penConnectionView;

- (BOOL)canPencilBeConnected;
- (void)isPairingSpotPressedDidChange:(BOOL)isPairingSpotPressed;

@end

#pragma mark -

@interface PenConnectionView : UIView

- (id)initWithCoder:(NSCoder *)aDecoder __unavailable;
- (id)initWithFrame:(CGRect)frame __unavailable;
@property (nonatomic, weak) id<PenConnectionViewDelegate> delegate;
@property (nonatomic) FTPenManager *penManager;
@property (nonatomic) VisibilityState debugControlsVisibility;
@property (nonatomic) BOOL isActive;
@property (nonatomic, readonly) BOOL isPairingSpotPressed;
@property (nonatomic) BOOL suppressDialogs;
@property (nonatomic) BOOL shouldSuspendNewAnimations;
@property (nonatomic) FTPairingUIStyle style;
@property (nonatomic) CGFloat penConnectionSpotRadius;

- (BOOL)isPenConnected;
- (BOOL)isPenDisconnected;
- (BOOL)isPenBatteryLow;
- (BOOL)isPenUnpaired;

@end

@interface PenConnectionView (Paper)
@property (nonatomic, readonly) PairingSpotView *pairingSpotView;
@end
