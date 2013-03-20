//
//  FTPenManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTPen.h"

@protocol FTPenManagerDelegate;

@interface FTPenManager : NSObject

@property(nonatomic, weak) id<FTPenManagerDelegate> delegate;
@property(nonatomic, readonly) FTPen* pairedPen;
@property(nonatomic, readonly) FTPen* connectedPen;
@property(nonatomic, readonly) BOOL isReady;

- (id)initWithDelegate:(id<FTPenManagerDelegate>)delegate;
- (void)startPairing;
- (void)stopPairing;
- (void)connect;
- (void)disconnect;
- (void)deletePairedPen:(FTPen *)pen;
- (void)registerView:(UIView *)view;
- (void)deregisterView:(UIView *)view;

@end

@protocol FTPenManagerDelegate

- (void)penManager:(FTPenManager *)penManager didPairWithPen:(FTPen *)pen;
- (void)penManager:(FTPenManager *)penManager didConnectToPen:(FTPen *)pen;
- (void)penManager:(FTPenManager *)penManager didFailConnectToPen:(FTPen *)pen;
- (void)penManager:(FTPenManager *)penManager didDisconnectFromPen:(FTPen *)pen;
- (void)penManager:(FTPenManager *)penManager didUpdateDeviceInfo:(FTPen *)pen;
- (void)penManager:(FTPenManager *)penManager didUpdateDeviceBatteryLevel:(FTPen *)pen;

@end
