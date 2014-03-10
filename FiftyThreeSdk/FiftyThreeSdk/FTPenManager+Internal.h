//
//  FTPenManager+Internal.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import "FTPen.h"
#import "FTPenManager.h"

extern NSString * const kFTPenManagerDidUpdateStateNotificationName;
extern NSString * const kFTPenManagerDidFailToDiscoverPenNotificationName;

@interface FTPenManager (Internal)

@property (nonatomic, readonly) FTPenManagerState state;

@property (nonatomic, readonly) FTPen *pen;

@property (nonatomic) BOOL isPairingSpotPressed;

- (void)disconnect;

@end
