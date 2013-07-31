//
//  FTDeviceInfoServiceClient.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>

#import "FTDeviceInfoServiceClient.h"
#import "FTServiceUUIDs.h"

@interface FTDeviceInfoServiceClient ()

@property (nonatomic) CBService *deviceInfoService;

@property (nonatomic) CBCharacteristic *manufacturerNameCharacteristic;
@property (nonatomic) CBCharacteristic *modelNumberCharateristic;
@property (nonatomic) CBCharacteristic *serialNumberCharateristic;
@property (nonatomic) CBCharacteristic *firmwareRevisionCharateristic;
@property (nonatomic) CBCharacteristic *hardwareRevisionCharateristic;
@property (nonatomic) CBCharacteristic *softwareRevisionCharateristic;
@property (nonatomic) CBCharacteristic *systemIDCharateristic;
@property (nonatomic) CBCharacteristic *IEEECertificationDataCharateristic;
@property (nonatomic) CBCharacteristic *PnPIDCharateristic;
@property (nonatomic) NSInteger resultCount;
@property (nonatomic) CBPeripheral *parentPeripheral;
@property (nonatomic) CBPeripheral *peripheral;
@property (nonatomic) CBCentralManager *manager;

@end

@implementation FTDeviceInfoServiceClient

#pragma mark - Properties

- (void)setManufacturerName:(NSString *)manufacturerName
{
    _manufacturerName = manufacturerName;
}

- (void)setModelNumber:(NSString *)modelNumber
{
    _modelNumber = modelNumber;
}

- (void)setSerialNumber:(NSString *)serialNumber
{
    _serialNumber = serialNumber;
}

- (void)setFirmwareRevision:(NSString *)firmwareRevision
{
    _firmwareRevision = firmwareRevision;
}

- (void)setHardwareRevision:(NSString *)hardwareRevision
{
    _hardwareRevision = hardwareRevision;
}

- (void)setSoftwareRevision:(NSString *)softwareRevision
{
    _softwareRevision = softwareRevision;
}

- (void)setSystemID:(NSString *)systemID
{
    _systemID = systemID;
}

- (void)setIEEECertificationData:(NSData *)IEEECertificationData
{
    _IEEECertificationData = IEEECertificationData;
}

- (void)setPnpID:(PnPID)PnPID
{
    _PnPID = PnPID;
}

#pragma mark - FTServiceClient

