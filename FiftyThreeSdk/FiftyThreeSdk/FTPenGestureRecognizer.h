//
//  FTPenGestureRecognizer.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

#include "TouchClassifierManager.h"

@class FTPenManager;

@interface FTPenGestureRecognizer : UIGestureRecognizer

@property (nonatomic) fiftythree::sdk::TouchClassifierManager::Ptr classifierManager;

- (id)initWithTouchClassifierManager:(fiftythree::sdk::TouchClassifierManager::Ptr)classifierManager penManager:(FTPenManager *)penManager;
- (id)init __unavailable;

@end
