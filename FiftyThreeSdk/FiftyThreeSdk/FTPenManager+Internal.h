//
//  FTPenManager+Internal.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import "FTPen.h"
#import "FTPenManager.h"
#import "FTXCallbackURL.h"

extern NSString *const kFTPenManagerDidUpdateStateNotificationName;
extern NSString *const kFTPenManagerDidFailToDiscoverPenNotificationName;

@interface FTPenManager (Internal)

+ (FTPenManager *)sharedInstanceWithoutInitialization;

@property (nonatomic, readonly) FTPen *pen;

@property (nonatomic, readonly) FTXCallbackURL *pencilFirmwareUpgradeURL;

#pragma mark -  FTPenManager  - Advanced DisplayLink Support

// Defaults YES. We run a displayLink to drive animations and classifications.
// this is paused when no touch or pen events have occured recently.
//
// You may want to drive the animations and classifications in your own CADisplayLink.
// If that's the case, set this to FALSE and implement penManagerNeedsUpdateDidChange and
// call [[FTPenManager sharedInstance] update]; at the start of your render loop.
@property (nonatomic) BOOL automaticUpdatesEnabled;

// Indicates that update should be called on FTPenManager. You'd only need to check this if
// you've set automaticUpdateEnabled to NO.
//
// See also penManagerNeedsUpdateDidChange.
@property (nonatomic) BOOL needsUpdate;

// Only use this if you are running your own displayLink Call this at the start of your render loop.
- (void)update;

- (void)disconnect;

#pragma mark - Used by Adobe.
- (void)disconnectOrBecomeSingle;
@property (nonatomic) BOOL disableLongPressToUnpairIfTipPressed;
@property (nonatomic) BOOL isPairingSpotPressed;

@end
