//
//  FTFirmwareManager+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import "FiftyThreeSdk/FTFirmwareManager.h"

@interface FTFirmwareManager (Private)

+ (NSURL *)firmwareURL;
+ (void)fetchFirmware:(NSURL *)firmwareUrl withCompletionHandler:(void (^)(NSData *))handler;
+ (BOOL)firmwareVersionOnPen:(FTPen *)pen
                forImageType:(FTFirmwareImageType)imageType
                     version:(NSInteger *)version
          isCurrentlyRunning:(BOOL *)isCurrentlyRunning;

@end
