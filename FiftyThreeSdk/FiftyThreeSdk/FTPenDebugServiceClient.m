//
//  FTPenDebugServiceClient.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "CBCharacteristic+Helpers.h"
#import "CBPeripheral+Helpers.h"
#import "FTPenDebugServiceClient.h"
#import "FTServiceUUIDs.h"

@interface FTPenDebugServiceClient ()

@property (nonatomic) CBPeripheral *peripheral;

@property (nonatomic) CBService *penDebugService;

//@property (nonatomic) CBCharacteristic *tipPressureCharacteristic;
//@property (nonatomic) CBCharacteristic *eraserPressureCharacteristic;
@property (nonatomic) CBCharacteristic *numTipPressesCharacteristic;
@property (nonatomic) CBCharacteristic *numEraserPressesCharacteristic;
@property (nonatomic) CBCharacteristic *numFailedConnectionsCharacteristic;
@property (nonatomic) CBCharacteristic *numSuccessfulConnectionsCharacteristic;
@property (nonatomic) CBCharacteristic *totalOnTimeCharacteristic;
@property (nonatomic) CBCharacteristic *manufacturingIDCharacteristic;
@property (nonatomic) CBCharacteristic *lastErrorCodeCharacteristic;
@property (nonatomic) CBCharacteristic *longPressTimeCharacteristic;
@property (nonatomic) CBCharacteristic *connectionTimeCharacteristic;

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
    NSAssert(manufacturingID.length == 15, @"Manufacturing ID must be 15 characters");

    [self.peripheral writeNSString:manufacturingID
                 forCharacteristic:self.manufacturingIDCharacteristic
                              type:CBCharacteristicWriteWithResponse];
}

- (void)setLongPressTimeMilliseconds:(NSUInteger)longPressTimeMilliseconds
{
    [self.peripheral writeNSUInteger:longPressTimeMilliseconds
                   forCharacteristic:self.longPressTimeCharacteristic
                                type:CBCharacteristicWriteWithoutResponse];
}

