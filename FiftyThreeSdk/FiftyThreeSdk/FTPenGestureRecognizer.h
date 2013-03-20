//
//  FTPenGestureRecognizer.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

#include "TouchClassifierManager.h"

@interface FTPenGestureRecognizer : UIGestureRecognizer

- (id)initWithTouchClassifierManager:(fiftythree::sdk::TouchClassifierManager::Ptr)manager;
- (id)init __unavailable;

@end
