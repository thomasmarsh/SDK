//
//  CBCharacteristic+Helpers.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "CBCharacteristic+Helpers.h"

@implementation CBCharacteristic (Helpers)

- (BOOL)valueAsBOOL
{
    return (self.value.length > 0 ?
            (*(uint8_t *)self.value.bytes) != 0 :
            NO);
}

- (NSString *)valueAsNSString
{
    return (self.value.length > 0 ?
            [[NSString alloc] initWithData:self.value encoding:NSASCIIStringEncoding] :
            nil);
}

- (NSUInteger)valueAsNSUInteger
{
    if (self.value.length == sizeof(uint32_t))
    {
        return CFSwapInt32LittleToHost(*((uint32_t *)self.value.bytes));
    }
    else
    {
        return NSUIntegerMax;
    }
}

@end
