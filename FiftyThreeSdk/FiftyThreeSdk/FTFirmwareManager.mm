//
//  FTFirmwareManager.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "Core/Asserts.h"
#import "Core/Log.h"
#import "FTFirmwareManager.h"
#import "FTLogPrivate.h"
#import "FTPen.h"

using namespace fiftythree::core;

static NSString *applicationDocumentsDirectory()
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
    for (NSString *fileName in directoryContent) {
        if ([[fileName pathExtension] isEqualToString:@"bin"]) {
            NSString *imagePath = [documentsDir stringByAppendingPathComponent:fileName];
            NSInteger version = [FTFirmwareManager versionOfImageAtPath:imagePath];
            if (!bestImagePath || version > bestVersion) {
                bestVersion = version;
                bestImagePath = imagePath;
            }
        }
    }

    // Always favor the documents dir, even if the image contained therein is an older version. We need a way
    // to downgrade.
    return bestImagePath ? bestImagePath : [self imagePath];
}

// Returns true IFF statusCode is in 2xx or 3xx range.
//
// Although many service endpoints narrowly define what response codes they will return on
// success, we usually want to future-proof the client and accept any normal success code.
+ (BOOL)isSuccessStatusCode:(NSInteger)statusCode
{
    NSInteger statusCodeBlock = statusCode - statusCode % 100;
    return (statusCodeBlock == 200 || statusCodeBlock == 300);
}

+ (NSURL *)firmwareURL
{
    NSString *endPoint = @"https://www.fiftythree.com/downloads/pencilv1upgradeimage.bin";
    return [NSURL URLWithString:endPoint];
}

+ (void)fetchLatestFirmwareWithCompletionHandler:(void (^)(NSData *))handler
{
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    defaultConfigObject.allowsCellularAccess = NO;

    NSURLSession *delegateFreeSession = [NSURLSession sessionWithConfiguration:defaultConfigObject
                                                                      delegate:nil
                                                                 delegateQueue:[NSOperationQueue mainQueue]];

    [[delegateFreeSession dataTaskWithURL:[FTFirmwareManager firmwareURL]
                        completionHandler:^(NSData *data,
                                            NSURLResponse *response,
                                            NSError *error) {
                            dispatch_async(dispatch_get_main_queue(), ^() {

                                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;

                                if (data &&
                                    !error &&
                                    httpResponse &&
                                    [self isSuccessStatusCode:httpResponse.statusCode])
                                {
                                    handler(data);
                                }
                                else
                                {
                                    MLOG_INFO(FTLogSDKVerbose, "Got response %s status %ld with error %s.\n",
                                              ObjcDescription(response),
                                              (long)httpResponse.statusCode,
                                              ObjcDescription(error));
                                    handler(nil);
                                }
                            });
                        }] resume];
}

+ (NSInteger)versionOfImage:(NSData *)image
{
    NSInteger version = -1;

    if (image.length >= sizeof(TIFirmwareImageHeader)) {
        TIFirmwareImageHeader* header = (TIFirmwareImageHeader*)image.bytes;
        version = (CFSwapInt16LittleToHost(header->version) >> 1);
    }

    return version;
}

+ (NSInteger)versionOfImageAtPath:(NSString *)imagePath
{
    FTAssert(imagePath, @"image path non-nil");

    NSInteger version = -1;
    if (imagePath) {
        // legacy behaviour: return 0 if there is an image path but we did not find a header?
        version = 0;
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:imagePath];
        FTAssert(fileHandle, @"firmware file exists at path");

        [fileHandle seekToFileOffset:0];
        NSData *data = [fileHandle readDataOfLength:sizeof(TIFirmwareImageHeader)];
        if (data.length == sizeof(TIFirmwareImageHeader)) {
            version = [FTFirmwareManager versionOfImage:data];
        }

        [fileHandle closeFile];
    }

    return version;
}

+ (BOOL)firmwareVersionOnPen:(FTPen *)pen
                forImageType:(FTFirmwareImageType)imageType
                     version:(NSInteger *)version
          isCurrentlyRunning:(BOOL *)isCurrentlyRunning
{
    *version = -1;
    *isCurrentlyRunning = NO;

    NSString *versionString = (imageType == FTFirmwareImageTypeFactory ? pen.firmwareRevision : pen.softwareRevision);

    if (versionString) {
        NSString *versionNumberString;
        NSError *error;
        NSRegularExpression *regex = [NSRegularExpression
            regularExpressionWithPattern:@"\\s*(\\d+)(\\*?)\\s*"
                                 options:NSRegularExpressionCaseInsensitive
                                   error:&error];
        NSTextCheckingResult *match = [regex firstMatchInString:versionString
                                                        options:0
                                                          range:NSMakeRange(0, versionString.length)];
        if (match) {
            versionNumberString = [versionString substringWithRange:[match rangeAtIndex:1]];
            *version = [versionNumberString intValue];

            NSRange asteriskRange = [match rangeAtIndex:2];
            *isCurrentlyRunning = (asteriskRange.length > 0);

            return YES;
        }
    }

    return NO;
}

+ (NSInteger)currentRunningFirmwareVersion:(FTPen *)pen
{
    NSInteger currentVersion = -1;
    NSInteger factoryVersion, upgradeVersion;
    BOOL factoryIsCurrentlyRunning, upgradeIsCurrentlyRunning;
    if ([FTFirmwareManager firmwareVersionOnPen:pen
                                   forImageType:FTFirmwareImageTypeFactory
                                        version:&factoryVersion
                             isCurrentlyRunning:&factoryIsCurrentlyRunning]) {
        if (factoryIsCurrentlyRunning) {
            currentVersion = factoryVersion;
        }
    }

    if ([FTFirmwareManager firmwareVersionOnPen:pen
                                   forImageType:FTFirmwareImageTypeUpgrade
                                        version:&upgradeVersion
                             isCurrentlyRunning:&upgradeIsCurrentlyRunning]) {
        if (upgradeIsCurrentlyRunning) {
            currentVersion = upgradeVersion;
        }
    }
    return currentVersion;
}

+ (NSNumber *)isVersionAtPath:(NSString *)imagePath
        newerThanVersionOnPen:(FTPen *)pen
               currentVersion:(NSInteger *)currentVersion
                updateVersion:(NSInteger *)updateVersion
{
    *currentVersion = [FTFirmwareManager currentRunningFirmwareVersion:pen];
    *updateVersion = -1;

    NSInteger version = [FTFirmwareManager versionOfImageAtPath:imagePath];
    if (version != -1 &&
        *currentVersion != -1) {
        *updateVersion = version;
        return @(*currentVersion < version);
    }

    return nil;
}

+ (BOOL)imageTypeRunningOnPen:(FTPen *)pen andType:(FTFirmwareImageType *)type
{
    NSInteger factoryVersion;
    BOOL factoryIsCurrentlyRunning;

    BOOL result = [FTFirmwareManager firmwareVersionOnPen:pen
                                             forImageType:FTFirmwareImageTypeFactory
                                                  version:&factoryVersion
                                       isCurrentlyRunning:&factoryIsCurrentlyRunning];

    if (factoryIsCurrentlyRunning) {
        *type = FTFirmwareImageTypeFactory;
    } else {
        *type = FTFirmwareImageTypeUpgrade;
    }
    return result;
}

@end
