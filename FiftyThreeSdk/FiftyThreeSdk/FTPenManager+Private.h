//
//  FTPenManager+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

#import "FTPenManager.h"

@interface FTPenManager ()

- (BOOL)isFirmwareUpdateAvailable;
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
