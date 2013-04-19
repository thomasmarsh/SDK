//
//  SenAsyncTestCase.h
//  FiftyThreeSdkTestApp
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

enum {
    SenAsyncTestCaseStatusUnknown = 0,
    SenAsyncTestCaseStatusWaiting,
    SenAsyncTestCaseStatusSucceeded,
    SenAsyncTestCaseStatusFailed,
    SenAsyncTestCaseStatusCancelled,
};
typedef NSUInteger SenAsyncTestCaseStatus;

@interface SenAsyncTestCase : SenTestCase

- (void)waitForStatus:(SenAsyncTestCaseStatus)status timeout:(NSTimeInterval)timeout;
- (void)waitForTimeout:(NSTimeInterval)timeout;
- (void)notify:(SenAsyncTestCaseStatus)status;

@end
