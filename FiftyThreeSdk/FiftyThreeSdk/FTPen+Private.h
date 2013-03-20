//
//  FTPen+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTPen.h"

@class CBPeripheral;

@interface FTPen ()
{
@package
    BOOL _tipPressed[2];
}

@property (nonatomic) CBPeripheral *peripheral;

- (id)initWithPeripheral:(CBPeripheral *)peripheral data:(NSDictionary *)data;
- (void)updateData:(NSDictionary *)data;
- (void)getInfo:(void(^)(FTPen *client, NSError *error))complete;
- (void)getBattery:(void(^)(FTPen *client, NSError *error))complete;

@end
