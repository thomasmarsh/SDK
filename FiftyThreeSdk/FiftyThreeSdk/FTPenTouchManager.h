//
//  FTPenTouchManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "FTPen.h"

@interface FTPenTouchManager : NSObject<FTPenDelegate>

- (void)registerView:(UIView *)view;
- (void)deregisterView:(UIView *)view;

@end
