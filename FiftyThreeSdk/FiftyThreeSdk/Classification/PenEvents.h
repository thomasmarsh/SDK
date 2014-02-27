//
//  PenEvents.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "Core/Touch/Touch.h"
#include "FiftyThreeSdk/Classification/Cluster.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/Stroke.h"
#include "FiftyThreeSdk/Classification/TouchLogger.h"

namespace fiftythree {
namespace sdk {

typedef std::pair<PenEventId, float> IdLikelihoodPair;

class PenEventClassifier {
protected:
    // members
    ClusterTracker::Ptr  _clusterTracker;
    const CommonData*    _commonData;

    bool _tip1DownDetected;
    bool _tip1UpDetected;

    core::TouchClassification _mostRecentTipType;

    std::list<PenEventId> _penDownCleared;

    // cache scores so we don't recompute on each request for a score
    std::map< ClusterId, std::pair<core::TouchClassification, float> > _clusterTypesAndScores;

    // store these so the classifier can resolve collisions
    std::map< core::TouchId, PenEventId > _bestPenDownEventForTouch;
    std::map< core::TouchId, PenEventId > _bestPenUpEventForTouch;

    // switch timing delay constant for switch arrival time exponentials.
    // 1 / lambda is the expected switch delay time
    //const float lambda = 20.0f;
    const float lambda = 20.0f;

    // based on some data with the production tips 11/25/2013
    const float _expectedDownDelayCycles  = 1.5f;
    const float _expectedUpPreDelayCycles = 1.0f;

public:
    // members

protected:

    void            MarkTouchTypes(IdTypeMap* touches, core::TouchId id, core::TouchClassification type);
    void            MarkTouchTypes(IdTypeMap* touches, TouchIdVector ids, core::TouchClassification type);

    void            FoundPenEventTouch(PenEventId id);
    bool            IsPenEventTouchFound(PenEventId id);

public:
    inline PenEventClassifier(ClusterTracker::Ptr clusterTracker, const CommonData* dataPtr) :
                                    _clusterTracker(clusterTracker),
                                    _commonData(dataPtr),
                                    _tip1DownDetected(false),
                                    _tip1UpDetected(false)
    {
    }

    // how long after a pen down do we wait for a switch-on event?
    // double not float, since it's used in double calculations.
    const double _maxPenEventDelay = 1.0;

    // returns probability that both down and up events were emitted by the given touch,
    // using some independence assumptions.
    std::pair<core::TouchClassification, float> TypeAndScoreForTouch(core::TouchId touchId, PenEventIdSet &validPenEvents);

    // similar to above, but used for isolated strokes.  above is used by clusters.
    std::pair<core::TouchClassification, float> TypeAndScoreForTouch(core::TouchId touchId);

    float SwitchDownLikelihoodForDeltaT(float deltaT);
    float SwitchUpLikelihoodForDeltaT(float deltaT);

    float SwitchDurationLikelihoodForTimingError(float timingError);

    std::pair<core::TouchClassification, float> TypeAndScoreForCluster(Cluster & cluster);

    IdLikelihoodPair BestPenDownEventForTouch(core::TouchId touchId, PenEventIdSet const &penDownEvents);
    IdLikelihoodPair BestPenUpEventForTouch(core::TouchId touchId,   PenEventIdSet const &penUpEvents);

    PenEventId BestPenDownEventForTouch(core::TouchId touchId);
    PenEventId BestPenUpEventForTouch(core::TouchId touchId);

    // when classifying a touch, we do not consider touches which ended more than
    // IrrelevancyTimeWindow seconds prior to the probe touch's begin time.
    // used by the clusterTracker/touchLog to determine when we can safely remove data.
    double IrrelevancyTimeWindow() const;

    float PenDownProbabilityForTouchGivenPenEvent(core::TouchId touchId, PenEventId downEventId,
                                                  TouchIdVector touchesBegan, Eigen::VectorXf prior);

    float PenUpProbabilityForTouchGivenPenEvent(core::TouchId touchId,   PenEventId upEventId,
                                                TouchIdVector touchesEnded, Eigen::VectorXf prior);

    float DurationTimeErrorProbabilityForTouch(core::TouchId probeId,
                                               float switchOnDuration,
                                               TouchIdVector concurrentTouches,
                                               Eigen::VectorXf prior);

    float SwitchOnDurationInTimeInterval(double t0, double t1);

    void SetNeedsClassification();

};

}
}
