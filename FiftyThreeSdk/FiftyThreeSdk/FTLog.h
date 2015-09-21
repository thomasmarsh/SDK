/*
    FTLog.h
    FiftyThreeSdk
 
    Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
    Use of this code is subject to the terms of the FiftyThree SDK License Agreement, included with this SDK as the file "FiftyThreeSDK-License.txt"
 */

#pragma once

// clang-format off

#import <Foundation/Foundation.h>

/*!
 @brief  Log level Enum. By default, disabled.
 
 @constant FTLogLevelDisabled
 @constant FTLogLevelEnabled
 @constant FTLogLevelEnabledVerbose
 */
typedef NS_ENUM(NSInteger, FTLogLevel){
    
    FTLogLevelDisabled = 0,
    FTLogLevelEnabled,
    FTLogLevelEnabledVerbose
};

/*!
 @brief  This is used by the FiftyThreeSdk for logging connection-related states and errors.
 */
@interface FTLog : NSObject
/*!
 @brief  This defaults to FTLogLevelDisabled
 
 @return Log level
 */
+ (FTLogLevel)logLevel;
/*!
 @brief  Sets log level. Default is FTLogLevelDisabled.
 
 @param logLevel Log level
 */
+ (void)setLogLevel:(FTLogLevel)logLevel;

@end
// clang-format on
