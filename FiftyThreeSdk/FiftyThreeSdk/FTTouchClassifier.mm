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

@interface FTTouchClassificationInfo ()
@property (nonatomic, readwrite) UITouch *touch;
@property (nonatomic, readwrite) NSInteger touchId;
@property (nonatomic, readwrite) FTTouchClassification oldValue;
@property (nonatomic, readwrite) FTTouchClassification newValue;
@end

@implementation  FTTouchClassificationInfo
@end

using namespace fiftythree::core;
using namespace fiftythree::sdk;
using std::vector;

@interface FTTouchClassifier ()
@property (nonatomic) EventToObjCAdapter<const vector<TouchClassificationChangedEventArgs> & >::Ptr touchClassificationsDidChangeAdapter;
@property (nonatomic) EventToObjCAdapter<const vector<TouchClassificationChangedEventArgs> & >::Ptr touchContinuedClassificationsDidChangeAdapter;
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
            
            self.touchClassificationsDidChangeAdapter = EventToObjCAdapter<const std::vector<TouchClassificationChangedEventArgs> & >::Bind(classifier->TouchContinuedClassificationsDidChange(),
                                                                                                                                            self,
                                                                                                                                            @selector(touchClassificationsDidChange:));
        }

        return self;
    }
    return nil;
}

- (void)dealloc
{
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
            return FTTouchClassificationPalm;
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

+ (BOOL)shouldReportClassificationChange:(const TouchClassificationChangedEventArgs &)change
{
    return !(change.oldValue != TouchClassification::UnknownDisconnected &&
             change.newValue == TouchClassification::UnknownDisconnected)
    && change.newValue != TouchClassification::RemovedFromClassification &&
    change.newValue != TouchClassification::UntrackedTouch;
}

- (void)touchClassificationsDidChange: (const vector<TouchClassificationChangedEventArgs> & )args
{
    TouchClassifier::Ptr classifier = ActiveClassifier::Instance();

    NSMutableSet *updatedTouchClassifications = [[NSMutableSet alloc] init];

    for (const auto & t : args)
    {
        if ([FTTouchClassifier shouldReportClassificationChange:t])
        {
            FTTouchClassificationInfo *info = [[FTTouchClassificationInfo alloc] init];
            info.touch = spc<TouchTrackerObjC>(TouchTracker::Instance())->UITouchForTouch(t.touch);
            if (t.oldValue == TouchClassification::UnknownDisconnected && classifier->IsPenConnected())
            {
                info.oldValue = FTTouchClassificationUnknown;
            }
            else
            {
                info.oldValue = [FTTouchClassifier classification:t.oldValue];
            }

            info.newValue = [FTTouchClassifier classification: t.touch->ContinuedClassification()];
            info.touchId = (NSInteger)t.touch->Id();
            if (info.newValue != info.oldValue)
            {
                [updatedTouchClassifications addObject:info];
            }
        }
    }
    
    if ([updatedTouchClassifications count] > 0)
    {
        [self.delegate classificationsDidChangeForTouches:updatedTouchClassifications];
    }
}

// Returns a unique id for the touch.
- (NSInteger)idForTouch:(UITouch *)touch
{
    Touch::Ptr ftTouch = spc<TouchTrackerObjC>(TouchTracker::Instance())->TouchForUITouch(touch);

    if (ftTouch)
    {
        return (NSInteger)ftTouch->Id();
    }
    else
    {
        return -1;
    }
}

- (BOOL)classification:(FTTouchClassification *)result forTouch:(UITouch *)touch
{
    Touch::Ptr ftTouch = spc<TouchTrackerObjC>(TouchTracker::Instance())->TouchForUITouch(touch);

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
            switch (ftTouch->ContinuedClassification())
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
        auto ftTouch = spc<TouchTrackerObjC>(TouchTracker::Instance())->TouchForUITouch(touch);
        classifier->RemoveTouchFromClassification(ftTouch);
    }
}

@end
