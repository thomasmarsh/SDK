//
//  FTApplication.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTApplication.h"
#import "Common/Touch/TouchTracker.h"

using namespace fiftythree::common;
using namespace boost;

@implementation FTApplication

- (void)sendEvent:(UIEvent *)event
{
    // If this event is a "touches" event, then send it to the TouchTracker for processing. Hooking into touch
    // dispatch at this level allows TouchTracker to observe all touches in the system.
    if (event.type == UIEventTypeTouches)
    {
        static_pointer_cast<TouchTrackerObjC>(TouchTracker::Instance())->ProcessTouchesEvent(event);
    }

    [super sendEvent:event];
}

@end
