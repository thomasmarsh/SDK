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

@property (nonatomic) CBCharacteristic *numTipPressesCharacteristic;
@property (nonatomic) CBCharacteristic *numEraserPressesCharacteristic;
@property (nonatomic) CBCharacteristic *numFailedConnectionsCharacteristic;
@property (nonatomic) CBCharacteristic *numSuccessfulConnectionsCharacteristic;
@property (nonatomic) CBCharacteristic *totalOnTimeCharacteristic;
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

- (void)readUsageProperties
{
    [self readValueForCharacteristic:self.numTipPressesCharacteristic];
    [self readValueForCharacteristic:self.numEraserPressesCharacteristic];
    [self readValueForCharacteristic:self.numFailedConnectionsCharacteristic];
    [self readValueForCharacteristic:self.numSuccessfulConnectionsCharacteristic];
    [self readValueForCharacteristic:self.totalOnTimeCharacteristic];
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
        self.numTipPressesCharacteristic = nil;
        self.numFailedConnectionsCharacteristic = nil;
        self.numSuccessfulConnectionsCharacteristic = nil;
        self.totalOnTimeCharacteristic = nil;
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

        NSArray *characteristics = @[[FTPenUsageServiceUUIDs numTipPresses],
                                     [FTPenUsageServiceUUIDs numEraserPresses],
                                     [FTPenUsageServiceUUIDs numFailedConnections],
                                     [FTPenUsageServiceUUIDs numSuccessfulConnections],
                                     [FTPenUsageServiceUUIDs totalOnTime],
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

    NSMutableSet *updatedProperties = [NSMutableSet set];

    if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numTipPresses]])
    {
        _numTipPresses = [characteristic valueAsNSUInteger];
        [updatedProperties addObject:kFTPenNumTipPressesPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numEraserPresses]])
    {
        _numEraserPresses = [characteristic valueAsNSUInteger];
        [updatedProperties addObject:kFTPenNumEraserPressesPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numFailedConnections]])
    {
        _numFailedConnections = [characteristic valueAsNSUInteger];
        [updatedProperties addObject:kFTPenNumFailedConnectionsPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numSuccessfulConnections]])
    {
        _numSuccessfulConnections = [characteristic valueAsNSUInteger];
        [updatedProperties addObject:kFTPenNumSuccessfulConnectionsPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs totalOnTime]])
    {
        _totalOnTimeSeconds = [characteristic valueAsNSUInteger];
        [updatedProperties addObject:kFTPenTotalOnTimeSecondsPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs longPressTime]])
    {
        _longPressTimeMilliseconds = [characteristic valueAsNSUInteger];
        [updatedProperties addObject:kFTPenLongPressTimeMillisecondsPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs connectionTime]])
    {
        _connectionTimeSeconds = [characteristic valueAsNSUInteger];
        [updatedProperties addObject:kFTPenConnectionTimeSecondsPropertyName];
    }

    if (updatedProperties.count > 0)
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

@end
