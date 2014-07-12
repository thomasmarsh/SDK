//
//  FTLog.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, FTLogLevel)
{
    FTLogLevelDisabled = 0,
    FTLogLevelEnabled,
    FTLogLevelEnabledVerbose
};

// This is used by the FiftyThreeSdk for logging connection related states and errors.
@interface FTLog : NSObject
// This defaults to FTLogLevelDisabled
+ (FTLogLevel)logLevel;
+ (void)setLogLevel:(FTLogLevel)logLevel;

@end
