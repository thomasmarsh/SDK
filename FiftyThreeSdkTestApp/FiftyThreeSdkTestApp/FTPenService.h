//
//  FTPenService.h
//  charcoal-prototype
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol FTPenServiceDelegate;

@interface FTPenService : NSObject

@property (nonatomic) BOOL secure;
@property (nonatomic) BOOL tip1Pressed;
@property (nonatomic) BOOL tip2Pressed;
@property (nonatomic) id<FTPenServiceDelegate> delegate;

@end

@protocol FTPenServiceDelegate

- (void)penService:(FTPenService *)penService connectionStateChanged:(BOOL)connected;

@end
