//
//  FTEventDispatcher.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//
#import <dispatch/dispatch.h>
#import <UIKit/UIKit.h>

#import "Core/Touch/TouchTracker.h"
#import "FiftyThreeSdk/FTEventDispatcher.h"
#import "FiftyThreeSdk/FTPenManager+Internal.h"
#import "FiftyThreeSdk/FTPenManager+Private.h"
#import "FiftyThreeSdk/FTPenManager.h"
#import "FiftyThreeSdk/TouchClassifier.h"

using namespace fiftythree::core;
using namespace fiftythree::sdk;

@interface FTEventDispatcher ()
{
    TouchClassifier::Ptr _classifier;
}
@property (nonatomic) BOOL hasSeenFTPenManager;
@end

@implementation FTEventDispatcher
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
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (FTEventDispatcher *)sharedInstance
{
    NSAssert([NSThread isMainThread], @"sharedInstance must be called on the UI thread.");
    static dispatch_once_t once;
    static FTEventDispatcher *instance;
    dispatch_once(&once, ^{
        instance = [[FTEventDispatcher alloc] init];
    });
    return instance;
}

#pragma mark - Touch Classification

- (void)clearClassifierAndPenState
{
    _classifier = TouchClassifier::Ptr();
    ActiveClassifier::Activate(TouchClassifier::Ptr());
    self.hasSeenFTPenManager = NO;
}

- (void)setClassifier:(fiftythree::sdk::TouchClassifier::Ptr)classifier
{
    [self clearClassifierAndPenState];
    _classifier = classifier;
}

- (TouchClassifier::Ptr)classifier
{
    if (self.hasSeenFTPenManager && _classifier)
    {
        ActiveClassifier::Activate(_classifier);
    }

    return _classifier;
}

#pragma mark - sendEvent
- (void)sendEvent:(UIEvent *)event
{
    NSAssert([NSThread isMainThread], @"sendEvent must be called on the UI thread.");

    // If this event is a "touches" event, then send it to the TouchTracker for processing. Hooking into touch
    // dispatch at this level allows TouchTracker to observe all touches in the system.
    if (event.type == UIEventTypeTouches)
    {
        static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->ProcessTouchesEvent(event);

        TouchClassifier::Ptr classifier = self.classifier;
        if (classifier)
        {
            std::set<fiftythree::core::Touch::cPtr> touches;

            for (UITouch *t in [event allTouches])
            {
                auto touch = static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->TouchForUITouch(t);
                touches.insert(touch);
            }

            classifier->TouchesDidChanged(touches);

            [[FTPenManager sharedInstanceWithoutInitialization].delegate shouldWakeDisplayLink];
        }
    }
}

#pragma mark - Pencil

- (void)isTipPressedStateChange:(NSNotification *)notification
{
    TouchClassifier::Ptr classifier = self.classifier;
    if (classifier)
    {
        FTPen *pen = (FTPen*)notification.object;

        PenEventArgs args;
        args.Timestamp = [NSProcessInfo processInfo].systemUptime;
        args.Type = (pen.isTipPressed ?
                     PenEventType::Tip1Down :
                     PenEventType::Tip1Up);
        classifier->PenStateDidChanged(args);
    }
}

- (void)isEraserPressedStateChange:(NSNotification *)notification
{
    TouchClassifier::Ptr classifier = self.classifier;
    if (classifier)
    {
        FTPen *pen = (FTPen*)notification.object;

        PenEventArgs args;
        args.Timestamp = [NSProcessInfo processInfo].systemUptime;
        args.Type = (pen.isEraserPressed ?
                     PenEventType::Tip2Down :
                     PenEventType::Tip2Up);
        classifier->PenStateDidChanged(args);
    }
}

- (void)didUpdateStateNotification:(NSNotification *)notification
{
    self.hasSeenFTPenManager = YES;

    TouchClassifier::Ptr classifier = self.classifier;
    if (classifier)
    {
        FTPenManager *manager = (FTPenManager *)notification.object;
        BOOL connected = FTPenManagerStateIsConnected(manager.state);
        classifier->SetPenConnected(connected);
    }
}

@end
