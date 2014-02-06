//
//  Helpers.m
//  Classification
//
//  Created by matt on 10/10/13.
//  Copyright (c) 2013 Peter Sibley. All rights reserved.
//

#import "Helpers.h"
#import "HelpersObjC.h"

@implementation Helpers


+(double) NSProcessInfoSystemUptime;
{
    return [NSProcessInfo processInfo].systemUptime;
}


@end


double NSProcessInfoSystemUptime()
{
    return [Helpers NSProcessInfoSystemUptime];
}


