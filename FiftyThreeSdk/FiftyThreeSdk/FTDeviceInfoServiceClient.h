//
//  FTDeviceInfoServiceClient.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

#import "FTPen.h"
#import "FTServiceClient.h"

@class FTDeviceInfoServiceClient;

@protocol FTDeviceInfoServiceClientDelegate <NSObject>

- (void)deviceInfoServiceClientDidUpdateDeviceInfo:(FTDeviceInfoServiceClient *)deviceInfoServiceClient
                                 updatedProperties:(NSSet *)updatedProperties;

@end

@interface FTDeviceInfoServiceClient : FTServiceClient

@property (nonatomic, weak) id<FTDeviceInfoServiceClientDelegate> delegate;

@property (nonatomic, readonly) NSString *manufacturerName;
@property (nonatomic, readonly) NSString *modelNumber;
@property (nonatomic, readonly) NSString *serialNumber;
@property (nonatomic, readonly) NSString *firmwareRevision;
@property (nonatomic, readonly) NSString *hardwareRevision;
@property (nonatomic, readonly) NSString *softwareRevision;
@property (nonatomic, readonly) NSString *systemID;
@property (nonatomic, readonly) NSData *IEEECertificationData;
@property (nonatomic, readonly) PnPID PnPID;

- (id)initWithPeripheral:(CBPeripheral *)peripheral;

// Requests a read of the model number and serial number characteristics from the peripheral.
- (void)refreshModelNumberAndSerialNumber;

// Clears the current firmwareRevision and softwareRevision values and requests a read of them
// from the peripheral.
- (void)refreshFirmwareRevisions;

@end
