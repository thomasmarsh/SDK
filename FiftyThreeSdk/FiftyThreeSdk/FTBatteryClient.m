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

@interface FTBatteryClient () <CBPeripheralDelegate, CBCentralManagerDelegate>
{
    void (^_complete)(FTBatteryClient *client, NSError *error);
}

@property (nonatomic) NSInteger resultCount;
@property (nonatomic) CBPeripheral *parentPeripheral;
@property (nonatomic) CBPeripheral *peripheral;
@property (nonatomic) CBCentralManager *manager;
@property uint8_t batteryLevel;

@end


@implementation FTBatteryClient

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

- (void)getBatteryLevel:(void(^)(FTBatteryClient *client, NSError *error))complete
{
    _complete = complete;

    if (!self.manager)
    {
        self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
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
    [peripheral discoverServices:@[[CBUUID UUIDWithString:kBatteryServiceUUID]]];
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

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    self.peripheral = nil;
    self.manager = nil;
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
    if (self.peripheral)
    {
        [self.manager cancelPeripheralConnection:self.peripheral];
    }
    
    _complete(self, error);
}

@end
