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
#import "FTFirmwareManager.h"

NSString * const kPairedPenUuidDefaultsKey = @"PairedPenUuid";
static const int kInterruptedUpdateDelayMax = 30;

@interface FTPenManager () <CBCentralManagerDelegate, CBPeripheralDelegate, TIUpdateManagerDelegate>

@property (nonatomic) CBCentralManager *centralManager;
@property (nonatomic) TIUpdateManager *updateManager;
@property (nonatomic, readwrite) FTPenManagerState state;
@property (nonatomic) NSTimer *pairingTimer;
@property (nonatomic) NSTimer *trialSeparationTimer;
@property (nonatomic) int maxRSSI;
@property (nonatomic) FTPen *closestPen;
@property (nonatomic, readwrite) FTPen *pairedPen;
@property (nonatomic, readwrite) FTPen *connectedPen;
@property (nonatomic, readwrite) BOOL pairing;

@end

@implementation FTPenManager

- (id)initWithDelegate:(id<FTPenManagerDelegate>)delegate;
{
    self = [super init];
    if (self) {
        _state = FTPenManagerStateUnavailable;
        _delegate = delegate;
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        _pairedPen = nil;
        _pairing = NO;
    }

    return self;
}

- (void)scan
{
    [self.centralManager scanForPeripheralsWithServices:
     @[[CBUUID UUIDWithString:FT_PEN_SERVICE_UUID]]
                                                options:nil];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn)
    {
        [self loadPairedPen];
    }
    else
    {
        [self updateState:FTPenManagerStateUnavailable];
    }
}

- (void)startPairing
{
    NSLog(@"startPairing");

    if (self.connectedPen)
    {
        [self disconnect];
    }

    self.pairedPen = nil;
    self.maxRSSI = 0;
    self.closestPen = nil;
    self.pairing = YES;
    [self scan];

    self.pairingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(pairingTimerExpired:)
                                                       userInfo:nil
                                                        repeats:NO];
}

- (void)stopPairing
{
    NSLog(@"stopPairing");

    [self.pairingTimer invalidate];
    self.pairingTimer = nil;

    self.pairing = NO;
    [self.centralManager stopScan];
}

- (void)pairingTimerExpired:(NSTimer *)timer
{
    self.pairingTimer = nil;

    if (self.closestPen)
    {
        [self connectPen:self.closestPen];
    }
}

- (void)connect
{
    if (!self.connectedPen && self.pairedPen) {
        [self connectPen:self.pairedPen];
    }
}

- (void)reconnect
{
    if (self.autoConnect && !self.trialSeparationTimer)
    {
        NSLog(@"auto reconnect");
        
        [self performSelectorOnMainThread:@selector(connect) withObject:nil waitUntilDone:NO];
    }
}

- (void)connectPen:(FTPen *)pen
{
    NSLog(@"Connecting to peripheral %@", pen.peripheral);

    [self.centralManager stopScan];

    self.connectedPen = pen;
    [self.centralManager connectPeripheral:pen.peripheral options:nil];
}

- (void)disconnect
{
    if (self.connectedPen) {
        [self.centralManager cancelPeripheralConnection:self.connectedPen.peripheral];
    }

    // Ensure we don't retry update when disconnect was initiated by the central.
    if (self.updateManager)
    {
        self.updateManager = nil;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    int rssiValue = [RSSI integerValue];
    //NSLog(@"Discovered %@ at %d", peripheral.name, rssiValue);

    if ((rssiValue > self.maxRSSI || self.maxRSSI == 0) &&
        self.closestPen.peripheral != peripheral)
    {
            //NSLog(@"Updated closest pen");

            self.maxRSSI = rssiValue;
            self.closestPen = [[FTPen alloc] initWithPeripheral:peripheral data:advertisementData];
    }

    // Have we already seen it?
    if (self.closestPen.peripheral == peripheral) {
        [self.closestPen updateData:advertisementData];
    }
    
    // Timer already expired without finding a pen, so connect immediately.
    if (!self.pairingTimer)
    {
        [self connectPen:self.closestPen];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Failed to connect to %@. (%@)", peripheral, [error localizedDescription]);
    [self cleanup];

    [self.delegate penManager:self didFailConnectToPen:self.connectedPen];
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
        return;
    }

    // Discover the characteristic we want...

    // Loop through the newly filled peripheral.services array, just in case there's more than one.
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[
         [CBUUID UUIDWithString:FT_PEN_TIP1_STATE_UUID],
         [CBUUID UUIDWithString:FT_PEN_TIP2_STATE_UUID]
         ] forService:service];
    }
}

