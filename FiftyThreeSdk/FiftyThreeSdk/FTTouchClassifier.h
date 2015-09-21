/*
    FTTouchClassifier.h
    FiftyThreeSdk
 
    Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
    Use of this code is subject to the terms of the FiftyThree SDK License Agreement, included with this SDK as the file "FiftyThreeSDK-License.txt"
 */

#pragma once

// clang-format off

#import <Foundation/Foundation.h>

@class UITouch;

/*!
 @brief This enum lists all the classification states FTTouchClassifier exposes.
 
 @discussion Note - we use a placeholder state 'UnknownDisconnected' which indicates that the touch was processed when the pen wasn't connected via BTLE.
 
 @constant FTTouchClassificationUnknownDisconnected Whenever the Pen isn't connected we return this default state.
 @constant FTTouchClassificationUnknown Whenever we don't know what the touch is. This can happen if we haven't received any signals from the pen.
 @constant FTTouchClassificationFinger Whenever we think the touch is a single finger. This at the moment only is triggered if there's a single touch active on the screen.
 @constant FTTouchClassificationPalm Whenever we think the touch is a palm.
 @constant FTTouchClassificationPen Whenever we think the touch correspoinds to the pen tip.
 @constant FTTouchClassificationEraser Whenever we think the touch corresoponds to the eraser (flat side) of the pen.
 */
typedef NS_ENUM(NSInteger, FTTouchClassification){
    FTTouchClassificationUnknownDisconnected,
    FTTouchClassificationUnknown,
    FTTouchClassificationFinger,
    FTTouchClassificationPalm,
    FTTouchClassificationPen,
    FTTouchClassificationEraser,
};

/*!
 @brief This describes a Touch classification change.
 */
@interface FTTouchClassificationInfo : NSObject

// The touch property may be nil. For example if the touch has already ended but we re-classify it
// due to reading more data off the pen.
//
// Background: UITouches aren't designed to be retained
// as they are reused: https://developer.apple.com/library/ios/documentation/UIKit/Reference/UITouch_Class/
// Here's the relevant bit from Apple's UITouch documentation:
//
// "You should never retain an UITouch object when handling an event.
//  If you need to keep information about a touch from one phase to another, you should copy that information
//  from the UITouch object."
//
// This is motivation for providing the integer key touchId and the method
// (NSInteger)idForTouch:(UITouch *)touch;
//

/*!
 @brief This is motivation for providing the integer key touchId and the method (NSInteger)idForTouch:(UITouch *)touch
 */
@property (nonatomic, readonly, weak) UITouch *touch;

// See above about why we use touchId integer for book keeping code. This is unique per touch.
/*!
 @discussion If you need to keep information about a touch from one phase to another, you should copy that information from the UITouch object.
 */
@property (nonatomic, readonly) NSInteger touchId;

// Prior classification state.
/*!
 @brief Prior classification state.
 */
@property (nonatomic, readonly) FTTouchClassification oldValue;

// Newest classification result. Rendering should be updated to reflect this state.
/*!
 @brief Newest classification result. Rendering should be updated to reflect this state.
 */
@property (nonatomic, readonly) FTTouchClassification newValue;

@end

@protocol FTTouchClassificationsChangedDelegate <NSObject>
@required
/*!
 @brief touches may be reclassified after we've gotten more information from the stylus.
 
 @param touches a NSSet of FTTouchClassificationInfo objects.
 */
- (void)classificationsDidChangeForTouches:(NSSet *)touches;

@end

/*!
 @brief This is the main interface for classification-related parts of the FiftyThree SDK. The entry point is in [FTPenManager sharedInstance].classifier.
 */
@interface FTTouchClassifier : NSObject

/*!
 @brief Register for change notification via this delegate.
 */
@property (nonatomic, weak) id<FTTouchClassificationsChangedDelegate> delegate;

/*!
 @brief Checks if the touch is currently being tracked and the best classification.
 
 @param result Touch classification parameter.
 @param touch  Touch parameter.
 
 @return Returns true if the touch is currently being tracked and the best classification. If the touch isn't being tracked (for example it was cancelled or you've explicitly removed the touch from classification) this will return false.
 */
- (BOOL)classification:(FTTouchClassification *)result forTouch:(UITouch *)touch;

/*!
 @brief Checks id for touch. UIKit will reuse touch pointers, thus it can be handy to have a stable id for touches.
 
 @param touch parameter
 
 @return Returns a unique id for the touch.
 */
- (NSInteger)idForTouch:(UITouch *)touch;

/*!
 @brief Indiciates that a touch should no longer be considered a candidate for pen classification. This can be useful if you're implementing custom GRs.
 
 @discussion For example Paper's loupe control uses this to allow manipulation of the loupe and blending with one finger.
 
 @param touch parameter
 */
- (void)removeTouchFromClassification:(UITouch *)touch;

@end
// clang-format on
