//
//  FTFirmwareManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FTFirmwareManager : NSObject

+ (NSInteger)versionForModel:(NSString *)model;
+ (NSString *)filePathForModel:(NSString *)model;

@end
