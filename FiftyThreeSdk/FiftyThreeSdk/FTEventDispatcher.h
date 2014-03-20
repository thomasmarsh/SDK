//
//  FTEventDispatcher.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

@class UIEvent;

//  This singleton deals handles event dispatch for
//  FiftyThree's classification system. It is used internally by FTApplication
//  This *does not* touch any blue tooth related functionality it's role is to
//  process touch data for gesture & classification purposes.
//
@interface FTEventDispatcher : NSObject

//   Only use this from the main thread.
+ (FTEventDispatcher *)sharedInstance;

//  Invoke this pass events to FiftyThree's classification system.
//  For example:
//  [[FTEventDispatcher sharedInstance] sendEvent:event];
//
//  @param  UIEvent from a UIApplication (typically a touch event.)
//
- (void)sendEvent:(UIEvent *)event;
@end
