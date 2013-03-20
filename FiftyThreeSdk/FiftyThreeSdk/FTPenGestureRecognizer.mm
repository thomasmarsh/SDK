//
//  FTPenGestureRecognizer.m
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTPenGestureRecognizer.h"
#import <UIKit/UIKit.h>

#include <boost/foreach.hpp>
#include <boost/shared_ptr.hpp>
#include <vector>
#include <set>
#include "Common/PenManager.h"
#include "Common/TouchManager.h"
#include "Common/Asserts.h"

#include "TouchClassifier.h"
#include "LatencyTouchClassifier.h"

using namespace fiftythree::sdk;
using namespace fiftythree::common;

@interface FTPenGestureRecognizer ()

@property (nonatomic) std::vector<TouchClassifier::Ptr> classifiers;

@end

TouchPhase PhaseFromUIKit(UITouch *touch)
{
    switch (touch.phase)
    {
        case UITouchPhaseBegan:
            return TouchPhase::Began;
        case UITouchPhaseCancelled:
            return TouchPhase::Cancelled;
        case UITouchPhaseMoved:
            return TouchPhase::Moved;
        case UITouchPhaseEnded:
            return TouchPhase::Ended;
        case UITouchPhaseStationary:
            return TouchPhase::Stationary;
        default:
            DebugAssert(false);
            return TouchPhase::Unknown;
            break;
    }
}

Touch::Ptr TouchFromUITouch(UITouch *uiTouch, UIView *view)
{
    Touch::Ptr touch = Touch::New();
    CGPoint p = [uiTouch locationInView:view];
    InputSample sample(p.x, p.y, uiTouch.timestamp);
    
    if (touch->History)
    {
        touch->History->push_back(sample);
    }
    
    touch->Phase = PhaseFromUIKit(uiTouch);
    touch->Sample = sample;
    
    return touch;
}

TouchesSet TouchesSetFromNSSet(NSSet *nsSet, UIView *view)
{
    TouchesSet touchesSet;
    for (UITouch *touch in nsSet)
    {
        touchesSet.insert(TouchFromUITouch(touch, view));
    }

    return touchesSet;
}

@implementation FTPenGestureRecognizer

- (id)init
{
    self = [super init];
    if (self)
    {
        [self setCancelsTouchesInView:NO];
        [self setDelaysTouchesBegan:NO];
        [self setDelaysTouchesEnded:NO];

        _classifiers.push_back(LatencyTouchClassifier::New());

        DebugAssert(_classifiers.size());
    }
    
    return self;
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSLog(@"touchesBegan: %@", touches.allObjects);

    [super touchesBegan:touches withEvent:event];
    
    TouchesSet touchesSet = TouchesSetFromNSSet(touches, self.view);
    BOOST_FOREACH(const TouchClassifier::Ptr & classifier, self.classifiers)
    {
        classifier->TouchesBegan(touchesSet);
    }
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSLog(@"touchesMoved: %@", touches.allObjects);

    [super touchesMoved:touches withEvent:event];

    TouchesSet touchesSet = TouchesSetFromNSSet(touches, self.view);
    BOOST_FOREACH(const TouchClassifier::Ptr & classifier, self.classifiers)
    {
        classifier->TouchesMoved(touchesSet);
    }
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSLog(@"touchesEnded: %@", touches.allObjects);

    [super touchesEnded:touches withEvent:event];

    TouchesSet touchesSet = TouchesSetFromNSSet(touches, self.view);
    BOOST_FOREACH(const TouchClassifier::Ptr & classifier, self.classifiers)
    {
        classifier->TouchesEnded(touchesSet);
    }
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSLog(@"touchesCancelled: %@", touches.allObjects);

    [super touchesCancelled:touches withEvent:event];
    
    TouchesSet touchesSet = TouchesSetFromNSSet(touches, self.view);
    BOOST_FOREACH(const TouchClassifier::Ptr & classifier, self.classifiers)
    {
        classifier->TouchesCancelled(touchesSet);
    }
}

- (void) ignoreTouch:(UITouch *)touch forEvent:(UIEvent *)event
{
    //	Overriding this prevents touchesMoved:withEvent:
    //	not being called after moving a certain threshold
}

@end
