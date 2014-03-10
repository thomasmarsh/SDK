//
//  FTTouchClassifier.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import "Core/Memory.h"
#import "Core/Touch/TouchTracker.h"
#import "FiftyThreeSdk/TouchClassifier.h"
#import "FTTouchClassifier.h"

using namespace fiftythree::core;
using namespace fiftythree::sdk;
@implementation FTTouchClassifier

- (BOOL)classification:(FTTouchClassification *)result forTouch:(UITouch *)touch
{
    Touch::Ptr ftTouch = static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->TouchForUITouch(touch);

    if (ftTouch)
    {
        if (ftTouch->CurrentClassification() == TouchClassification::UntrackedTouch ||
            ftTouch->CurrentClassification() == TouchClassification::RemovedFromClassification ||
            ftTouch->CurrentClassification() == TouchClassification::Cancelled)

        {
            return NO;
        }
        else
        {
            switch (ftTouch->CurrentClassification()())
            {
                case TouchClassification::UnknownDisconnected:
                {
                    *result = FTTouchClassificationUnknownDisconnected;
                }
                break;
                case TouchClassification::Unknown:
                {
                    *result = FTTouchClassificationUnknown;
                }
                break;
                case TouchClassification::Finger:
                {
                    *result = FTTouchClassificationFinger;
                }
                break;
                case TouchClassification::Palm:
                {
                    *result = FTTouchClassificationPalm;
                }
                break;
                case TouchClassification::Pen:
                {
                    *result = FTTouchClassificationPen;
                }
                break;
                case TouchClassification::Eraser:
                {
                    *result = FTTouchClassificationEraser;
                }
                break;
                default:
                {
                    DebugAssert(false);
                }
                break;
            }
            return YES;
        }
    }
    return NO;
}

- (void)removeTouchFromClassification:(UITouch *)touch
{
    TouchClassifier::Ptr classifier = ActiveClassifier::Instance();
    if (classifier)
    {
        Touch::Ptr ftTouch = static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->TouchForUITouch(touch);
        classifier->RemoveTouchFromClassification(ftTouch);
    }
}

@end
