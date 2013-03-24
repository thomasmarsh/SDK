//
//  FTPenTouchManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "FTPen.h"

@class FTPenManager;

@interface FTPenTouchManager : NSObject<FTPenDelegate>

- (id)init __unavailable;
- (id)initWithPenManager:(FTPenManager *)penManager;
- (void)registerView:(UIView *)view;
- (void)deregisterView:(UIView *)view;

@end
