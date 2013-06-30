//
//  FTPeripheralDelegate.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTServiceClient.h"

@interface FTPeripheralDelegate : NSObject <CBPeripheralDelegate>

- (void)addServiceClient:(FTServiceClient *)serviceClient;

// Returns the list of services to be discovered as a result of the connection being established.
- (NSArray *)peripheral:(CBPeripheral *)peripheral isConnectedDidChange:(BOOL)isConnected;

@end
