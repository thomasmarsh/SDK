//
//  FTPen.h
//  FiftyThreeSdk
//
//  Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

typedef struct PnPID {
    uint8_t vendorIdSource;
    uint16_t vendorId;
    uint16_t productId;
    uint16_t productVersion;
} PnPID;

extern NSString *const kFTPenDidEncounterErrorNotificationName;
extern NSString *const kFTPenIsReadyDidChangeNotificationName;
extern NSString *const kFTPenIsTipPressedDidChangeNotificationName;
extern NSString *const kFTPenIsEraserPressedDidChangeNotificationName;
extern NSString *const kFTPenBatteryLevelDidChangeNotificationName;
extern NSString *const kFTPenDidUpdatePropertiesNotificationName;
extern NSString *const kFTPenNotificationPropertiesKey;
extern NSString *const kFTPenEncoderDidTurnNotificationName;

extern NSString *const kFTPenNamePropertyName;
extern NSString *const kFTPenManufacturerNamePropertyName;
extern NSString *const kFTPenModelNumberPropertyName;
extern NSString *const kFTPenSerialNumberPropertyName;
extern NSString *const kFTPenFirmwareRevisionPropertyName;
extern NSString *const kFTPenHardwareRevisionPropertyName;
extern NSString *const kFTPenSoftwareRevisionPropertyName;
extern NSString *const kFTPenSystemIDPropertyName;
extern NSString *const kFTPenIEEECertificationDataPropertyName;
extern NSString *const kFTPenPnPIDCertificationDataPropertyName;

extern NSString *const kFTPenIsTipPressedPropertyName;
extern NSString *const kFTPenIsEraserPressedPropertyName;
extern NSString *const kFTPenBatteryLevelPropertyName;

@protocol FTPenDelegate;

typedef struct FTAccelerationSample {
    int16_t x;
    int16_t y;
    int16_t z;
} FTAccelerationSample;

typedef struct FTMagneticForceSample {
    int16_t x;
    int16_t y;
    int16_t z;
} FTMagneticForceSample;

typedef struct FTMotionSample {
    FTAccelerationSample acceleration;
    FTMagneticForceSample magneticForce;

} FTMotionSample;

@interface FTPen : NSObject

@property (nonatomic, weak) id<FTPenDelegate> delegate;

// Device Info
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *manufacturerName;
@property (nonatomic, readonly) NSString *modelNumber;
@property (nonatomic, readonly) NSString *firmwareRevision;
@property (nonatomic, readonly) NSString *hardwareRevision;
@property (nonatomic, readonly) NSString *softwareRevision;
@property (nonatomic, readonly) NSString *systemID;
@property (nonatomic, readonly) NSString *IEEECertificationData;
@property (nonatomic, readonly) PnPID PnPID;

// Pen Client
@property (nonatomic, readonly) BOOL isTipPressed;
@property (nonatomic, readonly) BOOL isEraserPressed;
@property (nonatomic, readonly) float tipPressure;
@property (nonatomic, readonly) float eraserPressure;
@property (nonatomic, readonly) FTMotionSample motion;
@property (nonatomic, readonly) NSDate *lastTipReleaseTime;
@property (nonatomic, readonly) NSNumber *batteryLevel;

@end

@protocol FTPenDelegate <NSObject>

@optional
- (void)penDidUpdateDeviceInfoProperty:(FTPen *)pen;
- (void)pen:(FTPen *)pen isTipPressedDidChange:(BOOL)isTipPressed;
- (void)pen:(FTPen *)pen isEraserPressedDidChange:(BOOL)isEraserPressed;
- (void)pen:(FTPen *)pen tipPressureDidChange:(float)tipPressure;
- (void)pen:(FTPen *)pen eraserPressureDidChange:(float)eraserPressure;
- (void)pen:(FTPen *)pen motionDidChange:(FTMotionSample)motion;
- (void)pen:(FTPen *)pen batteryLevelDidChange:(NSNumber *)batteryLevel;
- (void)pen:(FTPen *)pen encoderDidTurn:(NSInteger)turnVector;

@end
