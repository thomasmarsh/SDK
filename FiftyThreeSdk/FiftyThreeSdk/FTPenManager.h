/*
    FTPenManager.h
    FiftyThreeSdk
 
    Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
    Use of this code is subject to the terms of the FiftyThree SDK License Agreement, included with this SDK as the file "FiftyThreeSDK-License.txt"
 */

#pragma once

// clang-format off

#import <Foundation/Foundation.h>

#import "FiftyThreeSdk/FTTouchClassifier.h"

/*!
 @brief This describes the potential connection states of the pen. Using the Pairing UI provided should insulate most apps from needing to know the details of this information.
 @discussion See also: FTPenManagerStateIsConnected & FTPenManagerStateIsDisconnected.
 
 @constant FTPenManagerStateUninitialized the pen is not initialized.
 @constant FTPenManagerStateUnpaired the pen is unpaired.
 @constant FTPenManagerStateSeeking the device is seeking for the pen.
 @constant FTPenManagerStateConnecting the pen is connecting to the device.
 @constant FTPenManagerStateConnected the pen is connected.
 @constant FTPenManagerStateConnectedLongPressToUnpair the connected pen is unpairng with the device.
 @constant FTPenManagerStateDisconnected the pen disconnected.
 @constant FTPenManagerStateDisconnectedLongPressToUnpair the pen is disconnected after long press.
 @constant FTPenManagerStateReconnecting the pen is reconnecting.
 @constant FTPenManagerStateUpdatingFirmware the pen's firmware is being updated.
 */
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

/*!
 @brief This describes the battery level of the pen.
 
 @constant FTPenBatteryLevelUnknown This is reported initially until the actual battery level can be returned. It can take up to 20 seconds to read the battery level off the stylus.
 @constant FTPenBatteryLevelHigh
 @constant FTPenBatteryLevelMediumHigh
 @constant FTPenBatteryLevelMediumLow
 @constant FTPenBatteryLevelLow
 @constant FTPenBatteryLevelCriticallyLow If we're reporting critically low, you should prompt the user to recharge.
 */

typedef NS_ENUM(NSInteger, FTPenBatteryLevel)
{
    FTPenBatteryLevelUnknown,
    FTPenBatteryLevelHigh,
    FTPenBatteryLevelMediumHigh,
    FTPenBatteryLevelMediumLow,
    FTPenBatteryLevelLow,
    FTPenBatteryLevelCriticallyLow
};

#ifdef __cplusplus
extern "C"
{
#endif
    
    /*!
     @brief  Returns YES if the given FTPenManagerState is a state in which the pen is connected.
     @discussion Returns YES if the given FTPenManagerState is a state in which the pen is connected:
     
     - FTPenManagerStateConnected
     
     - FTPenManagerStateConnectedLongPressToUnpair
     
     - FTPenManagerStateUpdatingFirmware
     
     @param state The current state.
     @return YES if the pen is connected.
     */
    BOOL FTPenManagerStateIsConnected(FTPenManagerState state);
    
    /*!
     @brief  Returns true if the given FTPenManagerState is a state in which the pen is disconnected.
     @discussion Returns true if the given FTPenManagerState is a state in which the pen is disconnected:
     
     - FTPenManagerStateDisconnected
     
     - FTPenManagerStateDisconnectedLongPressToUnpair
     
     - FTPenManagerStateReconnecting
     
     @param state The current state.
     @return returns YES if the state is disconnected.
     */
    BOOL FTPenManagerStateIsDisconnected(FTPenManagerState state);
    
    NSString *FTPenManagerStateToString(FTPenManagerState state);
    
#ifdef __cplusplus
}
#endif

/*!
 @brief  This contains some meta data you might show in a settings or details view. Since this is read via BTLE, it will be populated asynchronously. These values may be nil.
 @discussion See FTPenManagerDelegate. The FTPenInformation object is on the FTPenManager singleton.
 */
@interface FTPenInformation : NSObject

