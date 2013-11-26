//
//  CBPeripheral+Helpers.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "CBPeripheral+Helpers.h"
#import "FTAssert.h"

@implementation CBPeripheral (Helpers)

- (void)writeBOOL:(BOOL)value
forCharacteristic:(CBCharacteristic *)characteristic
             type:(CBCharacteristicWriteType)type
{
    if (characteristic)
    {
        NSData *data = [NSData dataWithBytes:value ? "1" : "0" length:1];
        [self writeValue:data forCharacteristic:characteristic type:type];
    }
    else
    {
        NSLog(@"Attempt to write to nil characteristic");
    }
}

- (void)writeNSUInteger:(NSUInteger)value
      forCharacteristic:(CBCharacteristic *)characteristic
                   type:(CBCharacteristicWriteType)type
{
    if (characteristic)
    {
        uint32_t littleEndianValue = CFSwapInt32HostToLittle(value);
        NSData *data = [NSData dataWithBytes:&littleEndianValue length:sizeof(littleEndianValue)];
        [self writeValue:data forCharacteristic:characteristic type:type];
    }
    else
    {
        NSLog(@"ERROR: Attempt to write to nil characteristic");
    }
}

- (void)writeNSString:(NSString *)value
    forCharacteristic:(CBCharacteristic *)characteristic
                 type:(CBCharacteristicWriteType)type
{
    NSAssert([value canBeConvertedToEncoding:NSASCIIStringEncoding], @"Value must be ASCII");

    if (characteristic)
    {
        NSData *data = [value dataUsingEncoding:NSASCIIStringEncoding];
        [self writeValue:data forCharacteristic:characteristic type:type];
    }
    else
    {
        NSLog(@"ERROR: Attempt to write to nil characteristic");
    }
}

@end
