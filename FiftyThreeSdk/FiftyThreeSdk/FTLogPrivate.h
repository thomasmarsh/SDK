//
//  FTLogPrivate.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "FTLog.h"

typedef NS_ENUM(NSInteger, FTLogModule) {
    FTLogSDK = 0x56878,
    FTLogSDKVerbose
};

#ifdef __cplusplus
#import <string>

// This macro is useful for converting an NSObject to a C-string for use in a %s field in a logging format
// string.
#define DESC(x) (DescriptionString(x).c_str())
extern std::string DescriptionString(NSObject *object);
#endif