/*!
 @brief  Pencil name
 */
@property (nonatomic, readonly) NSString *name;

/*!
 @brief  Manufacturer name
 */
@property (nonatomic, readonly) NSString *manufacturerName;

/*!
 @brief  Battery level
 */
@property (nonatomic, readonly) FTPenBatteryLevel batteryLevel;

/*!
 @brief  Firmware revision. Nil if we've not yet read the firmware revision.
 */
@property (nonatomic, readonly) NSString *firmwareRevision;

/*!
 @brief  True when the tip is pressed
 
 @discussion We only recommend using these properties for diagnostics. For example, showing a dot in the settings UI to indicate the tip is pressed and show the user that the application is correctly communicating with the pen.
 */
@property (nonatomic, readonly) BOOL isTipPressed;
/*!
 @brief  True when the eraser is pressed
 */
@property (nonatomic, readonly) BOOL isEraserPressed;

@end

/*!
 @brief  PenManagerDelegate
 */
@protocol FTPenManagerDelegate <NSObject>
@required

/*!
 @brief  Invoked when the state property of PenManger is changed.
 
 @discussion This typically occures during the connection flow.  However it can also happen if the battery module is removed from the stylus or Core Bluetooth drops the BTLE connection. See also FTPenManagerStateIsDisconnected & FTPenManagerStateIsConnected.
 
 @param state PenManager state
 */
- (void)penManagerStateDidChange:(FTPenManagerState)state;

@optional

/*!
 @brief  Invoked when any of the BTLE information is read off the pen. See FTPenInformation.
 
 @discussion This is also invoked if tip or eraser state is changed.
 */
- (void)penInformationDidChange;

/*!
 @brief  See FTPenManager (FirmwareUpdateSupport)
 */
- (void)penManagerFirmwareUpdateIsAvailableDidChange;

@optional

/*!
 @brief  Invoked if the needsUpdate property is set to YES. For most uses of our SDK this selector can be ignored.
 */
- (void)penManagerNeedsUpdate;

@end

@class UIView;
@class UIColor;

/*!
 @brief  Style overrides available for some values of FTPairingUIStyle.
 */
@interface FTPairingUIStyleOverrides : NSObject

/*!
 @brief  Override the color used by the style for drawing icons when the UI control is in a "selected" pseudo-state (e.g. "selected" is synonoumous with "connected").
 */
@property (nonatomic, strong) UIColor *selectedColor;

/*!
 @brief Override the color used by the style for drawing icons when the UI control is in an "normal" pseudo-state (e.g. "normal" is synonoumous with "disconnected").
 */
@property (nonatomic, strong) UIColor *unselectedColor;

/*!
 @brief  Override the color used by the style tinting the UI control. This value supercedes any tintColor set for the UIView or its type heiarchy.
 */
@property (nonatomic, strong) UIColor *tintColor;

/*!
 @brief  Override the color used by the style for tinting the UI control when in an "normal" pseudo-state (e.g. "normal" is synonoumous with "disconnected").
 */
@property (nonatomic, strong) UIColor *unselectedTintColor;

@end

/*!
 @brief "Kiss to pair" button UI style
 
 @constant FTPairingUIStyleDefault You should use this in release builds.
 @constant FTPairingUIStyleDebug This turns on two additional views that show if the tip or eraser are pressed.
 @constant FTPairingUIStyleFlat Uses an alternate visual style more compatible with the "flat" look of iOS7. This style supports FTPairingUIStyleOverrides
 @constant FTPairingUIStyleCompact Uses a visual style with thin comets, knocked-out graphics. Also suppresses flash while reconnecting.
 */

typedef NS_ENUM(NSInteger, FTPairingUIStyle) {
    FTPairingUIStyleDefault,
    FTPairingUIStyleDebug,
    FTPairingUIStyleFlat,
    FTPairingUIStyleCompact
};

#pragma mark -  FTPenManager

