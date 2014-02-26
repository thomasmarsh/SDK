//
//  OffscreenPenLongPress.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <dispatch/dispatch.h>

#include "Common/Touch/Touch.h"
#include "FiftyThreeSdk/Classification/Cluster.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/Stroke.h"
#include "FiftyThreeSdk/Classification/TouchLogger.h"

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
