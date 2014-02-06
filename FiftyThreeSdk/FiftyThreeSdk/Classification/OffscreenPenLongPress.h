//
//  OffscreenPenLongPress.h
//  Classification
//
//  Created by matt on 10/10/13.
//  Copyright (c) 2013 Peter Sibley. All rights reserved.
//

#pragma once

#include "FiftyThreeSdk/Classification/Stroke.h"
#include "Common/Touch/Touch.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/TouchLogger.h"
#include "FiftyThreeSdk/Classification/Cluster.h"

#include <dispatch/dispatch.h>


namespace fiftythree {
namespace sdk {

class OffscreenPenLongPressGestureRecognizer
{

    ClusterTracker::Ptr _clusterTracker;
    const CommonData*  _commonData;

    float   _minPressDuration;
    bool    _paused;
    double  _timerInterval;
    
    dispatch_source_t _timer;
    
    PenEventId _mostRecentLongPressPenEvent;
    
public:
    
    
    
    OffscreenPenLongPressGestureRecognizer(ClusterTracker::Ptr clusterTracker, const CommonData* dataPtr, float minPressDuration) :
    _clusterTracker(clusterTracker),
    _commonData(dataPtr),
    _minPressDuration(minPressDuration),
    _paused(true),
    _timerInterval(minPressDuration * .5f),
    _timer(NULL),
    _mostRecentLongPressPenEvent(-1)
    {
        
    }
    
    ~OffscreenPenLongPressGestureRecognizer();
    
        
    

    void SetPaused(bool paused);
    
    void CheckForLongPress();
    
};


}
}



