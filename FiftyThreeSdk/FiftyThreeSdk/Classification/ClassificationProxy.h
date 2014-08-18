//
//  ClassificationProxy.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <cmath>

#include "FiftyThreeSdk/Classification/Cluster.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/Debug.h"
#include "FiftyThreeSdk/Classification/EigenLAB.h"
#include "FiftyThreeSdk/Classification/FiniteDifferences.h"
#include "FiftyThreeSdk/Classification/IsolatedStrokes.h"
#include "FiftyThreeSdk/Classification/PenDirection.h"
#include "FiftyThreeSdk/Classification/PenEvents.h"
#include "FiftyThreeSdk/Classification/Quadrature.h"
#include "FiftyThreeSdk/Classification/TouchLogger.h"

// It's expected that the application routes touch and pen events
// to the classifier.

//

// The ClassificationProxy is what the app will deal with.  The proxy makes final decisions,
// and shields the app from the details of how and when the decision is made.  He's supposed
// to implement the application decision rules given what the classifier thinks.
//
// _classificationProxy public methods: (all void-type)
//
// AllowNonPenEventTouches();         Allow non-PenEvent touches as TouchClassification::Pen (default, and current
// implementation)
// RejectNonPenEventTouches();        Reject all non-PenEvent touches as TouchClassification::Palm
// StylusConnected();                 Enables explicit PenEvent classification decision tree
// StylusDisconnected();              Uses implicit PenEvent classification decision tree (default, and current
// implementation)
//
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

    int _clusterId;

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

    bool ReclassifyIfNeeded(double timestamp = -1.0);

    void StylusConnected();
    void StylusDisconnected();

    // Let the classifier know of changes to the world.
    void OnPenEvent(const PenEvent & pen);
    void OnTouchesChanged(const std::set<core::Touch::Ptr> & set);

    // The caller can let the classifier know a touch has been marked
    void RemoveTouchFromClassification(core::TouchId touchId);

    core::TouchClassification Classify(core::TouchId touchID);

    void SetUseDebugLogging(bool v);

    std::vector<core::TouchId> TouchesReclassified();

    void ClearTouchesReclassified();

    core::TouchClassification ClassifyPair(core::TouchId touch0, core::TouchId touch1, const TwoTouchPairType & type);

    core::TouchClassification ClassifyForGesture(core::TouchId touch0, const SingleTouchGestureType & type);

    Eigen::VectorXf GeometricStatistics(core::TouchId  touch0);

    bool AreAnyTouchesCurrentlyPenOrEraser();

    bool HasPenActivityOccurredRecently();

    bool IsAnySwitchDown();

    bool IsReclassifiable(core::Touch::Ptr const & touch, Stroke::Ptr const &stroke);

    void RemoveEdgeThumbs();

    void ClearSessionStatistics();
    SessionStatistics::Ptr SessionStatistics();

protected:

    SessionStatistics::Ptr _sessionStatistics;

    // not really clear if these need to be exposed as tuning parameters.
    // they are used to decide when a touch can no longer be reclassified and
    // associated resources can be released.
    // 10 seconds == 600 points if 60Hz sampling
    const float _noReclassifyDuration       = 2.0f;
    const float _noReclassifyTimeSinceEnded =  .3f;

    std::map<core::TouchId, core::TouchClassification> _currentTypes;

    std::map<core::TouchId, bool> _touchLocked;

    std::map<core::TouchId, TouchStatistics> _touchStatistics;

    ClusterTracker::Ptr _clusterTracker;

    IsolatedStrokesClassifier _isolatedStrokesClassifier;
    PenEventClassifier _penEventClassifier;
    PenTracker _penTracker;

    std::deque<PenEvent> _debounceQueue;

    // True if everything not associated with a penEvent is rejected.
    bool _penEventsRequired;
    // True if stylus is connected and can deliver PenEvents
    bool _activeStylusConnected;
    // True if we simply ignore penevents
    bool _ignorePenEvents;

    void UpdateIsolationStatistics();

    const CommonData _commonData;

    std::vector<core::TouchId> _endedTouchesReclassified;
    std::vector<core::TouchId> _activeTouchesReclassified;

    Eigen::Vector2f _penDirection;

