//
//  FTPenDebugServiceClient.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import "FTServiceClient.h"

@protocol FTPenDebugServiceClientDelegate <NSObject>

- (void)didWriteManufacturingID;
- (void)didFailToWriteManufacturingID;
- (void)didReadManufacturingID:(NSString *)manufacturingID;

@end

@interface FTPenDebugServiceClient : FTServiceClient

@property (nonatomic, weak) id<FTPenDebugServiceClientDelegate> delegate;

- (id)initWithPeripheral:(CBPeripheral *)peripheral;

- (void)getManufacturingID;
- (void)setManufacturingID:(NSString *)manufacturingID;

@end
