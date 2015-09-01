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

- (void)disconnect;

#pragma mark - Used by Adobe.
- (void)disconnectOrBecomeSingle;
@property (nonatomic) BOOL disableLongPressToUnpairIfTipPressed;
@property (nonatomic) BOOL isPairingSpotPressed;

@end
