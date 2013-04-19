//
//  FTLatencyTouchClassfierTests.h
//  FiftyThreeSdkTestApp
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "FiftyThreeSdk/LatencyTouchClassifier.h"

@interface FTLatencyTouchClassfierTests : SenTestCase
{
    fiftythree::sdk::LatencyTouchClassifier::Ptr _Classifier;
}

@end
