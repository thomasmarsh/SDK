//
//  FTLog.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, FTLogLevel)
{
    FTLogLevelDisabled = 0,
    FTLogLevelEnabled,
    FTLogLevelEnabledVerbose
};

@interface FTLog : NSObject

+ (FTLogLevel)logLevel;
+ (void)setLogLevel:(FTLogLevel)logLevel;

+ (void)log:(NSString *)string;
+ (void)logWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);
+ (void)logVerboseWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

@end
