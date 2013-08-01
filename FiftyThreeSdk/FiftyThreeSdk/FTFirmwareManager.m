//
//  FTFirmwareManager.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

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
    NSString *filePath = [self filePathForImageType:imageType];
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

+ (NSString *)filePathForImageType:(FTFirmwareImageType)imageType
{
    NSString *documentsDir = applicationDocumentsDirectory();
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDir
                                                                                    error:NULL];

    NSString *firmwareImageFilePath;

    for (NSString *fileName in directoryContent)
    {
        if ([[fileName pathExtension] isEqualToString:@"bin"])
        {
            if (!firmwareImageFilePath)
            {
                firmwareImageFilePath = [documentsDir stringByAppendingPathComponent:fileName];
            }
            else
            {
                // TODO: This error should be reported to caller, not shown in an alert view.
                [[[UIAlertView alloc] initWithTitle:@"Multiple Images Found"
                                            message:@"Only one firmware image may be present in the iTunes Documents directory." delegate:nil
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil, nil] show];

                return nil;
            }
        }
    }

    if (!firmwareImageFilePath)
    {
        // TODO: This error should be reported to caller, not shown in an alert view.

        [[[UIAlertView alloc] initWithTitle:@"No Image Found"
                                    message:@"No firmware image was found in the iTunes Documents directory."
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil, nil] show];
    }

    return firmwareImageFilePath;
}

@end