/*!
 @brief  This singleton deals with connection functions of the pen.
 */
@interface FTPenManager : NSObject

/*!
 @brief  Connection State.
 */
@property (nonatomic, readonly) FTPenManagerState state;

/*!
 @brief  Meta data about the pen.
 */
@property (nonatomic, readonly) FTPenInformation *info;

/*!
 @brief  Primary API to query information about UITouch objects.
 */
@property (nonatomic, readonly) FTTouchClassifier *classifier;

/*!
 @brief  Register to get connection related notifications.
 */
@property (nonatomic, weak) id<FTPenManagerDelegate> delegate;

/*!
 @brief  Use this to get at the instance. Note, this will initialize CoreBluetooth and potentially trigger the system UIAlertView for enabling Bluetooth LE.
 @discussion Please note that you need to be running on iOS 7 or higher to use any of this SDK. You can safely *link* against this SDK and not call it on iOS 6.
 
 @return sharedInstance
 */
+ (FTPenManager *)sharedInstance;

/*!
 @brief This provides a view that implements our BTLE pairing UI. The control is 81x101 points.
 @warning This must be called on the UI thread.
 
 @param style Paring button UI style
 
 @return Pairing button UI view
 */
- (UIView *)pairingButtonWithStyle:(FTPairingUIStyle)style;

/*!
 @brief  This provides a view that implements our BTLE pairing UI. The control is 81x101 points.
 @warning This must be called on the UI thread.
 
 @param style          style Paring button UI style
 @param styleOverrides style Paring button UI style overrides
 
 @return Pairing button UI view
 */
- (UIView *)pairingButtonWithStyle:(FTPairingUIStyle)style andStyleOverrides:(FTPairingUIStyleOverrides *)styleOverrides;

/*!
 @brief  Call this to tear down the API.
 @discussion This also will shut down any CoreBluetooth activity. You'll also need to release any views that FTPenManager has handed you. The next access to [FTPenManager sharedInstance] will re-setup CoreBluetooth.
 @warning This must be called on the UI thread.
 */
- (void)shutdown;

#pragma mark -  FTPenManager  - Touch Classification Processing

/*!
 @brief  Defaults YES.
 @discussion  We automatically process touches the next time the main thread's run loop is in one of the modes specified by updateRunLoopModes.
 
 To manually process touch classifications set this to NO and call [[FTPenManager sharedInstance] update] from the main thread where appropriate for your application. Normally this is done as part of a rendering loop before drawing.
 */
@property (nonatomic) BOOL automaticUpdatesEnabled;

/*!
 @brief This property is normally used by FTApplication by way of an FTEventDispatcher and can be ignored for most uses of our SDK.
 @discussion  If automaticUpdatesEnabled is YES (the default) then setting this property to YES will force touch classifications and pairing spot animations to be updated on the main thread the next time it processes its main loop in one of the modes specified by updateRunLoopModes. This is normally done automatically as a side effect of processing various events.
 
 If automaticUpdatesEnabled is NO then setting this propery will have no specific effect other than triggering the penManagerNeedsUpdate callback on the pen manager's delegate if the value changs from NO to YES.
 
 See also penManagerNeedsUpdate.
 
 */
@property (nonatomic) BOOL needsUpdate;

/*!
 @brief  This method can be ignored if automaticUpdatesEnabled is YES (the default)
 @discussion  If you've turned off automatic updates you must call this method to run touch classification and pairing spot animations.
 
 Since this method checks the needsUpdate property before updating classifications or animations it can be called as part of an app's rendering loop without wasting too much CPU time.
 
 You can also use the pen manager delegate's penManagerNeedsUpdate method to cause your rendering loop to execute if it has a sleep mode (e.g. to set the needsUpdate property of a UIView or the paused property of a GLKView).
 */
- (void)update;

