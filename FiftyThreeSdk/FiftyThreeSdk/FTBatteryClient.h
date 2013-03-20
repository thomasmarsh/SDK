//
//  FTBatteryClient.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CBPeripheral;

@interface FTBatteryClient : NSObject

@property (readonly) uint8_t batteryLevel;

- (id)initWithPeripheral:(CBPeripheral *)peripheral;
- (void)getBatteryLevel:(void(^)(FTBatteryClient *client, NSError *error))complete;

@end
