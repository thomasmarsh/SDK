//
//  FTApplication.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import <boost/optional/optional.hpp>

#import "Common/Touch/TouchTracker.h"
#import "FTApplication.h"
#import "FTPen.h"
#import "FTPenManager.h"

using namespace fiftythree::common;
using namespace boost;

@interface FTApplication ()
{
}
@property (nonatomic)boost::optional<TouchClassifier::Ptr> classifier;
@property (nonatomic) NSTimer *timer;
@end

@implementation FTApplication

- (id)init
{
    if (self = [super init])
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(isTipPressedStateChange:)
                                                     name:kFTPenIsTipPressedDidChangeNotificationName
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(isEraserPressedStateChange:)
                                                     name:kFTPenIsEraserPressedDidChangeNotificationName
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didUpdateStateNotification:)
                                                     name:kFTPenManagerDidUpdateStateNotificationName
                                                   object:nil];

        self.timer = [NSTimer scheduledTimerWithTimeInterval: 1.0f/60.0f
                                                      target: self
                                                    selector: @selector(onTimer:)
                                                    userInfo: nil
                                                     repeats: YES];

    }
    return self;
}

- (void)onTimer:(id)token
{
    if (self.classifier && *self.classifier)
    {
        double timestamp = [[NSProcessInfo processInfo] systemUptime];
        (*self.classifier)->ReclassifyIfNeeded(timestamp);
    }
}

- (void)dealloc
{
    [self.timer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (TouchClassifier::Ptr)createClassifier
{
    return TouchClassifier::Ptr();
}

- (void)sendEvent:(UIEvent *)event
{
    // If this event is a "touches" event, then send it to the TouchTracker for processing. Hooking into touch
    // dispatch at this level allows TouchTracker to observe all touches in the system.
    if (event.type == UIEventTypeTouches)
    {
        static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->ProcessTouchesEvent(event);
        if (!self.classifier)
        {
            // Lazily create the classifier.
            self.classifier  = [self createClassifier];
        }

        if (self.classifier && *self.classifier)
        {
            std::set<Touch::Ptr> touches;

            for (UITouch *t in [event allTouches])
            {
                Touch::Ptr touch = static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->TouchForUITouch(t);
                touches.insert(touch);
            }

            (*self.classifier)->Classify(touches);
        }
    }

    NSLog(@"SendEvent");
    [super sendEvent:event];
}

- (void)isTipPressedStateChange:(NSNotification *)notification
{
    if (self.classifier && *self.classifier)
    {
        FTPen *pen = (FTPen*)notification.object;

        PenEventArgs args;
        args.Timestamp = [NSProcessInfo processInfo].systemUptime;
        args.Type = pen.isTipPressed?PenEventType::Tip1Down : PenEventType::Tip1Up;
        (*self.classifier)->UpdatePenState(args);
    }
}

- (void)isEraserPressedStateChange:(NSNotification *)notification
{
    if (self.classifier && *self.classifier)
    {
        FTPen *pen = (FTPen*)notification.object;

        PenEventArgs args;
        args.Timestamp = [NSProcessInfo processInfo].systemUptime;
        args.Type = pen.isEraserPressed?PenEventType::Tip2Down : PenEventType::Tip2Up;
        (*self.classifier)->UpdatePenState(args);
    }
}

- (void)didUpdateStateNotification:(NSNotification *)notification
{
    if (!self.classifier)
    {
        // Lazily create the classifier.
        self.classifier  = [self createClassifier];
    }

    if (self.classifier && *self.classifier)
    {
        FTPenManager *manager = (FTPenManager*)notification.object;

        switch (manager.state)
        {
            case FTPenManagerStateUninitialized:
            case FTPenManagerStateUnpaired:
            case FTPenManagerStateConnecting:
            case FTPenManagerStateReconnecting:
            case FTPenManagerStateDisconnected:
            case FTPenManagerStateSeeking:
                (*self.classifier)->SetPenConnected(false);
                break;
            case FTPenManagerStateConnected:
                (*self.classifier)->SetPenConnected(true);
                break;
            default:
                DebugAssert(false);

        }
    }
}

@end