/*!
 @brief  A list of modes for the main thread's run loop in which touch classifications and pairing spot animations will be updated when automaticUpdatesEnabled is YES. If not using automatic updates this property has no effect
 @discussion  As of version 1.2.1 of this SDK the default is to use only the NSRunLoopCommonModes mode. This ensures that touch classifications can be processed even when input events would otherwise block default mode processing. See Apple's documentation on Run Loops for more details on these modes : https://goo.gl/65Zwv3
 */
@property (nonatomic) NSArray *updateRunLoopModes;

#pragma mark - SurfacePressure APIs iOS8+

/*!
 @brief  Returns a normalized value that corresponds to physical touch size in MM. This signal is very heavily quantized.
 
 @param uiTouch Physical touch.
 
 @return Returns nil if you are not on iOS 8 or pencil isn't connected.
 */
- (NSNumber *)normalizedRadiusForTouch:(UITouch *)uiTouch;

/*!
 @brief  Returns a smoothed normalized value that is suitable for rendering variable width ink.
 
 @param uiTouch Physical touch.
 
 @return Normalized value. Returns nil if you are not on iOS 8+ or pencil isn't connected.
 */
- (NSNumber *)smoothedRadiusForTouch:(UITouch *)uiTouch;

/*!
 @brief  Unnormalized smoothed radius the value is CGPoints.
 
 @param uiTouch Physical touch.
 
 @return Unnormalized value.
 */
- (NSNumber *)smoothedRadiusInCGPointsForTouch:(UITouch *)uiTouch;

#pragma mark -  FTPenManager - Support & Marketing URLs

/*!
 @brief  This provides a link the FiftyThree's marketing page about Pencil.
 */
@property (nonatomic, readonly) NSURL *learnMoreURL;
/*!
 @brief  This provides a link the FiftyThree's general support page about Pencil.
 */
@property (nonatomic, readonly) NSURL *pencilSupportURL;

#pragma mark -  FTPenManager - FirmwareUpdateSupport

/*!
 @brief  Defaults to NO. If YES the SDK will notify via the delegate if a firmware update for Pencil is available. This *does* use WiFi to make a webservice request periodically.
 */
@property (nonatomic) BOOL shouldCheckForFirmwareUpdates;

/*!
 @brief  Indicates if a firmware update can be installed on the connected Pencil. This is done via Paper by FiftyThree. This is either YES, NO or nil (if it's unknown.)
 @discussion See also shouldCheckForFirmwareUpdates, penManagerFirmwareUpdateIsAvailableDidChange.
 */
@property (nonatomic, readonly) NSNumber *firmwareUpdateIsAvailable;

/*!
 @brief  Provides a link to the firmware release notes.
 */
@property (nonatomic, readonly) NSURL *firmwareUpdateReleaseNotesLink;

/*!
 @brief  Provides a link to the FiftyThree support page on firmware upgrades.
 */
@property (nonatomic, readonly) NSURL *firmwareUpdateSupportLink;

/*!
 @brief  Returns NO if you're on an iphone or a device without Paper installed. (Or an older build of Paper that doesn't support Pencil firmware upgrades.)
 */
@property (nonatomic, readonly) BOOL canInvokePaperToUpdatePencilFirmware;

/*!
 @brief  This invokes Paper via x-callback-urls to upgrade the firmware. You can provide error, success, and cancel URLs so that Paper can return to your application after the Firmware upgrade is complete.
 
 @param source
 @param successCallbackUrl
 @param errorCallbackUrl
 @param cancelCallbackUrl
 
 @return Returns NO if Paper can't be invoked.
 */
- (BOOL)invokePaperToUpdatePencilFirmware:(NSString *)source           // This should be a human readable application name.
                                  success:(NSURL*)successCallbackUrl // e.g., YourApp://x-callback-url/success
                                    error:(NSURL*)errorCallbackUrl   // e.g., YourApp://x-callback-url/error
                                   cancel:(NSURL*)cancelCallbackUrl; // e.g., YourApp://x-callback-url/cancel
@end
// clang-format on
