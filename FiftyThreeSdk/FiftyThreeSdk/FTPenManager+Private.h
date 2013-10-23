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

// Returns a boolean value as a NSNumber, or nil if this cannot be determined.
//
// Returns true if a firmware update is available for the connected pen. This determination can
// only be made once the softwareRevision and firmwareRevision properties of the device info
// service have been initialized.
//
// If a firmware update is available, the value of the currentVersion and updateVersion
// parameters are updated.
- (NSNumber *)isFirmwareUpdateAvailable:(NSInteger *)currentVersion
                          updateVersion:(NSInteger *)updateVersion;
- (BOOL)updateFirmware;
- (BOOL)updateFirmware:(NSString *)firmwareImagePath;
- (void)cancelFirmwareUpdate;

// Returns a boolean value as a NSNumber, or nil if this cannot be determined.
//
// Returns true iff a pencil is connected, its model number is known and it is an aluminum
// pencil.
- (NSNumber *)isAluminumPencil;

- (void)startTrialSeparation;

@end
