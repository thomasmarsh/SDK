//
//  FTFirmwareManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTPenManager+Private.h"

@interface FTFirmwareManager : NSObject

+ (NSInteger)versionForModel:(NSString *)model imageType:(FTFirmwareImageType)imageType;
+ (NSString *)filePathForModel:(NSString *)model imageType:(FTFirmwareImageType)imageType;

@end
