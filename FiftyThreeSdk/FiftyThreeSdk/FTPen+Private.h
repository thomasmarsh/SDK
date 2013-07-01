//
//  FTPen+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTPen.h"

@class CBCentralManager;
@class CBPeripheral;

@interface FTPen ()

@property (nonatomic) CBPeripheral *peripheral;

@property (nonatomic) BOOL shouldSwing;
@property (nonatomic) BOOL shouldPowerOff;

- (id)initWithCentralManager:(CBCentralManager *)centralManager
                  peripheral:(CBPeripheral *)peripheral;

- (void)peripheralConnectionStatusDidChange;

- (void)updateData:(NSDictionary *)data;

@end
