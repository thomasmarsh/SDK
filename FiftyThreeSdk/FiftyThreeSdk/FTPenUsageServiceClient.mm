//
//  FTPenUsageServiceClient.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import "CBCharacteristic+Helpers.h"
#import "CBPeripheral+Helpers.h"
#import "Common/Log.h"
#import "FTLogPrivate.h"
#import "FTPenUsageServiceClient.h"
#import "FTServiceUUIDs.h"

using namespace fiftythree::common;

@interface FTPenUsageServiceClient ()

@property (nonatomic) CBPeripheral *peripheral;

@property (nonatomic) CBService *penUsageService;

@property (nonatomic) CBCharacteristic *numTipPressesCharacteristic;
@property (nonatomic) CBCharacteristic *numEraserPressesCharacteristic;
@property (nonatomic) CBCharacteristic *numFailedConnectionsCharacteristic;
@property (nonatomic) CBCharacteristic *numSuccessfulConnectionsCharacteristic;
@property (nonatomic) CBCharacteristic *numResetsCharacteristic;
@property (nonatomic) CBCharacteristic *numLinkTerminationsCharacteristic;
@property (nonatomic) CBCharacteristic *numDroppedNotificationsCharacteristic;
@property (nonatomic) CBCharacteristic *connectedSecondsCharacteristic;

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

- (void)readUsageProperties
{
    [self readValueForCharacteristic:self.numTipPressesCharacteristic];
    [self readValueForCharacteristic:self.numEraserPressesCharacteristic];
    [self readValueForCharacteristic:self.numFailedConnectionsCharacteristic];
    [self readValueForCharacteristic:self.numSuccessfulConnectionsCharacteristic];
    [self readValueForCharacteristic:self.numResetsCharacteristic];
    [self readValueForCharacteristic:self.numLinkTerminationsCharacteristic];
    [self readValueForCharacteristic:self.numDroppedNotificationsCharacteristic];
    [self readValueForCharacteristic:self.connectedSecondsCharacteristic];
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
        self.numResetsCharacteristic = nil;
        self.numLinkTerminationsCharacteristic = nil;
        self.numDroppedNotificationsCharacteristic = nil;
        self.connectedSecondsCharacteristic = nil;
    }

    return nil;
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error)
    {
        MLOG_ERROR(FTLogSDK, "Error discovering services: %s",
                   DESC(error.localizedDescription));

        // TODO: Report failed state
        return;
    }

    if (!self.penUsageService)
    {
        self.penUsageService = [FTServiceClient findServiceWithPeripheral:peripheral
                                                                  andUUID:[FTPenUsageServiceUUIDs penUsageService]];
        if (self.penUsageService)
        {
            NSArray *characteristics = @[[FTPenUsageServiceUUIDs numTipPresses],
                                         [FTPenUsageServiceUUIDs numEraserPresses],
                                         [FTPenUsageServiceUUIDs numFailedConnections],
                                         [FTPenUsageServiceUUIDs numSuccessfulConnections],
                                         [FTPenUsageServiceUUIDs numResets],
                                         [FTPenUsageServiceUUIDs numLinkTerminations],
                                         [FTPenUsageServiceUUIDs numDroppedNotifications],
                                         [FTPenUsageServiceUUIDs connectedSeconds]
                                         ];

            [peripheral discoverCharacteristics:characteristics forService:self.penUsageService];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error
{
    if (error || service.characteristics.count == 0)
    {
        MLOG_ERROR(FTLogSDK, "Error discovering characteristics: %s",
                   DESC(error.localizedDescription));

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
        else if (!self.numResetsCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numResets]])
        {
            self.numResetsCharacteristic = characteristic;
            [self.peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.numLinkTerminationsCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numLinkTerminations]])
        {
            self.numLinkTerminationsCharacteristic = characteristic;
            [self.peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.numDroppedNotificationsCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numDroppedNotifications]])
        {
            self.numDroppedNotificationsCharacteristic = characteristic;
            [self.peripheral readValueForCharacteristic:characteristic];
        }
        else if (!self.connectedSecondsCharacteristic &&
                 [characteristic.UUID isEqual:[FTPenUsageServiceUUIDs connectedSeconds]])
        {
            self.connectedSecondsCharacteristic = characteristic;
            [self.peripheral readValueForCharacteristic:characteristic];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    if (error)
    {
        if ([FTPenUsageServiceUUIDs nameForUUID:characteristic.UUID])
        {
            MLOG_ERROR(FTLogSDK, "Error updating value for characteristic: %s error: %s.",
                       DESC([FTPenServiceUUIDs nameForUUID:characteristic.UUID]),
                       DESC(error.localizedDescription));

            // TODO: Report failed state
        }
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
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numResets]])
    {
        _numResets = [characteristic valueAsNSUInteger];
        [updatedProperties addObject:kFTPenNumResetsPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numLinkTerminations]])
    {
        _numLinkTerminations = [characteristic valueAsNSUInteger];
        [updatedProperties addObject:kFTPenNumLinkTerminationsPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs numDroppedNotifications]])
    {
        _numDroppedNotifications = [characteristic valueAsNSUInteger];
        [updatedProperties addObject:kFTPenNumDroppedNotificationsPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenUsageServiceUUIDs connectedSeconds]])
    {
        _connectedSeconds = [characteristic valueAsNSUInteger];
        [updatedProperties addObject:kFTPenConnectedSecondsPropertyName];
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
        MLOG_ERROR(FTLogSDK, "Error changing notification state: %s.", DESC(error.localizedDescription));

        // TODO: Report failed state
        return;
    }
}

@end
