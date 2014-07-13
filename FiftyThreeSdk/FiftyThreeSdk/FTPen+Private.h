//
//  FTPen+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import "FTPen.h"

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
extern NSString * const kFTPenCentralIdPropertyName;

extern NSString * const kFTPenInactivityTimeoutPropertyName;
extern NSString * const kFTPenPressureSetupPropertyName;
extern NSString * const kFTPenManufacturingIDPropertyName;
extern NSString * const kFTPenLastErrorCodePropertyName;
extern NSString * const kFTPenAuthenticationCodePropertyName;
extern NSString * const kFTPenHasListenerPropertyName;

@class CBCentralManager;
@class CBPeripheral;

//
// FTPenPressureSetup
//
@interface FTPenPressureSetup : NSObject
@property (nonatomic, readonly) uint8_t samplePeriodMilliseconds;
@property (nonatomic, readonly) uint8_t notificatinPeriodMilliseconds;

@property (nonatomic, readonly) uint8_t tipFloorThreshold;
@property (nonatomic, readonly) uint8_t tipMinThreshold;
@property (nonatomic, readonly) uint8_t tipMaxThreshold;
@property (nonatomic, readonly) BOOL isTipGated;

@property (nonatomic, readonly) uint8_t eraserFloorThreshold;
@property (nonatomic, readonly) uint8_t eraserMinThreshold;
@property (nonatomic, readonly) uint8_t eraserMaxThreshold;
@property (nonatomic, readonly) BOOL isEraserGated;

- (id)init __unavailable;
- (id)initWithSamplePeriodMilliseconds:(uint8_t)samplePeriodMilliseconds
         notificatinPeriodMilliseconds:(uint8_t)notificatinPeriodMilliseconds
                     tipFloorThreshold:(uint8_t)tipFloorThreshold
                       tipMinThreshold:(uint8_t)tipMinThreshold
                       tipMaxThreshold:(uint8_t)tipMaxThreshold
                            isTipGated:(BOOL)isTipGated
                  eraserFloorThreshold:(uint8_t)eraserFloorThreshold
                    eraserMinThreshold:(uint8_t)eraserMinThreshold
                    eraserMaxThreshold:(uint8_t)eraserMaxThreshold
                         isEraserGated:(BOOL)isEraserGated;
- (id)initWithNSData:(NSData *)data;
- (void)writeToNSData:(NSData *)data;

@end

//
// FTPenLastErrorCode
//
@interface FTPenLastErrorCode : NSObject
- (id)init __unavailable;
- (id)initWithErrorID:(int)errorID andErrorValue:(int)errorValue;
@property (nonatomic, readonly) int lastErrorID;
@property (nonatomic, readonly) int lastErrorValue;
@end

//
// FTPenPrivateDelegate
//
@protocol FTPenPrivateDelegate <NSObject>

@optional

- (void)pen:(FTPen *)pen isReadyDidChange:(BOOL)isReady;

- (void)didWriteManufacturingID;
- (void)didFailToWriteManufacturingID;
- (void)didReadManufacturingID:(NSString *)manufacturingID;

- (void)didWriteAuthenticationCode;
- (void)didFailToWriteAuthenticationCode;
- (void)didReadAuthenticationCode:(NSData *)authenticationCode;

- (void)didUpdateUsageProperties:(NSSet *)updatedProperties;

@end

//
// FTPen
//
@interface FTPen ()

@property (nonatomic, weak) id<FTPenPrivateDelegate> privateDelegate;
@property (nonatomic, readonly) CBPeripheral *peripheral;

@property (nonatomic) BOOL canWriteCentralId;
@property (nonatomic) UInt32 centralId;

@property (nonatomic) BOOL canWriteHasListener;
@property (nonatomic) BOOL hasListenerSupportsNotifications;
@property (nonatomic) BOOL hasListener;
@property (nonatomic) FTPenPressureSetup *pressureSetup;

@property (nonatomic) NSString *manufacturingID;
@property (nonatomic) NSData *authenticationCode;
@property (nonatomic, readonly) NSString *serialNumber;

@property (nonatomic) NSInteger inactivityTimeout;
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

// Returns a boolean value as a NSNumber, or nil if this cannot be determined.
//
// Returns @(YES) IFF a pencil is connected, its model number is known and it is an aluminum
// pencil.
@property (nonatomic, readonly) NSNumber *isAluminumPencil;

- (id)initWithPeripheral:(CBPeripheral *)peripheral;

- (void)peripheralConnectionStatusDidChange;

- (void)startSwinging;

- (void)powerOff;

// Returns YES if the read request for the two characterisitcs was issued. It may fail
// if the characterisitics have not been discovered yet.
- (BOOL)readManufacturingIDAndAuthCode;

- (void)clearLastErrorCode;

- (void)readUsageProperties;

// Clears the current firmwareRevision and softwareRevision values and requests a read of them
// from the peripheral.
- (void)refreshFirmwareVersionProperties;

@end
