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

@interface FTPen ()

@property (nonatomic) CBPeripheral *peripheral;
@property (nonatomic) BOOL requiresTipBePressedToBecomeReady;
@property (nonatomic, readonly) BOOL isPoweringOff;

- (id)initWithCentralManager:(CBCentralManager *)centralManager
                  peripheral:(CBPeripheral *)peripheral;

- (void)peripheralConnectionStatusDidChange;

- (void)updateData:(NSDictionary *)data;

- (void)startSwinging;
- (void)powerOff;

@end