protected:

    void UpdateSessionStatistics();

    void SaveCurrentPenTipTouch(core::TouchId touchId);

    void ClassifyIsolatedStrokes();

    void ReclassifyClusters();

    void FingerTapIsolationRule(IdTypeMap & newTypes);

    void FingerToPalmRules(IdTypeMap & newTypes);

    void SetClusterType(Cluster::Ptr const & cluster, core::TouchClassification newType, IdTypeMap & changedTypes);

    IdTypeMap ReclassifyCurrentEvent();

    bool _needsClassification;

    std::vector<int> SortedIndices(std::vector<float>);

    void ClearStaleTouchStatistics();

    void ProcessDebounceQueue();

    bool _isolatedStrokesForClusterClassification;

public:

    bool _clearStaleStatistics;
    bool _showDebugLogMessages;
    bool _testingIsolated;

    // at the moment, this is used in one place -- there is some bookkeeping which
    // frees up old stroke data, and part of the calculation involves clock time.
    // this is not going to work when running RTs, and should not affect anything.
    bool _rtFlag;

    std::map<core::TouchId, TouchStatistics> & TouchStatistics()
    {
        return _touchStatistics;
    }

    typedef fiftythree::core::shared_ptr<TouchClassificationProxy> Ptr;

    core::TouchClassification CurrentClass(core::TouchId touchId);

    bool PenActive();

    // this feels like it should be in PenDirection, but it shouldn't.  The decision crosses multiple
    // components.
    bool HandednessLocked();

    void InitializeTouchTypes();

    void LockTypeForTouch(core::TouchId touchId);
    bool IsLocked(core::TouchId touchId);

    float MaximumPenEventWaitTime() const;

    void SetIsolatedStrokes(bool value);

    void SetNeedsClassification()
    {
        _needsClassification = true;
        _penEventClassifier.SetNeedsClassification();
    }

    bool ActiveStylusIsConnected()
    {
        return _activeStylusConnected;
    }

    bool TouchRadiusAvailable();

    // compare the cluster's score to all concurrent clusters.
    // return the minimum ratio of (cluster score) / (other cluster score).
    // if the worst ratio is larger than one, the probe is the best alive at the time.
    // if the worst ratio is very large, this guy dominates the others and should suppress them.
    float DominationScore(Cluster::Ptr const & probeCluster);

    bool IsLongestConcurrentTouch(core::TouchId probeId);

    void DebugPrintClusterStatus();

    void AllowNonPenEventTouches();
    void RejectNonPenEventTouches();

    void IgnorePenEvents();
    void ListenForPenEvents();

    std::vector<core::TouchId> EndedTouchesReclassified();
    void ClearEndedTouchesReclassified();

    std::vector<core::TouchId> ActiveTouchesReclassified();
    void ClearActiveTouchesReclassified();

    bool UseIsolatedStrokes()
    {
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

    // touches which are very short can end in the unknown state.
    // this is a backstop which makes sure they get assigned to something before the
    // cluster is marked stale. assigning them to palm right when they end might cause problems
    // if the pen events are just late.  (this is actually common with taps).
    void SetOldUnknownTouchesToType(core::TouchClassification newType);

    void SetCurrentTime(double timestamp);

    std::vector<float> SizeDataForTouch(core::TouchId touchId);

    core::TouchClassification TouchTypeForNewCluster()
    {
        if (_activeStylusConnected || _testingIsolated)
        {
            return core::TouchClassification::Unknown;
        }
        else
        {
            return core::TouchClassification::UnknownDisconnected;
        }
    }

    // callback from clustertracker when an event ends
    void OnClusterEventEnded();
    void RecomputeClusterPriors();

    Eigen::VectorXf PenPriorForTouches(TouchIdVector const & touchIds);
    Eigen::VectorXf PenPriorForClusters(std::vector<Cluster::Ptr> const & clusters);

    inline TouchClassificationProxy():
    _commonData(&_currentTypes, &_touchLocked, this),
    _clusterTracker(ClusterTracker::Ptr::make_shared(&_commonData)),
    _isolatedStrokesClassifier(_clusterTracker, &_commonData),
    _penEventClassifier(_clusterTracker, &_commonData),
    _needsClassification(false),
    _penTracker(_clusterTracker, &_commonData),
    _showDebugLogMessages(false),
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
