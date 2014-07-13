//
//  ClassificationProxy.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <iostream>

#include "FiftyThreeSdk/Classification/Cluster.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/Debug.h"
#include "FiftyThreeSdk/Classification/DumbStylus.h"
#include "FiftyThreeSdk/Classification/EigenLAB.h"
#include "FiftyThreeSdk/Classification/FiniteDifferences.h"
#include "FiftyThreeSdk/Classification/IsolatedStrokes.h"
#include "FiftyThreeSdk/Classification/OffscreenPenLongPress.h"
#include "FiftyThreeSdk/Classification/PenDirection.h"
#include "FiftyThreeSdk/Classification/PenEvents.h"
#include "FiftyThreeSdk/Classification/Quadrature.h"
#include "FiftyThreeSdk/Classification/TouchLogger.h"
#include "math.h"

// It's expected that the application routes touch and pen events
// to the classifier.

//

/*
 The ClassificationProxy is what the app will deal with.  The proxy makes final decisions,
 and shields the app from the details of how and when the decision is made.  He's supposed
 to implement the application decision rules given what the classifier thinks.
 */

/*
 _classificationProxy public methods: (all void-type)

 AllowNonPenEventTouches();         Allow non-PenEvent touches as TouchType::PenTip1 (default, and current
 implementation)
 RejectNonPenEventTouches();        Reject all non-PenEvent touches as TouchType::Palm
 StylusConnected();                 Enables explicit PenEvent classification decision tree
 StylusDisconnected();              Uses implicit PenEvent classification decision tree (default, and current
 implementation)

*/

namespace fiftythree
{
namespace sdk
{

struct TouchStatistics
{
    float _penDownDeltaT;
    float _penUpDeltaT;
    float _switchOnDuration;
    float _touchDuration;

    float _handednessPrior;
    float _isolatedPrior;
    float _clusterPrior;
    float _touchPrior;
    float _lengthPrior;

    float _orthogonalJerk;
    float _curvatureScore;

    float _finalPenScore;
    float _smoothLength;

    float _dominationScore;
    float _preIsolation;
    float _postIsolation;

    double _tBegan;
    double _tEnded;

    int   _clusterId;

    // using 100.0f since max() is really annoying when you open the spreadsheet.
    // 100 is big enough and easy to identify as the default.
    TouchStatistics() :
    _penDownDeltaT(100.0f),
    _penUpDeltaT(100.0f),
    _switchOnDuration(0.0f),
    _touchDuration(0.0f),
    _finalPenScore(0.0f),
    _handednessPrior(-1.0f),
    _isolatedPrior(-1.0f),
    _clusterPrior(-1.0f),
    _lengthPrior(-1.0f),
    _touchPrior(-1.0f),
    _clusterId(0),
    _orthogonalJerk(-1.0f),
    _curvatureScore(-1.0f),
    _smoothLength(-1.0f),
    _dominationScore(0.0f),
    _preIsolation(100.0f),
    _postIsolation(100.0f),
    _tBegan(-1.0f),
    _tEnded(-1.0f)
    {

    }

};

class TouchClassificationProxy : public Classifier
{
public:

#pragma mark - Classifier interface.
    // Subscribe to this event to get notified
    Event<Unit> & LongPressWithPencilTip();

    bool ReclassifyIfNeeded(double timestamp = -1.0);

    void StylusConnected();
    void StylusDisconnected();

    // Let the classifier know of changes to the world.
    void OnPenEvent(const PenEvent & pen);
    void OnTouchesChanged(const std::set<common::Touch::Ptr> & set);

    // The caller can let the classifier know a touch has been marked
    void RemoveTouchFromClassification(common::TouchId touchId);

    TouchType Classify(common::TouchId touchID);

    void SetUsePrivateAPI(bool v);

    void SetUseDebugLogging(bool v);

    std::vector<common::TouchId> TouchesReclassified();

    void ClearTouchesReclassified();

    TouchType ClassifyPair(common::TouchId touch0, common::TouchId touch1, const common::TwoTouchPairType & type);

    TouchType ClassifyForGesture(common::TouchId touch0, const common::SingleTouchGesture & type);

    Eigen::VectorXf GeometricStatistics(common::TouchId  touch0);

    bool AreAnyTouchesCurrentlyPenOrEraser();

    bool HasPenActivityOccurredRecently();

    bool IsAnySwitchDown();

    bool IsReclassifiable(common::Touch::Ptr const & touch, Stroke::Ptr const &stroke);

    void RemoveEdgeThumbs();

    void ClearSessionStatistics();
    fiftythree::common::SessionStatistics::Ptr SessionStatistics();

protected:

    fiftythree::common::SessionStatistics::Ptr _sessionStatistics;

    // not really clear if these need to be exposed as tuning parameters.
    // they are used to decide when a touch can no longer be reclassified and
    // associated resources can be released.
    // 10 seconds == 600 points if 60Hz sampling
    const float _noReclassifyDuration       = 2.0f;
    const float _noReclassifyTimeSinceEnded =  .3f;

    Event<Unit> _LongPressWithPencilTip;
    std::map<common::TouchId, TouchType> _currentTypes;

    std::map<common::TouchId, bool>      _touchLocked;

    std::map<common::TouchId, TouchStatistics> _touchStatistics;

    ClusterTracker::Ptr                  _clusterTracker;

    IsolatedStrokesClassifier            _isolatedStrokesClassifier;
    PenEventClassifier                   _penEventClassifier;
    PenTracker                           _penTracker;

    OffscreenPenLongPressGestureRecognizer _offscreenPenLongPressGR;

    std::deque<PenEvent>                 _debounceQueue;

