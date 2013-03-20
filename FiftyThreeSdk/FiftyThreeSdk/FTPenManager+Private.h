//
//  FTPenManager+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FTPenManager ()

- (bool)isPenFirmwareUpdatable:(FTPen *)pen;
- (void)updateFirmware:(NSString *)imagePath forPen:(FTPen *)pen;

@end
