//
//  FTTrialSeparationMonitor.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Core/Property.hpp"
#import "Core/Threading.h"
#import "Core/Touch/TouchTracker.h"
#import "FTPen.h"
#import "FTPenManager+Private.h"
#import "FTTrialSeparationMonitor.h"

using namespace fiftythree::core;

static const NSTimeInterval kTrialSeparationInitializeTime = 1.0;

@interface FTTrialSeparationMonitor ()
@property (nonatomic) NSTimer *timer;
@property (nonatomic) PropertyToObjCAdapter<int>::Ptr touchAdapter;
@end

@implementation FTTrialSeparationMonitor

- (id)init
{
    if (self = [super init])
    {
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
