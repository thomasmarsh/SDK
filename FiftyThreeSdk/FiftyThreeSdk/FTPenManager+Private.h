//
//  FTPenManager+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

#import "FTPenManager.h"

extern NSString *const kFTPenUnexpectedDisconnectNotificationName;
extern NSString *const kFTPenUnexpectedDisconnectWhileConnectingNotifcationName;
extern NSString *const kFTPenUnexpectedDisconnectWhileUpdatingFirmwareNotificationName;

extern NSString *const kFTPenManagerFirmwareUpdateDidBegin;
extern NSString *const kFTPenManagerFirmwareUpdateDidPrepare;
extern NSString *const kFTPenManagerFirmwareUpdateDidBeginSendingUpdate;
extern NSString *const kFTPenManagerFirmwareUpdateDidUpdatePercentComplete;
extern NSString *const kFTPenManagerPercentCompleteProperty;
extern NSString *const kFTPenManagerFirmwareUpdateDidFinishSendingUpdate;
extern NSString *const kFTPenManagerFirmwareUpdateDidCompleteSuccessfully;
extern NSString *const kFTPenManagerFirmwareUpdateDidFail;
extern NSString *const kFTPenManagerFirmwareUpdateWasCancelled;
extern NSString *const kFTPenManagerFirmwareUpdateWaitingForPencilTipRelease;

@interface FTPenManager ()

- (void)ensureNeedsUpdate;

// Returns a boolean value as a NSNumber, or nil if this cannot yet be determined.
//
// Returns @(YES) if a firmware update is available for the connected pen. This determination
// can only be made once the softwareRevision and firmwareRevision properties of the device
// info service have been initialized.
//
// currentVersion is updated if it is available; otherwise it is set to -1.
//
// updateVersion is updated IFF the return value is @(@YES) and should otherwise be ignored.
- (NSNumber *)isFirmwareUpdateAvailable:(NSInteger *)currentVersion
                          updateVersion:(NSInteger *)updateVersion;

// Gets the firmware image ready for update and prepares the peripheral. This action
// is still reversable (i.e. no firmware images on the peripheral will be invalidated
// until the update proceeds).
- (BOOL)prepareFirmwareUpdate;
- (BOOL)prepareFirmwareUpdate:(NSString *)firmwareImagePath;

// Deprecated. Use prepareFirmwareUpdate first then call startUpdatingFirmware
// once the kFTPenManagerFirmwareUpdateDidPrepare was receieved.
// Note that this method will try to start the firmware update automatically but
// could fail to do so. For some older peripherals this method could prepare the
// update and then wait indefinitly for more user input.
- (BOOL)updateFirmware __attribute__((deprecated));
- (BOOL)updateFirmware:(NSString *)firmwareImagePath __attribute__((deprecated));

// Call this after the kFTPenManagerFirmwareUpdateDidPrepare was received.
//
// Returns YES if the update has started else returns NO.
- (BOOL)startUpdatingFirmware;

- (void)cancelFirmwareUpdate;

- (void)startTrialSeparation;

@end
