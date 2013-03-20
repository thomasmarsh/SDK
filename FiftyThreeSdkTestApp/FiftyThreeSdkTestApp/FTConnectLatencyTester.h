//
//  FTConnectLatencyTester.h
//  charcoal-prototype
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FiftyThreeSdk/FTPenManager.h"

@interface FTConnectLatencyTester : NSObject <FTPenManagerDelegate>

- (id)initWithPenManager:(FTPenManager *)penManager;
- (void)startTest:(void(^)(NSError *error))complete;

@end
