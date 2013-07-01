//
//  FTPenServiceClient.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTPenServiceClient.h"
#import "FTServiceUUIDs.h"

@interface FTPenServiceClient ()

@property (nonatomic) CBPeripheral *peripheral;

@property (nonatomic) CBService *penService;
@property (nonatomic) CBCharacteristic *isTipPressedCharacteristic;
@property (nonatomic) CBCharacteristic *isEraserPressedCharacteristic;
@property (nonatomic) CBCharacteristic *shouldSwingCharacteristic;
@property (nonatomic) CBCharacteristic *shouldPowerOffCharacteristic;

@property (nonatomic, readwrite) NSDate *lastTipReleaseTime;

@property (nonatomic) BOOL isReady;

@end

@implementation FTPenServiceClient

- (id)initWithPeripheral:(CBPeripheral *)peripheral
{
    self = [super init];
    if (self)
    {
        _peripheral = peripheral;
    }
    return self;
}

- (BOOL)isTipPressed
{
    if (self.isTipPressedCharacteristic)
    {
        return ((const char *)self.isTipPressedCharacteristic.value.bytes)[0] != 0;
    }

    return NO;
}

- (BOOL)isEraserPressed
{
    if (self.isEraserPressedCharacteristic)
    {
        return ((const char *)self.isEraserPressedCharacteristic.value.bytes)[0] != 0;
    }

    return NO;
}

- (void)setIsReady:(BOOL)isReady
{
    _isReady = isReady;

    [self.delegate penServiceClient:self isReadyDidChange:isReady];
}

- (BOOL)shouldSwing
{
    if (self.shouldSwing)
    {
        return ((const char *)self.shouldSwingCharacteristic.value.bytes)[0] != 0;
    }

    return NO;
}

- (void)setShouldSwing:(BOOL)shouldSwing
{
    if (self.shouldSwingCharacteristic)
    {
        NSData *data = [NSData dataWithBytes:shouldSwing ? "1" : "0" length:1];
        [self.peripheral writeValue:data
                  forCharacteristic:self.shouldSwingCharacteristic
                               type:CBCharacteristicWriteWithResponse];
    }
}

- (BOOL)shouldPowerOff
{
    if (self.shouldPowerOffCharacteristic)
    {
        return ((const char *)self.shouldPowerOffCharacteristic.value.bytes)[0] != 0;
    }

    return NO;
}

- (void)setShouldPowerOff:(BOOL)shouldPowerOff
{
    if (self.shouldPowerOffCharacteristic)
    {
        NSData *data = [NSData dataWithBytes:shouldPowerOff ? "1" : "0" length:1];
        [self.peripheral writeValue:data
                  forCharacteristic:self.shouldPowerOffCharacteristic
                               type:CBCharacteristicWriteWithResponse];
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
                                         [FTPenServiceUUIDs shouldSwing],
                                         [FTPenServiceUUIDs shouldPowerOff],
                                         [FTPenServiceUUIDs batteryVoltage],
                                         [FTPenServiceUUIDs inactivityTime]
                                         ];

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

        // ShouldSwing
        if (!self.shouldSwingCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs shouldSwing]])
        {
            self.shouldSwingCharacteristic = characteristic;
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }

        // ShouldPowerOff
        if (!self.shouldPowerOffCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs shouldPowerOff]])
        {
            self.shouldPowerOffCharacteristic = characteristic;
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

    if ([characteristic isEqual:self.isTipPressedCharacteristic])
    {
        BOOL isTipPressed = self.isTipPressed;

        // TODO: Assumes tip was initially pressed... may not be the case?
        if (!isTipPressed)
        {
            self.lastTipReleaseTime = [NSDate date];
        }

        [self.delegate penServiceClient:self isTipPressedDidChange:isTipPressed];

        NSLog(@"IsTipPressed characteristic changed: %d.", isTipPressed);
    }
    else if ([characteristic isEqual:self.isEraserPressedCharacteristic])
    {
        BOOL isEraserPressed = self.isEraserPressed;
        [self.delegate penServiceClient:self isEraserPressedDidChange:isEraserPressed];

        NSLog(@"IsEraserPressed characteristic changed: %d.", isEraserPressed);
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
        if ([characteristic isEqual:self.isTipPressedCharacteristic])
        {
            self.isReady = YES;
        }
    }
    else
    {
        if ([characteristic isEqual:self.isTipPressedCharacteristic])
        {
            self.isReady = NO;
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
}

@end
