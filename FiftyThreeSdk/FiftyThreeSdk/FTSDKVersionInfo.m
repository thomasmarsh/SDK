//
//  FTSDKVersionInfo.m
//  FiftyThreeSdk
//
//  Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
//

#import "FTSDKVersionInfo.h"

// clang-format off
@implementation FTSDKVersionInfo
- (NSString *)version
{
    return [NSString stringWithFormat:@"%ld.%ld.%ld",(long)self.majorVersion,(long)self.minorVersion,(long)self.patchVersion];
}
- (NSInteger)majorVersion
{
    return 1;
}
- (NSInteger)minorVersion
{
    return 0;
}
- (NSInteger)patchVersion
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
// clang-format on
