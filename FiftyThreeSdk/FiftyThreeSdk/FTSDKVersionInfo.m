//
//  FTSDKVersionInfo.m
//  FiftyThreeSdk
//
//  Created by Peter Sibley on 3/10/14.
//  Copyright (c) 2014 FiftyThree. All rights reserved.
//

#import "FTSDKVersionInfo.h"

@implementation FTSDKVersionInfo
- (NSString *) version
{
    return [NSString stringWithFormat:@"%ld.%ld",(long)self.majorVersion,(long)self.minorVersion];
}
- (NSInteger) majorVersion
{
    return 0;
}
- (NSInteger) minorVersion
{
    return 5;
}
- (NSString *) commit
{
    return @"";
}

- (NSString *) timestamp
{
    return @"";
}
@end
