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
@property (nonatomic) CBCharacteristic *hasListenerCharacteristic;
@property (nonatomic) CBCharacteristic *shouldSwingCharacteristic;
@property (nonatomic) CBCharacteristic *shouldPowerOffCharacteristic;
@property (nonatomic) CBCharacteristic *manufacturingIDCharacteristic;
@property (nonatomic) CBCharacteristic *lastErrorCodeCharacteristic;

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
        return [self.batteryLevelCharacteristic valueAsNSUInteger];
    }

    return -1;
}

- (void)setHasListener:(BOOL)hasListener
{
    _hasListener = hasListener;
    [self writeHasListener];
}

- (void)writeHasListener
{
    if (self.hasListenerCharacteristic)
    {
        const uint8_t hasListenerByte = (self.hasListener ? 1 : 0);
        [self.peripheral writeValue:[NSData dataWithBytes:&hasListenerByte length:1]
                  forCharacteristic:self.hasListenerCharacteristic
                               type:CBCharacteristicWriteWithResponse];
    }
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

- (void)setManufacturingID:(NSString *)manufacturingID
{
    NSAssert(manufacturingID.length == 15, @"Manufacturing ID must be 15 characters");

    [self.peripheral writeNSString:manufacturingID
                 forCharacteristic:self.manufacturingIDCharacteristic
                              type:CBCharacteristicWriteWithResponse];
}

- (FTPenLastErrorCode *)lastErrorCode
{
    FTPenLastErrorCode *lastErrorCode;
    lastErrorCode.lastErrorID = 0;
    lastErrorCode.lastErrorValue = 0;

    if (self.lastErrorCodeCharacteristic)
    {
        NSData *data = self.lastErrorCodeCharacteristic.value;
        if (data.length == 2 * sizeof(uint32_t))
        {
            lastErrorCode.lastErrorID = CFSwapInt32LittleToHost(((uint32_t *)data.bytes)[0]);
            lastErrorCode.lastErrorValue = CFSwapInt32LittleToHost(((uint32_t *)data.bytes)[1]);
        }
    }

    return lastErrorCode;
}

- (void)readManufacturingID
{
    if (self.manufacturingIDCharacteristic)
    {
        [self.peripheral readValueForCharacteristic:self.manufacturingIDCharacteristic];
    }
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
        self.hasListenerCharacteristic = nil;
        self.shouldSwingCharacteristic = nil;
        self.shouldPowerOffCharacteristic = nil;
        self.manufacturingIDCharacteristic = nil;
        self.lastErrorCodeCharacteristic = nil;

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
                                         [FTPenServiceUUIDs hasListener],
                                         [FTPenServiceUUIDs eraserPressure],
                                         [FTPenServiceUUIDs batteryLevel],
                                         [FTPenServiceUUIDs shouldSwing],
                                         [FTPenServiceUUIDs shouldPowerOff],
                                         [FTPenServiceUUIDs manufacturingID],
                                         [FTPenServiceUUIDs lastErrorCode]
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

        if (!self.hasListenerCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs hasListener]])
        {
            self.hasListener = YES;
            [self writeHasListener];
            self.hasListenerCharacteristic = characteristic;
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

        // Manufacturing ID
        if (!self.manufacturingIDCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs manufacturingID]])
        {
            self.manufacturingIDCharacteristic = characteristic;
        }

        // Last Error Code
        if (!self.lastErrorCodeCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs lastErrorCode]])
        {
            self.lastErrorCodeCharacteristic = characteristic;
        }
    }

    [self ensureCharacteristicNotificationsAndInitialization];
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
    else if ([characteristic.UUID isEqual:[FTPenServiceUUIDs manufacturingID]])
    {
        _manufacturingID = [characteristic valueAsNSString];

        [self.delegate penServiceClient:self didReadManufacturingID:self.manufacturingID];
        [updatedProperties addObject:kFTPenManufacturingIDPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenServiceUUIDs lastErrorCode]])
    {
        [updatedProperties addObject:kFTPenLastErrorCodePropertyName];
    }

    if (updatedProperties.count > 0)
    {
        [self.delegate penServiceClient:self didUpdatePenProperties:updatedProperties];
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

    [self ensureCharacteristicNotificationsAndInitialization];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    if (characteristic == self.manufacturingIDCharacteristic)
    {
        if (error)
        {
            [self.delegate penServiceClientDidFailToWriteManufacturingID:self];
        }
        else
        {
            [self.delegate penServiceClientDidWriteManufacturingID:self];
        }
    }
    else if (characteristic == self.hasListenerCharacteristic)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenDidWriteHasListenerNotificationName
                                                            object:nil];
    }
}

#pragma mark -

- (void)ensureCharacteristicNotificationsAndInitialization
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
            [self.peripheral readValueForCharacteristic:self.batteryLevelCharacteristic];
        }

        if (self.manufacturingIDCharacteristic && !self.manufacturingID)
        {
            [self.peripheral readValueForCharacteristic:self.manufacturingIDCharacteristic];
        }

        if (self.lastErrorCodeCharacteristic && !self.lastErrorCode)
        {
            [self.peripheral readValueForCharacteristic:self.lastErrorCodeCharacteristic];
        }
    }
}

@end
