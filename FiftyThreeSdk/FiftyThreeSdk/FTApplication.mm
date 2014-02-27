//
//  FTApplication.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import "Common/Touch/TouchTracker.h"
#import "Core/Touch/Touch.h"
#import "FTApplication.h"
#import "FTPen.h"
#import "FTPenManager.h"

using namespace fiftythree::common;
using namespace fiftythree::core;

using boost::optional;

@interface FTApplication () {
    optional<TouchClassifier::Ptr> _classifier;
}

@property (nonatomic) BOOL hasSeenFTPenManager;

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
    }

    // Initialize the classifier here, as early as possible, since other components may try to consume it
    // in their initialization.
    [self classifier];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Touch Classification

- (TouchClassifier::Ptr)createClassifier
{
    return TouchClassifier::Ptr();
}

- (TouchClassifier::Ptr)classifier
{
    // Don't instantiate the classifier until we've seen an FTPenManager. That way classification doesn't
    // interfere with devices that don't support Pencil, and performance is not degraded if Pencil is not
    // used on devices that do support it but disable it (possibly).
    if (self.hasSeenFTPenManager && !_classifier)
    {
        // Lazily create the classifier.
        _classifier = [self createClassifier];
        ActiveClassifier::Activate(*_classifier);
    }

    return _classifier ? * _classifier : TouchClassifier::Ptr();
}

#pragma mark - Event Dispatch

- (void)sendEvent:(UIEvent *)event
{
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
        }
    }

    [super sendEvent:event];
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

        switch (manager.state)
        {
            case FTPenManagerStateUninitialized:
            case FTPenManagerStateUpdatingFirmware:
            case FTPenManagerStateUnpaired:
            case FTPenManagerStateConnecting:
            case FTPenManagerStateReconnecting:
            case FTPenManagerStateDisconnected:
            case FTPenManagerStateDisconnectedLongPressToUnpair:
            case FTPenManagerStateSeeking:
                classifier->SetPenConnected(false);
                break;
            case FTPenManagerStateConnected:
            case FTPenManagerStateConnectedLongPressToUnpair:
                classifier->SetPenConnected(true);
                break;
            default:
                DebugAssert(false);
        }
    }
}

@end
