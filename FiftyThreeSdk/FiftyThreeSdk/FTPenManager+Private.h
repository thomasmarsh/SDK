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
- (void)updateFirmware:(NSString *)firmwareImagePath;
- (void)cancelFirmwareUpdate;

- (void)startTrialSeparation;

@end

@protocol FTPenManagerDelegatePrivate <FTPenManagerDelegate>

@optional

- (void)penManagerDidStartFirmwareUpdate:(FTPenManager *)manager;
- (void)penManager:(FTPenManager *)manager didUpdateFirmwareUpdatePercentComplete:(float)percentComplete;
- (void)penManager:(FTPenManager *)manager didFinishFirmwareUpdate:(NSError *)error;

@end
