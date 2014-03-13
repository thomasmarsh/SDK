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

// This contains some meta data you might show in a settings or detail view.
// Since this is read via BTLE, it will be populated asynchronously.
// See FTPenManagerDelegate. The FTPenInformation object is on the FTPenManager singleton.
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

// Use this to get at the instance. Note, this will initialize CoreBluetooth and
// potentially trigger the system UIAlertView for enabling Bluetooth LE.
+ (FTPenManager *)sharedInstance;

// Connection State.
@property (nonatomic, readonly) FTPenManagerState state;

// Meta data about the pen.
@property (nonatomic, readonly) FTPenInformation *info;

// Primary API to query information about UITouch objects.
@property (nonatomic, readonly) FTTouchClassifier *classifier;

// Register to get connection related notifications.
@property (nonatomic, weak) id<FTPenManagerDelegate> delegate;

// TODO: Parameters will depend on UI design.
// This provides a view that implements our BTLE pairing UI.
//
// This must be called on the UI thread.
- (UIView *)pairingButtonWithStye:(FTPairingUIStyle)style
                     andTintColor:(UIColor *)color
                         andFrame:(CGRect)frame;

// Call this at the start of your render loop. Returns YES if we'd like to get called again (i.e., a
// reclassification may happen.)
//
// This must be called on the UI thread.
- (BOOL)update;

// Call this to tear down the API. This also shut down any CoreBluetooth activity.
// You'll also need to release
// any views that FTPenManager has handed you. The next access to [FTPenManager sharedInstance] will
// re-setup CoreBluetooth.
//
// This must be called on the UI thread.
- (void)shutdown;

@end
