//
//  OffscreenPenLongPress.cpp
//  Classification
//
//  Created by matt on 10/10/13.
//  Copyright (c) 2013 Peter Sibley. All rights reserved.
//

#include "FiftyThreeSdk/Classification/OffscreenPenLongPress.h"
#include "FiftyThreeSdk/Classification/Helpers.h"
#include "FiftyThreeSdk/Classification/ClassificationProxy.h"
#include "FiftyThreeSdk/Classification/Cluster.h"

// from Apple
dispatch_source_t CreateDispatchTimer(uint64_t interval,
                                      uint64_t leeway,
                                      dispatch_queue_t queue,
                                      dispatch_block_t block)
{
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                                     0, 0, queue);
    if (timer)
    {
        dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), interval, leeway);
        dispatch_source_set_event_handler(timer, block);
        dispatch_resume(timer);
    }
    return timer;
}




namespace fiftythree
{
namespace classification
{
    
OffscreenPenLongPressGestureRecognizer::~OffscreenPenLongPressGestureRecognizer()
{
    // this will cancel and release the timer.
    SetPaused(true);
}

    
// Rules for detecting offscreen long press:
// 1. Most recent pen event was Tip1Down
// 2. Elapsed time since most recent pen event is > _minPressDuration
// 3. There's no pen cluster which is using this pen event
//
// (3) happens when either there's no pen which is using this event,
// or (subtle) there is a long pen using this event, but it has been ended for more than 1 second.
// in the latter case, the app should technically re-render that ended stroke as palm, since the classifier
// will actually have tried to declare it to be a palm but the "don't reclassify long strokes"
// logic prevented this from happening.  seems like an obscure bug.
void OffscreenPenLongPressGestureRecognizer::CheckForLongPress()
{
    PenEventId penEvent = _clusterTracker->MostRecentPenEvent();
    
    if(penEvent < 0 || penEvent == _mostRecentLongPressPenEvent)
    {
        return;
    }
    
    
    double systemUptime = NSProcessInfoSystemUptime();
    float dt            = systemUptime - _clusterTracker->PenData(penEvent)->Time();
    
    if (_clusterTracker->PenData(penEvent)->Type() == PenEventType::Tip2Down && dt > _minPressDuration)
    {
        Cluster::Ptr matchingPenCluster = _commonData->proxy->ClusterTracker()->ClusterOfTypeForPenDownEvent(TouchType::PenTip2, penEvent);

        bool noGoodMatch             = ! matchingPenCluster;
        
        // if the cluster ended as a pen, it may still be one due to "don't reclassify" logic.
        // so we'll check for ended here.
        // if the touch ended more than one second ago, it is not a good match.
        if(matchingPenCluster)
        {
            //Cluster& cluster      = _commonData->proxy->ClusterTracker()->Cluster(matchingPenCluster);
            
            if(matchingPenCluster->AllTouchesEnded())
            {
                float dtEnded         = systemUptime - matchingPenCluster->LastTimestamp();
                if(dtEnded > 1.0f)
                {
                    noGoodMatch = true;
                }
            }
        
        }
        
        if(noGoodMatch)
        {
            _mostRecentLongPressPenEvent = penEvent;
            _commonData->proxy->LongPressWithPencilTip().Fire(Unit());
        }
    }
    
}

void OffscreenPenLongPressGestureRecognizer::SetPaused(bool paused)
{
    
    if(_paused == paused)
    {
        return;
    }
    
    if(paused)
    {
        if(_timer)
        {
            // we could also suspend it, but this is simpler and performance is a non-issue.
            dispatch_source_cancel(_timer);
            dispatch_release(_timer);
            _timer = NULL;
        }
    }
    else
    {
        
        if(! _timer)
        {
            _timer = CreateDispatchTimer(_timerInterval * NSEC_PER_SEC,
                                         .25f * _timerInterval * NSEC_PER_SEC, // tolerance -- we don't need very precise timing
                                         dispatch_get_main_queue(),
                                         ^{
                                             CheckForLongPress();
                                         });
        }

        
    }
    
    _paused = paused;

    
    
}


}
}


























