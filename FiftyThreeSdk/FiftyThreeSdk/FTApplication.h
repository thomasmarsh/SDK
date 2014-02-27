//
//  FTApplication.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <UIKit/UIKit.h>

#ifdef __cplusplus
#import <boost/optional/optional.hpp>

#import "FiftyThreeSdk/TouchClassifier.h"

#endif

@interface FTApplication : UIApplication

#ifdef __cplusplus

@property (nonatomic, readonly) fiftythree::sdk::TouchClassifier::Ptr classifier;

// Optionally, let a subclass inject a classifier into the touch processing pipeline.
- (fiftythree::sdk::TouchClassifier::Ptr)createClassifier;

#endif

@end
