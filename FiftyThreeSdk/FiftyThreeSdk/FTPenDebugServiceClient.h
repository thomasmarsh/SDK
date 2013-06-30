//
//  FTPenDebugServiceClient.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTServiceClient.h"

@protocol FTPenDebugServiceClientDelegate <NSObject>

@end

@interface FTPenDebugServiceClient : FTServiceClient

@property (nonatomic, weak) id<FTPenDebugServiceClientDelegate> delegate;

@end
