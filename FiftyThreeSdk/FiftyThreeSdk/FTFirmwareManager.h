//
//  FTFirmwareManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

@class FTPen;

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, FTFirmwareImageType) {
    FTFirmwareImageTypeFactory,
    FTFirmwareImageTypeUpgrade
};

typedef void (^FirmwareCompletionBlock)(NSData *data);

@interface FTFirmwareManager : NSObject

+ (NSString *)imagePath;
+ (NSString *)imagePathIncludingDocumentsDir;
+ (NSInteger)versionOfImage:(NSData *)image;
+ (NSInteger)versionOfImageAtPath:(NSString *)imagePath;

// Returns a boolean value as a NSNumber, or nil if this cannot yet be determined.
//
// currentVersion is updated if it is available; otherwise it is set to -1.
//
// updateVersion is updated IFF the return value is @(@YES) and should otherwise be ignored.
+ (NSNumber *)isVersionAtPath:(NSString *)imagePath
        newerThanVersionOnPen:(FTPen *)pen
               currentVersion:(NSInteger *)currentVersion
                updateVersion:(NSInteger *)updateVersion;

+ (FTFirmwareImageType)imageTypeRunningOnPen:(FTPen *)pen;

// nil if there's any errors or issues.
+ (void)fetchLatestFirmwareWithCompletionHandler:(FirmwareCompletionBlock)completionHandler;
@end
