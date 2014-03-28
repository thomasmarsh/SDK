//
//  FTPenManager+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

#import "FTPenManager.h"

extern NSString * const kFTPenUnexpectedDisconnectNotificationName;
extern NSString * const kFTPenUnexpectedDisconnectWhileConnectingNotifcationName;
extern NSString * const kFTPenUnexpectedDisconnectWhileUpdatingFirmwareNotificationName;

extern NSString * const kFTPenManagerFirmwareUpdateDidBegin;
extern NSString * const kFTPenManagerFirmwareUpdateDidBeginSendingUpdate;
extern NSString * const kFTPenManagerFirmwareUpdateDidUpdatePercentComplete;
extern NSString * const kFTPenManagerPercentCompleteProperty;
extern NSString * const kFTPenManagerFirmwareUpdateDidFinishSendingUpdate;
extern NSString * const kFTPenManagerFirmwareUpdateDidCompleteSuccessfully;
extern NSString * const kFTPenManagerFirmwareUpdateDidFail;
extern NSString * const kFTPenManagerFirmwareUpdateWasCancelled;

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
- (BOOL)updateFirmware;
- (BOOL)updateFirmware:(NSString *)firmwareImagePath;
- (void)cancelFirmwareUpdate;

- (void)startTrialSeparation;

@end
