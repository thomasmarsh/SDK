//
//  TIUpdateManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TIUpdateManagerState)
{
    TIUpdateManagerStateNotStarted,
    TIUpdateManagerStateInProgress,
    TIUpdateManagerStateFailed,
    TIUpdateManagerStateCancelled,
    TIUpdateManagerStateSucceeded
};

@class CBPeripheral;

@protocol TIUpdateManagerDelegate;

@interface TIUpdateManager : NSObject

@property (nonatomic) TIUpdateManagerState state;
@property (nonatomic) BOOL shouldRestorePeripheralDelegate;

- (id)init __unavailable;

- (id)initWithPeripheral:(CBPeripheral *)peripheral
                delegate:(id<TIUpdateManagerDelegate>)delegate;

- (void)updateWithImagePath:(NSString *)imagePath;

- (void)cancelUpdate;

@end

@protocol TIUpdateManagerDelegate <NSObject>

- (void)updateManager:(TIUpdateManager *)manager didUpdatePercentComplete:(float)percent;
- (void)updateManager:(TIUpdateManager *)manager didFinishUpdate:(NSError *)error;

@end
