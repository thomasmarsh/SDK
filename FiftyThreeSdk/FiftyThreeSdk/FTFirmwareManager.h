//
//  FTFirmwareManager.h
//  FiftyThreeSdk
//
//  Created by Adam on 3/27/13.
//  Copyright (c) 2013 FiftyThree. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FTFirmwareManager : NSObject

+ (NSInteger)versionForModel:(NSString *)model;
+ (NSString *)filePathForModel:(NSString *)model;

@end
