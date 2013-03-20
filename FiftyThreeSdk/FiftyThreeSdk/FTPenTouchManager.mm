//
//  FTPenTouchManager.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTPenTouchManager.h"
#import "FTPenGestureRecognizer.h"

#include "TouchClassifierManager.h"

@interface FTPenTouchManager ()

@end

@implementation FTPenTouchManager

- (void)registerView:(UIView *)view
{
    [view addGestureRecognizer:[[FTPenGestureRecognizer alloc] initWithTouchClassifierManager:fiftythree::sdk::TouchClassifierManager::New()]];
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
