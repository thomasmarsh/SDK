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

- (void)pen:(FTPen *)pen didChangeIsReadyState:(BOOL)isReady;

@end

@interface FTPen ()

@property (nonatomic, weak) id<FTPenPrivateDelegate> privateDelegate;
@property (nonatomic) CBPeripheral *peripheral;

- (id)initWithCentralManager:(CBCentralManager *)centralManager
                  peripheral:(CBPeripheral *)peripheral;

- (void)peripheralConnectionStatusDidChange;

- (void)updateData:(NSDictionary *)data;

- (void)getInfo:(void(^)(FTPen *client, NSError *error))complete;

- (void)getBattery:(void(^)(FTPen *client, NSError *error))complete;

@end