    // True if everything not associated with a penEvent is rejected.
    bool                                 _penEventsRequired;
    // True if stylus is connected and can deliver PenEvents
    bool                                 _activeStylusConnected;
    // True if we simply ignore penevents
    bool                                 _ignorePenEvents;

    void UpdateIsolationStatistics();

    const CommonData _commonData;

    std::vector<common::TouchId> _endedTouchesReclassified;
    std::vector<common::TouchId> _activeTouchesReclassified;

    Eigen::Vector2f    _penDirection;

    bool _usePrivateTouchSizeAPI;

protected:

    void UpdateSessionStatistics();

    void SaveCurrentPenTipTouch(common::TouchId touchId);

    void ClassifyIsolatedStrokes();

    void ReclassifyClusters();

    void FingerTapIsolationRule(IdTypeMap& newTypes);

    void SetClusterType(Cluster::Ptr const & cluster, TouchType newType, IdTypeMap &changedTypes);

    IdTypeMap ReclassifyCurrentEvent();

    bool _needsClassification;

    std::vector<int> SortedIndices(std::vector<float>);

    void ClearStaleTouchStatistics();

    void ProcessDebounceQueue();

    // Akil:
    bool _isolatedStrokesForClusterClassification;

public:

    bool _clearStaleStatistics;
    bool _showDebugLogMessages;
    bool _testingIsolated;

    // at the moment, this is used in one place -- there is some bookkeeping which
    // frees up old stroke data, and part of the calculation involves clock time.
    // this is not going to work when running RTs, and should not affect anything.
    bool _rtFlag;

    std::map<common::TouchId, TouchStatistics> & TouchStatistics()
    {
        return _touchStatistics;
    }

    typedef fiftythree::common::shared_ptr<TouchClassificationProxy> Ptr;

    TouchType CurrentClass(common::TouchId touchId);

    bool      PenActive();

    // this feels like it should be in PenDirection, but it shouldn't.  The decision crosses multiple
    // components.
    bool      HandednessLocked();

    void      InitializeTouchTypes();

    void      LockTypeForTouch(common::TouchId touchId);
    bool      IsLocked(common::TouchId touchId);

    float     MaximumPenEventWaitTime() const;

    void      SetIsolatedStrokes(bool value);

    void      SetNeedsClassification()
    {
        _needsClassification = true;
        _penEventClassifier.SetNeedsClassification();
    }

    bool      ActiveStylusIsConnected()
    {
        return _activeStylusConnected;
    }

    // compare the cluster's score to all concurrent clusters.
    // return the minimum ratio of (cluster score) / (other cluster score).
    // if the worst ratio is larger than one, the probe is the best alive at the time.
    // if the worst ratio is very large, this guy dominates the others and should suppress them.
    float     DominationScore(Cluster::Ptr const & probeCluster);

    bool      IsLongestConcurrentTouch(common::TouchId probeId);

    void      DebugPrintClusterStatus();

    void      AllowNonPenEventTouches();
    void      RejectNonPenEventTouches();

    void      IgnorePenEvents();
    void      ListenForPenEvents();

    std::vector<common::TouchId> EndedTouchesReclassified();
    void ClearEndedTouchesReclassified();

    std::vector<common::TouchId> ActiveTouchesReclassified();
    void ClearActiveTouchesReclassified();

    bool UseIsolatedStrokes() {
        return _isolatedStrokesForClusterClassification;
    }

    PenEventClassifier* PenEventClassifier()
    {
        return &_penEventClassifier;
    }

    IsolatedStrokesClassifier* IsolatedStrokesClassifier()
    {
        return &_isolatedStrokesClassifier;
    }

    ClusterTracker::Ptr ClusterTracker()
    {
        return _clusterTracker;
    }

    PenTracker* PenTracker()
    {
        return &_penTracker;
    }

    bool UsePrivateAPI()
    {
        return _usePrivateTouchSizeAPI;
    }

    void SetUsePrivateTouchSizeAPI(bool useIt)
    {
        _usePrivateTouchSizeAPI = useIt;
    }

    // touches which are very short can end in the unknown state.
    // this is a backstop which makes sure they get assigned to something before the
    // cluster is marked stale. assigning them to palm right when they end might cause problems
    // if the pen events are just late.  (this is actually common with taps).
    void SetOldUnknownTouchesToType(TouchType newType);

    void SetCurrentTime(double timestamp);

    std::vector<float> SizeDataForTouch(common::TouchId touchId);

    TouchType       TouchTypeForNewCluster()
    {
        if(_activeStylusConnected || _testingIsolated)
        {
            return TouchType::Unknown;
        }
        else
        {
            return TouchType::UnknownDisconnected;
        }
    }

    // callback from clustertracker when an event ends
    void            OnClusterEventEnded();

    void            RecomputeClusterPriors();

    Eigen::VectorXf PenPriorForTouches(TouchIdVector const &touchIds);
    Eigen::VectorXf PenPriorForClusters(std::vector<Cluster::Ptr> const &clusters);

    inline TouchClassificationProxy():
    _commonData(&_currentTypes, &_touchLocked, this),
    _clusterTracker(ClusterTracker::Ptr::make_shared(&_commonData)),
    _isolatedStrokesClassifier(_clusterTracker, &_commonData),
    _penEventClassifier(_clusterTracker, &_commonData),
    _needsClassification(false),
    _penTracker(_clusterTracker, &_commonData),
    _usePrivateTouchSizeAPI(false),
    _showDebugLogMessages(false),
    _offscreenPenLongPressGR(_clusterTracker, &_commonData, 3.0f),
    _rtFlag(false),
    _testingIsolated(false),
    _clearStaleStatistics(true),
    _activeStylusConnected(false)
    {

        ClearEndedTouchesReclassified();
        ClearActiveTouchesReclassified();

        ClearSessionStatistics();
    }

};

}
}
