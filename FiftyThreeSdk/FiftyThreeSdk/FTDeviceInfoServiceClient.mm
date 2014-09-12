//
//  FTDeviceInfoServiceClient.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>

#import "CBCharacteristic+Helpers.h"
#import "Core/Log.h"
#import "FTDeviceInfoServiceClient.h"
#import "FTLogPrivate.h"
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

@end

@implementation FTDeviceInfoServiceClient

- (id)initWithPeripheral:(CBPeripheral *)peripheral
{
    self = [super init];
    if (self)
    {
        _peripheral = peripheral;
    }
    return self;
}

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

- (NSArray *)ensureServicesForConnectionState:(BOOL)isConnected;
{
    if (isConnected)
    {
        return (self.deviceInfoService ?
                nil :
                @[[FTDeviceInfoServiceUUIDs deviceInfoService]]);
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
            NSArray* characteristics = @[
                                         [FTDeviceInfoServiceUUIDs softwareRevision],
                                         [FTDeviceInfoServiceUUIDs firmwareRevision],
                                         [FTDeviceInfoServiceUUIDs serialNumber],
                                         [FTDeviceInfoServiceUUIDs modelNumber],
                                         [FTDeviceInfoServiceUUIDs manufacturerName],
                                         [FTDeviceInfoServiceUUIDs hardwareRevision],
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
    if (service != self.deviceInfoService)
    {
        return;
    }

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
    if (error)
    {
        if ([FTDeviceInfoServiceUUIDs nameForUUID:characteristic.UUID])
        {
            MLOG_ERROR(FTLogSDK, "Error updating value for characteristic: %s error: %s.",
                       ObjcDescription([FTPenServiceUUIDs nameForUUID:characteristic.UUID]),
                       ObjcDescription(error.localizedDescription));
            // TODO: Report failed state
        }
        return;
    }

    BOOL updatedCharacteristic = NO;
    NSMutableSet *updatedProperties = [NSMutableSet set];

    if ([characteristic isEqual:self.manufacturerNameCharacteristic])
    {
        self.manufacturerName = [characteristic valueAsNSString];
        updatedCharacteristic = YES;
        [updatedProperties addObject:kFTPenManufacturerNamePropertyName];
    }
    else if ([characteristic isEqual:self.modelNumberCharateristic])
    {
        self.modelNumber = [characteristic valueAsNSString];
        updatedCharacteristic = YES;
        [updatedProperties addObject:kFTPenModelNumberPropertyName];
    }
    else if ([characteristic isEqual:self.serialNumberCharateristic])
    {
        self.serialNumber = [characteristic valueAsNSString];
        updatedCharacteristic = YES;
        [updatedProperties addObject:kFTPenSerialNumberPropertyName];
    }
    else if ([characteristic isEqual:self.firmwareRevisionCharateristic])
    {
        self.firmwareRevision = [characteristic valueAsNSString];
        updatedCharacteristic = YES;
        [updatedProperties addObject:kFTPenFirmwareRevisionPropertyName];
    }
    else if ([characteristic isEqual:self.hardwareRevisionCharateristic])
    {
        self.hardwareRevisionCharateristic = characteristic;
        self.hardwareRevision = [characteristic valueAsNSString];
        updatedCharacteristic = YES;
        [updatedProperties addObject:kFTPenHardwareRevisionPropertyName];
    }
    else if ([characteristic isEqual:self.softwareRevisionCharateristic])
    {
        self.softwareRevisionCharateristic = characteristic;
        self.softwareRevision = [characteristic valueAsNSString];
        updatedCharacteristic = YES;
        [updatedProperties addObject:kFTPenSoftwareRevisionPropertyName];
    }
    else if ([characteristic isEqual:self.systemIDCharateristic])
    {
        self.systemID = [characteristic valueAsNSString];
        updatedCharacteristic = YES;
        [updatedProperties addObject:kFTPenSystemIDPropertyName];
    }
    else if ([characteristic isEqual:self.IEEECertificationDataCharateristic])
    {
        self.IEEECertificationData = characteristic.value;
        updatedCharacteristic = YES;
        [updatedProperties addObject:kFTPenIEEECertificationDataPropertyName];
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
        [updatedProperties addObject:kFTPenPnPIDCertificationDataPropertyName];
    }

    if (updatedCharacteristic)
    {
        [self.delegate deviceInfoServiceClientDidUpdateDeviceInfo:self
                                                updatedProperties:updatedProperties];
    }
}

#pragma mark -

- (void)refreshModelNumberAndSerialNumber
{
    if (self.modelNumberCharateristic)
    {
        [self.peripheral readValueForCharacteristic:self.modelNumberCharateristic];
    }

    if (self.serialNumberCharateristic)
    {
        [self.peripheral readValueForCharacteristic:self.serialNumberCharateristic];
    }
}

- (void)refreshFirmwareRevisions
{
    self.firmwareRevision = nil;
    self.softwareRevision = nil;

    if (self.firmwareRevisionCharateristic)
    {
        [self.peripheral readValueForCharacteristic:self.firmwareRevisionCharateristic];
    }

    if (self.softwareRevisionCharateristic)
    {
        [self.peripheral readValueForCharacteristic:self.softwareRevisionCharateristic];
    }
}

@end
