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

// Full firmware image header. Note that for the OAD service the Image Identify characteristic
// must only receive the last 12 bytes (i.e. skip the CRC and CRC shadow).
typedef struct {
    uint16_t crc;
    uint16_t crcShadow;
    uint16_t version;
    uint16_t blockCount;
    uint8_t uid[4];
    uint8_t reserved[4];
    
} TIFirmwareImageHeader;

@interface FTFirmwareManager : NSObject

+ (NSString *)imagePath;
+ (NSString *)imagePathIncludingDocumentsDir;
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

+ (BOOL)imageTypeRunningOnPen:(FTPen *)pen andType:(FTFirmwareImageType *)type;

+ (void)fetchLatestFirmwareWithCompletionHandler:(void (^)(NSData *))handler;

+ (NSInteger)versionOfImage:(NSData *)image;

+ (NSInteger)currentRunningFirmwareVersion:(FTPen *)pen;
@end
