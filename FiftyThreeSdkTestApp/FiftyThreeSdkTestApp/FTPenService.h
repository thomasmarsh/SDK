//
//  FTPenService.h
//  FiftyThreeSdkTestApp
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

@protocol FTPenServiceDelegate;

@interface FTPenService : NSObject

@property (nonatomic) id<FTPenServiceDelegate> delegate;

@property (nonatomic, readonly) BOOL isTipPressed;
@property (nonatomic, readonly) BOOL isEraserPressed;

@end

@protocol FTPenServiceDelegate

- (void)penService:(FTPenService *)penService connectionStateChanged:(BOOL)connected;

@end
