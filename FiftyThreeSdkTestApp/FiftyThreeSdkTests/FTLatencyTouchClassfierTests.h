//
//  FTLatencyTouchClassfierTests.h
//  FiftyThreeSdkTestApp
//
//  Created by Adam on 3/28/13.
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "LatencyTouchClassifier.h"

@interface FTLatencyTouchClassfierTests : SenTestCase
{
    fiftythree::sdk::LatencyTouchClassifier::Ptr _Classifier;
}

@end
