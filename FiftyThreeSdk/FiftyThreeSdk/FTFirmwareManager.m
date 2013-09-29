//
//  FTFirmwareManager.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "FTFirmwareManager.h"
#import "FTPen.h"

NSString *applicationDocumentsDirectory()
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

@implementation FTFirmwareManager

+ (NSString *)imagePath
{
    return [[NSBundle mainBundle] pathForResource:@"PencilFirmware" ofType:@"bin"];
}

+ (NSString *)imagePathIncludingDocumentsDir
{
    NSString *bestImagePath;
    NSInteger bestVersion;

    NSString *documentsDir = applicationDocumentsDirectory();
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDir
                                                                                    error:NULL];
    for (NSString *fileName in directoryContent)
    {
        if ([[fileName pathExtension] isEqualToString:@"bin"])
        {
            NSString *imagePath = [documentsDir stringByAppendingPathComponent:fileName];
            NSInteger version = [FTFirmwareManager versionOfImageAtPath:imagePath];
            if (!bestImagePath || version > bestVersion)
            {
                bestVersion = version;
                bestImagePath = imagePath;
            }
        }
    }

    // Always favor the documents dir, even if the image contained therein is an older version. We need a way
    // to downgrade.
    return bestImagePath ? bestImagePath : [self imagePath];
}

+ (NSInteger)versionOfImageAtPath:(NSString *)imagePath
{
    NSAssert(imagePath, @"image path non-nil");

    uint16_t version = 0;
    if (imagePath)
    {
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:imagePath];
        NSAssert(fileHandle, @"firmware file exists at path");

        [fileHandle seekToFileOffset:4];
        NSData *data = [fileHandle readDataOfLength:sizeof(version)];
        if (data.length == sizeof(version))
        {
            version = *((uint16_t *)data.bytes);
            version >>= 1; // LSB is ImgA/ImgB
        }

        [fileHandle closeFile];

        return version;
    }

    return -1;
}

+ (BOOL)firmwareVersionOnPen:(FTPen *)pen
                forImageType:(FTFirmwareImageType)imageType
                     version:(NSInteger *)version
          isCurrentlyRunning:(BOOL *)isCurrentlyRunning
{
    *version = -1;
    *isCurrentlyRunning = NO;

    NSString *versionString = (imageType == FTFirmwareImageTypeFactory ?
                               pen.firmwareRevision :
                               pen.softwareRevision);

    if (versionString)
    {
        NSString *versionNumberString;
        NSError *error;
        NSRegularExpression *regex = [NSRegularExpression
                                      regularExpressionWithPattern:@"\\s*(\\d+)(\\*?)\\s*"
                                      options:NSRegularExpressionCaseInsensitive
                                      error:&error];
        NSTextCheckingResult *match = [regex firstMatchInString:versionString
                                                        options:0
                                                          range:NSMakeRange(0, versionString.length)];
        if (match)
        {
            versionNumberString = [versionString substringWithRange:[match rangeAtIndex:1]];
            *version = [versionNumberString intValue];

            NSRange asteriskRange = [match rangeAtIndex:2];
            *isCurrentlyRunning = (asteriskRange.length > 0);

            return YES;
        }
    }

    return NO;
}

+ (BOOL)isVersionAtPath:(NSString *)imagePath
  newerThanVersionOnPen:(FTPen *)pen
         currentVersion:(NSInteger *)currentVersion
          updateVersion:(NSInteger *)updateVersion
{
    *currentVersion = -1;
    *updateVersion = -1;

    NSInteger factoryVersion, upgradeVersion;
    BOOL factoryIsCurrentlyRunning, upgradeIsCurrentlyRunning;
    if ([FTFirmwareManager firmwareVersionOnPen:pen
                                   forImageType:FTFirmwareImageTypeFactory
                                        version:&factoryVersion
                             isCurrentlyRunning:&factoryIsCurrentlyRunning])
    {
        if (factoryIsCurrentlyRunning)
        {
            *currentVersion = factoryVersion;
        }
    }

    if ([FTFirmwareManager firmwareVersionOnPen:pen
                                   forImageType:FTFirmwareImageTypeUpgrade
                                        version:&upgradeVersion
                             isCurrentlyRunning:&upgradeIsCurrentlyRunning])
    {
        if (upgradeIsCurrentlyRunning)
        {
            *currentVersion = upgradeVersion;
        }
    }

    NSInteger version = [FTFirmwareManager versionOfImageAtPath:imagePath];
    if (version != -1 &&
        *currentVersion != -1 &&
        *currentVersion < version)
    {
        *updateVersion = version;
        return YES;
    }

    return NO;
}

+ (FTFirmwareImageType)imageTypeRunningOnPen:(FTPen *)pen;
{
    NSInteger factoryVersion;
    BOOL factoryIsCurrentlyRunning;

    BOOL result = [FTFirmwareManager firmwareVersionOnPen:pen
                                   forImageType:FTFirmwareImageTypeFactory
                                        version:&factoryVersion
                         isCurrentlyRunning:&factoryIsCurrentlyRunning];
    NSAssert(result, @"Must be able to fetch factory version");

    if (factoryIsCurrentlyRunning)
    {
        return FTFirmwareImageTypeFactory;
    }
    else
    {
        return FTFirmwareImageTypeUpgrade;
    }
}

@end
