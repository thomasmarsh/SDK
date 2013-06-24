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
+ (CBUUID *)shouldSwing;
+ (CBUUID *)shouldPowerOff;
+ (CBUUID *)batteryVoltage;
+ (CBUUID *)inactivityTime;

+ (NSString *)nameForPenServiceUUID:(CBUUID *)UUID;

@end

@interface FTPenDebugServiceUUIDs : NSObject

+ (CBUUID *)penDebugService;
+ (CBUUID *)deviceState;
+ (CBUUID *)tipPressure;
+ (CBUUID *)erasurePressure;
+ (CBUUID *)longPressTime;
+ (CBUUID *)connectionTime;

+ (NSString *)nameForPenDebugServiceUUID:(CBUUID *)UUID;

@end

extern NSString *FTNameForServiceUUID(CBUUID *UUID);