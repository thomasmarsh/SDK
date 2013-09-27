//
//  FTFirmwareManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

@class FTPen;

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, FTFirmwareImageType) {
    FTFirmwareImageTypeFactory,
    FTFirmwareImageTypeUpgrade
};

@interface FTFirmwareManager : NSObject

+ (NSString *)imagePath;
+ (NSString *)imagePathIncludingDocumentsDir;
+ (NSInteger)versionOfImageAtPath:(NSString *)imagePath;
+ (BOOL)isVersionAtPath:(NSString *)imagePath newerThanVersionOnPen:(FTPen *)pen;
+ (FTFirmwareImageType)imageTypeRunningOnPen:(FTPen *)pen;

@end
