//
//  FTTrialSeparationMonitor.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Common/Property.hpp"
#import "Common/Threading.h"
#import "Common/Touch/TouchTracker.h"
#import "FTPen.h"
#import "FTPenManager+Private.h"
#import "FTTrialSeparationMonitor.h"

using namespace fiftythree::common;

static const NSTimeInterval kTrialSeparationInitializeTime = 1.0;

@interface FTTrialSeparationMonitor ()
@property (nonatomic) NSTimer *timer;
@property (nonatomic) PropertyToObjCAdapter<int>::Ptr touchAdapter;
@property (nonatomic) NSDate *lastApplicationDidBecomeActiveTime;
@end

@implementation FTTrialSeparationMonitor

- (id)init
{
    if (self = [super init])
    {
        self.lastApplicationDidBecomeActiveTime = [NSDate date];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(penIsTipPressedDidChange:)
                                                     name:kFTPenIsTipPressedDidChangeNotificationName
                                                   object:nil];

        self.touchAdapter = PropertyToObjCAdapter<int>::Bind(TouchTracker::Instance()->LiveTouchCount(),
                                                             self,
                                                             @selector(touchTrackerLiveTouchCountDidChange:newValue:));

    }
    return self;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    self.lastApplicationDidBecomeActiveTime = [NSDate date];
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    [self clearTimer];
}

- (void)touchTrackerLiveTouchCountDidChange:(const int &)oldValue
                                   newValue:(const int &)newValue
{
    DebugAssert(IsMainThread());
    if (newValue > 0)
    {
        [self clearTimer];
    }
}

- (void)dealloc
{
    [self clearTimer];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)clearTimer
{
    if (self.timer)
    {
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)timerFired:(NSTimer *)timer
{
    [self.penManager startTrialSeparation];
    [self clearTimer];
}

- (void)tipWasPressed
{
    NSTimeInterval timeSinceLastAppDidBecomeActive = -[self.lastApplicationDidBecomeActiveTime timeIntervalSinceNow];

    // Only consider a trial separation if the app is active and it's been at least a little while since the
    // app became action. If you don't wait a little bit, it's possible to get tip pressed w/out a touch,
    // thereby causing a trial separation.
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive &&
        timeSinceLastAppDidBecomeActive > 3.0)
    {
        bool haveRecentlySeenATouch = std::abs([[NSProcessInfo processInfo] systemUptime] - TouchTracker::Instance()->LastProcessedTimestamp()) < 0.25;
        if (!haveRecentlySeenATouch && TouchTracker::Instance()->LiveTouchCount() == 0)
        {
            [self clearTimer];
            self.timer = [NSTimer scheduledTimerWithTimeInterval:kTrialSeparationInitializeTime
                                                 target:self
                                               selector:@selector(timerFired:)
                                               userInfo:nil
                                                repeats:NO];

        }
    }
}

- (void)tipWasReleased
{
    [self clearTimer];
}

- (void)penIsTipPressedDidChange:(NSNotification *)notification
{
    FTPen *pen = (FTPen*)notification.object;
    if (pen && pen.isTipPressed)
    {
        [self tipWasPressed];
    }
    else
    {
        [self tipWasReleased];
    }
}

@end
