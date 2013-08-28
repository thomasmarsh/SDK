//
//  FTPenDebugServiceClient.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import "FTPen+Private.h"
#import "FTServiceClient.h"

@protocol FTPenDebugServiceClientDelegate <NSObject>

- (void)didReadManufacturingID:(NSString *)manufacturingID;
- (void)didWriteManufacturingID;
- (void)didFailToWriteManufacturingID;

- (void)didUpdateDebugProperties;

@end

@interface FTPenDebugServiceClient : FTServiceClient

@property (nonatomic, weak) id<FTPenDebugServiceClientDelegate> delegate;

// Debug Properties
@property (nonatomic, readonly) NSUInteger numTipPresses;
@property (nonatomic, readonly) NSUInteger numEraserPresses;
@property (nonatomic, readonly) NSUInteger numFailedConnections;
@property (nonatomic, readonly) NSUInteger numSuccessfulConnections;
@property (nonatomic, readonly) NSUInteger totalOnTimeSeconds;
@property (nonatomic) NSString *manufacturingID;
@property (nonatomic, readonly) FTPenLastErrorCode lastErrorCode;
@property (nonatomic) NSUInteger longPressTimeMilliseconds;
@property (nonatomic) NSUInteger connectionTimeSeconds;

- (id)initWithPeripheral:(CBPeripheral *)peripheral;

- (void)clearLastErrorCode;

- (void)readDebugProperties;

@end
