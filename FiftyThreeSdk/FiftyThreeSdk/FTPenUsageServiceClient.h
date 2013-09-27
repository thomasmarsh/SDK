//
//  FTPenUsageServiceClient.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import "FTPen+Private.h"
#import "FTServiceClient.h"

@protocol FTPenUsageServiceClientDelegate <NSObject>

- (void)didReadManufacturingID:(NSString *)manufacturingID;
- (void)didWriteManufacturingID;
- (void)didFailToWriteManufacturingID;
- (void)didUpdateUsageProperties:(NSSet *)updatedProperties;

@end

@interface FTPenUsageServiceClient : FTServiceClient

@property (nonatomic, weak) id<FTPenUsageServiceClientDelegate> delegate;

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

- (void)readUsageProperties;

@end
