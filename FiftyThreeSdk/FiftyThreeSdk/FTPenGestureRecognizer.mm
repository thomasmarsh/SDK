//
//  FTPenGestureRecognizer.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTPenGestureRecognizer.h"
#import <UIKit/UIKit.h>

#include "Common/TouchManager.h"
#include "TouchClassifierManager.h"

using namespace fiftythree::sdk;
using namespace fiftythree::common;

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

@interface FTPenGestureRecognizer ()

@end

@implementation FTPenGestureRecognizer

- (id)initWithTouchClassifierManager:(TouchClassifierManager::Ptr)manager
{
    self = [super init];
    if (self)
    {
        [self setCancelsTouchesInView:NO];
        [self setDelaysTouchesBegan:NO];
        [self setDelaysTouchesEnded:NO];

        _manager = manager;
    }

    return self;
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSLog(@"touchesBegan: %@", touches.allObjects);

    [super touchesBegan:touches withEvent:event];

    TouchesSet touchesSet = TouchesSetFromNSSet(touches, self.view);
    self.manager->TouchesBegan(touchesSet);
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSLog(@"touchesMoved: %@", touches.allObjects);

    [super touchesMoved:touches withEvent:event];

    TouchesSet touchesSet = TouchesSetFromNSSet(touches, self.view);
    self.manager->TouchesMoved(touchesSet);
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSLog(@"touchesEnded: %@", touches.allObjects);

    [super touchesEnded:touches withEvent:event];

    TouchesSet touchesSet = TouchesSetFromNSSet(touches, self.view);
    self.manager->TouchesEnded(touchesSet);
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSLog(@"touchesCancelled: %@", touches.allObjects);

    [super touchesCancelled:touches withEvent:event];

    TouchesSet touchesSet = TouchesSetFromNSSet(touches, self.view);
    self.manager->TouchesCancelled(touchesSet);
}

- (void) ignoreTouch:(UITouch *)touch forEvent:(UIEvent *)event
{
    //	Overriding this prevents touchesMoved:withEvent:
    //	not being called after moving a certain threshold
}

@end
