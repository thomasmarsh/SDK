//
//  FTPenServiceClient.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTError.h"
#import "FTPenServiceClient.h"
#import "FTServiceUUIDs.h"

@interface FTPenServiceClient ()

@property (nonatomic) CBPeripheral *peripheral;

@property (nonatomic) CBService *penService;
@property (nonatomic) CBCharacteristic *isTipPressedCharacteristic;
@property (nonatomic) CBCharacteristic *isEraserPressedCharacteristic;
@property (nonatomic) CBCharacteristic *batteryLevelCharacteristic;
@property (nonatomic) CBCharacteristic *shouldSwingCharacteristic;
@property (nonatomic) CBCharacteristic *shouldPowerOffCharacteristic;

@property (nonatomic, readwrite) NSDate *lastTipReleaseTime;

@property (nonatomic) BOOL isReady;
@property (nonatomic) BOOL shouldPowerOff;

@end

@implementation FTPenServiceClient

- (id)initWithPeripheral:(CBPeripheral *)peripheral
{
    self = [super init];
    if (self)
    {
        _peripheral = peripheral;
        _requiresTipBePressedToBecomeReady = YES;
    }
    return self;
}

- (BOOL)isTipPressed
{
    if (self.isTipPressedCharacteristic.value.length > 0)
    {
        return ((const char *)self.isTipPressedCharacteristic.value.bytes)[0] != 0;
    }

    return NO;
}

- (BOOL)isEraserPressed
{
    if (self.isEraserPressedCharacteristic.value.length > 0)
    {
        return ((const char *)self.isEraserPressedCharacteristic.value.bytes)[0] != 0;
    }

    return NO;
}

- (NSInteger)batteryLevel
{
    if (self.batteryLevelCharacteristic.value.length > 0)
    {
        return ((const char *)self.batteryLevelCharacteristic.value.bytes)[0];
    }

    return -1;
}

- (void)setIsReady:(BOOL)isReady
{
    _isReady = isReady;

    [self.delegate penServiceClient:self isReadyDidChange:isReady];
}

- (void)startSwinging
{
    if (self.shouldSwingCharacteristic)
    {
        NSData *data = [NSData dataWithBytes:"1" length:1];
        [self.peripheral writeValue:data
                  forCharacteristic:self.shouldSwingCharacteristic
                               type:CBCharacteristicWriteWithResponse];
    }
    else
    {
        NSLog(@"ShouldSwing characteristic not initialized.");
    }
}

- (void)powerOff
{
    _isPoweringOff = YES;

    if (self.shouldPowerOffCharacteristic)
    {
        NSData *data = [NSData dataWithBytes:"1" length:1];
        [self.peripheral writeValue:data
                  forCharacteristic:self.shouldPowerOffCharacteristic
                               type:CBCharacteristicWriteWithResponse];
    }
    else
    {
        NSLog(@"ShouldPowerOff characteristic not initialized.");
    }
}

#pragma mark - FTServiceClient

