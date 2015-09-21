/*
    FTEventDispatcher.h
    FiftyThreeSdk
 
    Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
    Use of this code is subject to the terms of the FiftyThree SDK License Agreement, included with this SDK as the file "FiftyThreeSDK-License.txt"
 */

#pragma once

// clang-format off

#import <Foundation/Foundation.h>

@class UIEvent;

/*!
 @brief  This singleton handles event dispatch for FiftyThree's classification system.
 
 @discussion It is used internally by FTApplication This *does not* touch any Bluetooth-related functionality. Its role is to process touch data for gesture & classification purposes.
 */
@interface FTEventDispatcher : NSObject

/*!
 @brief  Only use this from the main thread.
 
 @return sharedInstance
 */
+ (FTEventDispatcher *)sharedInstance;

/*!
 @brief  Invoke this to pass events to FiftyThree's classification system.
 @discussion For example: [[FTEventDispatcher sharedInstance] sendEvent:event];
 
 
 @param event UIEvent from a UIApplication (typically a touch event.)
 */
- (void)sendEvent:(UIEvent *)event;
@end
// clang-format on
