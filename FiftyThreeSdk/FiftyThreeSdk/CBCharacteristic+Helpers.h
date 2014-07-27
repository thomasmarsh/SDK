//
//  CBCharacteristic+Helpers.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <CoreBluetooth/CoreBluetooth.h>

@interface CBCharacteristic (Helpers)

- (BOOL)valueAsBOOL;
- (NSString *)valueAsNSString;
- (NSUInteger)valueAsNSUInteger;

@end
