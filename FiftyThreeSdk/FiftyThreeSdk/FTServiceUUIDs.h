//
//  FTServiceUUIDs.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <CoreBluetooth/CoreBluetooth.h>

@interface FTPenServiceUUIDs : NSObject

+ (CBUUID *)penService;
+ (CBUUID *)isTipPressed;
+ (CBUUID *)isEraserPressed;
+ (CBUUID *)tipPressure;
+ (CBUUID *)eraserPressure;
+ (CBUUID *)batteryLevel;
+ (CBUUID *)shouldSwing;
+ (CBUUID *)shouldPowerOff;
+ (CBUUID *)inactivityTime;

+ (NSString *)nameForUUID:(CBUUID *)UUID;

@end

@interface FTPenUsageServiceUUIDs : NSObject

+ (CBUUID *)penUsageService;

+ (CBUUID *)numTipPresses;
+ (CBUUID *)numEraserPresses;
+ (CBUUID *)numFailedConnections;
+ (CBUUID *)numSuccessfulConnections;
+ (CBUUID *)totalOnTime;
+ (CBUUID *)manufacturingID;
+ (CBUUID *)lastErrorCode;
+ (CBUUID *)longPressTime;
+ (CBUUID *)connectionTime;

+ (NSString *)nameForUUID:(CBUUID *)UUID;

@end

@interface FTDeviceInfoServiceUUIDs :NSObject

+ (CBUUID *)deviceInfoService;
+ (CBUUID *)manufacturerName;
+ (CBUUID *)modelNumber;
+ (CBUUID *)serialNumber;

+ (CBUUID *)firmwareRevision;
+ (CBUUID *)hardwareRevision;
+ (CBUUID *)softwareRevision;

+ (CBUUID *)systemID;
+ (CBUUID *)IEEECertificationData;
+ (CBUUID *)PnPID;

+ (NSString *)nameForUUID:(CBUUID *)UUID;

@end

extern NSString *FTNameForServiceUUID(CBUUID *UUID);
