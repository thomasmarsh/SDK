//
//  FTXCallbackURL.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

// Internal helper for parsing x-callback-urls.
@interface FTXCallbackURL : NSURL {
}
// Create a XCallbackUrl with named parameters. This sets up query parameters & url encodes the bits.
+ (FTXCallbackURL *)URLWithScheme:(NSString *)scheme
                             host:(NSString *)host
                           action:(NSString *)action
                           source:(NSString *)source
                       successUrl:(NSURL *)success
                         errorUrl:(NSURL *)error
                        cancelUrl:(NSURL *)cancel;

// Parse components etc.. out of an vanilla NSURL.
+ (FTXCallbackURL *)URLWithNSURL:(NSURL *)other;

@property (nonatomic, readonly) NSString *source;
@property (nonatomic, readonly) NSURL *successUrl;
@property (nonatomic, readonly) NSURL *errorUrl;
@property (nonatomic, readonly) NSURL *cancelUrl;
@property (nonatomic, readonly) NSString *action;

@end
