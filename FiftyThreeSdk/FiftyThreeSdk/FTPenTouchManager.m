//
//  FTPenTouchManager.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTPenTouchManager.h"
#import "FTPenGestureRecognizer.h"

@interface FTPenTouchManager ()

@end

@implementation FTPenTouchManager

- (id)init
{
    self = [super init];
    if (self)
    {

    }
    return self;
}

- (void)registerView:(UIView *)view
{
    [view addGestureRecognizer:[[FTPenGestureRecognizer alloc] init]];
}

- (void)deregisterView:(UIView *)view
{
    for (UIGestureRecognizer *rec in view.gestureRecognizers)
    {
        if ([rec isKindOfClass:[FTPenGestureRecognizer class]])
        {
            [view removeGestureRecognizer:rec];
        }
    }
}

@end