- (NSArray *)peripheral:(CBPeripheral *)peripheral isConnectedDidChange:(BOOL)isConnected
{
    if (isConnected)
    {
        return @[[FTDeviceInfoServiceUUIDs deviceInfoService]];
    }
    else
    {
        self.deviceInfoService = nil;

        return nil;
    }
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (!self.deviceInfoService)
    {
        self.deviceInfoService = [FTServiceClient findServiceWithPeripheral:peripheral
                                                                    andUUID:[FTDeviceInfoServiceUUIDs deviceInfoService]];

        if (self.deviceInfoService)
        {
            NSArray* characteristics = @[[FTDeviceInfoServiceUUIDs manufacturerName],
                                         [FTDeviceInfoServiceUUIDs modelNumber],
                                         [FTDeviceInfoServiceUUIDs serialNumber],
                                         [FTDeviceInfoServiceUUIDs firmwareRevision],
                                         [FTDeviceInfoServiceUUIDs hardwareRevision],
                                         [FTDeviceInfoServiceUUIDs softwareRevision],
                                         [FTDeviceInfoServiceUUIDs systemID],
                                         [FTDeviceInfoServiceUUIDs IEEECertificationData],
                                         [FTDeviceInfoServiceUUIDs PnPID]];

            [peripheral discoverCharacteristics:characteristics forService:self.deviceInfoService];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error
{
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        if (!self.manufacturerNameCharacteristic &&
            [characteristic.UUID isEqual:[FTDeviceInfoServiceUUIDs manufacturerName]])
        {
            self.manufacturerNameCharacteristic = characteristic;
            [peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.modelNumberCharateristic &&
                 [characteristic.UUID isEqual:[FTDeviceInfoServiceUUIDs modelNumber]])
        {
            self.modelNumberCharateristic = characteristic;
            [peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.serialNumberCharateristic &&
                 [characteristic.UUID isEqual:[FTDeviceInfoServiceUUIDs serialNumber]])
        {
            self.serialNumberCharateristic = characteristic;
            [peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.firmwareRevisionCharateristic &&
                 [characteristic.UUID isEqual:[FTDeviceInfoServiceUUIDs firmwareRevision]])
        {
            self.firmwareRevisionCharateristic = characteristic;
            [peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.hardwareRevisionCharateristic &&
                 [characteristic.UUID isEqual:[FTDeviceInfoServiceUUIDs hardwareRevision]])
        {
            self.hardwareRevisionCharateristic = characteristic;
            [peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.softwareRevisionCharateristic &&
                 [characteristic.UUID isEqual:[FTDeviceInfoServiceUUIDs softwareRevision]])
        {
            self.softwareRevisionCharateristic = characteristic;
            [peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.systemIDCharateristic &&
                 [characteristic.UUID isEqual:[FTDeviceInfoServiceUUIDs systemID]])
        {
            self.systemIDCharateristic = characteristic;
            [peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.IEEECertificationDataCharateristic &&
                 [characteristic.UUID isEqual:[FTDeviceInfoServiceUUIDs IEEECertificationData]])
        {
            self.IEEECertificationDataCharateristic = characteristic;
            [peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.PnPIDCharateristic &&
                 [characteristic.UUID isEqual:[FTDeviceInfoServiceUUIDs PnPID]])
        {
            self.PnPIDCharateristic = characteristic;
            [peripheral readValueForCharacteristic:characteristic];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    BOOL updatedCharacteristic = NO;

    if ([characteristic isEqual:self.manufacturerNameCharacteristic])
    {
        self.manufacturerName = [NSString stringWithUTF8String:characteristic.value.bytes];
        updatedCharacteristic = YES;
    }
    else if ([characteristic isEqual:self.modelNumberCharateristic])
    {
        self.modelNumber = [NSString stringWithUTF8String:characteristic.value.bytes];
        updatedCharacteristic = YES;
    }
    else if ([characteristic isEqual:self.serialNumberCharateristic])
    {
        self.serialNumber = [NSString stringWithUTF8String:characteristic.value.bytes];
        updatedCharacteristic = YES;
    }
    else if ([characteristic isEqual:self.firmwareRevisionCharateristic])
    {
        self.firmwareRevision = [NSString stringWithUTF8String:characteristic.value.bytes];
        updatedCharacteristic = YES;
    }
    else if ([characteristic isEqual:self.hardwareRevisionCharateristic])
    {
        self.hardwareRevisionCharateristic = characteristic;
        self.hardwareRevision = [NSString stringWithUTF8String:characteristic.value.bytes];
        updatedCharacteristic = YES;
    }
    else if ([characteristic isEqual:self.softwareRevisionCharateristic])
    {
        self.softwareRevisionCharateristic = characteristic;
        self.softwareRevision = [NSString stringWithUTF8String:characteristic.value.bytes];
        updatedCharacteristic = YES;
    }
    else if ([characteristic isEqual:self.systemIDCharateristic])
    {
        self.systemID = [NSString stringWithUTF8String:characteristic.value.bytes];
        updatedCharacteristic = YES;
    }
    else if ([characteristic isEqual:self.IEEECertificationDataCharateristic])
    {
        self.IEEECertificationData = characteristic.value;
        updatedCharacteristic = YES;
    }
    else if ([characteristic isEqual:self.IEEECertificationDataCharateristic])
    {
        if (characteristic.value.length != 7)
        {
            return;
        }
        char* bytes = (char *)characteristic.value.bytes;

        PnPID pnpID;
        pnpID.vendorIdSource = bytes[0];
        pnpID.vendorId = bytes[1] | (bytes[2] << 8);
        pnpID.productId = bytes[3] | (bytes[4] << 8);
        pnpID.productVersion = bytes[5] | (bytes[6] << 8);

        self.PnpID = pnpID;

        updatedCharacteristic = YES;
    }

    if (updatedCharacteristic)
    {
        [self.delegate deviceInfoServiceClientDidUpdateDeviceInfo:self];
    }
}

@end
