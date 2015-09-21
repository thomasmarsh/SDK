/*
    FTSDKVersionInfo.h
    FiftyThreeSdk
 
    Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
    Use of this code is subject to the terms of the FiftyThree SDK License Agreement, included with this SDK as the file "FiftyThreeSDK-License.txt"
 */

#pragma once

// clang-format off

#import <Foundation/Foundation.h>

/*!
 @brief  Describes the version of the SDK.
 */
@interface FTSDKVersionInfo : NSObject
@property (nonatomic, readonly) NSString *version;
@property (nonatomic, readonly) NSInteger majorVersion;
@property (nonatomic, readonly) NSInteger minorVersion;
@property (nonatomic, readonly) NSInteger patchVersion;
@property (nonatomic, readonly) NSString *commit;
@property (nonatomic, readonly) NSString *timestamp;
@end
// clang-format on
