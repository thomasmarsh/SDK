//
//  FTFirmwareManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

#import "FTPenManager+Private.h"

@interface FTFirmwareManager : NSObject

+ (NSInteger)versionForModel:(NSString *)model imageType:(FTFirmwareImageType)imageType;
+ (NSString *)filePathForImageType:(FTFirmwareImageType)imageType;

@end
