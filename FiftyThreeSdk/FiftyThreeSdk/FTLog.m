//
//  FTLog.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTLog.h"

#if defined(DEBUG) || defined(PREVIEW_BUILD) || defined(INTERNAL_BUILD)
static FTLogLevel sLogLevel = FTLogLevelEnabled;
#else
static FTLogLevel sLogLevel = FTLogLevelDisabled;
#endif

@implementation FTLog

+ (FTLogLevel)logLevel
{
    return sLogLevel;
}

+ (void)setLogLevel:(FTLogLevel)logLevel
{
    sLogLevel = logLevel;
}

+ (void)log:(NSString *)string
{
    if (FTLog.logLevel != FTLogLevelDisabled)
    {
        NSLog(@"%@", string);
    }
}

+ (void)logWithFormat:(NSString *)format, ...
{
    if (FTLog.logLevel != FTLogLevelDisabled)
    {
        va_list args;
        va_start(args, format);
        NSLogv(format, args);
        va_end(args);
    }
}

+ (void)logVerboseWithFormat:(NSString *)format, ...
{
    if (FTLog.logLevel == FTLogLevelEnabledVerbose)
    {
        va_list args;
        va_start(args, format);
        NSLogv(format, args);
        va_end(args);
    }
}

@end
