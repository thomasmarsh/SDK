//
//  FTPenServiceClient.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "CBCharacteristic+Helpers.h"
#import "CBPeripheral+Helpers.h"
#import "FTError.h"
#import "FTPenServiceClient.h"
#import "FTServiceUUIDs.h"

@interface FTPenServiceClient ()

@property (nonatomic) CBPeripheral *peripheral;

@property (nonatomic) CBService *penService;
@property (nonatomic) CBCharacteristic *isTipPressedCharacteristic;
@property (nonatomic) CBCharacteristic *isEraserPressedCharacteristic;
@property (nonatomic) CBCharacteristic *tipPressureCharacteristic;
@property (nonatomic) CBCharacteristic *eraserPressureCharacteristic;
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
    return [self.isTipPressedCharacteristic valueAsBOOL];
}

- (BOOL)isEraserPressed
{
    return [self.isEraserPressedCharacteristic valueAsBOOL];
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
    [self.peripheral writeBOOL:YES
             forCharacteristic:self.shouldSwingCharacteristic
                          type:CBCharacteristicWriteWithResponse];
}

- (void)powerOff
{
    _isPoweringOff = YES;

    [self.peripheral writeBOOL:YES
             forCharacteristic:self.shouldPowerOffCharacteristic
                          type:CBCharacteristicWriteWithResponse];
}

#pragma mark - FTServiceClient

- (NSArray *)ensureServicesForConnectionState:(BOOL)isConnected;
{
    if (isConnected)
    {
        return (self.penService ?
                nil :
                @[[FTPenServiceUUIDs penService]]);
    }
    else
    {
        self.penService = nil;
        self.isTipPressedCharacteristic = nil;
        self.isEraserPressedCharacteristic = nil;
        self.tipPressureCharacteristic = nil;
        self.eraserPressureCharacteristic = nil;
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
                                         [FTPenServiceUUIDs tipPressure],
                                         [FTPenServiceUUIDs isEraserPressed],
                                         [FTPenServiceUUIDs eraserPressure],
                                         [FTPenServiceUUIDs batteryLevel],
                                         [FTPenServiceUUIDs shouldSwing],
                                         [FTPenServiceUUIDs shouldPowerOff]
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

    if (service != self.penService)
    {
        return;
    }

    for (CBCharacteristic *characteristic in service.characteristics)
    {
        // IsTipPressed
        if (!self.isTipPressedCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs isTipPressed]])
        {
            self.isTipPressedCharacteristic = characteristic;
        }

        // IsEraserPressed
        if (!self.isEraserPressedCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs isEraserPressed]])
        {
            self.isEraserPressedCharacteristic = characteristic;
        }

        // TipPressure
        if (!self.tipPressureCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs tipPressure]])
        {
            self.tipPressureCharacteristic = characteristic;
        }

        // EraserPressure
        if (!self.eraserPressureCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs eraserPressure]])
        {
            self.eraserPressureCharacteristic = characteristic;
        }

        // BatteryLevel
        if (!self.batteryLevelCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs batteryLevel]])
        {
            self.batteryLevelCharacteristic = characteristic;
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

    [self ensureNotifications];
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
//        NSLog(@"IsTipPressed did update value: %d", isTipPressed);

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

//        NSLog(@"IsEraserPressed did update value: %d", isEraserPressed);
    }
    if ([characteristic.UUID isEqual:[FTPenServiceUUIDs tipPressure]])
    {
        _tipPressure = (32767 - [characteristic valueAsNSUInteger]) / 32767.f;
        [self.delegate penServiceClient:self didUpdateTipPressure:_tipPressure];
    }
    else if ([characteristic.UUID isEqual:[FTPenServiceUUIDs eraserPressure]])
    {
        _eraserPressure = (32767 - [characteristic valueAsNSUInteger]) / 32767.f;
        [self.delegate penServiceClient:self didUpdateEraserPressure:_eraserPressure];
    }
    else if ([characteristic isEqual:self.batteryLevelCharacteristic])
    {
        NSInteger batteryLevel = self.batteryLevel;
        [self.delegate penServiceClient:self batteryLevelDidChange:batteryLevel];

//        NSLog(@"BatteryLevel did update value: %d", batteryLevel);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error changing notification state: %@", error.localizedDescription);
        // TODO: Report failed state
        return;
    }

    if (characteristic.isNotifying)
    {
        // Once we start listening for changes in the characteristic it's safe to read its value. (We avoid
        // the opposite order since that might lead to a race condidtion where we miss a change in the
        // characteristic.)
        [peripheral readValueForCharacteristic:characteristic];
    }

    [self ensureNotifications];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
}

#pragma mark -

- (void)ensureNotifications
{
    const BOOL isTipPressedNotifying = (self.isTipPressedCharacteristic &&
                                        self.isTipPressedCharacteristic.isNotifying);
    if (!isTipPressedNotifying)
    {
        [self.peripheral setNotifyValue:YES forCharacteristic:self.isTipPressedCharacteristic];
    }

    if (isTipPressedNotifying)
    {
        if (self.isEraserPressedCharacteristic && !self.isEraserPressedCharacteristic.isNotifying)
        {
            [self.peripheral setNotifyValue:YES
                          forCharacteristic:self.isEraserPressedCharacteristic];
        }

        if (self.tipPressureCharacteristic && !self.tipPressureCharacteristic.isNotifying)
        {
            // TODO: Enable notifications on tip pressure
//            [self.peripheral setNotifyValue:YES
//                          forCharacteristic:self.tipPressureCharacteristic];
        }

        if (self.eraserPressureCharacteristic && !self.eraserPressureCharacteristic.isNotifying)
        {
            // TODO: Enable notifications on eraser pressure
//            [self.peripheral setNotifyValue:YES
//                          forCharacteristic:self.eraserPressureCharacteristic];
        }

        if (self.batteryLevelCharacteristic && !self.batteryLevelCharacteristic.isNotifying)
        {
            [self.peripheral setNotifyValue:YES
                          forCharacteristic:self.batteryLevelCharacteristic];
        }
    }
}

@end
