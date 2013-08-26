//
//  FTPenManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

#import "FTPen.h"

typedef NS_ENUM(NSInteger, FTPenManagerState)
{
    FTPenManagerStateUninitialized,
    FTPenManagerStateUnpaired,
    FTPenManagerStateConnecting,
    FTPenManagerStateReconnecting,
    FTPenManagerStateConnected,
    FTPenManagerStateDisconnected
};

extern NSString * const kFTPenManagerDidUpdateStateNotificationName;

@protocol FTPenManagerDelegate;

@interface FTPenManager : NSObject

@property (nonatomic, readonly) FTPen *pen;
@property (nonatomic, readonly) FTPenManagerState state;

@property (nonatomic, weak) id<FTPenManagerDelegate> delegate;
@property (nonatomic) BOOL isPairingSpotPressed;

- (id)initWithDelegate:(id<FTPenManagerDelegate>)delegate;

- (void)disconnect;

@end

@protocol FTPenManagerDelegate <NSObject>

- (void)penManager:(FTPenManager *)penManager didUpdateState:(FTPenManagerState)state;
- (void)penManager:(FTPenManager *)penManager didUpdateDeviceInfo:(FTPen *)pen;

@end
