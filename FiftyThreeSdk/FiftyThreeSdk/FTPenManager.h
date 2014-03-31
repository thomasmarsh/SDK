//
//  FTPenManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

#import "FiftyThreeSdk/FTTouchClassifier.h"

// This describes the potential connection states of the pen. Using the Pairing UI provided should
// insulate most apps from needing to know the details of this information.
// See also: FTPenManagerStateIsConnected & FTPenManagerStateIsDisconnected.
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

    // Returns YES if the given FTPenManagerState is a state in which the pen is connected:
    //   * FTPenManagerStateConnected
    //   * FTPenManagerStateConnectedLongPressToUnpair
    //   * FTPenManagerStateUpdatingFirmware
    ///
    //  @param state The current state.
    ///
    //  @return YES if the pen is connected.
    BOOL FTPenManagerStateIsConnected(FTPenManagerState state);

    // Returns true if the given FTPenManagerState is a state in which the pen is disconnected:
    //   * FTPenManagerStateDisconnected
    //   * FTPenManagerStateDisconnectedLongPressToUnpair
    //   * FTPenManagerStateReconnectin
    ///
    //  @param state The current state.
    ///
    //  @return returns YES if the state is disconnected.
    BOOL FTPenManagerStateIsDisconnected(FTPenManagerState state);

    NSString *FTPenManagerStateToString(FTPenManagerState state);

#ifdef __cplusplus
}
#endif

// This contains some meta data you might show in a settings or details view.
// Since this is read via BTLE, it will be populated asynchronously. These values may be nil.
// See FTPenManagerDelegate. The FTPenInformation object is on the FTPenManager singleton.
@interface FTPenInformation : NSObject
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *manufacturerName;
@property (nonatomic, readonly) NSNumber *batteryLevel;
@property (nonatomic, readonly) NSString *firmwareRevision;
@property (nonatomic, readonly) NSURL *learnMoreURL;
// We only recommend using these properties for diagnostics. For example showing a dot in the settings UI
// to indicate the tip is pressed and show the user that the application is correctly communicating with
// the pen.
@property (nonatomic, readonly) BOOL isTipPressed;
@property (nonatomic, readonly) BOOL isEraserPressed;

@end

@protocol FTPenManagerDelegate <NSObject>
@required
// Invoked when the state property of PenManager is changed.
// This typically occures during the connection flow however it
// can also happen if the battery module is removed from the stylus or
// Core Bluetooth drops the BTLE connection.
// See also FTPenManagerStateIsDisconnected & FTPenManagerStateIsConnected
- (void)penManagerStateDidChange:(FTPenManagerState)state;

@optional
// See FTPenManager's automaticUpdates property.
//
// Invoked if we get events that should trigger turning on the display link. You should only need this
// if you're running your own displayLink.
- (void)penManagerNeedsUpdateDidChange;

// Invoked when any of the BTLE information is read off the pen. See FTPenInformation.
// This is also invoted if tip or eraser state is changed.
- (void)penInformationDidChange;
@end

@class UIView;
@class UIColor;

//  TBD on final UI design.
typedef NS_ENUM(NSInteger, FTPairingUIStyle) {
    //  TBD final UI design.
    FTPairingUIStyleLight,
    //  TBD final UI design.
    FTPairingUIStyleDark,
    //  TBD final UI design. Shows additional two indicator dots for tip up/down events.
    FTPairingUIStyleDebug,
};

//  This singleton deals with connection functions of the pen.
@interface FTPenManager : NSObject

// Use this to get at the instance. Note, this will initialize CoreBluetooth and
// potentially trigger the system UIAlertView for enabling Bluetooth LE.
+ (FTPenManager *)sharedInstance;

// Developers should obtain this from FiftyThree.
// [FTPenManager sharedInstance].appToken = [NSUUID alloc] initWithString:"..."];
@property (nonatomic) NSUUID *appToken;

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

// Connection State.
@property (nonatomic, readonly) FTPenManagerState state;

// Meta data about the pen.
@property (nonatomic, readonly) FTPenInformation *info;

// Primary API to query information about UITouch objects.
@property (nonatomic, readonly) FTTouchClassifier *classifier;

// Register to get connection related notifications.
@property (nonatomic, weak) id<FTPenManagerDelegate> delegate;

// TBD.
// TODO: Parameters will depend on UI design.
// This provides a view that implements our BTLE pairing UI.
//
// Depending on design this may change from a single view to a viewcontroller we have
// the client present in a UIPopover - still under discussion.
//
// This must be called on the UI thread.
- (UIView *)pairingButtonWithStyle:(FTPairingUIStyle)style
                      andTintColor:(UIColor *)color
                          andFrame:(CGRect)frame;

// Call this to tear down the API. This also will shut down any CoreBluetooth activity.
// You'll also need to release any views that FTPenManager has handed you. The next access to
// [FTPenManager sharedInstance] will re-setup CoreBluetooth.
//
// This must be called on the UI thread.
- (void)shutdown;

// Optional:
//
// Only use this if you are running your own displayLink Call this at the start of your render loop.
// See  automaticUpdateEnabled
// See  penManagerNeedsUpdateDidChange.
- (void)update;
@end
