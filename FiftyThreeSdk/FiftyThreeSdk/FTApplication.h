//
//  FTApplication.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <UIKit/UIKit.h>

#ifdef __cplusplus
#import <boost/optional/optional.hpp>

#import "Common/Touch/TouchClassifier.h"

#endif

@interface FTApplication : UIApplication

#ifdef __cplusplus

// Optionally, let a subclass inject a classifier into the touch processing pipeline.
- (fiftythree::common::TouchClassifier::Ptr)createClassifier;

@property (nonatomic, readonly)boost::optional<fiftythree::common::TouchClassifier::Ptr> classifier;

#endif

@end
