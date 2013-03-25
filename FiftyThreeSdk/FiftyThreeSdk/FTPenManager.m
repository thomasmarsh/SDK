//
//  FTPenManager.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTPenManager.h"
#import "FTPenManager+Private.h"
#import <CoreBluetooth/CoreBluetooth.h>
#include "FTPenServiceUUID.h"
#import "FTPen.h"
#import "FTPen+Private.h"
#import "FTDeviceInfoClient.h"
#import "TIUpdateManager.h"
#import "FTPenTouchManager.h"

NSString * const kPairedPenUuidDefaultsKey = @"PairedPenUuid";

@interface FTPenManager () <CBCentralManagerDelegate, CBPeripheralDelegate, TIUpdateManagerDelegate>
{
    FTPen *_pairedPen;
    FTPen *_connectedPen;
    BOOL _pairing;
    dispatch_queue_t _queue;
#if USE_TI_UUIDS
    char _lastState;
#endif
}

- (void)updateFirmware:(NSString *)imagePath forPen:(FTPen *)pen;

@property (nonatomic) CBCentralManager *centralManager;
@property (nonatomic) TIUpdateManager *updateManager;
@property (nonatomic) FTPenTouchManager *penTouchManager;

@end

@implementation FTPenManager

@synthesize connectedPen = _connectedPen;

- (id)initWithDelegate:(id<FTPenManagerDelegate>)delegate;
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _queue = dispatch_queue_create("com.fiftythree.penmanager", NULL);
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:_queue];
        _penTouchManager = [[FTPenTouchManager alloc] initWithPenManager:self];
        _pairedPen = nil;
        _pairing = NO;
#if USE_TI_UUIDS
        _lastState = 0;
#endif
    }

    return self;
}

- (FTPen *)pairedPen
{
    return _pairedPen;
}

- (void)scan
{
    [self.centralManager scanForPeripheralsWithServices:
#if !USE_TI_UUIDS
     @[[CBUUID UUIDWithString:FT_PEN_SERVICE_UUID]]
#else
     @[[CBUUID UUIDWithString:TI_SIMPLE_BLE_ADV_UUID]]
#endif
                                                options:nil];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self loadPairedPen];
    }
}

- (void)startPairing
{
    NSLog(@"startPairing");

    _pairing = YES;
    [self scan];
}

- (void)stopPairing
{
    NSLog(@"stopPairing");

    _pairing = NO;
    [self.centralManager stopScan];
}

- (void)connect
{
    if (!self.connectedPen && self.pairedPen) {
        [self connectPen:_pairedPen];
    }
}

- (void)connectPen:(FTPen *)pen
{
    NSLog(@"Connecting to peripheral %@", pen.peripheral);

    [self.centralManager stopScan];

    _connectedPen = pen;
    [self.centralManager connectPeripheral:pen.peripheral options:nil];
}

- (void)disconnect
{
    if (self.connectedPen) {
        [self.centralManager cancelPeripheralConnection:_connectedPen.peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);

    // Ok, it's in range - have we already seen it?
    if (_connectedPen.peripheral != peripheral) {
        FTPen *pen = [[FTPen alloc] initWithPeripheral:peripheral data:advertisementData];

        [self connectPen:pen];
    } else {
        [_connectedPen updateData:advertisementData];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Failed to connect to %@. (%@)", peripheral, [error localizedDescription]);
    [self cleanup];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate penManager:self didFailConnectToPen:self.connectedPen];
    });
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral Connected");

    peripheral.delegate = self;
    [peripheral discoverServices:@[[CBUUID UUIDWithString:FT_PEN_SERVICE_UUID]]];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        [self cleanup];
    }

    NSLog(@"found service");

#if USE_TI_UUIDS
    if (peripheral.services.count == 0)
    {
        [self connectedToPen:_connectedPen];
    }
#endif

    // Discover the characteristic we want...
    
    // Loop through the newly filled peripheral.services array, just in case there's more than one.
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[
         [CBUUID UUIDWithString:FT_PEN_TIP1_STATE_UUID],
#if !USE_TI_UUIDS
         [CBUUID UUIDWithString:FT_PEN_TIP2_STATE_UUID]
#endif
         ] forService:service];
    }
}