- (NSArray *)peripheral:(CBPeripheral *)peripheral isConnectedDidChange:(BOOL)isConnected
{
    if (isConnected)
    {
        return @[[FTPenServiceUUIDs penService]];
    }
    else
    {
        self.penService = nil;
        self.isTipPressedCharacteristic = nil;
        self.isEraserPressedCharacteristic = nil;
        self.batteryLevelCharacteristic = nil;
        self.shouldSwingCharacteristic = nil;
        self.shouldPowerOffCharacteristic = nil;

        return nil;
    }
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (!self.penService)
    {
        self.penService = [FTServiceClient findServiceWithPeripheral:peripheral
                                                             andUUID:[FTPenServiceUUIDs penService]];

        if (self.penService)
        {
            NSArray *characteristics = @[[FTPenServiceUUIDs isTipPressed],
                                         [FTPenServiceUUIDs isEraserPressed],
                                         [FTPenServiceUUIDs batteryLevel],
                                         [FTPenServiceUUIDs shouldSwing],
                                         [FTPenServiceUUIDs shouldPowerOff]
                                         ];
//            NSArray *characteristics = @[[FTPenServiceUUIDs isTipPressed],
//                                         [FTPenServiceUUIDs isEraserPressed],
//                                         [FTPenServiceUUIDs shouldSwing],
//                                         [FTPenServiceUUIDs shouldPowerOff],
//                                         [FTPenServiceUUIDs batteryVoltage],
//                                         [FTPenServiceUUIDs inactivityTime]
//                                         ];

            [peripheral discoverCharacteristics:characteristics forService:self.penService];
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
        // IsTipPressed
        if (!self.isTipPressedCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs isTipPressed]])
        {
            self.isTipPressedCharacteristic = characteristic;
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }

        // IsEraserPressed
        if (!self.isEraserPressedCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs isEraserPressed]])
        {
            self.isEraserPressedCharacteristic = characteristic;
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }

        // BatteryLevel
        if (!self.batteryLevelCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs batteryLevel]])
        {
            self.batteryLevelCharacteristic = characteristic;
            [peripheral readValueForCharacteristic:characteristic];
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }

        // ShouldSwing
        if (!self.shouldSwingCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs shouldSwing]])
        {
            self.shouldSwingCharacteristic = characteristic;
        }

        // ShouldPowerOff
        if (!self.shouldPowerOffCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs shouldPowerOff]])
        {
            self.shouldPowerOffCharacteristic = characteristic;
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

    if ([characteristic isEqual:self.isTipPressedCharacteristic])
    {
        // To avoid race conditions, it's crucial that we start listening for changes in the characteristic
        // before reading its value for the first time.
        NSAssert(self.isTipPressedCharacteristic.isNotifying,
                 @"The IsTipPressed characteristic must be notifying before we first read its value.");

        BOOL isTipPressed = self.isTipPressed;
        NSLog(@"IsTipPressed did update value: %d.", isTipPressed);

        if (self.isReady)
        {
            if (!isTipPressed)
            {
                self.lastTipReleaseTime = [NSDate date];
            }

            // This must be called *after* updating the lastTipReleaseTime property since the delegate code
            // may need to take that property into account.
            [self.delegate penServiceClient:self isTipPressedDidChange:isTipPressed];
        }
        else
        {
            if (!self.requiresTipBePressedToBecomeReady || isTipPressed)
            {
                self.isReady = YES;
            }
            else
            {
                NSDictionary *userInfo = @{ NSLocalizedDescriptionKey :
                                                @"The pen tip must be pressed to finalize the connection." };
                NSError *error = [NSError errorWithDomain:kFiftyThreeErrorDomain
                                                     code:FTPenErrorConnectionFailedTipNotPressed
                                                 userInfo:userInfo];
                [self.delegate penServiceClient:self didEncounterError:error];
            }
        }
    }
    else if ([characteristic isEqual:self.isEraserPressedCharacteristic])
    {
        // To avoid race conditions, it's crucial that we start listening for changes in the characteristic
        // before reading its value for the first time.
        NSAssert(self.isEraserPressedCharacteristic.isNotifying,
                 @"The IsEraserPressed characteristic must be notifying before we first read its value.");

        BOOL isEraserPressed = self.isEraserPressed;
        [self.delegate penServiceClient:self isEraserPressedDidChange:isEraserPressed];

        NSLog(@"IsEraserPressed did update value: %d.", isEraserPressed);
    }
    else if ([characteristic isEqual:self.batteryLevelCharacteristic])
    {
        NSInteger batteryLevel = self.batteryLevel;
        [self.delegate penServiceClient:self batteryLevelDidChange:batteryLevel];

        NSLog(@"BatteryLevel did update value: %d.", batteryLevel);
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

    if (characteristic.isNotifying)
    {
        // Once we start listening for changes in the characteristic it's safe to read its value. (We avoid
        // the opposite order since that might lead to a race condidtion where we miss a change in the
        // characteristic.)
        if ([characteristic isEqual:self.isTipPressedCharacteristic] ||
            [characteristic isEqual:self.isEraserPressedCharacteristic])
        {
            [peripheral readValueForCharacteristic:characteristic];
        }
    }
    else
    {
        // TODO: Is this an error case that needs to be handled.
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
}

@end