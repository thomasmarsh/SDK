//
//  FTPen+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTPen.h"

@class CBCentralManager;
@class CBPeripheral;

@protocol FTPenPrivateDelegate

- (void)pen:(FTPen *)pen isReadyDidChange:(BOOL)isReady;

@end

@interface FTPen ()

@property (nonatomic, weak) id<FTPenPrivateDelegate> privateDelegate;
@property (nonatomic) CBPeripheral *peripheral;

- (id)initWithCentralManager:(CBCentralManager *)centralManager
                  peripheral:(CBPeripheral *)peripheral;

- (void)peripheralConnectionStatusDidChange;

- (void)updateData:(NSDictionary *)data;

@end
