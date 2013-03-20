//
//  FTBatteryClient.h
//  FiftyThreeSdk
//
//  Created by Adam on 3/11/13.
//  Copyright (c) 2013 FiftyThree. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CBPeripheral;

@interface FTBatteryClient : NSObject

@property (readonly) uint8_t batteryLevel;

- (id)initWithPeripheral:(CBPeripheral *)peripheral;
- (void)getBatteryLevel:(void(^)(FTBatteryClient *client, NSError *error))complete;

@end
