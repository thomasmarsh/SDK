//
//  FTLatencyTouchClassfierTests.m
//  FiftyThreeSdkTestApp
//
//  Created by Adam on 3/28/13.
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTLatencyTouchClassfierTests.h"

using namespace fiftythree::sdk;

@implementation FTLatencyTouchClassfierTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
    
    _Classifier = LatencyTouchClassifier::New();
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testTouchOnly
{    
}

@end
