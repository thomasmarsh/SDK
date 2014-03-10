//
//  FTTouchClassifier.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

@class UITouch;

typedef NS_ENUM(NSInteger, FTTouchClassification) {
    // whenever the Pen isn't connected we return this default state.
    FTTouchClassificationUnknownDisconnected,
    // whenever we don't know what the touch is.
    FTTouchClassificationUnknown,
    // whenever we think the touch is a single finger. Note, this at
    // the moment only is triggered if there's 1 touch active on the screen.
    FTTouchClassificationFinger,
    // whenever we think the touch is a palm touch
    FTTouchClassificationPalm,
    // whenever we think the touch correspoinds to the pen tip.
    FTTouchClassificationPen,
    // whenever we think the touch corresoponds to the eraser.
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

@interface FTTouchClassifier : NSObject

// Register for change notification via this delegate.
@property (nonatomic, weak)   id <FTTouchClassificationsChangedDelegate>   delegate;

// Returns true if the touch is currently being tracked. Otherwise it returns false.
- (BOOL)classification:(FTTouchClassification *)result forTouch:(UITouch *)touch;

// Indiciates that a touch should no longer be considered a candidate for pen
// classification. This case be useful if you're implementing custom GRs.
// For example Paper's loupe control uses this to allow manipulation of the loupe and
// smudging with one finger.
- (void)removeTouchFromClassification:(UITouch *)touch;

@end
