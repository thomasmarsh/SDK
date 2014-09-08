//
//  Classifier.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "Core/Enum.h"
#include "Core/Event.hpp"
#include "Core/Memory.h"
#include "Core/Touch/Touch.h"
#include "FiftyThreeSdk/TouchClassifier.h"

namespace fiftythree
{
namespace sdk
{

DEFINE_ENUM(EdgeThumbState,
            NotThumb,
            Possible,
            Thumb);

struct PenEvent
{
    PenEventType _type;
    double       _timestamp;

    PenEvent() : _type(PenEventType::Tip1Up), _timestamp(0.0) {}

    bool UpEvent() const
    {
        return _type == PenEventType::Tip1Up || _type == PenEventType::Tip2Up;
    }

    bool DownEvent() const
    {
        return _type == PenEventType::Tip1Down || _type == PenEventType::Tip2Down;
    }
};

// This is the primary API to communicate with this module.
class Classifier
{
public:
    typedef fiftythree::core::shared_ptr<Classifier> Ptr;
    typedef fiftythree::core::shared_ptr<const Classifier> cPtr;

    // Invoke this to update internal classification structures.
    virtual bool ReclassifyIfNeeded(double timestamp = -1.0) = 0;

    // Invoke these on pen connections & disconnections.
    // If the pen is disconnected the classifier returns all Touches with state
    // TouchClassification::UnknownDisconnected.
    virtual void StylusConnected() = 0;
    virtual void StylusDisconnected() = 0;

    // Let the classifier know of changes to the world.
    virtual void OnPenEvent(const PenEvent & pen) = 0;
    virtual void OnTouchesChanged(const std::set<core::Touch::Ptr> & set) = 0;

    // The caller can let the classifier know a touch has been marked
    virtual void RemoveTouchFromClassification(core::TouchId touchId) = 0;

    // Invoke this on each touch ID, to get the latest classification. Note, this
    // may take a few frames to be up-to-date.
    virtual core::TouchClassification Classify(core::TouchId touchID)  = 0;

    // Given a pair of touches what are their most likely type.
    virtual core::TouchClassification ClassifyPair(core::TouchId touch0, core::TouchId touch1, const TwoTouchPairType & type)  = 0;

    // Given a single touch what is mostly likely for 1-touch gestures.
    virtual core::TouchClassification ClassifyForGesture(core::TouchId touch0, const SingleTouchGestureType & type) = 0;

    // TODO:
    //  Revisit this API once isolated stroke stuff has settled down a bit.
    //  Ideally GRs ask binary questions rather than have to know about ranges and valid stats...
    virtual Eigen::VectorXf GeometricStatistics(core::TouchId  touch0) = 0;

    virtual void SetUseDebugLogging(bool v) = 0;

    // Returns a list of touch ids since the last call to ClearTouchesReclassified
    virtual std::vector<core::TouchId> TouchesReclassified() = 0;

    virtual void ClearTouchesReclassified() = 0;

    virtual void ClearSessionStatistics() = 0;
    virtual fiftythree::sdk::SessionStatistics::Ptr SessionStatistics() = 0;

    // TODO:
    //    API clean up. Rightnow these live in an interface so we can get at them from within Paper.

    //  IsolatedStrokes::IsTap uses these.
    // values from Amit's work
    float _maxTapArcLengthAtMaxDuration = 85;
    float _maxTapArcLengthAtMinDuration = 55;
    // values from Matt.
    float _minTapDuration = 0.016f;
    float _maxTapDuration = 0.2f;
    // Existing values.
    float _maxPenEventWaitTime = .3f;
    float _longPenLength = 250.0f;
    float _longFingerLength = 66.0f;
    float _longDuration = 1.2f;
    float _fingerTapIsolationSeconds = 0.139206f;

    // we remove bogus up-down pairs.  sometimes this removes the wrong things.
    // we have a workaround which prevents pens from being reclassified as palms when they are at the pen
    // end.  the minPenDownDt is a sanity check on the pen-down event for that particular touch, we don't
    // want the workaround to fire when the best pen event arrived long before the touch began since this
    // is very unlikely.
    bool  _debounceWorkaroundEnabled = true;
    float _debounceWorkaroundMinPenDownDt = 0.0f;

    bool  _trustHandednessOnceLocked = true;

    bool  _handednessRequirePenDown = false;
    bool  _handednessNoPenDownMinLength = 11.0f;
    float _handednessRecentPenEventDt = .3f;
    float _handednessMinPenDownDt = -.0167;
    float _handednessMaxPenDownDt = .5f;

    // required predelay for a finger smudge sequence.  once a sequence begins,
    // subsequent touches don't need any temporal isolation from each other
    float _fingerSmudgeIsolationSeconds = .135f;

    // the smudge isolation above is used to control the predelay before a smudge sequence.
    // this controls temporal isolation for taps within a sequence.
    float _smudgeTapIsolationSeconds = .1429604f;

    // really fast tapping can violate the isolation time _smudgeTapIsolationSeconds if it's larger than .9 or so.
    // so if we see (_smudgeCommitCount) fingers in the current cluster event, don't apply
    // the isolation rule anymore.  assume they're just tapping really fast.
    // we still apply the other rules for declaring finger, so this should be pretty safe
    int   _smudgeCommitCount = 2;

    float _minFingerIsolatedStrokeTravel = 7.0f; // Was 44, see IsolatedStrokes TestPalmVFinger.
    // number of cycles we're allowing pen events to arrive before touches.
    float _penDownBeforeTouchCycleThreshold = 8.0f;
    float _penUpAfterTouchCycleThreshold = 8.0f;

    // The parameters below are used in ClassifyPairs. See sliders in PalmRejectionTestApp to create them...
    float _pairwisePinchTotalTravelThreshold = 11.029411;
    float _pairwisePinchAbsDotThreshold = 0.711765;
    float _pairwisePinchLengthThreshold = 6.078432;
    float _pairwisePinchCorrelationCutoff = 0.194118;
    float _pairwisePinchFingerCutoff = 0.845098;
    float _pairwisePinchLengthRatioCutoff = 0.000000;
    float _pairwisePinchKinkFreeCutoff = 0.715686;
    float _pairwisePanLengthThreshold = 8.823529;
    float _pairwisePanCorrelationCutoff = 0.150980;
    float _pairwisePanFingerCutoff = 0.727451;
    float _pairwisePanLengthRatioCutoff = 0.000000;
    float _pairwisePanKinkFreeCutoff = 0.292157;
    float _pairwisePanStartDistanceThreshold = 235.705887;
    float _pairwisePanPalmCentroidTime = 0.756863;
    float _pairwisePanPalmCentroidThreshold = 108.221474;

    float _maxTapGestureTapArcLengthAtMaxDuration = 22;
    float _maxTapGestureTapArcLengthAtMinDuration = 13;
    // values from Matt.
    float _minTapGestureTapDuration =  0.0145f;
    float _maxTapGestureTapDuration =  0.32;

    // only debounce the really insane ones.  if we debounce everything, we end up eliminating valid
    // data which has lousy timing data.
    float _debounceInterval = .005f;

    static Classifier::Ptr New();
};
}
}
