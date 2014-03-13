//
//  FTTouchClassifier.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

@class UITouch;

// This enum lists all the classification states FTTouchClassifier exposes.
//
// Note - we use a place holder state 'UnknownDisconnected' which indicates that
//        the touch was processed when the pen wasn't connected via BTLE.
//
typedef NS_ENUM(NSInteger, FTTouchClassification)
{
    // Whenever the Pen isn't connected we return this default state.
    FTTouchClassificationUnknownDisconnected,
    
    // Whenever we don't know what the touch is. This can happen if we've not get
    // gotten any signals from the pen.
    FTTouchClassificationUnknown,
    
    // Whenever we think the touch is a single finger. This at
    // the moment only is triggered if there's 1 touch active on the screen.
    FTTouchClassificationFinger,
    
    // whenever we think the touch is a palm.
    FTTouchClassificationPalm,
    
    // whenever we think the touch correspoinds to the pen tip.
    FTTouchClassificationPen,
    
    // whenever we think the touch corresoponds to the eraser (flat side) of the pen.
    FTTouchClassificationEraser,
};

@interface FTTouchClassificationInfo : NSObject
@property (nonatomic) UITouch *touch;
@property (nonatomic) FTTouchClassification oldValue;
@property (nonatomic) FTTouchClassification newValue;
@end

@protocol FTTouchClassificationsChangedDelegate <NSObject>

// touches is a NSSet of FTTouchClassificationInfo objects.
// Touches may be reclassified after we've gotten more information about
// the stylus.
- (void)classificationsDidChangeForTouches:(NSSet *)touches;

@end

// This is the main interface for classification related parts of the FiftyThree SDK. The entry point
// is by [FTPenManager sharedInstance].classifier.
@interface FTTouchClassifier : NSObject

// Register for change notification via this delegate.
@property (nonatomic, weak)   id <FTTouchClassificationsChangedDelegate>   delegate;

// Returns true if the touch is currently being tracked and the best classification.
// If the touch isn't being tracked (for example it was cancelled or you've explicitly removed the touch from
// classification this will return false.
- (BOOL)classification:(FTTouchClassification *)result forTouch:(UITouch *)touch;

// Indiciates that a touch should no longer be considered a candidate for pen
// classification. This case be useful if you're implementing custom GRs.
// For example Paper's loupe control uses this to allow manipulation of the loupe and
// smudging with one finger.
- (void)removeTouchFromClassification:(UITouch *)touch;

@end
