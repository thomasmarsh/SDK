//
//  FTDeviceInfoClient.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CBPeripheral;

@interface FTDeviceInfoClient : NSObject

@property (nonatomic, readonly) NSString *manufacturerName;
@property (nonatomic, readonly) NSString *modelNumber;
@property (nonatomic, readonly) NSString *serialNumber;
@property (nonatomic, readonly) NSString *firmwareRevision;
@property (nonatomic, readonly) NSString *hardwareRevision;
@property (nonatomic, readonly) NSString *softwareRevision;
@property (nonatomic, readonly) NSString *systemId;
@property (nonatomic, readonly) NSString *certificationData;
@property (nonatomic, readonly) NSString *pnpId;

- (id)initWithPeripheral:(CBPeripheral *)peripheral;
- (void)getInfo:(void(^)(FTDeviceInfoClient *client, NSError *error))complete;

@end
