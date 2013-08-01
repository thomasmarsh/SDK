//
//  FTFirmwareManager.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTFirmwareManager.h"

NSString *applicationDocumentsDirectory()
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

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
//    model = [model lowercaseString];
//
//    // map model to image name
//    NSDictionary* modelMap = @{
//                               @"es1" : @"charcoal",
//                               @"es2" : @"charcoal",
//                               @"es3" : @"charcoal",
//                               @"charcoal" : @"charcoal"
//                               };
//
//    NSString *imagePrefix = [modelMap valueForKey:model];
//    if (!imagePrefix)
//    {
//        return nil;
//    }

    NSString *imagePrefix = @"charcoal";

    if (imageType == Factory)
    {
        return [[NSBundle mainBundle] pathForResource:[imagePrefix stringByAppendingString:@"-factory"]
                                               ofType:@"bin"];
    }
    else
    {
        NSString *baseFilename = [imagePrefix stringByAppendingString:@"-upgrade"];
        NSString *filename = [baseFilename stringByAppendingPathExtension:@"bin"];

        NSString *documentsDirImagePath = [applicationDocumentsDirectory() stringByAppendingPathComponent:filename];
        if ([[NSFileManager defaultManager] fileExistsAtPath:documentsDirImagePath])
        {
            return documentsDirImagePath;
        }
        else
        {
            return [[NSBundle mainBundle] pathForResource:[imagePrefix stringByAppendingString:@"-upgrade"]
                                                   ofType:@"bin"];
        }
    }
}

@end
