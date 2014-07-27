//
//  FTServiceClient.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <CoreBluetooth/CoreBluetooth.h>
#import <Foundation/Foundation.h>

@interface FTServiceClient : NSObject <CBPeripheralDelegate>

// Returns the list of services that should be discoverred as a result of the connection being established.
- (NSArray *)ensureServicesForConnectionState:(BOOL)isConnected;

+ (CBService *)findServiceWithPeripheral:(CBPeripheral *)peripheral andUUID:(CBUUID *)UUID;

@end
