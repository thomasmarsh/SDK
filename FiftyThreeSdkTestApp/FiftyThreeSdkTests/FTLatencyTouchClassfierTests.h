//
//  FTLatencyTouchClassfierTests.h
//  FiftyThreeSdkTestApp
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <SenTestingKit/SenTestingKit.h>

#import "FiftyThreeSdk/LatencyTouchClassifier.h"

@interface FTLatencyTouchClassfierTests : SenTestCase {
    fiftythree::sdk::LatencyTouchClassifier::Ptr _Classifier;
}

@end
