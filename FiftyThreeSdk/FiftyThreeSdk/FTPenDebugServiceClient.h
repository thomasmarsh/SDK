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

- (void)didWriteManufacturingID;
- (void)didFailToWriteManufacturingID;
- (void)didReadManufacturingID:(NSString *)manufacturingID;
- (void)didUpdateDebugProperties;

@end

@interface FTPenDebugServiceClient : FTServiceClient

@property (nonatomic, weak) id<FTPenDebugServiceClientDelegate> delegate;

// Debug Properties
@property (nonatomic, readonly) FTPenLastErrorCode lastErrorCode;

- (id)initWithPeripheral:(CBPeripheral *)peripheral;

- (void)getManufacturingID;
- (void)setManufacturingID:(NSString *)manufacturingID;

- (void)clearLastErrorCode;

@end
