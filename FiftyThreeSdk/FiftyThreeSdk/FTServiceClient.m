//
//  FTServiceClient.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTServiceClient.h"

@implementation FTServiceClient

- (NSArray *)peripheral:(CBPeripheral *)peripheral isConnectedDidChange:(BOOL)isConnected
{
    return nil;
}

+ (CBService *)findServiceWithPeripheral:(CBPeripheral *)peripheral andUUID:(CBUUID *)UUID
{
    for (CBService *service in peripheral.services)
    {
        if ([service.UUID isEqual:UUID])
        {
            return service;
        }
    }

    return nil;
}

@end
