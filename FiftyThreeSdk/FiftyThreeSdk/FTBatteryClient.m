//
//  FTBatteryClient.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTBatteryClient.h"
#import <CoreBluetooth/CoreBluetooth.h>

static NSString *const kBatteryServiceUUID = @"0x180F";

static NSString *const kBatteryLevelUUID = @"0x2A19";

@interface FTBatteryClient () <CBPeripheralDelegate>
{
    NSInteger _resultCount;
    uint8_t _batteryLevel;
}

@end

@implementation FTBatteryClient
{
    CBPeripheral *_peripheral;
    void (^_complete)(FTBatteryClient *client, NSError *error);
    id<CBPeripheralDelegate> _oldDelegate;
}

- (id)initWithPeripheral:(CBPeripheral *)peripheral
{
    self = [super init];
    if (self) {
        _peripheral = peripheral;
    }
    return self;
}

- (void)getBatteryLevel:(void(^)(FTBatteryClient *client, NSError *error))complete
{
    _complete = complete;
    _oldDelegate = _peripheral.delegate;
    _peripheral.delegate = self;
    [_peripheral discoverServices:@[[CBUUID UUIDWithString:kBatteryServiceUUID]]];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error || !peripheral.services || peripheral.services.count == 0) {
        NSLog(@"Error discovering device info service: %@", [error localizedDescription]);
        [self done:error];
        return;
    }

    NSArray* characteristics = @[
                                 [CBUUID UUIDWithString:kBatteryLevelUUID]
                                 ];
    _resultCount = 0;

    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:characteristics forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering device info characteristics: %@", [error localizedDescription]);
        [self done:error];
        return;
    }

    for (CBCharacteristic *characteristic in service.characteristics) {
        [peripheral readValueForCharacteristic:characteristic];
        _resultCount++;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kBatteryLevelUUID]]) {
        _batteryLevel = ((char *)characteristic.value.bytes)[0];
    }

    _resultCount--;
    if (_resultCount == 0) {
        [self done:error];
    }
}

- (void)done:(NSError *)error
{
    _peripheral.delegate = _oldDelegate;
    _oldDelegate = nil;
    _complete(self, error);
}

@end
