//
//  FTTouchClassifier.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import "Core/Memory.h"
#import "Core/Touch/TouchTracker.h"
#import "FiftyThreeSdk/FTTouchClassifier+Private.h"
#import "FiftyThreeSdk/FTTouchClassifier.h"
#import "FiftyThreeSdk/TouchClassifier.h"

@implementation  FTTouchClassificationInfo
@end

using namespace fiftythree::core;
using namespace fiftythree::sdk;
using std::vector;

@interface FTTouchClassifier ()
@property (nonatomic) EventToObjCAdapter<const vector<TouchClassificationChangedEventArgs> & >::Ptr touchClassificationsDidChangeAdapter;
@end

using namespace fiftythree::core;
using namespace fiftythree::sdk;
@implementation FTTouchClassifier

- (id)init
{

    if (self = [super init])
    {
        TouchClassifier::Ptr classifier = ActiveClassifier::Instance();

        if (classifier)
        {
            self.touchClassificationsDidChangeAdapter = EventToObjCAdapter<const std::vector<TouchClassificationChangedEventArgs> & >::Bind(classifier->TouchClassificationsDidChange(),
                                                                                                                                        self,
                                                                                                                                        @selector(touchClassificationsDidChange:));
        }

        return self;
    }
    return nil;
}
- (void)dealloc
{
    // Unsub
}
+ (FTTouchClassification)classification:(const fiftythree::core::TouchClassification &)c
{
    switch (c)
    {
        case TouchClassification::UnknownDisconnected:
        {
            return FTTouchClassificationUnknownDisconnected;
        }
        break;
        case TouchClassification::Unknown:
        {
            return FTTouchClassificationUnknown;
        }
        break;
        case TouchClassification::Finger:
        {
            return FTTouchClassificationFinger;
        }
        break;
        case TouchClassification::Palm:
        {
            return  FTTouchClassificationPalm;
        }
        break;
        case TouchClassification::Pen:
        {
            return FTTouchClassificationPen;
        }
        break;
        case TouchClassification::Eraser:
        {
            return FTTouchClassificationEraser;
        }
        break;
        default:
        {
            return FTTouchClassificationUnknownDisconnected;
        }
        break;
    }
    return FTTouchClassificationUnknownDisconnected;
}
- (void)touchClassificationsDidChange: (const vector<TouchClassificationChangedEventArgs> & )args
{
    NSMutableSet *updatedTouchClassifications = [[NSMutableSet alloc] init];

    for(const auto & t : args)
    {
        FTTouchClassificationInfo *info = [[FTTouchClassificationInfo alloc] init];
        info.touch = static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->UITouchForTouch(t.touch);
        info.oldValue = [FTTouchClassifier classification:t.oldValue];
        info.newValue = [FTTouchClassifier classification:t.newValue];
        [updatedTouchClassifications addObject:info];
    }

    [self.delegate classificationsDidChangeForTouches:updatedTouchClassifications];
}

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

- (void)update
{
    auto classifier = ActiveClassifier::Instance();

    if (classifier)
    {
        classifier->UpdateClassifications();
    }
}

- (void)removeTouchFromClassification:(UITouch *)touch
{
    auto classifier = ActiveClassifier::Instance();
    if (classifier)
    {
        auto ftTouch = static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->TouchForUITouch(touch);
        classifier->RemoveTouchFromClassification(ftTouch);
    }
}

@end
