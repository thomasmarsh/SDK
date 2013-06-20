//
//  FTPenService.h
//  FiftyThreeSdkTestApp
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol FTPenServiceDelegate;

@interface FTPenService : NSObject

@property (nonatomic) BOOL secure;
@property (nonatomic) BOOL isTipPressed;
@property (nonatomic) BOOL isEraserPressed;
@property (nonatomic) id<FTPenServiceDelegate> delegate;

@end

@protocol FTPenServiceDelegate

- (void)penService:(FTPenService *)penService connectionStateChanged:(BOOL)connected;

@end
