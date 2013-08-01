//
//  FTPenManager+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

#import "FTPenManager.h"

typedef NS_ENUM(NSInteger, FTFirmwareImageType) {
    Factory,
    Upgrade
};

@interface FTPenManager ()

- (BOOL)isUpdateAvailableForPen:(FTPen *)pen;

- (void)updateFirmwareForPen:(FTPen *)pen;

- (void)startTrialSeparation;

@end

@protocol FTPenManagerDelegatePrivate <FTPenManagerDelegate>

@optional

- (void)penManager:(FTPenManager *)manager didFinishUpdate:(NSError *)error;
- (void)penManager:(FTPenManager *)manager didUpdatePercentComplete:(float)percent;

@end
