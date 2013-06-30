//
//  FTServiceClient.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface FTServiceClient : NSObject <CBPeripheralDelegate>

// Returns the list of services that should be discoverred as a result of the connection being established.
- (NSArray *)peripheral:(CBPeripheral *)peripheral isConnectedDidChange:(BOOL)isConnected;

+ (CBService *)findServiceWithPeripheral:(CBPeripheral *)peripheral andUUID:(CBUUID *)UUID;

@end