- (void)savePairedPen:(FTPen *)pen
{
    CFUUIDRef uuid = pen.peripheral.UUID;
    NSString* uuidString = uuid != nil ? CFBridgingRelease(CFUUIDCreateString(NULL, uuid)) : nil;

    [[NSUserDefaults standardUserDefaults] setValue:uuidString
                                             forKey:kPairedPenUuidDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadPairedPen
{
    NSString *uuid = [[NSUserDefaults standardUserDefaults] stringForKey:kPairedPenUuidDefaultsKey];
    if (uuid) {
        [self.centralManager retrievePeripherals:[NSArray arrayWithObject:CFBridgingRelease(CFUUIDCreateFromString(NULL, (CFStringRef)uuid)) ]];
    } else {
        _isReady = YES;
    }
}

- (void)deletePairedPen:(FTPen *)pen
{
    if (_pairedPen == pen)
    {
        _pairedPen = nil;

        [[NSUserDefaults standardUserDefaults] setValue:nil
                                                 forKey:kPairedPenUuidDefaultsKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    if (_connectedPen == pen)
    {
        [self disconnect];
    }
}

- (void)connectedToPen:(FTPen *)pen
{
    if (_pairing) {
        _pairedPen = pen;
        [self stopPairing];

        [self savePairedPen:pen];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate penManager:self didPairWithPen:_pairedPen];
        });
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate penManager:self didConnectToPen:_pairedPen];
    });

    // Now that we are connected update the device info
    [_connectedPen getInfo:^(FTPen *client, NSError *error) {
        if (error) {
            // We failed to get info, but that's ok, continue anyway
            NSLog(@"Failed to get device info, error=%@", [error localizedDescription]);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate penManager:self didUpdateDeviceInfo:self.connectedPen];

            [_connectedPen getBattery:^(FTPen *client, NSError *error) {
                if (error) {
                    // We failed to get info, but that's ok, continue anyway
                    NSLog(@"Failed to get device info, error=%@", [error localizedDescription]);
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate penManager:self didUpdateDeviceBatteryLevel:self.connectedPen];
                });
            }];
        });
    }];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSAssert(peripheral == _connectedPen.peripheral, @"got wrong pen");

    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        [self cleanup];
        return;
    }

    // Again, we loop through the array, just in case.
    for (CBCharacteristic *characteristic in service.characteristics) {

        // And check if it's the right one
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FT_PEN_TIP1_STATE_UUID]]
#if !USE_TI_UUIDS
            || [characteristic.UUID isEqual:[CBUUID UUIDWithString:FT_PEN_TIP2_STATE_UUID]]
#endif
        ) {

            // If it is, subscribe to it
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}

#if USE_TI_UUIDS

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSAssert(peripheral == _connectedPen.peripheral, @"got wrong pen");
    
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        return;
    }

    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:FT_PEN_TIP1_STATE_UUID]]) {
        NSLog(@"Unrecognized characteristic");
        return;
    }
    
    if (characteristic.value.length == 0) {
        NSLog(@"No data received");
        return;
    }
    
    const char *bytes = characteristic.value.bytes;
    char state = bytes[0];
    
    FTPenTip tip = FTPenTip1;
    BOOL pressed = YES;
    
    switch (state)
    {
        case TI_KEY_PRESS_STATE_NONE:
        {
            pressed = NO;
            if (_lastState == TI_KEY_PRESS_STATE_KEY1)
            {
                tip = FTPenTip1;
            }
            else if (_lastState == TI_KEY_PRESS_STATE_KEY2)
            {
                tip = FTPenTip2;
            }
            else
            {
                NSAssert(FALSE, nil);
            }
        }
        break;
        case TI_KEY_PRESS_STATE_KEY1:
        {
            pressed = YES;
            tip = FTPenTip1;
        }
        break;
        case TI_KEY_PRESS_STATE_KEY2:
        {
            pressed = YES;
            tip = FTPenTip2;
        }
        break;
        default:
            break;
    }
    
    _lastState = state;
    
    _connectedPen->_tipPressed[tip] = pressed;
    NSAssert([self.connectedPen isTipPressed:tip] == pressed, @"");
    
    if (pressed) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.connectedPen.delegate pen:self.connectedPen didPressTip:tip];
            [self.penTouchManager pen:self.connectedPen didPressTip:tip];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.connectedPen.delegate pen:self.connectedPen didReleaseTip:tip];
            [self.penTouchManager pen:self.connectedPen didReleaseTip:tip];
        });
    }
}

