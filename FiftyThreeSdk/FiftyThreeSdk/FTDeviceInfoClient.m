//
//  FTDeviceInfoClient.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTDeviceInfoClient.h"
#import <CoreBluetooth/CoreBluetooth.h>

static NSString *const kDeviceInfoServiceUUID = @"0x180A";

static NSString *const kManufacturerNameUUID = @"0x2A29";
static NSString *const kModelNumberUUID = @"0x2A24";
static NSString *const kSerialNumberUUID = @"0x2A25";
static NSString *const kFirmwareRevisionUUID = @"0x2A26";
static NSString *const kHardwareRevisionUUID = @"0x2A27";
static NSString *const kSoftwareRevisionUUID = @"0x2A28";
static NSString *const kSystemIdUUID = @"0x2A23";
static NSString *const kIEEECertificationDataUUID = @"0x2A2A";
static NSString *const kPnpIdUUID = @"0x2A50";

@interface FTDeviceInfoClient () <CBPeripheralDelegate>
{
    NSInteger _resultCount;
}

@end

@implementation FTDeviceInfoClient
{
    CBPeripheral *_peripheral;
    void (^_complete)(FTDeviceInfoClient *client, NSError *error);
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

- (void)getInfo:(void(^)(FTDeviceInfoClient *client, NSError *error))complete
{
    _complete = complete;
    _oldDelegate = _peripheral.delegate;
    _peripheral.delegate = self;
    [_peripheral discoverServices:@[[CBUUID UUIDWithString:kDeviceInfoServiceUUID]]];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error || !peripheral.services || peripheral.services.count == 0) {
        NSLog(@"Error discovering device info service: %@", [error localizedDescription]);
        [self done:error];
        return;
    }

    NSArray* characteristics = @[
                                 [CBUUID UUIDWithString:kManufacturerNameUUID],
                                 [CBUUID UUIDWithString:kModelNumberUUID],
                                 [CBUUID UUIDWithString:kSerialNumberUUID],
                                 [CBUUID UUIDWithString:kFirmwareRevisionUUID],
                                 [CBUUID UUIDWithString:kHardwareRevisionUUID],
                                 [CBUUID UUIDWithString:kSoftwareRevisionUUID],
                                 [CBUUID UUIDWithString:kSystemIdUUID],
                                 [CBUUID UUIDWithString:kIEEECertificationDataUUID],
                                 [CBUUID UUIDWithString:kPnpIdUUID],
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
    if (error || characteristic.value.length == 0) {
        NSLog(@"Error in receiving characteristic value: %@", [error localizedDescription]);
        return;
    }
    
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kManufacturerNameUUID]]) {
        _manufacturerName = [NSString stringWithUTF8String:characteristic.value.bytes];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kModelNumberUUID]]) {
        _modelNumber = [NSString stringWithUTF8String:characteristic.value.bytes];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kSerialNumberUUID]]) {
        _serialNumber = [NSString stringWithUTF8String:characteristic.value.bytes];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kFirmwareRevisionUUID]]) {
        _firmwareRevision = [NSString stringWithUTF8String:characteristic.value.bytes];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kHardwareRevisionUUID]]) {
        _hardwareRevision = [NSString stringWithUTF8String:characteristic.value.bytes];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kSoftwareRevisionUUID]]) {
        _softwareRevision = [NSString stringWithUTF8String:characteristic.value.bytes];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kSystemIdUUID]]) {
        _systemId = [NSString stringWithUTF8String:characteristic.value.bytes];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kIEEECertificationDataUUID]]) {
        _certificationData = characteristic.value;
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kPnpIdUUID]]) {
        if (characteristic.value.length != 7) return;
        char* bytes = (char *)characteristic.value.bytes;
        
        _pnpId.vendorIdSource = bytes[0];
        _pnpId.vendorId = bytes[1] | (bytes[2] << 8);
        _pnpId.productId = bytes[3] | (bytes[4] << 8);
        _pnpId.productVersion = bytes[5] | (bytes[6] << 8);
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
