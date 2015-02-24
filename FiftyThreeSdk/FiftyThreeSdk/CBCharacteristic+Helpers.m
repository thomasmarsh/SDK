//
//  CBCharacteristic+Helpers.m
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import "CBCharacteristic+Helpers.h"

@implementation CBCharacteristic (Helpers)

- (NSData *)removeTrailingZeros:(NSData *)data
{
    NSData *value = self.value;
    NSUInteger length = value.length;
    for (; length > 0; length--) {
        if (((uint8_t *)value.bytes)[length - 1] != '\0') {
            break;
        }
    }

    return ((value.length == length) ? value : [value subdataWithRange:NSMakeRange(0, length)]);
}

- (BOOL)valueAsBOOL
{
    return (self.value.length > 0 ? (*(uint8_t *)self.value.bytes) != 0 : NO);
}

- (NSString *)valueAsNSString
{
    NSData *data = [self removeTrailingZeros:self.value];

    return (data.length > 0 ? [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] : nil);
}

- (NSUInteger)valueAsNSUInteger
{
    if (self.value.length == sizeof(uint32_t)) {
        return CFSwapInt32LittleToHost(*((uint32_t *)self.value.bytes));
    } else if (self.value.length == sizeof(uint16_t)) {
        return CFSwapInt16LittleToHost(*((uint16_t *)self.value.bytes));
    } else if (self.value.length == sizeof(uint8_t)) {
        return (*(uint8_t *)self.value.bytes);
    } else {
        return NSUIntegerMax;
    }
}

@end
