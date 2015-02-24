//
//  Helpers.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import "FiftyThreeSdk/Classification/Helpers.h"
#import "FiftyThreeSdk/Classification/HelpersObjC.h"

@implementation Helpers

+ (double)NSProcessInfoSystemUptime;
{
    return [NSProcessInfo processInfo].systemUptime;
}

@end

namespace fiftythree
{
namespace sdk
{
double NSProcessInfoSystemUptime()
{
    return [Helpers NSProcessInfoSystemUptime];
}
}
}
