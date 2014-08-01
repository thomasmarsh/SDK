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
    struct LogLevelInitializer
    {
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
    LogService::Instance()->RemoveFilter(FTLogSDK);
    LogService::Instance()->RemoveFilter(FTLogSDKVerbose);
    LogService::Instance()->RemoveFilter(FTLogSDKClassificationLinker);

    switch (sLogLevel)
    {
        case FTLogLevelEnabled:
            LogService::Instance()->AddFilter(FTLogSDKVerbose);
            break;
        case FTLogLevelEnabledVerbose:
            break;
        case FTLogLevelDisabled:
        default:
            LogService::Instance()->AddFilter(FTLogSDK);
            LogService::Instance()->AddFilter(FTLogSDKVerbose);
            LogService::Instance()->AddFilter(FTLogSDKClassificationLinker);
            break;
    }
#endif
}

@end
