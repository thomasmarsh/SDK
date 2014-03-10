//
//  FTApplication+Private.h
//  FiftyThreeSdk
//
//  Created by Peter Sibley on 3/10/14.
//  Copyright (c) 2014 FiftyThree. All rights reserved.
//
#pragma once

#ifdef __cplusplus
#import <boost/optional/optional.hpp>
#import "FiftyThreeSdk/TouchClassifier.h"
#endif

#import "FiftythreeSdk/FTApplication.h"

@interface FTApplication (Private)

#ifdef __cplusplus

@property (nonatomic, readonly) fiftythree::sdk::TouchClassifier::Ptr classifier;

// Optionally, let a subclass inject a classifier into the touch processing pipeline.
- (fiftythree::sdk::TouchClassifier::Ptr)createClassifier;

#endif

@end


