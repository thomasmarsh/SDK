//
//  FTSDKVersionInfo.m
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import "FTSDKVersionInfo.h"

@implementation FTSDKVersionInfo
- (NSString *)version
{
    return [NSString stringWithFormat:@"%ld.%ld",(long)self.majorVersion,(long)self.minorVersion];
}
- (NSInteger)majorVersion
{
    return 1;
}
- (NSInteger)minorVersion
{
    return 0;
}
- (NSString *)commit
{
    return @"";
}

- (NSString *)timestamp
{
    return @"";
}
@end
