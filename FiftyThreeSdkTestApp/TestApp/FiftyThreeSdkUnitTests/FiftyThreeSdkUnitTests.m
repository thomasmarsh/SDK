//
//  FiftyThreeSdkUnitTests.m
//  FiftyThreeSdkUnitTests
//
//  Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
//


#import <XCTest/XCTest.h>
#import "FiftyThreeSdk/FiftyThreeSdk.h"

@interface FiftyThreeSdkUnitTests : XCTestCase

@end

@implementation FiftyThreeSdkUnitTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}


/*
  Sanity test to ensure we can create a penManager.
 */
- (void)testCreatePenManager {
    [self measureBlock:^{
        FTPenManager* sharedPenManager = [FTPenManager sharedInstance];
        XCTAssertNotNil(sharedPenManager);
    }];
}

@end
