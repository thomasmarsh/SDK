//
//  CBPeripheral+Helpers.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <CoreBluetooth/CoreBluetooth.h>

@interface CBPeripheral (Helpers)

- (void)writeBOOL:(BOOL)value
forCharacteristic:(CBCharacteristic *)characteristic
             type:(CBCharacteristicWriteType)type;

- (void)writeNSUInteger:(NSUInteger)value
      forCharacteristic:(CBCharacteristic *)characteristic
                   type:(CBCharacteristicWriteType)type;

- (void)writeNSString:(NSString *)value
    forCharacteristic:(CBCharacteristic *)characteristic
                 type:(CBCharacteristicWriteType)type;

@end
