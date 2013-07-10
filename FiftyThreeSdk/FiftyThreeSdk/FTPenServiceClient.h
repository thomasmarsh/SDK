//
//  FTPenServiceClient.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTServiceClient.h"

@protocol FTPenServiceClientDelegate;

@interface FTPenServiceClient : FTServiceClient

- (id)initWithPeripheral:(CBPeripheral *)peripheral;

@property (nonatomic, weak) id<FTPenServiceClientDelegate> delegate;

@property (nonatomic, readonly) BOOL isReady;
@property (nonatomic, readonly) BOOL isTipPressed;
@property (nonatomic, readonly) BOOL isEraserPressed;
@property (nonatomic, readonly) NSDate *lastTipReleaseTime;

// Defaults to YES
@property (nonatomic) BOOL requiresTipBePressedToBecomeReady;
@property (nonatomic) BOOL shouldSwing;
@property (nonatomic) BOOL shouldPowerOff;

@end

@protocol FTPenServiceClientDelegate <NSObject>

- (void)penServiceClient:(FTPenServiceClient *)penServiceClient didEncounterError:(NSError *)error;
- (void)penServiceClient:(FTPenServiceClient *)penServiceClient isReadyDidChange:(BOOL)isReady;
- (void)penServiceClient:(FTPenServiceClient *)penServiceClient isTipPressedDidChange:(BOOL)isTipPressed;
- (void)penServiceClient:(FTPenServiceClient *)penServiceClient isEraserPressedDidChange:(BOOL)isEraserPressed;

@end