#else

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSAssert(peripheral == _connectedPen.peripheral, @"got wrong pen");

    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        return;
    }

    FTPenTip tip;
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FT_PEN_TIP1_STATE_UUID]]) {
        tip = FTPenTip1;
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FT_PEN_TIP2_STATE_UUID]]) {
        tip = FTPenTip2;
    } else {
        NSLog(@"Unrecognized characteristic");
        return;
    }

    if (characteristic.value.length == 0) {
        NSLog(@"No data received");
        return;
    }

    const char *bytes = characteristic.value.bytes;
    BOOL pressed = bytes[0] == FT_PEN_TIP_STATE_PRESSED;

    _connectedPen->_tipPressed[tip] = pressed;
    NSAssert([self.connectedPen isTipPressed:tip] == pressed, @"");

    if (pressed) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.connectedPen.delegate pen:self.connectedPen didPressTip:tip];
            [self.penTouchManager pen:self.connectedPen didPressTip:tip];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.connectedPen.delegate pen:self.connectedPen didReleaseTip:tip];
            [self.penTouchManager pen:self.connectedPen didReleaseTip:tip];
        });
    }
}

#endif

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSAssert(peripheral == _connectedPen.peripheral, @"got wrong pen");

    if (error) {
        NSLog(@"Error changing notification state: %@", error.localizedDescription);
        return;
    }

    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:FT_PEN_TIP1_STATE_UUID]]
#if !USE_TI_UUIDS
        && ![characteristic.UUID isEqual:[CBUUID UUIDWithString:FT_PEN_TIP2_STATE_UUID]]
#endif
        ) {
        return;
    }

    if (characteristic.isNotifying) {
        NSLog(@"Notification began on %@", characteristic);

        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FT_PEN_TIP1_STATE_UUID]]) {
            // "connected" means we have the primary tip notifying
            [self connectedToPen:_connectedPen];
        }
    } else {
        NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"didDisconnectPeripheral");

    FTPen* pen = self.connectedPen;
    _connectedPen = nil;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate penManager:self didDisconnectFromPen:pen];
    });
}

- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals
{
    if (!_pairedPen)
    {
        if (peripherals.count)
        {
            _pairedPen = [[FTPen alloc] initWithPeripheral:peripherals[0] data:nil];
        }
    }

    _isReady = YES;
}

- (void)updateFirmware:(NSString *)imagePath forPen:(FTPen *)pen
{
    self.updateManager = [[TIUpdateManager alloc] initWithPeripheral:pen.peripheral delegate:self]; // BUGBUG - ugly cast
    [self.updateManager updateImage:imagePath];
}

- (void)updateManager:(TIUpdateManager *)manager didFinishUpdate:(NSError *)error
{
    if (error)
    {
        // We failed to get info, but that's ok, continue anyway
        NSLog(@"update failed=%@", [error localizedDescription]);
    }
    else
    {
        NSLog(@"update complete");
    }

    self.updateManager = nil;

    if ([self.delegate conformsToProtocol:@protocol(FTPenManagerDelegatePrivate)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            id<FTPenManagerDelegatePrivate> d = (id<FTPenManagerDelegatePrivate>)self.delegate;
            [d penManager:self didFinishUpdate:error];
        });
    }
}

- (void)updateManager:(TIUpdateManager *)manager didUpdatePercentComplete:(float)percent
{
    if ([self.delegate conformsToProtocol:@protocol(FTPenManagerDelegatePrivate)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            id<FTPenManagerDelegatePrivate> d = (id<FTPenManagerDelegatePrivate>)self.delegate;
            [d penManager:self didUpdatePercentComplete:percent];
        });
    }
}

- (void)didDetectMultitaskingGesturesEnabled
{
    if ([self.delegate respondsToSelector:@selector(didDetectMultitaskingGesturesEnabled)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate didDetectMultitaskingGesturesEnabled];
        });
    }
}

- (void)cleanup
{
    NSLog(@"cleanup");

    if (!self.connectedPen.isConnected) {
        return;
    }

    // See if we are subscribed to a characteristic on the peripheral
    if (_connectedPen.peripheral.services != nil) {
        for (CBService *service in _connectedPen.peripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FT_PEN_TIP1_STATE_UUID]]
#if !USE_TI_UUIDS
                        || [characteristic.UUID isEqual:[CBUUID UUIDWithString:FT_PEN_TIP2_STATE_UUID]]
#endif
                        ) {
                        if (characteristic.isNotifying) {
                            [_connectedPen.peripheral setNotifyValue:NO forCharacteristic:characteristic];

                            return;
                        }
                    }
                }
            }
        }
    }

    // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
    [self.centralManager cancelPeripheralConnection:_connectedPen.peripheral];
}

- (void)registerView:(UIView *)view
{
    [_penTouchManager registerView:view];
}

- (void)deregisterView:(UIView *)view
{
    [_penTouchManager deregisterView:view];
}

@end