- (void)updateState:(FTPenManagerState)state
{
    self.state = state;
    [self.delegate penManagerDidUpdateState:self];
}

- (void)savePairedPen:(FTPen *)pen
{
    NSAssert(pen, nil);

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
        [self updateState:FTPenManagerStateAvailable];
    }
}

- (void)deletePairedPen:(FTPen *)pen
{
    NSAssert(pen, nil);

    if (self.pairedPen == pen)
    {
        self.pairedPen = nil;

        [[NSUserDefaults standardUserDefaults] setValue:nil
                                                 forKey:kPairedPenUuidDefaultsKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    if (self.connectedPen == pen)
    {
        [self disconnect];
    }
}

- (void)connectedToPen:(FTPen *)pen
{
    NSAssert(pen, nil);

    if (!self.pairing) {
        self.pairedPen = pen;
        [self stopPairing];

        [self savePairedPen:pen];

        [self.delegate penManager:self didPairWithPen:self.pairedPen];
    }

    if (self.updateManager)
    {
        if (-[self.updateManager.updateStartTime timeIntervalSinceNow] < kInterruptedUpdateDelayMax)
        {
            [self updateFirmwareForPen:self.connectedPen];
            return;
        }
        else
        {
            self.updateManager = nil;
        }
    }

    [self.delegate penManager:self didConnectToPen:self.pairedPen];

    // Now that we are connected update the device info
    [self.connectedPen getInfo:^(FTPen *client, NSError *error) {
        if (error) {
            // We failed to get info, but that's ok, continue anyway
            NSLog(@"Failed to get device info, error=%@", [error localizedDescription]);
        }

        [self.delegate penManager:self didUpdateDeviceInfo:self.connectedPen];

        [self.connectedPen getBattery:^(FTPen *client, NSError *error) {
            if (error) {
                // We failed to get info, but that's ok, continue anyway
                NSLog(@"Failed to get device info, error=%@", [error localizedDescription]);
            }

            [self.delegate penManager:self didUpdateDeviceBatteryLevel:self.connectedPen];
        }];
    }];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSAssert(peripheral == self.connectedPen.peripheral, @"got wrong pen");

    if (error || service.characteristics.count == 0) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        [self cleanup];
        return;
    }

    // Again, we loop through the array, just in case.
    for (CBCharacteristic *characteristic in service.characteristics) {

        // And check if it's the right one
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FT_PEN_TIP1_STATE_UUID]]
            || [characteristic.UUID isEqual:[CBUUID UUIDWithString:FT_PEN_TIP2_STATE_UUID]]
        ) {

            // If it is, subscribe to it
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSAssert(peripheral == self.connectedPen.peripheral, @"got wrong pen");

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

    self.connectedPen->_tipPressed[tip] = pressed;
    NSAssert([self.connectedPen isTipPressed:tip] == pressed, @"");

    if (pressed) {
        [self.connectedPen.delegate pen:self.connectedPen didPressTip:tip];
    } else {
        [self.connectedPen.delegate pen:self.connectedPen didReleaseTip:tip];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSAssert(peripheral == self.connectedPen.peripheral, @"got wrong pen");

    if (error) {
        NSLog(@"Error changing notification state: %@", error.localizedDescription);
        [self cleanup];
        return;
    }

    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:FT_PEN_TIP1_STATE_UUID]]
        && ![characteristic.UUID isEqual:[CBUUID UUIDWithString:FT_PEN_TIP2_STATE_UUID]]
        ) {
        return;
    }

    if (characteristic.isNotifying) {
        NSLog(@"Notification began on %@", characteristic);

        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FT_PEN_TIP1_STATE_UUID]]) {
            // "connected" means we have the primary tip notifying
            [self connectedToPen:self.connectedPen];
        }
    } else {
        NSLog(@"Notification stopped on %@. Disconnecting", characteristic);
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    FTPen* pen = self.connectedPen;
    self.connectedPen = nil;

    if (self.updateManager)
    {
        if (-[self.updateManager.updateStartTime timeIntervalSinceNow] < kInterruptedUpdateDelayMax)
        {
            NSLog(@"Disconnected while performing update, attempting reconnect");

            [self performSelectorOnMainThread:@selector(connect) withObject:nil waitUntilDone:NO];
        }
        else
        {
            self.updateManager = nil;
        }
    }

    [self.delegate penManager:self didDisconnectFromPen:pen];
    
    [self reconnect];
}

- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals
{
    if (!self.pairedPen)
    {
        if (peripherals.count)
        {
            self.pairedPen = [[FTPen alloc] initWithPeripheral:peripherals[0] data:nil];
        }
    }

    [self updateState:FTPenManagerStateAvailable];
}

- (BOOL)isUpdateAvailableForPen:(FTPen *)pen
{
    NSAssert(pen, nil);
    
    return [self isUpdateAvailableForPen:pen imageType:Factory] || [self isUpdateAvailableForPen:pen imageType:Upgrade];
}

- (BOOL)isUpdateAvailableForPen:(FTPen *)pen imageType:(FTFirmwareImageType)imageType
{
    NSAssert(pen, nil);

    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle:NSNumberFormatterDecimalStyle];

    NSInteger availableVersion = [FTFirmwareManager versionForModel:pen.modelNumber imageType:imageType];
    NSInteger existingVersion;
    if (imageType == Factory)
    {
        existingVersion = [f numberFromString:[pen.firmwareRevision componentsSeparatedByString:@" "][0]].integerValue;
        
        NSLog(@"Factory version: Available = %d, Existing = %d", availableVersion, existingVersion);
    }
    else
    {
        existingVersion = [f numberFromString:[pen.softwareRevision componentsSeparatedByString:@" "][0]].integerValue;
        
        NSLog(@"Upgrade version: Available = %d, Existing = %d", availableVersion, existingVersion);
    }

    return availableVersion > existingVersion;
}

- (void)updateFirmwareForPen:(FTPen *)pen
{
    NSAssert(pen, nil);
    
    FTFirmwareImageType imageType;
    if ([self isUpdateAvailableForPen:pen imageType:Factory])
    {
        imageType = Factory;
    }
    else if ([self isUpdateAvailableForPen:pen imageType:Upgrade])
    {
        imageType = Upgrade;
    }
    else
    {
        return;
    }
    
    NSString *filePath = [FTFirmwareManager filePathForModel:pen.modelNumber imageType:imageType];
    self.updateManager = [[TIUpdateManager alloc] initWithPeripheral:pen.peripheral delegate:self]; // BUGBUG - ugly cast
    
    [self.updateManager updateImage:filePath];
}

- (void)updateManager:(TIUpdateManager *)manager didFinishUpdate:(NSError *)error
{
    NSAssert(manager, nil);

    self.updateManager = nil;

    if ([self.delegate conformsToProtocol:@protocol(FTPenManagerDelegatePrivate)])
    {
        id<FTPenManagerDelegatePrivate> d = (id<FTPenManagerDelegatePrivate>)self.delegate;
        [d penManager:self didFinishUpdate:error];
    }
}

- (void)updateManager:(TIUpdateManager *)manager didUpdatePercentComplete:(float)percent
{
    NSAssert(manager, nil);

    if ([self.delegate conformsToProtocol:@protocol(FTPenManagerDelegatePrivate)])
    {
        id<FTPenManagerDelegatePrivate> d = (id<FTPenManagerDelegatePrivate>)self.delegate;
        [d penManager:self didUpdatePercentComplete:percent];
    }
}

- (void)cleanup
{
    if (!self.connectedPen.isConnected) {
        return;
    }

    // See if we are subscribed to a characteristic on the peripheral
    if (self.connectedPen.peripheral.services != nil) {
        for (CBService *service in self.connectedPen.peripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FT_PEN_TIP1_STATE_UUID]]
                        || [characteristic.UUID isEqual:[CBUUID UUIDWithString:FT_PEN_TIP2_STATE_UUID]]
                        ) {
                        if (characteristic.isNotifying) {
                            [self.connectedPen.peripheral setNotifyValue:NO forCharacteristic:characteristic];

                            return;
                        }
                    }
                }
            }
        }
    }

    // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
    [self.centralManager cancelPeripheralConnection:self.connectedPen.peripheral];
}

- (void)startTrialSeparation
{
    NSLog(@"startTrialSeparation");

    [self disconnect];
    
    // BUGBUG - the timer based approach is not sufficient to allow for fast reconnection in the case where the
    // user is not actually pairing with another iPad. Need a scanning strategy for that. This is only a placeholder until
    // FW can implement this.
    
    self.trialSeparationTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                     target:self
                                   selector:@selector(stopTrialSeparation)
                                   userInfo:nil
                                    repeats:NO];
}

- (void)stopTrialSeparation
{
    NSLog(@"stopTrialSeparation");

    self.trialSeparationTimer = nil;
    
    [self reconnect];
}


@end