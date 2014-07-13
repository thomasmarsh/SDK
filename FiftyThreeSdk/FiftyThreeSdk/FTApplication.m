//
//  FTApplication.m
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//
#import <UIKit/UIKit.h>

#import "FiftyThreeSdk/FTApplication.h"
#import "FiftyThreeSdk/FTEventDispatcher.h"

@implementation FTApplication

#pragma mark - Event Dispatch

- (void)sendEvent:(UIEvent *)event
{
    [[FTEventDispatcher sharedInstance] sendEvent:event];

    [super sendEvent:event];
}
@end
