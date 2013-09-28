//
//  FTPenUsageServiceClient.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "CBCharacteristic+Helpers.h"
#import "CBPeripheral+Helpers.h"
#import "FTPenUsageServiceClient.h"
#import "FTServiceUUIDs.h"

@interface FTPenUsageServiceClient ()

@property (nonatomic) CBPeripheral *peripheral;

@property (nonatomic) CBService *penUsageService;

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

@implementation FTPenUsageServiceClient

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

- (void)readUsageProperties
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

- (NSArray *)ensureServicesForConnectionState:(BOOL)isConnected;
{
    if (isConnected)
    {
        return (self.penUsageService ?
                nil :
                @[[FTPenUsageServiceUUIDs penUsageService]]);
    }
    else
    {
        self.penUsageService = nil;
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

    if (!self.penUsageService)
    {
        self.penUsageService = [FTServiceClient findServiceWithPeripheral:peripheral
                                                                  andUUID:[FTPenUsageServiceUUIDs penUsageService]];

        NSArray *characteristics = @[//[FTPenUsageServiceUUIDs tipPressure],
                                     //[FTPenUsageServiceUUIDs eraserPressure],
                                     [FTPenUsageServiceUUIDs numTipPresses],
                                     [FTPenUsageServiceUUIDs numEraserPresses],
                                     [FTPenUsageServiceUUIDs numFailedConnections],
                                     [FTPenUsageServiceUUIDs numSuccessfulConnections],
                                     [FTPenUsageServiceUUIDs totalOnTime],
                                     [FTPenUsageServiceUUIDs manufacturingID],
                                     [FTPenUsageServiceUUIDs lastErrorCode],
                                     [FTPenUsageServiceUUIDs longPressTime],
                                     [FTPenUsageServiceUUIDs connectionTime]
                                     ];

        [peripheral discoverCharacteristics:characteristics forService:self.penUsageService];
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

    if (service != self.penUsageService)
    {
        return;
    }

    for (CBCharacteristic *characteristic in service.characteristics)
    {
//        if (!self.tipPressureCharacteristic &&
//                 [characteristic.UUID isEqual:[FTPenUsageServiceUUIDs tipPressure]])
//        {
//            self.tipPressureCharacteristic = characteristic;
//            // [peripheral setNotifyValue:YES forCharacteristic:characteristic];
//        }
//        else if (!self.eraserPressureCharacteristic &&
//                 [characteristic.UUID isEqual:[FTPenUsageServiceUUIDs eraserPressure]])
//        {
//            self.eraserPressureCharacteristic = characteristic;
//            // [peripheral setNotifyValue:YES forCharacteristic:characteristic];
//        }
        if (!self.numTipPressesCharacteristic &&
            [characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numTipPresses]])
        {
            self.numTipPressesCharacteristic = characteristic;
            [self.peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.numEraserPressesCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numEraserPresses]])
        {
            self.numEraserPressesCharacteristic = characteristic;
            [self.peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.numFailedConnectionsCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numFailedConnections]])
        {
            self.numFailedConnectionsCharacteristic = characteristic;
            [self.peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.numSuccessfulConnectionsCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numSuccessfulConnections]])
        {
            self.numSuccessfulConnectionsCharacteristic = characteristic;
            [self.peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.totalOnTimeCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenUsageServiceUUIDs totalOnTime]])
        {
            self.totalOnTimeCharacteristic = characteristic;
            [self.peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.manufacturingIDCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenUsageServiceUUIDs manufacturingID]])
        {
            self.manufacturingIDCharacteristic = characteristic;
            [self.peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.lastErrorCodeCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenUsageServiceUUIDs lastErrorCode]])
        {
            self.lastErrorCodeCharacteristic = characteristic;
            [self.peripheral readValueForCharacteristic:characteristic];
            [peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.longPressTimeCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenUsageServiceUUIDs longPressTime]])
        {
            self.longPressTimeCharacteristic = characteristic;
            [self.peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.connectionTimeCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenUsageServiceUUIDs connectionTime]])
        {
            self.connectionTimeCharacteristic = characteristic;
            [self.peripheral readValueForCharacteristic:characteristic];
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

    BOOL didUpdate = NO;
    NSMutableSet *updatedProperties = [NSMutableSet set];

    if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numTipPresses]])
    {
        _numTipPresses = [characteristic valueAsNSUInteger];
        didUpdate = YES;
        [updatedProperties addObject:kFTPenNumTipPressesPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numEraserPresses]])
    {
        _numEraserPresses = [characteristic valueAsNSUInteger];
        didUpdate = YES;
        [updatedProperties addObject:kFTPenNumEraserPressesPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numFailedConnections]])
    {
        _numFailedConnections = [characteristic valueAsNSUInteger];
        didUpdate = YES;
        [updatedProperties addObject:kFTPenNumFailedConnectionsPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numSuccessfulConnections]])
    {
        _numSuccessfulConnections = [characteristic valueAsNSUInteger];
        didUpdate = YES;
        [updatedProperties addObject:kFTPenNumSuccessfulConnectionsPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs totalOnTime]])
    {
        _totalOnTimeSeconds = [characteristic valueAsNSUInteger];
        didUpdate = YES;
        [updatedProperties addObject:kFTPenTotalOnTimeSecondsPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs manufacturingID]])
    {
        _manufacturingID = [characteristic valueAsNSString];

        [self.delegate didReadManufacturingID:self.manufacturingID];
        didUpdate = YES;
        [updatedProperties addObject:kFTPenManufacturingIDPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs lastErrorCode]])
    {
        didUpdate = YES;
        [updatedProperties addObject:kFTPenLastErrorCodePropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs longPressTime]])
    {
        _longPressTimeMilliseconds = [characteristic valueAsNSUInteger];
        didUpdate = YES;
        [updatedProperties addObject:kFTPenLongPressTimeMillisecondsPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs connectionTime]])
    {
        _connectionTimeSeconds = [characteristic valueAsNSUInteger];
        didUpdate = YES;
        [updatedProperties addObject:kFTPenConnectionTimeSecondsPropertyName];
    }

    if (didUpdate)
    {
        [self.delegate didUpdateUsageProperties:updatedProperties];
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
