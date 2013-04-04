//
//  FTPenManager+Private.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FTPenManager ()

- (BOOL)isUpdateAvailableForPen:(FTPen *)pen;
- (void)updateFirmwareForPen:(FTPen *)pen;
- (void)didDetectMultitaskingGesturesEnabled;

@end

@protocol FTPenManagerDelegatePrivate <FTPenManagerDelegate>

@optional

- (void)penManager:(FTPenManager *)manager didFinishUpdate:(NSError *)error;
- (void)penManager:(FTPenManager *)manager didUpdatePercentComplete:(float)percent;

@end