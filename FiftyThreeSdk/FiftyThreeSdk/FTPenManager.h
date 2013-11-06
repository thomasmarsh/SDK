//
//  FTPenManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

#import "FTPen.h"

typedef NS_ENUM(NSInteger, FTPenManagerState)
{
    FTPenManagerStateUninitialized,
    FTPenManagerStateUnpaired,
    FTPenManagerStateSeeking,
    FTPenManagerStateConnecting,
    FTPenManagerStateConnected,
    FTPenManagerStateConnectedLongPressToUnpair,
    FTPenManagerStateDisconnected,
    FTPenManagerStateDisconnectedLongPressToUnpair,
    FTPenManagerStateReconnecting,
    FTPenManagerStateUpdatingFirmware
};

#ifdef __cplusplus
extern "C"
{
#endif

    // Returns true if the given FTPenManagerState is a state in which the pen is connected:
    //   * FTPenManagerStateConnected
    //   * FTPenManagerStateConnectedLongPressToUnpair
    //   * FTPenManagerStateUpdatingFirmware
    BOOL FTPenManagerStateIsConnected(FTPenManagerState state);

    NSString *FTPenManagerStateToString(FTPenManagerState state);

#ifdef __cplusplus
}
#endif

extern NSString * const kFTPenManagerDidUpdateStateNotificationName;
extern NSString * const kFTPenManagerDidFailToDiscoverPenNotificationName;

@interface FTPenManager : NSObject

@property (nonatomic, readonly) FTPenManagerState state;

@property (nonatomic, readonly) FTPen *pen;

@property (nonatomic) BOOL isPairingSpotPressed;

- (void)disconnect;

@end
