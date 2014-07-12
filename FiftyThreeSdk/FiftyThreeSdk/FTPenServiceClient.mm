//
//  FTPenServiceClient.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "CBCharacteristic+Helpers.h"
#import "CBPeripheral+Helpers.h"
#import "Core/Asserts.h"
#import "Core/Log.h"
#import "FTError.h"
#import "FTLogPrivate.h"
#import "FTPenManager.h"
#import "FTPenServiceClient.h"
#import "FTServiceUUIDs.h"

using namespace fiftythree::core;

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
@property (nonatomic) CBCharacteristic *inactivityTimeoutCharacteristic;
@property (nonatomic) CBCharacteristic *pressureSetupCharacteristic;
@property (nonatomic) CBCharacteristic *manufacturingIDCharacteristic;
@property (nonatomic) CBCharacteristic *lastErrorCodeCharacteristic;
@property (nonatomic) CBCharacteristic *authenticationCodeCharacteristic;
@property (nonatomic) CBCharacteristic *centralIdCharacteristic;

@property (nonatomic) BOOL isTipPressedDidSetNofifyValue;
@property (nonatomic) BOOL isEraserPressedDidSetNofifyValue;
@property (nonatomic) BOOL tipPressureDidSetNofifyValue;
@property (nonatomic) BOOL eraserPressureDidSetNofifyValue;
@property (nonatomic) BOOL batteryLevelDidSetNofifyValue;
@property (nonatomic) BOOL batteryLevelDidReceiveFirstUpdate;
@property (nonatomic) BOOL hasListenerDidSetNofifyValue;
@property (nonatomic) BOOL didInitialReadOfInactivityTimeout;
@property (nonatomic) BOOL didInitialReadOfPressureSetup;
@property (nonatomic) BOOL didInitialReadOfManufacturingID;
@property (nonatomic) BOOL didInitialReadOfLastErrorCode;
@property (nonatomic) BOOL didInitialReadOfAuthenticationCode;
@property (nonatomic) BOOL didInitialReadOfHasListener;

@property (nonatomic, readwrite) NSDate *lastTipReleaseTime;

@property (nonatomic) BOOL isReady;
@property (nonatomic) BOOL shouldPowerOff;

@property (nonatomic) NSTimer *batteryLevelReadTimer;

@end

@implementation FTPenServiceClient

