//
//  FTPenManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTPen.h"

typedef NS_ENUM(NSInteger, FTPenManagerState) {
    FTPenManagerStateUnavailable = 0,
    FTPenManagerStateAvailable,
};

@protocol FTPenManagerDelegate;

@interface FTPenManager : NSObject

@property(nonatomic, weak) id<FTPenManagerDelegate> delegate;
@property(nonatomic, readonly) FTPen *pen;
@property(nonatomic, readonly) FTPenManagerState state;
@property (nonatomic) BOOL isPairingSpotPressed;

- (id)initWithDelegate:(id<FTPenManagerDelegate>)delegate;

- (void)disconnect;

@end

@protocol FTPenManagerDelegate <NSObject>

- (void)penManagerDidUpdateState:(FTPenManager *)penManager;
- (void)penManager:(FTPenManager *)penManager didBegingConnectingToPen:(FTPen *)pen;
- (void)penManager:(FTPenManager *)penManager didConnectToPen:(FTPen *)pen;
- (void)penManager:(FTPenManager *)penManager didFailToConnectToPen:(FTPen *)pen;
- (void)penManager:(FTPenManager *)penManager didDisconnectFromPen:(FTPen *)pen;
- (void)penManager:(FTPenManager *)penManager didUpdateDeviceInfo:(FTPen *)pen;

@end
