//
//  FTPenManager+Internal.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import "Common/FTXCallbackURL.h"
#import "FTPen.h"
#import "FTPenManager.h"

extern NSString * const kFTPenManagerDidUpdateStateNotificationName;
extern NSString * const kFTPenManagerDidFailToDiscoverPenNotificationName;

@interface FTPenManager (Internal)

+ (FTPenManager *)sharedInstanceWithoutInitialization;

@property (nonatomic, readonly) FTPen *pen;

@property (nonatomic) BOOL isPairingSpotPressed;

@property (nonatomic, readonly) FTXCallbackURL *pencilFirmwareUpgradeURL;

- (void)disconnect;
- (void)discconnectOrBecomeSingle;

@end
