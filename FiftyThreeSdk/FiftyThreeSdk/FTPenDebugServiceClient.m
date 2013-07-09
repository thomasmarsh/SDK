//
//  FTPenDebugServiceClient.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTPenDebugServiceClient.h"
#import "FTServiceUUIDs.h"

@interface FTPenDebugServiceClient ()

@property (nonatomic) CBService *penDebugService;
@property (nonatomic) CBCharacteristic *deviceStateCharacteristic;

@end

@implementation FTPenDebugServiceClient

#pragma mark - FTServiceClient

- (NSArray *)peripheral:(CBPeripheral *)peripheral isConnectedDidChange:(BOOL)isConnected
{
    if (isConnected)
    {
        return @[[FTPenDebugServiceUUIDs penDebugService]];
    }
    else
    {
        self.penDebugService = nil;
        self.deviceStateCharacteristic = nil;

        return nil;
    }
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        // TODO: Report failed state
        return;
    }

    if (!self.penDebugService)
    {
        self.penDebugService = [FTServiceClient findServiceWithPeripheral:peripheral
                                                                  andUUID:[FTPenDebugServiceUUIDs penDebugService]];

        if (self.penDebugService)
        {
//            NSArray *characteristics = @[[FTPenDebugServiceUUIDs deviceState],
//                                         [FTPenDebugServiceUUIDs tipPressure],
//                                         [FTPenDebugServiceUUIDs erasurePressure],
//                                         [FTPenDebugServiceUUIDs longPressTime],
//                                         [FTPenDebugServiceUUIDs connectionTime]
//                                         ];
            NSArray *characteristics = @[[FTPenDebugServiceUUIDs deviceState]];

            [peripheral discoverCharacteristics:characteristics forService:self.penDebugService];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error
{
    if (error || service.characteristics.count == 0)
    {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        // TODO: Report failed state
        return;
    }

    for (CBCharacteristic *characteristic in service.characteristics)
    {
        // DeviceState
        if (!self.deviceStateCharacteristic &&
            [characteristic.UUID isEqual:[FTPenDebugServiceUUIDs deviceState]])
        {
            self.deviceStateCharacteristic = characteristic;
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error discovering characteristics: %@.", [error localizedDescription]);
        // TODO: Report failed state
        return;
    }

    if ([characteristic.UUID isEqual:[FTPenDebugServiceUUIDs deviceState]])
    {
        const int state = ((const char *)characteristic.value.bytes)[0];
        NSLog(@"DeviceState changed: %d.", state);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error changing notification state: %@.", error.localizedDescription);
        // TODO: Report failed state
        return;
    }

    if (![characteristic.UUID isEqual:[FTPenServiceUUIDs isTipPressed]] &&
        ![characteristic.UUID isEqual:[FTPenServiceUUIDs isEraserPressed]])
    {
        return;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
}

@end
