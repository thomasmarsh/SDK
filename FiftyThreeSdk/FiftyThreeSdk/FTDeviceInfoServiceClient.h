//
//  FTDeviceInfoServiceClient.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTServiceClient.h"
#import "FTPen.h"

@interface FTDeviceInfoServiceClient : FTServiceClient

@property (nonatomic, readonly) NSString *manufacturerName;
@property (nonatomic, readonly) NSString *modelNumber;
@property (nonatomic, readonly) NSString *serialNumber;
@property (nonatomic, readonly) NSString *firmwareRevision;
@property (nonatomic, readonly) NSString *hardwareRevision;
@property (nonatomic, readonly) NSString *softwareRevision;
@property (nonatomic, readonly) NSString *systemID;
@property (nonatomic, readonly) NSData *IEEECertificationData;
@property (nonatomic, readonly) PnPID PnPID;

@end
