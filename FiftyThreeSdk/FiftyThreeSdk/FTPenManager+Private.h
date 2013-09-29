//
//  FTPenManager+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
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
extern NSString * const kFTPenManagerFirmwareUpdateWasCancelled;

@interface FTPenManager ()

// Returns true if a firmware update is available for the connected pen. This determination can only be made
// once the softwareRevision and firmwareRevision properties of the device info service have been initialized.
//
// If the current version of the firmware can be determined, currentVersion gets that version; otherwise it
// gets -1.
//
// If the firmware can be updated, updateVersion gets the version that the firmware can be updated to;
// otherwise it gets - 1.
- (BOOL)isFirmwareUpdateAvailable:(NSInteger *)currentVersion
                    updateVersion:(NSInteger *)updateVersion;
- (BOOL)updateFirmware;
- (BOOL)updateFirmware:(NSString *)firmwareImagePath;
- (void)cancelFirmwareUpdate;

- (void)startTrialSeparation;

@end
