//
//  TIUpdateManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TIUpdateManagerState) {
    TIUpdateManagerStateNotStarted,
    TIUpdateManagerStateStarting,
    TIUpdateManagerStateInProgress,
    TIUpdateManagerStateFailed,
    TIUpdateManagerStateCancelled,
    TIUpdateManagerStateProbablyDone
};

@class CBPeripheral;

@protocol TIUpdateManagerDelegate;

@interface TIUpdateManager : NSObject

@property (nonatomic) TIUpdateManagerState state;
@property (nonatomic) BOOL shouldRestorePeripheralDelegate;

- (id)init __unavailable;

- (id)initWithPeripheral:(CBPeripheral *)peripheral
                delegate:(id<TIUpdateManagerDelegate>)delegate;

- (void)startUpdateFromWeb;

- (void)startUpdate:(NSString *)imagePath;

- (void)cancelUpdate;

@end

@protocol TIUpdateManagerDelegate <NSObject>

- (void)updateManager:(TIUpdateManager *)manager didLoadFirmwareFromWeb:(NSInteger)firmwareVersion;
- (void)updateManager:(TIUpdateManager *)manager didBeginUpdateToVersion:(uint16_t)firmwareUpdateVersion;
- (void)updateManager:(TIUpdateManager *)manager didUpdatePercentComplete:(float)percent;
- (void)updateManager:(TIUpdateManager *)manager didFinishUpdate:(NSError *)error;

@end
