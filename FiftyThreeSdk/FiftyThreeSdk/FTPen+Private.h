//
//  FTPen+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import "FTPen.h"

typedef struct FTPenLastErrorCode
{
    int lastErrorID;
    int lastErrorValue;
} FTPenLastErrorCode;

@class CBCentralManager;
@class CBPeripheral;

@protocol FTPenPrivateDelegate <NSObject>

- (void)didWriteManufacturingID;
- (void)didFailToWriteManufacturingID;
- (void)didReadManufacturingID:(NSString *)manufacturingID;
- (void)didUpdateDeviceInfo;
- (void)didUpdateDebugProperties;

@end

@interface FTPen ()

@property (nonatomic, weak) id<FTPenPrivateDelegate> privateDelegate;
@property (nonatomic, readonly) CBPeripheral *peripheral;
@property (nonatomic, readonly) BOOL isPoweringOff;
@property (nonatomic) BOOL requiresTipBePressedToBecomeReady;

// Debug Properties
@property (nonatomic, readonly) FTPenLastErrorCode lastErrorCode;

- (id)initWithCentralManager:(CBCentralManager *)centralManager
                  peripheral:(CBPeripheral *)peripheral;

- (void)peripheralConnectionStatusDidChange;

- (void)startSwinging;

- (void)powerOff;

// Gets the Manufacturing ID, which is the combination of the SKU and SN.
- (void)getManufacturingID;

// Sets the Manufacturing ID, which is the combination of the SKU and SN. This is to be used only in the
// manufacturing process, and may only be called once.
- (void)setManufacturingID:(NSString *)manufacturingID;

- (void)clearLastErrorCode;

@end
