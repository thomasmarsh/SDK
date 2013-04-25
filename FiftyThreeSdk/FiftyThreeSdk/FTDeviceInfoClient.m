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

@interface FTDeviceInfoClient () <CBPeripheralDelegate, CBCentralManagerDelegate>
{
    void (^_complete)(FTDeviceInfoClient *client, NSError *error);
}

@property (nonatomic) NSInteger resultCount;
@property (nonatomic) CBPeripheral *parentPeripheral;
@property (nonatomic) CBPeripheral *peripheral;
@property (nonatomic) CBCentralManager *manager;

@end

@implementation FTDeviceInfoClient

- (id)initWithPeripheral:(CBPeripheral *)peripheral
{
    self = [super init];
    if (self)
    {
        self.parentPeripheral = peripheral;
    }
    return self;
}

- (void)dealloc
{
    if (self.peripheral)
    {
        [self.manager cancelPeripheralConnection:self.peripheral];
    }
}

- (void)getInfo:(void(^)(FTDeviceInfoClient *client, NSError *error))complete
{
    if (!self.manager)
    {
        self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    
    _complete = complete;
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn)
    {
        // We go through the process of retrieving the peripherals to avoid interfering with other instances
        [central retrieveConnectedPeripherals];
    }
}

- (void)centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals
{
    for (CBPeripheral *peripheral in peripherals)
    {
        if (CFEqual(peripheral.UUID, self.parentPeripheral.UUID))
        {
            self.peripheral = peripheral;
            self.peripheral.delegate = self;
            [self.manager connectPeripheral:self.peripheral options:nil];
            break;
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    [peripheral discoverServices:@[[CBUUID UUIDWithString:kDeviceInfoServiceUUID]]];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    self.peripheral = nil;
    self.manager = nil;
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
    self.resultCount = 0;

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
        self.resultCount++;
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

    self.resultCount--;
    if (self.resultCount == 0) {
        [self done:error];
    }
}

- (void)done:(NSError *)error
{
    if (self.peripheral)
    {
        [self.manager cancelPeripheralConnection:self.peripheral];
    }

    _complete(self, error);
}

@end
