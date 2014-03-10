//
//  FTPenManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

#import "FiftyThreeSdk/FTTouchClassifier.h"

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

    // Returns true if the given FTPenManagerState is a state in which the pen is disconnected:
    //   * FTPenManagerStateDisconnected
    //   * FTPenManagerStateDisconnectedLongPressToUnpair
    //   * FTPenManagerStateReconnecting
    BOOL FTPenManagerStateIsDisconnected(FTPenManagerState state);

    NSString *FTPenManagerStateToString(FTPenManagerState state);

#ifdef __cplusplus
}
#endif

@interface FTPenInformation : NSObject
@property (nonatomic, readonly) int batteryLevel;
@property (nonatomic, readonly) NSString *firmwareRevision;
@end

@protocol FTPenManagerDelegate <NSObject>
@optional
// Invoked when the connection state is altered.
- (void)connectionDidChange;
// Invoked if we get events that should trigger turning on the display link.
- (void)shouldWakeDisplayLink;
// Invoked when any of the BTLE information is read off the pen.
- (void)penInformationDidChange;
// Invoked when all of the BTLE information is read off the pen.
- (void)penInformationDidFinishUpdating;
@end

@class UIView;
@class UIColor;

typedef NS_ENUM(NSInteger, FTPairingUIStyle) {
    FTPairingUIStyleLight,  // TODO: This will depeend on the visual design we end up.
    FTPairingUIStyleDark
};

@interface FTPenManager : NSObject

// Use this to get at the instance.
+ (id)sharedInstance;

// Connection State.
@property (nonatomic, readonly) FTPenManagerState state;

// Meta data about the pen.
@property (nonatomic, readonly) FTPenInformation *info;

@property (nonatomic, readonly) FTTouchClassifier *classifier;

@property (nonatomic, weak) id<FTPenManagerDelegate> delegate;

// TODO: Parameters will depend on UI design.
- (UIView *)pairingButtonWithStye:(FTPairingUIStyle)style
                     andTintColor:(UIColor *)color
                         andFrame:(CGRect)frame;

- (BOOL)update;

- (void)shutdown;

@end
