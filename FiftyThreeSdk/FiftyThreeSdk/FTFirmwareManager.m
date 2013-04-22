//
//  FTFirmwareManager.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTFirmwareManager.h"

@implementation FTFirmwareManager

+ (NSInteger)versionForModel:(NSString *)model imageType:(FTFirmwareImageType)imageType
{
    uint16_t version = 0;
    NSString *filePath = [self filePathForModel:model imageType:imageType];
    if (filePath)
    {
        NSFileHandle* fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
        [fileHandle seekToFileOffset:4];
        NSData* data = [fileHandle readDataOfLength:sizeof(version)];
        if (data.length == sizeof(version))
        {
            version = *((uint16_t *)data.bytes);
            version >>= 1; // LSB is ImgA/ImgB
        }

        [fileHandle closeFile];
    }

    return version;
}

+ (NSString *)filePathForModel:(NSString *)model imageType:(FTFirmwareImageType)imageType
{
    model = [model lowercaseString];
    
    // map model to image name
    NSDictionary* modelMap = @{
                          @"es1" : @"charcoal",
                          @"es2" : @"charcoal",
                          @"charcoal" : @"charcoal"
                          };

    NSString *imagePrefix = [modelMap valueForKey:model];
    if (!imagePrefix)
    {
        return nil;
    }

    NSString *imageFileName;
    if (imageType == Factory)
    {
        imageFileName = [imagePrefix stringByAppendingString:@"-factory"];
    }
    else
    {
        imageFileName = [imagePrefix stringByAppendingString:@"-upgrade"];
    }
    
    return [[NSBundle mainBundle] pathForResource:imageFileName ofType:@"bin"];
}

@end
