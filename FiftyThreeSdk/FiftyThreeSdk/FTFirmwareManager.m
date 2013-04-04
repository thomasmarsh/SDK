//
//  FTFirmwareManager.m
//  FiftyThreeSdk
//
//  Created by Adam on 3/27/13.
//  Copyright (c) 2013 FiftyThree. All rights reserved.
//

#import "FTFirmwareManager.h"

@implementation FTFirmwareManager

+ (NSInteger)versionForModel:(NSString *)model
{
    uint16_t version = 0;
    NSString *filePath = [self filePathForModel:model];
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

+ (NSString *)filePathForModel:(NSString *)model
{
    model = [model lowercaseString];
    NSArray* models = @[
        @"es1"
    ];
    
    NSUInteger index = [models indexOfObject:model];
    if (index == NSNotFound) return nil;
    return [[NSBundle mainBundle] pathForResource:models[index] ofType:@"img"];
}

@end
