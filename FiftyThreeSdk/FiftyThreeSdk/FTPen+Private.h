//
//  FTPen+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import "FTPen.h"

@class CBCentralManager;
@class CBPeripheral;

@protocol FTPenPrivateDelegate <NSObject>

- (void)didWriteManufacturingID;
- (void)didFailToWriteManufacturingID;
- (void)didReadManufacturingID:(NSString *)manufacturingID;

@end

@interface FTPen ()

@property (nonatomic, weak) id<FTPenPrivateDelegate> privateDelegate;
@property (nonatomic) CBPeripheral *peripheral;
@property (nonatomic) BOOL requiresTipBePressedToBecomeReady;
@property (nonatomic, readonly) BOOL isPoweringOff;

- (id)initWithCentralManager:(CBCentralManager *)centralManager
                  peripheral:(CBPeripheral *)peripheral;

- (void)peripheralConnectionStatusDidChange;

- (void)updateData:(NSDictionary *)data;

- (void)startSwinging;
- (void)powerOff;

// Gets the Manufacturing ID, which is the combination of the SKU and SN.
- (void)getManufacturingID;

// Sets the Manufacturing ID, which is the combination of the SKU and SN. This is to be used only in the
// manufacturing process, and may only be called once.
- (void)setManufacturingID:(NSString *)manufacturingID;

@end
