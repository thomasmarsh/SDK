//
//  FTLog.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import "Common/Log.h"
#import "FTLogPrivate.h"

using namespace fiftythree::common;

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

std::string DescriptionString(NSObject *object)
{
    NSString *description = object.description;
    return description ? std::string(description.UTF8String).c_str() : "";
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
            break;
    }
#endif
}

@end
