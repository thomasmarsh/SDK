//
//  FTPen+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import "FTPen.h"

@interface FTPenLastErrorCode : NSObject
@property (nonatomic) int lastErrorID;
@property (nonatomic) int lastErrorValue;
@end

extern NSString * const kFTPenDidUpdatePrivatePropertiesNotificationName;
extern NSString * const kFTPenDidWriteHasListenerNotificationName;

extern NSString * const kFTPenNumTipPressesPropertyName;
extern NSString * const kFTPenNumEraserPressesPropertyName;
extern NSString * const kFTPenNumFailedConnectionsPropertyName;
extern NSString * const kFTPenNumSuccessfulConnectionsPropertyName;
extern NSString * const kFTPenNumResetsPropertyName;
extern NSString * const kFTPenNumLinkTerminationsPropertyName;
extern NSString * const kFTPenNumDroppedNotificationsPropertyName;
extern NSString * const kFTPenConnectedSecondsPropertyName;

extern NSString * const kFTPenManufacturingIDPropertyName;
extern NSString * const kFTPenLastErrorCodePropertyName;

@class CBCentralManager;
@class CBPeripheral;

@protocol FTPenPrivateDelegate <NSObject>

@optional
- (void)pen:(FTPen *)pen isReadyDidChange:(BOOL)isReady;
- (void)didWriteManufacturingID;
- (void)didFailToWriteManufacturingID;
- (void)didReadManufacturingID:(NSString *)manufacturingID;
- (void)didUpdateUsageProperties:(NSSet *)updatedProperties;

@end

@interface FTPen ()

@property (nonatomic, weak) id<FTPenPrivateDelegate> privateDelegate;
@property (nonatomic, readonly) CBPeripheral *peripheral;

@property (nonatomic) BOOL hasListener;
@property (nonatomic) NSString *manufacturingID;
@property (nonatomic, readonly) FTPenLastErrorCode *lastErrorCode;

@property (nonatomic, readonly) BOOL isReady;
@property (nonatomic, readonly) BOOL isPoweringOff;
@property (nonatomic) BOOL requiresTipBePressedToBecomeReady;

// Usage Properties
@property (nonatomic, readonly) NSUInteger numTipPresses;
@property (nonatomic, readonly) NSUInteger numEraserPresses;
@property (nonatomic, readonly) NSUInteger numFailedConnections;
@property (nonatomic, readonly) NSUInteger numSuccessfulConnections;
@property (nonatomic, readonly) NSUInteger numResets;
@property (nonatomic, readonly) NSUInteger numLinkTerminations;
@property (nonatomic, readonly) NSUInteger numDroppedNotifications;
@property (nonatomic, readonly) NSUInteger connectedSeconds;

- (id)initWithCentralManager:(CBCentralManager *)centralManager
                  peripheral:(CBPeripheral *)peripheral;

- (void)peripheralConnectionStatusDidChange;

- (void)startSwinging;

- (void)powerOff;

- (void)readManufacturingID;

- (void)clearLastErrorCode;

- (void)readUsageProperties;

// Clears the current firmwareRevision and softwareRevision values and requests a read of them
// from the peripheral.
- (void)refreshFirmwareVersionProperties;

@end
