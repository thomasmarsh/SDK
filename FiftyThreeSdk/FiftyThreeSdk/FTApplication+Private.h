//
//  FTApplication+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#ifdef __cplusplus
#import "FiftyThreeSdk/TouchClassifier.h"
#endif

#import "FiftythreeSdk/FTApplication.h"

@interface FTApplication (Private)

- (void)clearClassifierAndPenState;
- (void)ensureClassifierConfigured;

#ifdef __cplusplus
@property (nonatomic) fiftythree::sdk::TouchClassifier::Ptr classifier;
// Optionally, let a subclass inject a classifier into the touch processing pipeline.
- (fiftythree::sdk::TouchClassifier::Ptr)createClassifier;

#endif

@end
