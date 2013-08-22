//
//  FTPeripheralDelegate.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTPeripheralDelegate.h"
#import "FTServiceUUIDs.h"

@interface FTPeripheralDelegate ()

@property (nonatomic) NSMutableArray *serviceClients;

@end

@implementation FTPeripheralDelegate

- (id)init
{
    self = [super init];
    if (self)
    {
        _serviceClients = [NSMutableArray array];
    }
    return self;
}

- (void)addServiceClient:(FTServiceClient *)serviceClient
{
    [_serviceClients addObject:serviceClient];
}

- (NSArray *)peripheral:(CBPeripheral *)peripheral isConnectedDidChange:(BOOL)isConnected;
{
    NSMutableArray *servicesToBeDiscovered = [NSMutableArray array];

    for (FTServiceClient *serviceClient in self.serviceClients)
    {
        NSArray *servicesToBeDiscoveredForClient = [serviceClient peripheral:peripheral
                                                        isConnectedDidChange:isConnected];

        if (servicesToBeDiscoveredForClient)
        {
            [servicesToBeDiscovered addObjectsFromArray:servicesToBeDiscoveredForClient];
        }
    }

    return servicesToBeDiscovered;
}

#pragma mark - CBPeripheralDelegate

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral did update name: %@", peripheral.name);

    for (FTServiceClient *serviceClient in self.serviceClients)
    {
        [serviceClient peripheralDidUpdateName:peripheral];
    }
}

- (void)peripheralDidInvalidateServices:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral did invalidate services.");

    for (FTServiceClient *serviceClient in self.serviceClients)
    {
        [serviceClient peripheralDidInvalidateServices:peripheral];
    }
}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
    for (FTServiceClient *serviceClient in self.serviceClients)
    {
        [serviceClient peripheralDidUpdateRSSI:peripheral error:error];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    {
        NSMutableString *serviceNames = [NSMutableString string];

        for (int i = 0; i < peripheral.services.count; i++)
        {
            NSString *serviceName = FTNameForServiceUUID(((CBService *)peripheral.services[i]).UUID);
            if (!serviceName)
            {
                serviceName = @"(Unknown)";
            }

            if (i == peripheral.services.count - 1)
            {
                [serviceNames appendString:serviceName];
            }
            else
            {
                [serviceNames appendFormat:@"%@, ", serviceName];
            }
        }

        NSLog(@"Peripheral did discover service(s): %@.", serviceNames);
    }

    for (FTServiceClient *serviceClient in self.serviceClients)
    {
        [serviceClient peripheral:peripheral didDiscoverServices:error];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverIncludedServicesForService:(CBService *)service
             error:(NSError *)error
{
    NSLog(@"Peripheral did discover included services for service: %@", FTNameForServiceUUID(service.UUID));
    for (FTServiceClient *serviceClient in self.serviceClients)
    {
        [serviceClient peripheral:peripheral didDiscoverIncludedServicesForService:service error:error];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error
{
    NSLog(@"Peripheral did discover characterisitics for service: %@", FTNameForServiceUUID(service.UUID));

    for (FTServiceClient *serviceClient in self.serviceClients)
    {
        [serviceClient peripheral:peripheral didDiscoverCharacteristicsForService:service error:error];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    NSLog(@"Peripheral did update value for characteristic: %@", FTNameForServiceUUID(characteristic.UUID));

    for (FTServiceClient *serviceClient in self.serviceClients)
    {
        [serviceClient peripheral:peripheral didUpdateValueForCharacteristic:characteristic error:error];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    NSLog(@"Peripheral did write value for characteristic: %@", FTNameForServiceUUID(characteristic.UUID));

    for (FTServiceClient *serviceClient in self.serviceClients)
    {
        [serviceClient peripheral:peripheral didWriteValueForCharacteristic:characteristic error:error];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    if (characteristic.isNotifying)
    {
        NSLog(@"Peripheral notification began on charateristic: %@.", FTNameForServiceUUID(characteristic.UUID));
    }
    else
    {
        NSLog(@"Peripheral notification stopped on characteristic: %@.", FTNameForServiceUUID(characteristic.UUID));
    }

    for (FTServiceClient *serviceClient in self.serviceClients)
    {
        [serviceClient peripheral:peripheral didUpdateNotificationStateForCharacteristic:characteristic error:error];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    NSLog(@"Peripheral did discover descriptors for characteristic: %@.", FTNameForServiceUUID(characteristic.UUID));

    for (FTServiceClient *serviceClient in self.serviceClients)
    {
        [serviceClient peripheral:peripheral didDiscoverDescriptorsForCharacteristic:characteristic error:error];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor
             error:(NSError *)error
{
    NSLog(@"Peripheral did update value for descriptor.");

    for (FTServiceClient *serviceClient in self.serviceClients)
    {
        [serviceClient peripheral:peripheral didUpdateValueForDescriptor:descriptor error:error];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor
             error:(NSError *)error
{
    NSLog(@"Peripheral did write value for descriptor.");

    for (FTServiceClient *serviceClient in self.serviceClients)
    {
        [serviceClient peripheral:peripheral didWriteValueForDescriptor:descriptor error:error];
    }
}

@end