//
//  CBPeripheral+Helpers.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <CoreBluetooth/CoreBluetooth.h>

@interface CBPeripheral (Helpers)

- (void)writeBOOL:(BOOL)value
    forCharacteristic:(CBCharacteristic *)characteristic
                 type:(CBCharacteristicWriteType)type;

- (void)writeUInt32:(uint32_t)value
    forCharacteristic:(CBCharacteristic *)characteristic
                 type:(CBCharacteristicWriteType)type;

- (void)writeNSString:(NSString *)value
    forCharacteristic:(CBCharacteristic *)characteristic
                 type:(CBCharacteristicWriteType)type;

@end
