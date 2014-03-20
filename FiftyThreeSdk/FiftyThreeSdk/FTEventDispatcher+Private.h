//
//  FTEventDispatcher+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#ifdef __cplusplus
#import "FiftyThreeSdk/TouchClassifier.h"

#endif

#import "FiftythreeSdk/FTEventDispatcher.h"

@interface FTEventDispatcher (Private)

- (void)clearClassifierAndPenState;
- (void)ensureClassifierConfigured;

#ifdef __cplusplus
@property (nonatomic) fiftythree::sdk::TouchClassifier::Ptr classifier;
#endif

@end
