//
//  FTTouchTests.mm
//  FiftyThreeSdkTestApp
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include "Common/RandomNumberGenerator.h"
#include "Common/TouchManager.h"
#include "FiftyThreeSdk/PenEvent.h"

#import "FTTouchTests.h"

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
    Touch::Ptr t = Touch::New(
        12345678,
        TouchPhase::Began,
        InputSample(Eigen::Vector2f(12.34567, 89.01234), Eigen::Vector2f(12.34567, 89.01234), 123.4567));

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
    for (int i = 0; i < 1000; i++) {
        Touch::Ptr t1 = Touch::New(
            rng.RandomIntInRange(0, std::numeric_limits<int>::max()),
            TouchPhase((TouchPhase::TouchPhaseEnum)rng.RandomIntInRange(TouchPhase::Began, TouchPhase::Unknown)),
            InputSample(
                Eigen::Vector2f(rng.Random() * std::numeric_limits<float>::max(), rng.Random() * std::numeric_limits<float>::max()),
                Eigen::Vector2f(rng.Random() * std::numeric_limits<float>::max(), rng.Random() * std::numeric_limits<float>::max()),
                rng.Random() * std::numeric_limits<float>::max()));

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
    for (int i = 0; i < 1000; i++) {
        PenEvent::Ptr e1 = PenEvent::New(rng.Random() * std::numeric_limits<float>::max(),
                                         PenEventType((PenEventType::PenEventTypeEnum)rng.RandomIntInRange(PenEventType::PenUp, PenEventType::PenDown)),
                                         PenTip((PenTip::PenTipEnum)rng.RandomIntInRange(PenTip::Tip1, PenTip::Tip2)));

        std::string outputString = e1->ToString();
        //        std::cout << outputString << std::endl;

        PenEvent::Ptr e2 = PenEvent::FromString(outputString);

        STAssertTrue(*e1 == *e2, @"Deserialized form does not match");
    }
}

@end
