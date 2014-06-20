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

typedef NS_ENUM(NSInteger, FTPenBatteryLevel)
{
    FTPenBatteryLevelHigh,
    FTPenBatteryLevelMediumHigh,
    FTPenBatteryLevelMediumLow,
    FTPenBatteryLevelLow
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
@property (nonatomic, readonly) FTPenBatteryLevel batteryLevel;
@property (nonatomic, readonly) NSString *firmwareRevision;
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

// See FTPenManager (FirmwareUpdateSupport)
- (void)penManagerFirmwareUpdateIsAvailbleDidChange;
@end

@class UIView;
@class UIColor;

typedef NS_ENUM(NSInteger, FTPairingUIStyle) {
    // You should use this in release builds.
    FTPairingUIStyleDefault,
    // This turns on two additional views that show if the tip or eraser are pressed.
    FTPairingUIStyleDebug
};

#pragma mark -  FTPenManager

//  This singleton deals with connection functions of the pen.
@interface FTPenManager : NSObject

// Developers should obtain this from FiftyThree.
// [FTPenManager sharedInstance].appToken = [NSUUID alloc] initWithString:"..."];
@property (nonatomic) NSUUID *appToken;

// Connection State.
@property (nonatomic, readonly) FTPenManagerState state;

// Meta data about the pen.
@property (nonatomic, readonly) FTPenInformation *info;

// Primary API to query information about UITouch objects.
@property (nonatomic, readonly) FTTouchClassifier *classifier;

// Register to get connection related notifications.
@property (nonatomic, weak) id<FTPenManagerDelegate> delegate;

// Use this to get at the instance. Note, this will initialize CoreBluetooth and
// potentially trigger the system UIAlertView for enabling Bluetooth LE.
+ (FTPenManager *)sharedInstance;

// This provides a view that implements our BTLE pairing UI. The control is 81x101 points.
//
// This must be called on the UI thread.
- (UIView *)pairingButtonWithStyle:(FTPairingUIStyle)style;

// Call this to tear down the API. This also will shut down any CoreBluetooth activity.
// You'll also need to release any views that FTPenManager has handed you. The next access to
// [FTPenManager sharedInstance] will re-setup CoreBluetooth.
//
// This must be called on the UI thread.
- (void)shutdown;

#pragma mark -  FTPenManager - Support & Marketing URLs

// This provides a link the FiftyThree's marketing page about Pencil.
@property (nonatomic, readonly) NSURL *learnMoreURL;
// This provides a link the FiftyThree's general support page about Pencil.
@property (nonatomic, readonly) NSURL *pencilSupportURL;

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

#pragma mark -  FTPenManager - FirmwareUpdateSupport

// Defaults to NO. If YES the SDK will notify via the delegate if a firmware update for Pencil
// is available. This *does* use WiFi to make a webservice request periodically.
@property (nonatomic) BOOL shouldCheckForFirmwareUpdates;

// Indicates if a firmware update can be installed on the connected Pencil. This is done
// via Paper by FiftyThree. This is either YES, NO or nil (if it's unknown.)
//
// See also shouldCheckForFirmwareUpdates
// See also penManagerFirmwareUpdateIsAvailbleDidChange
@property (nonatomic, readonly) NSNumber *firmwareUpdateIsAvailble;

// Provides an link to offer some information from our support page about the firmware release notes.
@property (nonatomic, readonly) NSURL *firmwareUpdateReleaseNotesLink;

// Provides an link to offer some information from our support page about the firmware upgrade.
@property (nonatomic, readonly) NSURL *firmwareUpdateSupportLink;

// Returns NO if you're on an iphone or a device without Paper installed. (Or an older build of Paper that
// doesn't support the firmware upgrades of Pencil.)
@property (nonatomic, readonly) BOOL canInvokePaperToUpdatePencilFirmware;

// This invokes Paper via x-callback-urls to upgrade the firmware.
//
// You can provide error, success, and cancel URLs so that Paper
// can return to your application after the Firmware upgrade is complete.
// Returns NO if Paper can't be invoked.
- (BOOL)invokePaperToUpdatePencilFirmware:(NSString *)source          // This should be human readable Application name.
                                   success:(NSURL*)successCallbackUrl  // e.g., YourApp://x-callback-url/success
                                     error:(NSURL*)errorCallbackUrl    // e.g., YourApp://x-callback-url/error
                                    cancel:(NSURL*)cancelCallbackUrl;  // e.g., YourApp://x-callback-url/cancel

@end
