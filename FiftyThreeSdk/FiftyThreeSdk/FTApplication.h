//
//  FTApplication.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <UIKit/UIKit.h>

#ifdef __cplusplus

#import "Common/Touch/TouchClassifier.h"

@interface FTApplication : UIApplication

// Optionally, let a subclass inject a classifier into touch processing pipeline.
- (fiftythree::common::TouchClassifier::Ptr)createClassifier;

@end
#endif
