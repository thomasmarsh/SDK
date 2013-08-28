//
//  FTPenDebugServiceClient.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTPenDebugServiceClient.h"
#import "FTServiceUUIDs.h"

@interface FTPenDebugServiceClient ()

@property (nonatomic) CBPeripheral *peripheral;

@property (nonatomic) CBService *penDebugService;

@property (nonatomic) CBCharacteristic *tipPressureCharacteristic;
@property (nonatomic) CBCharacteristic *eraserPressureCharacteristic;
@property (nonatomic) CBCharacteristic *longPressTimeCharacteristic;
@property (nonatomic) CBCharacteristic *connectionTimeCharacteristic;
@property (nonatomic) CBCharacteristic *numFailedConnectionsCharacteristic;
@property (nonatomic) CBCharacteristic *manufacturingIDCharacteristic;
@property (nonatomic) CBCharacteristic *lastErrorCodeCharacteristic;

@end

@implementation FTPenDebugServiceClient

- (id)initWithPeripheral:(CBPeripheral *)peripheral
{
    self = [super init];
    if (self)
    {
        _peripheral = peripheral;
    }
    return self;
}

- (void)setManufacturingID:(NSString *)manufacturingID
{
    NSAssert([manufacturingID canBeConvertedToEncoding:NSASCIIStringEncoding],
             @"Manufacturing ID must be ASCII");
    NSAssert(manufacturingID.length == 15, @"Manufacturing ID must be 15 characters");

    if (self.manufacturingIDCharacteristic)
    {
        [self.peripheral writeValue:[manufacturingID dataUsingEncoding:NSASCIIStringEncoding]
                  forCharacteristic:self.manufacturingIDCharacteristic
                               type:CBCharacteristicWriteWithResponse];
    }
}

- (void)getManufacturingID
{
    if (self.manufacturingIDCharacteristic)
    {
        [self.peripheral readValueForCharacteristic:self.manufacturingIDCharacteristic];
    }
}

- (FTPenLastErrorCode)lastErrorCode
{
    FTPenLastErrorCode lastErrorCode;
    lastErrorCode.lastErrorID = 0;
    lastErrorCode.lastErrorValue = 0;

    if (self.lastErrorCodeCharacteristic)
    {
        NSData *data = self.lastErrorCodeCharacteristic.value;
        if (data.length == sizeof(FTPenLastErrorCode))
        {
            lastErrorCode.lastErrorID = CFSwapInt32LittleToHost(*((uint32_t *)&data.bytes[0]));
            lastErrorCode.lastErrorValue = CFSwapInt32LittleToHost(*((uint32_t *)&data.bytes[4]));
        }
    }

    return lastErrorCode;
}

- (void)clearLastErrorCode
{
    if (self.lastErrorCodeCharacteristic)
    {
        uint32_t value[2] = { 0, 0 };
        NSData *data = [NSData dataWithBytes:&value length:sizeof(value)];
        [self.peripheral writeValue:data
                  forCharacteristic:self.lastErrorCodeCharacteristic
                               type:CBCharacteristicWriteWithResponse];

        [self.peripheral readValueForCharacteristic:self.lastErrorCodeCharacteristic];
    }
}

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
            NSArray *characteristics = @[[FTPenDebugServiceUUIDs tipPressure],
                                         [FTPenDebugServiceUUIDs eraserPressure],
                                         [FTPenDebugServiceUUIDs longPressTime],
                                         [FTPenDebugServiceUUIDs connectionTime],
                                         [FTPenDebugServiceUUIDs numFailedConnections],
                                         [FTPenDebugServiceUUIDs manufacturingID],
                                         [FTPenDebugServiceUUIDs lastErrorCode]
                                         ];

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
        if (!self.tipPressureCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenDebugServiceUUIDs tipPressure]])
        {
            self.tipPressureCharacteristic = characteristic;
            // [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
        else if (!self.eraserPressureCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenDebugServiceUUIDs eraserPressure]])
        {
            self.eraserPressureCharacteristic = characteristic;
            // [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
        else if (!self.longPressTimeCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenDebugServiceUUIDs longPressTime]])
        {
            self.longPressTimeCharacteristic = characteristic;
        }
        else if (!self.connectionTimeCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenDebugServiceUUIDs connectionTime]])
        {
            self.connectionTimeCharacteristic = characteristic;
        }
        else if (!self.numFailedConnectionsCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenDebugServiceUUIDs numFailedConnections]])
        {
            self.numFailedConnectionsCharacteristic = characteristic;
        }
        else if (!self.manufacturingIDCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenDebugServiceUUIDs manufacturingID]])
        {
            self.manufacturingIDCharacteristic = characteristic;
        }
        else if (!self.lastErrorCodeCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenDebugServiceUUIDs lastErrorCode]])
        {
            self.lastErrorCodeCharacteristic = characteristic;
            [peripheral readValueForCharacteristic:characteristic];
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

    if ([characteristic.UUID isEqual:[FTPenDebugServiceUUIDs manufacturingID]])
    {
        NSString *manufacturingID = [[NSString alloc] initWithData:characteristic.value encoding:NSASCIIStringEncoding];
        [self.delegate didReadManufacturingID:manufacturingID];
    }
    else if ([characteristic.UUID isEqual:[FTPenDebugServiceUUIDs lastErrorCode]])
    {
        [self.delegate didUpdateDebugProperties];
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
    if (characteristic == self.manufacturingIDCharacteristic)
    {
        if (error)
        {
            [self.delegate didFailToWriteManufacturingID];
        }
        else
        {
            [self.delegate didWriteManufacturingID];
        }

    }
}

@end
