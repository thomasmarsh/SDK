//
//  FTPenUsageServiceClient.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import "FTPen+Private.h"
#import "FTServiceClient.h"

@protocol FTPenUsageServiceClientDelegate <NSObject>

- (void)didUpdateUsageProperties:(NSSet *)updatedProperties;

@end

@interface FTPenUsageServiceClient : FTServiceClient

@property (nonatomic, weak) id<FTPenUsageServiceClientDelegate> delegate;

// Debug Properties
@property (nonatomic, readonly) NSUInteger numTipPresses;
@property (nonatomic, readonly) NSUInteger numEraserPresses;
@property (nonatomic, readonly) NSUInteger numFailedConnections;
@property (nonatomic, readonly) NSUInteger numSuccessfulConnections;
@property (nonatomic, readonly) NSUInteger numResets;
@property (nonatomic, readonly) NSUInteger numLinkTerminations;
@property (nonatomic, readonly) NSUInteger numDroppedNotifications;
@property (nonatomic, readonly) NSUInteger connectedSeconds;

- (id)initWithPeripheral:(CBPeripheral *)peripheral;

- (void)readUsageProperties;

@end
