//
//  FTTouchTests.m
//  FiftyThreeSdkTestApp
//
//  Created by Adam on 4/1/13.
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTTouchTests.h"
#include "Common/TouchManager.h"
#include "Common/RandomNumberGenerator.h"
#include "FiftyThreeSdk/PenEvent.h"

using namespace fiftythree::common;
using namespace fiftythree::sdk;

@implementation FTTouchTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testTouchSerialization
{
    Touch::Ptr t = Touch::New();
    t->Phase = TouchPhase::Began;
    t->Id = (void *)12345678;

    InputSample s(12.34567, 89.01234, 123.4567);
    t->Sample = s;
    
    std::string outputString = t->ToString();
//    std::cout << outputString << std::endl;
    
    Touch::Ptr t2 = Touch::FromString(outputString);
    
    STAssertTrue(*t == *t2, @"Deserialized form does not match");
}

- (void)testTouchRandomSerialization
{
    RandomNumberGenerator rng;

    Touch::Ptr t1;
    Touch::Ptr t2;
    for (int i = 0; i < 1000; i++)
    {
        Touch::Ptr t1 = Touch::New();
        t1->Phase = TouchPhase((TouchPhase::TouchPhaseEnum)rng.RandomIntInRange(TouchPhase::Began, TouchPhase::Unknown));
        t1->Id = (void *)rng.RandomIntInRange(0, std::numeric_limits<int>::max());
    
        InputSample s(
                      rng.Random() * std::numeric_limits<float>::max(),
                      rng.Random() * std::numeric_limits<float>::max(),
                      rng.Random() * std::numeric_limits<float>::max()
                      );
        t1->Sample = s;
    
        std::string outputString = t1->ToString();
//        std::cout << outputString << std::endl;

        Touch::Ptr t2 = Touch::FromString(outputString);
    
        STAssertTrue(*t1 == *t2, @"Deserialized form does not match");
    }
}

- (void)testPenEventRandomSerialization
{
    RandomNumberGenerator rng;
    
    PenEvent::Ptr e1;
    PenEvent::Ptr e2;
    for (int i = 0; i < 1000; i++)
    {
                
        InputSample s(
                      rng.Random() * std::numeric_limits<float>::max(),
                      rng.Random() * std::numeric_limits<float>::max(),
                      rng.Random() * std::numeric_limits<float>::max()
                      );
        
        PenEvent::Ptr e1 = PenEvent::New(s,
                                         PenEventType((PenEventType::PenEventTypeEnum)rng.RandomIntInRange(PenEventType::PenUp, PenEventType::PenDown)),
                                         PenTip((PenTip::PenTipEnum)rng.RandomIntInRange(PenTip::Tip1, PenTip::Tip2))
                                         );
        
        std::string outputString = e1->ToString();
        //        std::cout << outputString << std::endl;
        
        PenEvent::Ptr e2 = PenEvent::FromString(outputString);
        
        STAssertTrue(*e1 == *e2, @"Deserialized form does not match");
    }
}

@end