- (id)initWithPeripheral:(CBPeripheral *)peripheral
{
    self = [super init];
    if (self)
    {
        _peripheral = peripheral;
        _requiresTipBePressedToBecomeReady = YES;
        _inactivityTimeout = -1;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [self resetBatteryLevelReadTimer];
}

- (BOOL)isTipPressed
{
    return [self.isTipPressedCharacteristic valueAsBOOL];
}

- (BOOL)isEraserPressed
{
    return [self.isEraserPressedCharacteristic valueAsBOOL];
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
        MLOG_INFO(FTLogSDK, "Set HasListener: %d", self.hasListener);

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

- (void)setInactivityTimeout:(NSInteger)inactivityTimeout
{
    FTAssert(inactivityTimeout >= 0 && inactivityTimeout < 256,
             @"Inactivity timeout in valid range");

    _inactivityTimeout = inactivityTimeout;

    if (self.inactivityTimeoutCharacteristic)
    {
        uint8_t inactivityTimeoutByte = inactivityTimeout;
        [self.peripheral writeValue:[NSData dataWithBytes:&inactivityTimeoutByte length:1]
                  forCharacteristic:self.inactivityTimeoutCharacteristic
                               type:CBCharacteristicWriteWithResponse];
        [self readInactivityTimeout];
    }
}

- (void)readInactivityTimeout
{
    if (self.inactivityTimeoutCharacteristic)
    {
        [self.peripheral readValueForCharacteristic:self.inactivityTimeoutCharacteristic];
    }
}

- (void)setPressureSetup:(FTPenPressureSetup *)pressureSetup
{
    FTAssert(pressureSetup, @"pressureSetup non-nil");

    _pressureSetup = pressureSetup;
    if (self.pressureSetupCharacteristic)
    {
        static int length = 10;
        uint8_t bytes[length];
        NSData *data = [NSData dataWithBytes:bytes length:10];
        [self.pressureSetup writeToNSData:data];

        [self.peripheral writeValue:data
                  forCharacteristic:self.pressureSetupCharacteristic
                               type:CBCharacteristicWriteWithResponse];

        [self.peripheral readValueForCharacteristic:self.pressureSetupCharacteristic];
    }
}

- (void)setManufacturingID:(NSString *)manufacturingID
{
    FTAssert(manufacturingID.length == 15, @"Manufacturing ID must be 15 characters");

    if (self.manufacturingIDCharacteristic)
    {
        [self.peripheral writeNSString:manufacturingID
                     forCharacteristic:self.manufacturingIDCharacteristic
                                  type:CBCharacteristicWriteWithResponse];
    }

    // Setting the manufacturing ID can update the inactivity timeout, so read it as well
    // to ensure we report its most up to date value.
    [self readInactivityTimeout];
}

- (void)setAuthenticationCode:(NSData *)authenticationCode
{
    FTAssert(authenticationCode.length == 20, @"Authentication Code must be 20 bytes");

    if (self.authenticationCodeCharacteristic)
    {
        [self.peripheral writeValue:authenticationCode
                  forCharacteristic:self.authenticationCodeCharacteristic
                               type:CBCharacteristicWriteWithResponse];
    }
}

- (BOOL)canWriteCentralId
{
    return self.centralIdCharacteristic != nil;
}

- (void)setCentralId:(UInt32)centralId
{
    if (self.centralIdCharacteristic)
    {
        _centralId = centralId;

        NSData * data = [NSData dataWithBytes:&_centralId length:4];
        [self.peripheral writeValue:data
                  forCharacteristic:self.centralIdCharacteristic
                               type:CBCharacteristicWriteWithResponse];

        MLOG_INFO(FTLogSDK, "Set CentralId: %x", (unsigned int)self.centralId);
    }
    else
    {
        MLOG_ERROR(FTLogSDK, "Attempted to write CentralId before possible.");
    }
}

- (BOOL)readManufacturingIDAndAuthCode
{
    if (self.manufacturingIDCharacteristic && self.authenticationCodeCharacteristic)
    {
        [self.peripheral readValueForCharacteristic:self.manufacturingIDCharacteristic];
        [self.peripheral readValueForCharacteristic:self.authenticationCodeCharacteristic];

        return YES;
    }

    return NO;
}

- (void)clearLastErrorCode
{
    _lastErrorCode = nil;

    if (self.lastErrorCodeCharacteristic)
    {
        uint32_t value[2] = { 0, 0 };
        NSData *data = [NSData dataWithBytes:&value length:sizeof(value)];
        [self.peripheral writeValue:data
                  forCharacteristic:self.lastErrorCodeCharacteristic
                               type:CBCharacteristicWriteWithResponse];

        [self.peripheral readValueForCharacteristic:self.lastErrorCodeCharacteristic];

        NSSet *updatedProperties = [NSSet setWithArray:@[kFTPenLastErrorCodePropertyName]];
        [self.delegate penServiceClient:self didUpdatePenProperties:updatedProperties];
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
        self.inactivityTimeoutCharacteristic = nil;
        self.pressureSetupCharacteristic = nil;
        self.manufacturingIDCharacteristic = nil;
        self.lastErrorCodeCharacteristic = nil;
        self.authenticationCodeCharacteristic = nil;
        self.centralIdCharacteristic = nil;

        self.isTipPressedDidSetNofifyValue = NO;
        self.isEraserPressedDidSetNofifyValue = NO;
        self.tipPressureDidSetNofifyValue = NO;
        self.eraserPressureDidSetNofifyValue = NO;
        self.hasListenerDidSetNofifyValue = NO;
        self.batteryLevelDidSetNofifyValue = NO;
        self.batteryLevelDidReceiveFirstUpdate = NO;

        self.didInitialReadOfInactivityTimeout = NO;
        self.didInitialReadOfPressureSetup = NO;
        self.didInitialReadOfManufacturingID = NO;
        self.didInitialReadOfLastErrorCode = NO;
        self.didInitialReadOfAuthenticationCode = NO;
        self.didInitialReadOfHasListener = NO;

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
                                         [FTPenServiceUUIDs hasListener],
                                         [FTPenServiceUUIDs tipPressure],
                                         [FTPenServiceUUIDs isEraserPressed],
                                         [FTPenServiceUUIDs eraserPressure],
                                         [FTPenServiceUUIDs batteryLevel],
                                         [FTPenServiceUUIDs shouldSwing],
                                         [FTPenServiceUUIDs shouldPowerOff],
                                         [FTPenServiceUUIDs inactivityTimeout],
                                         [FTPenServiceUUIDs manufacturingID],
                                         [FTPenServiceUUIDs authenticationCode],
                                         [FTPenServiceUUIDs lastErrorCode],
                                         [FTPenServiceUUIDs pressureSetup],
                                         [FTPenServiceUUIDs centralId],
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
        MLOG_ERROR(FTLogSDK, "Error discovering characteristics: %s", DESC(error.localizedDescription));

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

        // HasListener
        if (!self.hasListenerCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs hasListener]])
        {
            self.hasListener = YES;
            self.hasListenerCharacteristic = characteristic;
            [self writeHasListener];
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

        // InactivityTimeout
        if (!self.inactivityTimeoutCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs inactivityTimeout]])
        {
            self.inactivityTimeoutCharacteristic = characteristic;
        }

        // PressureSetup
        if (!self.pressureSetupCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs pressureSetup]])
        {
            self.pressureSetupCharacteristic = characteristic;
        }

        // ManufacturingID
        if (!self.manufacturingIDCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs manufacturingID]])
        {
            self.manufacturingIDCharacteristic = characteristic;
        }

        // LastErrorCode
        if (!self.lastErrorCodeCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs lastErrorCode]])
        {
            self.lastErrorCodeCharacteristic = characteristic;
        }

        // AuthenticationCode
        if (!self.authenticationCodeCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs authenticationCode]])
        {
            self.authenticationCodeCharacteristic = characteristic;
        }

        // CentralId
        if (!self.centralIdCharacteristic &&
            [characteristic.UUID isEqual:[FTPenServiceUUIDs centralId]])
        {
            self.centralIdCharacteristic = characteristic;
        }
    }

    [self ensureCharacteristicNotificationsAndInitialization];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    if (error)
    {
        if ([FTPenServiceUUIDs nameForUUID:characteristic.UUID])
        {
            MLOG_ERROR(FTLogSDK, "Error updating value for characteristic: %s error: %s.",
                       DESC([FTPenServiceUUIDs nameForUUID:characteristic.UUID]),
                       DESC(error.localizedDescription));

            // TODO: Report failed state
        }
        return;
    }

    NSMutableSet *updatedProperties = [NSMutableSet set];

    if ([characteristic isEqual:self.isTipPressedCharacteristic])
    {
        // To avoid race conditions, it's crucial that we start listening for changes in the characteristic
        // before reading its value for the first time.
        FTAssert(self.isTipPressedDidSetNofifyValue,
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
        FTAssert(self.isEraserPressedDidSetNofifyValue,
                 @"The IsEraserPressed characteristic must be notifying before we first read its value.");

        BOOL isEraserPressed = self.isEraserPressed;
        [self.delegate penServiceClient:self isEraserPressedDidChange:isEraserPressed];

//        NSLog(@"IsEraserPressed did update value: %d", isEraserPressed);
    }
    if ([characteristic.UUID isEqual:[FTPenServiceUUIDs tipPressure]])
    {
        _tipPressure = [characteristic valueAsNSUInteger];
        [self.delegate penServiceClient:self didUpdateTipPressure:_tipPressure];
    }
    else if ([characteristic.UUID isEqual:[FTPenServiceUUIDs eraserPressure]])
    {
        _eraserPressure = [characteristic valueAsNSUInteger];
        [self.delegate penServiceClient:self didUpdateEraserPressure:_eraserPressure];
    }
    else if ([characteristic isEqual:self.batteryLevelCharacteristic])
    {
        // Ignore the first battery level update that results from setting notification on the
        // characterisitic. We only want to pay attention to notifications from the peripheral itself.
        if (self.batteryLevelDidReceiveFirstUpdate)
        {
            _batteryLevel = (self.batteryLevelCharacteristic.value.length > 0 ?
                             @([self.batteryLevelCharacteristic valueAsNSUInteger]) :
                             nil);
            [self.delegate penServiceClient:self batteryLevelDidChange:self.batteryLevel];

            [self resetBatteryLevelReadTimer];

            //NSLog(@"BatteryLevel did update value: %@", self.batteryLevel);
        }
        else
        {
            self.batteryLevelDidReceiveFirstUpdate = YES;
        }
    }
    else if ([characteristic isEqual:self.inactivityTimeoutCharacteristic])
    {
        _inactivityTimeout = [self.inactivityTimeoutCharacteristic valueAsNSUInteger];
        [updatedProperties addObject:kFTPenInactivityTimeoutPropertyName];
    }
    else if ([characteristic isEqual:self.pressureSetupCharacteristic])
    {
        if (characteristic.value.length == 10)
        {
            _pressureSetup = [[FTPenPressureSetup alloc] initWithNSData:characteristic.value];
            [updatedProperties addObject:kFTPenPressureSetupPropertyName];
        }
    }
    else if ([characteristic.UUID isEqual:[FTPenServiceUUIDs manufacturingID]])
    {
        _manufacturingID = [characteristic valueAsNSString];

        [self.delegate penServiceClient:self didReadManufacturingID:self.manufacturingID];
        [updatedProperties addObject:kFTPenManufacturingIDPropertyName];
    }
    else if ([characteristic.UUID isEqual:[FTPenServiceUUIDs lastErrorCode]])
    {
        if (self.lastErrorCodeCharacteristic)
        {
            FTAssert(characteristic == self.lastErrorCodeCharacteristic,
                     @"matches last error code characterisit");

            NSData *data = self.lastErrorCodeCharacteristic.value;
            if (data.length == 2 * sizeof(uint32_t))
            {
                int errorId = CFSwapInt32LittleToHost(((uint32_t *)data.bytes)[0]);
                int errorValue = CFSwapInt32LittleToHost(((uint32_t *)data.bytes)[1]);
                _lastErrorCode = [[FTPenLastErrorCode alloc] initWithErrorID:errorId
                                                               andErrorValue:errorValue];

                [updatedProperties addObject:kFTPenLastErrorCodePropertyName];
            }
        }
    }
    else if ([characteristic.UUID isEqual:[FTPenServiceUUIDs authenticationCode]])
    {
        if (self.authenticationCodeCharacteristic)
        {
            FTAssert(characteristic == self.authenticationCodeCharacteristic,
                     @"characteristic is authenenticationCode characteristic");

            _authenticationCode = [self.authenticationCodeCharacteristic.value copy];

            [self.delegate penServiceClient:self
                  didReadAuthenticationCode:self.authenticationCode];
            [updatedProperties addObject:kFTPenAuthenticationCodePropertyName];
        }
    }
    else if ([characteristic.UUID isEqual:[FTPenServiceUUIDs hasListener]])
    {
        if (self.hasListenerCharacteristic)
        {
            FTAssert(characteristic == self.hasListenerCharacteristic, @"characteristic is hasListener characteristic");
            _hasListener = [self.hasListenerCharacteristic valueAsBOOL];
            [updatedProperties addObject:kFTPenHasListenerPropertyName];
        }
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
        MLOG_ERROR(FTLogSDK, "Error changing notification state: %s", DESC(error.localizedDescription));

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
    else if (characteristic == self.authenticationCodeCharacteristic)
    {
        if (error)
        {
            [self.delegate penServiceClientDidFailToWriteAuthenticationCode:self];
        }
        else
        {
            [self.delegate penServiceClientDidWriteAuthenticationCode:self];
        }
    }
    else if (characteristic == self.centralIdCharacteristic)
    {
        if (error)
        {
            MLOG_ERROR(FTLogSDK, "Failed to write CentralId characteristic: %s",
                       DESC(error.localizedDescription));
            [self.delegate penServiceClientDidFailToWriteCentralId:self];
        }
        else
        {
            MLOG_INFO(FTLogSDK, "Confirmed CentralId characterisitic write.");
            [self.delegate penServiceClientDidWriteCentralId:self];
        }
    }
    else if (characteristic == self.hasListenerCharacteristic)
    {
        if (error)
        {
            MLOG_ERROR(FTLogSDK, "Failed to write HasListener characteristic: %s",
                       DESC(error.localizedDescription));
        }
        else
        {
            MLOG_INFO(FTLogSDK, "Confirmed HasListener characteristic write.");
            [[NSNotificationCenter defaultCenter] postNotificationName:kFTPenDidWriteHasListenerNotificationName
                                                                object:nil];
        }
    }
}

#pragma mark -

- (void)ensureCharacteristicNotificationsAndInitialization
{
    const BOOL isTipPressedNotifying = self.isTipPressedCharacteristic.isNotifying;

    if (!isTipPressedNotifying)
    {
        if (!self.isTipPressedDidSetNofifyValue)
        {
            [self.peripheral setNotifyValue:YES
                          forCharacteristic:self.isTipPressedCharacteristic];
            self.isTipPressedDidSetNofifyValue = YES;
        }
    }
    else
    {
        if (self.isEraserPressedCharacteristic && !self.isEraserPressedDidSetNofifyValue)
        {
            [self.peripheral setNotifyValue:YES
                          forCharacteristic:self.isEraserPressedCharacteristic];
            self.isEraserPressedDidSetNofifyValue = YES;
        }

        if (self.tipPressureCharacteristic && !self.tipPressureDidSetNofifyValue)
        {
            [self.peripheral setNotifyValue:YES
                          forCharacteristic:self.tipPressureCharacteristic];
            self.tipPressureDidSetNofifyValue = YES;
        }

        if (self.eraserPressureCharacteristic && !self.eraserPressureDidSetNofifyValue)
        {
            [self.peripheral setNotifyValue:YES
                          forCharacteristic:self.eraserPressureCharacteristic];
            self.eraserPressureDidSetNofifyValue = YES;
        }

        if (self.batteryLevelCharacteristic && !self.batteryLevelDidSetNofifyValue)
        {
            [self.peripheral setNotifyValue:YES
                          forCharacteristic:self.batteryLevelCharacteristic];
            self.batteryLevelDidSetNofifyValue = YES;
        }

        if (self.batteryLevelCharacteristic && !self.batteryLevel && !self.batteryLevelReadTimer)
        {
            // If we don't see a battery level within 22s of connecting, then we need to perform a manual
            // read of the characteristic. The complexity here is that the Pencil's battery level is
            // unreliable for the first 20s, so we either wait for the first notification in order to get the
            // level, or in the case that we don't get one, we read manually.
            self.batteryLevelReadTimer = [NSTimer scheduledTimerWithTimeInterval:22.0
                                                                          target:self
                                                                        selector:@selector(batteryLevelReadTimerDidFire:)
                                                                        userInfo:nil
                                                                         repeats:NO];
        }

        if (self.inactivityTimeoutCharacteristic && !self.didInitialReadOfInactivityTimeout)
        {
            [self.peripheral readValueForCharacteristic:self.inactivityTimeoutCharacteristic];
            self.didInitialReadOfInactivityTimeout = YES;
        }

        if (self.pressureSetupCharacteristic && !self.didInitialReadOfPressureSetup)
        {
            [self.peripheral readValueForCharacteristic:self.pressureSetupCharacteristic];
            self.didInitialReadOfPressureSetup = YES;
        }

        if (self.manufacturingIDCharacteristic && !self.didInitialReadOfManufacturingID)
        {
            [self.peripheral readValueForCharacteristic:self.manufacturingIDCharacteristic];
            self.didInitialReadOfManufacturingID = YES;
        }

        if (self.lastErrorCodeCharacteristic && !self.didInitialReadOfLastErrorCode)
        {
            [self.peripheral readValueForCharacteristic:self.lastErrorCodeCharacteristic];
            self.didInitialReadOfLastErrorCode = YES;
        }

        if (self.authenticationCodeCharacteristic && !self.didInitialReadOfAuthenticationCode)
        {
            [self.peripheral readValueForCharacteristic:self.authenticationCodeCharacteristic];
            self.didInitialReadOfAuthenticationCode = YES;
        }

        // Version 55 and older firmware did not mark the HasListener characteristic as notifying,
        // so only request notificatons if they're available.
        if (self.hasListenerCharacteristic.isNotifying && !self.hasListenerDidSetNofifyValue)
        {
            [self.peripheral setNotifyValue:YES
                          forCharacteristic:self.hasListenerCharacteristic];
            self.hasListenerDidSetNofifyValue = YES;
        }

        if (self.hasListenerCharacteristic && !self.didInitialReadOfHasListener)
        {
            [self.peripheral readValueForCharacteristic:self.hasListenerCharacteristic];
            self.didInitialReadOfHasListener = YES;
        }
    }
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    [self resetBatteryLevelReadTimer];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    if (self.batteryLevelCharacteristic && !self.batteryLevel)
    {
        [self.peripheral readValueForCharacteristic:self.batteryLevelCharacteristic];
    }
}

- (void)batteryLevelReadTimerDidFire:(NSTimer *)sender
{
    if (self.batteryLevelCharacteristic && !self.batteryLevel)
    {
        [self.peripheral readValueForCharacteristic:self.batteryLevelCharacteristic];
    }
}

- (void)resetBatteryLevelReadTimer
{
    // Capture a strong reference to the current instance as invalidating the timer may
    // otherwise dealloc this instance.
    FTPenServiceClient *instance = self;
    DebugAssert(instance);

    [instance.batteryLevelReadTimer invalidate];
    instance.batteryLevelReadTimer = nil;
}

@end
