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

extern NSString * const kFTPenDidUpdateUsagePropertiesNotificationName;

@class CBCentralManager;
@class CBPeripheral;

@protocol FTPenPrivateDelegate <NSObject>

- (void)didWriteManufacturingID;
- (void)didFailToWriteManufacturingID;
- (void)didReadManufacturingID:(NSString *)manufacturingID;
- (void)didUpdateUsageProperty;

@end

@interface FTPen ()

@property (nonatomic, weak) id<FTPenPrivateDelegate> privateDelegate;
@property (nonatomic, readonly) CBPeripheral *peripheral;
@property (nonatomic, readonly) BOOL isPoweringOff;
@property (nonatomic) BOOL requiresTipBePressedToBecomeReady;

// Usage Properties
@property (nonatomic, readonly) NSUInteger numTipPresses;
@property (nonatomic, readonly) NSUInteger numEraserPresses;
@property (nonatomic, readonly) NSUInteger numFailedConnections;
@property (nonatomic, readonly) NSUInteger numSuccessfulConnections;
@property (nonatomic, readonly) NSUInteger totalOnTimeSeconds;
@property (nonatomic) NSString *manufacturingID;
@property (nonatomic, readonly) FTPenLastErrorCode lastErrorCode;
@property (nonatomic) NSUInteger longPressTimeMilliseconds;
@property (nonatomic) NSUInteger connectionTimeSeconds;

- (id)initWithCentralManager:(CBCentralManager *)centralManager
                  peripheral:(CBPeripheral *)peripheral;

- (void)peripheralConnectionStatusDidChange;

- (void)startSwinging;

- (void)powerOff;

- (void)clearLastErrorCode;

- (void)readUsageProperties;

// Clears the current firmwareRevision and softwareRevision values and requests a read of them
// from the peripheral.
- (void)refreshFirmwareVersionProperties;

@end
