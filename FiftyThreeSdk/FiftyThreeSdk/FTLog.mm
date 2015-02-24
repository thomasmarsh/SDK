//
//  FTLog.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import "Core/Log.h"
#import "FTLog.h"
#import "FTLogPrivate.h"

using namespace fiftythree::core;

namespace
{
static FTLogLevel sLogLevel;

// Initialize the log level to disabled at static initialization time.
struct LogLevelInitializer {
    LogLevelInitializer()
    {
        [FTLog setLogLevel:FTLogLevelDisabled];
    }
};
static LogLevelInitializer sInitializer;
}

@implementation FTLog

+ (FTLogLevel)logLevel
{
    return sLogLevel;
}

+ (void)setLogLevel:(FTLogLevel)logLevel
{
    sLogLevel = logLevel;

#ifdef USE_LOGGING
    SET_LOG_MODULE_SEVERITY(FTLogSDK, kFTLogSeverityInfo);
    SET_LOG_MODULE_SEVERITY(FTLogSDKVerbose, kFTLogSeverityInfo);
    SET_LOG_MODULE_SEVERITY(FTLogSDKClassificationLinker, kFTLogSeverityInfo);

    switch (sLogLevel) {
        case FTLogLevelEnabled:
            SET_LOG_MODULE_SEVERITY(FTLogSDKVerbose, kFTLogSeverityOff);
            SET_LOG_MODULE_SEVERITY(FTLogSDKClassificationLinker, kFTLogSeverityOff);
            break;
        case FTLogLevelEnabledVerbose:
            break;
        case FTLogLevelDisabled:
        default:
            SET_LOG_MODULE_SEVERITY(FTLogSDK, kFTLogSeverityOff);
            SET_LOG_MODULE_SEVERITY(FTLogSDKVerbose, kFTLogSeverityOff);
            SET_LOG_MODULE_SEVERITY(FTLogSDKClassificationLinker, kFTLogSeverityOff);
            break;
    }
#endif
}

@end
