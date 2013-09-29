//
//  FTPenServiceClient.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

#import "FTServiceClient.h"

@protocol FTPenServiceClientDelegate;

@interface FTPenServiceClient : FTServiceClient

- (id)initWithPeripheral:(CBPeripheral *)peripheral;

@property (nonatomic, weak) id<FTPenServiceClientDelegate> delegate;

@property (nonatomic, readonly) BOOL isReady;
@property (nonatomic, readonly) BOOL isTipPressed;
@property (nonatomic, readonly) BOOL isEraserPressed;
@property (nonatomic, readonly) float eraserPressure;
@property (nonatomic, readonly) float tipPressure;
@property (nonatomic, readonly) NSInteger batteryLevel;
@property (nonatomic, readonly) BOOL isPoweringOff;
@property (nonatomic, readonly) NSDate *lastTipReleaseTime;

// Defaults to YES
@property (nonatomic) BOOL requiresTipBePressedToBecomeReady;

- (void)startSwinging;
- (void)powerOff;

@end

@protocol FTPenServiceClientDelegate <NSObject>

- (void)penServiceClient:(FTPenServiceClient *)penServiceClient didEncounterError:(NSError *)error;
- (void)penServiceClient:(FTPenServiceClient *)penServiceClient isReadyDidChange:(BOOL)isReady;
- (void)penServiceClient:(FTPenServiceClient *)penServiceClient isTipPressedDidChange:(BOOL)isTipPressed;
- (void)penServiceClient:(FTPenServiceClient *)penServiceClient didUpdateTipPressure:(float)tipPressure;
- (void)penServiceClient:(FTPenServiceClient *)penServiceClient didUpdateEraserPressure:(float)eraserPressure;
- (void)penServiceClient:(FTPenServiceClient *)penServiceClient isEraserPressedDidChange:(BOOL)isEraserPressed;
- (void)penServiceClient:(FTPenServiceClient *)penServiceClient batteryLevelDidChange:(NSInteger)batteryLevel;

@end
