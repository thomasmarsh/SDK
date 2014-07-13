//
//  FTEventDispatcher+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#ifdef __cplusplus
#import "Common/Touch/TouchClassifier.h"

#endif

#import "FiftythreeSdk/FTEventDispatcher.h"

@interface FTEventDispatcher (Private)

- (void)clearClassifierAndPenState;
- (void)ensureClassifierConfigured;

#ifdef __cplusplus
@property (nonatomic) fiftythree::common::TouchClassifier::Ptr classifier;
#endif

@end