- (void)setConnectionTimeSeconds:(NSUInteger)connectionTimeSeconds
{
    [self.peripheral writeNSUInteger:connectionTimeSeconds
                   forCharacteristic:self.connectionTimeCharacteristic
                                type:CBCharacteristicWriteWithoutResponse];
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

- (void)readDebugProperties
{
    //[self readValueForCharacteristic:self.tipPressureCharacteristic];
    //[self readValueForCharacteristic:self.eraserPressureCharacteristic];
    [self readValueForCharacteristic:self.numTipPressesCharacteristic];
    [self readValueForCharacteristic:self.numEraserPressesCharacteristic];
    [self readValueForCharacteristic:self.numFailedConnectionsCharacteristic];
    [self readValueForCharacteristic:self.numSuccessfulConnectionsCharacteristic];
    [self readValueForCharacteristic:self.totalOnTimeCharacteristic];
    [self readValueForCharacteristic:self.manufacturingIDCharacteristic];
    [self readValueForCharacteristic:self.lastErrorCodeCharacteristic];
    [self readValueForCharacteristic:self.longPressTimeCharacteristic];
    [self readValueForCharacteristic:self.connectionTimeCharacteristic];
}

- (void)readValueForCharacteristic:(CBCharacteristic *)characteristic
{
    if (characteristic)
    {
        [self.peripheral readValueForCharacteristic:characteristic];
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
        //self.tipPressureCharacteristic = nil;
        //self.eraserPressureCharacteristic = nil;
        self.numTipPressesCharacteristic = nil;
        self.numFailedConnectionsCharacteristic = nil;
        self.numSuccessfulConnectionsCharacteristic = nil;
        self.totalOnTimeCharacteristic = nil;
        self.manufacturingIDCharacteristic = nil;
        self.lastErrorCodeCharacteristic = nil;
        self.longPressTimeCharacteristic = nil;
        self.connectionTimeCharacteristic = nil;
    }

    return nil;
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

        NSArray *characteristics = @[//[FTPenDebugServiceUUIDs tipPressure],
                                     //[FTPenDebugServiceUUIDs eraserPressure],
                                     [FTPenDebugServiceUUIDs numTipPresses],
                                     [FTPenDebugServiceUUIDs numEraserPresses],
                                     [FTPenDebugServiceUUIDs numFailedConnections],
                                     [FTPenDebugServiceUUIDs numSuccessfulConnections],
                                     [FTPenDebugServiceUUIDs totalOnTime],
                                     [FTPenDebugServiceUUIDs manufacturingID],
                                     [FTPenDebugServiceUUIDs lastErrorCode],
                                     [FTPenDebugServiceUUIDs longPressTime],
                                     [FTPenDebugServiceUUIDs connectionTime]
                                     ];

        [peripheral discoverCharacteristics:characteristics forService:self.penDebugService];
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
//        if (!self.tipPressureCharacteristic &&
//                 [characteristic.UUID isEqual:[FTPenDebugServiceUUIDs tipPressure]])
//        {
//            self.tipPressureCharacteristic = characteristic;
//            // [peripheral setNotifyValue:YES forCharacteristic:characteristic];
//        }
//        else if (!self.eraserPressureCharacteristic &&
//                 [characteristic.UUID isEqual:[FTPenDebugServiceUUIDs eraserPressure]])
//        {
//            self.eraserPressureCharacteristic = characteristic;
//            // [peripheral setNotifyValue:YES forCharacteristic:characteristic];
//        }
        if (!self.numTipPressesCharacteristic &&
            [characteristic.UUID isEqual:[FTPenDebugServiceUUIDs numTipPresses]])
        {
            self.numTipPressesCharacteristic = characteristic;
        }
        else if (!self.numEraserPressesCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenDebugServiceUUIDs numEraserPresses]])
        {
            self.numEraserPressesCharacteristic = characteristic;
        }
        else if (!self.numFailedConnectionsCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenDebugServiceUUIDs numFailedConnections]])
        {
            self.numFailedConnectionsCharacteristic = characteristic;
        }
        else if (!self.numSuccessfulConnectionsCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenDebugServiceUUIDs numSuccessfulConnections]])
        {
            self.numSuccessfulConnectionsCharacteristic = characteristic;
        }
        else if (!self.totalOnTimeCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenDebugServiceUUIDs totalOnTime]])
        {
            self.totalOnTimeCharacteristic = characteristic;
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

    if ([characteristic.UUID isEqual:[FTPenDebugServiceUUIDs numTipPresses]])
    {
        _numTipPresses = [characteristic valueAsNSUInteger];
        [self.delegate didUpdateDebugProperties];
    }
    else if ([characteristic.UUID isEqual:[FTPenDebugServiceUUIDs numEraserPresses]])
    {
        _numEraserPresses = [characteristic valueAsNSUInteger];
        [self.delegate didUpdateDebugProperties];
    }
    else if ([characteristic.UUID isEqual:[FTPenDebugServiceUUIDs numFailedConnections]])
    {
        _numFailedConnections = [characteristic valueAsNSUInteger];
        [self.delegate didUpdateDebugProperties];
    }
    else if ([characteristic.UUID isEqual:[FTPenDebugServiceUUIDs numSuccessfulConnections]])
    {
        _numSuccessfulConnections = [characteristic valueAsNSUInteger];
        [self.delegate didUpdateDebugProperties];
    }
    else if ([characteristic.UUID isEqual:[FTPenDebugServiceUUIDs totalOnTime]])
    {
        _totalOnTimeSeconds = [characteristic valueAsNSUInteger];
        [self.delegate didUpdateDebugProperties];
    }
    else if ([characteristic.UUID isEqual:[FTPenDebugServiceUUIDs manufacturingID]])
    {
        _manufacturingID = [characteristic valueAsNSString];

        [self.delegate didReadManufacturingID:self.manufacturingID];
        [self.delegate didUpdateDebugProperties];
    }
    else if ([characteristic.UUID isEqual:[FTPenDebugServiceUUIDs lastErrorCode]])
    {
        [self.delegate didUpdateDebugProperties];
    }
    else if ([characteristic.UUID isEqual:[FTPenDebugServiceUUIDs longPressTime]])
    {
        _longPressTimeMilliseconds = [characteristic valueAsNSUInteger];
        [self.delegate didUpdateDebugProperties];
    }
    else if ([characteristic.UUID isEqual:[FTPenDebugServiceUUIDs connectionTime]])
    {
        _connectionTimeSeconds = [characteristic valueAsNSUInteger];
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
