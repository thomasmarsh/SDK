//
//  TIUpdateManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CBPeripheral;

@protocol TIUpdateManagerDelegate;

@interface TIUpdateManager : NSObject

@property (nonatomic) BOOL waitingForReboot;
@property (nonatomic, readonly) NSDate* updateStartTime;

- (id) init __unavailable;
- (id)initWithPeripheral:(CBPeripheral *)peripheral delegate:(id<TIUpdateManagerDelegate>)delegate;
- (void)updateImage:(NSString *)filePath;
@end

@protocol TIUpdateManagerDelegate <NSObject>

- (void)updateManager:(TIUpdateManager *)manager didFinishUpdate:(NSError *)error;
- (void)updateManager:(TIUpdateManager *)manager didUpdatePercentComplete:(float)percent;

@end