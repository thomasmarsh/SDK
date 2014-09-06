//
//  ClassificationProxy.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include <iomanip>
#include <tuple>

#include "Core/Eigen.h"
#include "Core/Touch/Touch.h"
#include "Core/Touch/TouchTracker.h"
#include "FiftyThreeSdk/Classification/ClassificationProxy.h"
#include "FiftyThreeSdk/Classification/FiniteDifferences.h"
#include "FiftyThreeSdk/Classification/Helpers.h"
#include "FiftyThreeSdk/Classification/LineFitting.h"
#include "FiftyThreeSdk/Classification/Stroke.h"
#include "FiftyThreeSdk/Classification/TouchSize.h"

using Eigen::Vector2f;
using fiftythree::core::TouchClassification;
using fiftythree::core::TouchId;
using std::tie;
using std::vector;

using namespace fiftythree::core;

using namespace Eigen;

namespace fiftythree
{
namespace sdk
{
void TouchClassificationProxy::RemoveTouchFromClassification(TouchId touchId)
{
    if (CurrentClass(touchId) != TouchClassification::RemovedFromClassification && _clusterTracker->Data(touchId))
    {
        _clusterTracker->RemoveTouchFromClassification(touchId);
        _currentTypes[touchId] = TouchClassification::RemovedFromClassification;
        SetNeedsClassification();
    }
}

bool TouchClassificationProxy::PenActive()
{
    for (Cluster::Ptr const & cluster:_clusterTracker->CurrentEventActiveClusters())
    {
        if (cluster->IsPenType() && ! cluster->AllTouchesEnded())
        {
            return true;
        }
    }
    return false;
}

bool TouchClassificationProxy::IsAnySwitchDown()
{
    PenEventId eventId = _clusterTracker->MostRecentPenEvent();
    if (eventId == PenEventId(-1))
    {
        return false;
    }
    else
    {
        PenEventType tipType = _clusterTracker->PenType(eventId);
        return (tipType == PenEventType::Tip1Down || tipType == PenEventType::Tip2Down);
    }
}

void TouchClassificationProxy::OnPenEvent(const PenEvent & event)
{

    DebugAssert(_debounceQueue.size() <= 1);

    bool ignoreFlag = false;
    if (_activeStylusConnected)
    {
        if (event.DownEvent())
        {
            if (!_debounceQueue.empty())
            {

                float dt = event._timestamp - _debounceQueue.back()._timestamp;
                // if we got a spurious down, that means a spurious up got into the logs.
                // we will remove it now.  the next up could be the real one.
                if (dt < _debounceInterval)
                {
                    if (_showDebugLogMessages)
                    {
                        std::cerr << "\nRemoving spurious up-down pair, dt = " << dt;
                    }
                    ignoreFlag = true;
                }
                else
                {
                    // we got here before the callback did.
                    _clusterTracker->LogPenEvent(_debounceQueue.back());
                }
                _debounceQueue.pop_front();
            }
        }
        else if (event.UpEvent())
        {
            // we'd like to assert this but it happens after pairing, for example
            //DebugAssert(_debounceQueue.empty());
            _debounceQueue.clear();
            _debounceQueue.push_back(event);
        }

        if (! ignoreFlag)
        {
            _clusterTracker->LogPenEvent(event);
        }

        _needsClassification = true;

        SetCurrentTime(_clusterTracker->Time());
     }
}

void TouchClassificationProxy::LockTypeForTouch(TouchId touchId)
{
    _touchLocked[touchId] = true;
}

bool TouchClassificationProxy::IsLocked(TouchId touchId)
{
    return _touchLocked[touchId];
}

bool TouchClassificationProxy::HandednessLocked()
{
    if (_activeStylusConnected)
    {
        ClusterEventStatistics::Ptr const & stats = _clusterTracker->CurrentEventStatistics();
        float lPen = stats->_endedPenArcLength;

        bool locked  = lPen >= 88.0f && (stats->_endedPenDirectionScore > 2.0f);

        if (stats->_handednessLockFlag != locked)
        {
            stats->_handednessLockFlag = locked;
        }

        return locked;
    }
    else
    {
        return false;
    }
}

bool TouchClassificationProxy::AreAnyTouchesCurrentlyPenOrEraser()
{
    if (!_activeStylusConnected)
    {
        return false;
    }
    else
    {
        TouchIdVector touches = _clusterTracker->LiveTouches();
        for (TouchId t:touches)
        {
            if (CurrentClass(t) == TouchClassification::Pen || CurrentClass(t) == TouchClassification::Eraser)
            {
                return true;
            }
        }
        return false;
    }
}

bool TouchClassificationProxy::HasPenActivityOccurredRecently()
{
    if (_activeStylusConnected)
    {
        bool areAnyTouchesCurrentlyPenOrEraser = AreAnyTouchesCurrentlyPenOrEraser();
        if (areAnyTouchesCurrentlyPenOrEraser)
        {
            return true;
        }
        PenEventId id = _clusterTracker->MostRecentPenEvent();

        if (id != -1)
        {
            double t = NSProcessInfoSystemUptime();
            return (t - _clusterTracker->PenData(id)->Time()) < 0.08;
        }
        else
        {
            return false;
        }

    }
    else
    {
        return false;
    }
}

TouchClassification TouchClassificationProxy::ClassifyPair(TouchId touch0, TouchId touch1, const TwoTouchPairType & type)
{
    // goodness of fit of tangents over the first few points.
    // this is a sort of poor-man's correlation coefficient, optimized for the case of
    // short strokes (the case we're interested in for GR's).  correlation coefficients will
    // be unstable in this case, so simplifying to mean velocities is basically denoising.

    if (!_clusterTracker->ContainsTouchWithId(touch0) || !_clusterTracker->ContainsTouchWithId(touch1))
    {
        return TouchClassification::Unknown;
    }

    auto data0 = _clusterTracker->Data(touch0);
    auto data1 = _clusterTracker->Data(touch0);

    auto stroke0 = data0->Stroke();
    auto stroke1 = data1->Stroke();

    float corr = .5f;
    if (stroke0->Size() > 1 && stroke1->Size() > 1)
    {
        Vector2f v0 = stroke0->LastPoint() - stroke0->FirstPoint();
        Vector2f v1 = stroke1->LastPoint() - stroke1->FirstPoint();

        // we consider both plus and minus so we can handle pinch, where velocities are opposites
        // it would be better to break ClassifyPair into two methods
        // this is basically the R^2 test statistic, modified for symmetry.
        float error2 = std::min((v0-v1).squaredNorm(), (v0+v1).squaredNorm());
        corr         = std::max(0.0f, 1.0f - error2 / (v1.squaredNorm() + v0.squaredNorm()));
    }

    // this returns a regularity score between 0 and 1.
    // larger scores indicate less regular strokes.
    // (1 - score) can be used as a "geometric probability"
    float score0 = _isolatedStrokesClassifier.NormalizedScore(touch0);
    float score1 = _isolatedStrokesClassifier.NormalizedScore(touch1);

    // this is used only in the 2-finger gesture case, so we assume finger
    float pFinger0     = std::max(0.0f, std::min(1.0f, 1.0f - score0));
    float pFinger1     = std::max(0.0f, std::min(1.0f, 1.0f - score1));

    float pBothFinger  = pFinger0 * pFinger1;

    float lengthScore  = std::min(std::max(0.0f, stroke0->ArcLength() - _pairwisePinchLengthThreshold), std::max(0.0f, stroke1->ArcLength() - _pairwisePinchLengthThreshold));

    float lengthRatio = std::min(stroke0->ArcLength(), stroke1->ArcLength()) / (0.001f + std::max(stroke0->ArcLength(), stroke1->ArcLength()));

    // GIS people call this sinuosity. Very naive way to ruling out squiggly lines or lines with kinks.
    // ||s - t|| / arcLength
    float kinkFreeRatio0 = (stroke0->FirstPoint() - stroke0->LastPoint()).norm()/stroke0->ArcLength();
    float kinkFreeRatio1 = (stroke1->FirstPoint() - stroke1->LastPoint()).norm()/stroke1->ArcLength();
    float kinkFreeRatio  = std::min(kinkFreeRatio0, kinkFreeRatio1);

    // Palm touches initially can be quite far apart in the cold start case.
    // for pan, we're not interested in starting a pan with both hands.
    float startDistance = (stroke0->FirstPoint() - stroke1->FirstPoint()).norm();

    float totalLengthScore = stroke0->ArcLength() + stroke1->ArcLength();

    // Looks at the opening angle between the vectors. This is to rule out nearly parallel lines from
    // triggering a pinch.
    Vector2f d0 = stroke0->LastPoint() - stroke0->FirstPoint();
    d0.normalize();
    Vector2f d1 = stroke1->LastPoint() - stroke1->FirstPoint();
    d1.normalize();
    float dot = std::abs(d0.dot(d1));

    // This Palm logic is about dealing with the case where you have two palm touches and you're writing
    // while moving your palm. You don't want those two touches triggering a palm. You also don't want
    // that area of the screen to for-ever prevent two finger pans.
    //
    // We combine using the distance with time we end up with the code below.
    //bool veryCloseToPalm = false;
    float distanceToPalm = 1e8;
    double penTimestamp = 0.0;
    double currentTimestamp = std::min(stroke0->FirstAbsoluteTimestamp(), stroke1->FirstAbsoluteTimestamp());

    PenEventId event = _clusterTracker->MostRecentPenEvent();
    if (event != -1)
    {
        penTimestamp = _clusterTracker->PenData(event)->Time();
    }

    if (PenTracker()->TrackingPalmLocation() &&
        PenTracker()->Confidence() > 0.8f &&
        std::abs(currentTimestamp - penTimestamp) < _pairwisePanPalmCentroidTime)
    {
        const Eigen::Vector2f palmLocation = PenTracker()->PalmLocation();
        Vector2f centroid = (stroke0->FirstPoint()  + stroke1->FirstPoint()) / 2.0f;
        distanceToPalm = (centroid - palmLocation).norm();
    }

    bool isPalmViaRadiusTest = false;

    if (!stroke0->TouchRadius().empty() && !stroke1->TouchRadius().empty())
    {
        constexpr float varianceThreshold = 46.65f;
        constexpr float maxThreshold = 65.99f;

        isPalmViaRadiusTest = data0->_radiusVariance > varianceThreshold || data1->_radiusVariance > varianceThreshold;
        isPalmViaRadiusTest &= data1->_radiusMax > maxThreshold || data1->_radiusMax > maxThreshold;
    }

    switch (type)
    {
        case TwoTouchPairType::Pinch:
        {
            if (lengthScore > 0.0f &&
                pBothFinger > _pairwisePinchFingerCutoff &&
                lengthRatio > _pairwisePinchLengthRatioCutoff &&
                corr > _pairwisePinchCorrelationCutoff &&
                kinkFreeRatio > _pairwisePinchKinkFreeCutoff &&
                totalLengthScore > _pairwisePinchTotalTravelThreshold &&
                dot > _pairwisePinchAbsDotThreshold &&
                !isPalmViaRadiusTest)
            {
                return TouchClassification::Finger;
            }
            else
            {
                return TouchClassification::Palm;
            }
        }
        break;
        case TwoTouchPairType::Pan:
        {
            if (lengthScore > 0.0f &&
                pBothFinger > _pairwisePanFingerCutoff &&
                lengthRatio > _pairwisePanLengthRatioCutoff &&
                corr > _pairwisePanCorrelationCutoff &&
                kinkFreeRatio > _pairwisePanKinkFreeCutoff &&
                startDistance < _pairwisePanStartDistanceThreshold &&
                distanceToPalm > _pairwisePanPalmCentroidThreshold &&
                !isPalmViaRadiusTest)
            {
                return TouchClassification::Finger;
            }
            else
            {
                return TouchClassification::Palm;
            }
        }
        break;

        default:
            DebugAssert(false);
            break;
    }
    return TouchClassification::Unknown;
}

TouchClassification TouchClassificationProxy::ClassifyForGesture(TouchId touch0, const SingleTouchGestureType & type)
{
    // Else
    //     switch type
    //     case tap
    //          if phase != ended false, otherwise tap detect?
    //     case long press
    //          Isolation in time, limited travel? Not much else to do here.

    if (_activeStylusConnected)
    {
        if (!_clusterTracker->ContainsTouchWithId(touch0))
        {
            return TouchClassification::Unknown;
        }
        else
        {
            TouchClassification touchType = CurrentClass(touch0);

            if (touchType == TouchClassification::Pen || touchType == TouchClassification::Eraser)
            {
                return touchType;
            }

            auto touch = _clusterTracker->TouchWithId(touch0);

            if (!touch)
            {
                DebugAssert(false);
                return TouchClassification::Unknown;
            }

            TouchData::Ptr touchData = _clusterTracker->Data(touch0);
            Stroke::Ptr const & stroke = touchData->Stroke();

            switch (type)
            {
                case SingleTouchGestureType::Tap:
                {
                    if (touch->Phase() != core::TouchPhase::Ended)
                    {
                        return TouchClassification::Unknown;
                    }

                    constexpr float tapPalmVFingerThreshold = 19.63f;

                    if (touch->MaxTouchRadius() && *(touch->MaxTouchRadius()) > tapPalmVFingerThreshold)
                    {
                        return TouchClassification::Palm;
                    }
                    else if (touch->MaxTouchRadius() && *(touch->MaxTouchRadius()) <= tapPalmVFingerThreshold)
                    {
                        return TouchClassification::Finger;
                    }

                    // We only use the isolation in time test if we have no touch radius information.
                    // this isolation in time test is very conservative test so we want to avoid it if at all possible.

                    bool isStartIsolated = _touchStatistics[touch0]._preIsolation  > 0.05f;
                    bool isEndIsolated = _touchStatistics[touch0]._postIsolation  > 0.06f;

                    float dt = stroke->LastAbsoluteTimestamp() - stroke->FirstAbsoluteTimestamp();
                    float L  = stroke->ArcLength();

                    float lambda = std::min(1.0f, std::max(0.0f, (dt - _minTapGestureTapDuration) / (_maxTapGestureTapDuration - _minTapGestureTapDuration)));
                    float maxLength = lambda * _maxTapGestureTapArcLengthAtMaxDuration + (1.0f - lambda) * _maxTapGestureTapArcLengthAtMinDuration;
                    size_t numSamples = stroke->Size();

                    bool isFingerTap =  isEndIsolated && isStartIsolated && (L < maxLength) && (numSamples == 2 || L >= 0.00f)  && (dt >= _minTapGestureTapDuration) && (dt < _maxTapGestureTapDuration);

                    if (stroke->Size() >= 5)
                    {
                        float isPalmNPScore = 1.0f - _isolatedStrokesClassifier.NPVoteScore(touch0);
                        isFingerTap = isFingerTap && (isPalmNPScore < 0.5f);
                    }

                    if (isFingerTap)
                    {
                        return TouchClassification::Finger;
                    }
                    else
                    {
                        return TouchClassification::Palm;
                    }

                    break;
                }
                case SingleTouchGestureType::Drag:
                {
                    // This is used on Loupe starting with a single touch.
                    // There are a few cases here:
                    //      If something is a Pen or Eraser we early out with Pen & Eraser above.
                    //      If we only have a single touch & it's old but few samples we just assume it's the
                    //      start of the drag.
                    //      However if we have a few samples then we can use some curvature based measures to see
                    //      if we think it's a drag. These measures are unstable with 3 or fewer samples.
                    if (touch->IsPhaseEndedOrCancelled())
                    {
                        return TouchClassification::Unknown;
                    }

                    constexpr float longPressVFingerThreshold = 19.63f;

                    // Early out if we've got real radius data.
                    if (touch->MaxTouchRadius() && *(touch->MaxTouchRadius()) > longPressVFingerThreshold)
                    {
                        return TouchClassification::Palm;
                    }
                    else if (touch->MaxTouchRadius() && *(touch->MaxTouchRadius()) <= longPressVFingerThreshold)
                    {
                        return TouchClassification::Finger;
                    }

                    // Max Travel is the dist to the farthest point from the start point.
                    // maxTraval ~= arcLength  => straightline. This is pretty robust with small # samples.
                    //
                    float L = stroke->ArcLength();
                    float maxTravelOverL = stroke->Statistics()->_maxTravel / L;
                    float dt = stroke->LastAbsoluteTimestamp() - stroke->FirstAbsoluteTimestamp();
                    size_t numSamples = stroke->Size();

                    // As we get more information we put more faith in the maxTravel heuristic and tighten
                    // the time window.
                    bool t0 = dt > 0.3 && numSamples >= 2;
                    bool t1 = dt > 0.1 && maxTravelOverL > 0.97 && numSamples >= 3;
                    bool t2 = dt > 0.08 && maxTravelOverL > 0.95 && numSamples >= 4;
                    bool t3 = dt > 0.05 && maxTravelOverL > 0.95 && numSamples >= 5;
                    bool t4 = dt > 0.04 && maxTravelOverL > 0.95 && numSamples >= 6;

                    // As we get more information about a long moving touch allow that to override
                    // the time constraint.
                    bool t5 = dt > 0.06 && L > 7.0 && numSamples == 2;
                    bool t6 = dt > 0.05 && L > 9.0 && maxTravelOverL > 0.95 && numSamples >= 3;
                    bool t7 = dt > 0.04 && L > 11.0 && maxTravelOverL > 0.95 && numSamples >= 4;

                    return (t0 || t1 || t2 || t3 || t4 || t5 || t6 || t7) ?TouchClassification::Finger : TouchClassification::Unknown;

                    break;
                }
                case SingleTouchGestureType::LongPress:
                {
                    if (touch->IsPhaseEndedOrCancelled())
                    {
                        return TouchClassification::Unknown;
                    }

                    if (touch->MaxTouchRadius() && *(touch->MaxTouchRadius()) > 27.96f)
                    {
                        return TouchClassification::Palm;
                    }

                    float dt = stroke->LastAbsoluteTimestamp() - stroke->FirstAbsoluteTimestamp();
                    float L  = stroke->ArcLength();

                    float _minLongPressDuration = 0.5f;
                    float _maxLongPressDuration = 3.0f;
                    float _maxLongPressArcLength = 10.0f;
                    bool timeOK = dt >= _minLongPressDuration && dt < _maxLongPressDuration;
                    bool distanceOK = L < _maxLongPressArcLength;

                    if (timeOK && distanceOK)
                    {
                        return TouchClassification::Finger;
                    }
                    else if (dt < _minLongPressDuration)
                    {
                        return TouchClassification::Unknown;
                    }
                    else
                    {
                        return TouchClassification::Unknown;
                    }
                    break;
                }
                default:
                {
                    DebugAssert(false);
                    return TouchClassification::UnknownDisconnected;
                    break;
                }
            }
        }
    }
    else
    {
        return TouchClassification::UnknownDisconnected;
    }
}

Eigen::VectorXf TouchClassificationProxy::GeometricStatistics(TouchId  touch0)
{
    // TODO:
    //     Investigate why this lookup sometimes fails.
    if (!_clusterTracker->ContainsTouchWithId(touch0))
    {
        VectorXf result(10);
        result.setZero();
        return result;
    }

    Stroke::Ptr stroke0 = _clusterTracker->Stroke(touch0);
    float kink = (stroke0->FirstPoint() - stroke0->LastPoint()).norm() / stroke0->ArcLength();

    float score0 = _isolatedStrokesClassifier.NormalizedScore(touch0);
    float pFinger0  = std::max(0.0f, std::min(1.0f, 1.0f - score0));

    float arcLength = stroke0->ArcLength();

    float distanceToPalm = 1e8;
    if (PenTracker()->TrackingPalmLocation() &&
        PenTracker()->Confidence() > 0.8f)
    {
        const Eigen::Vector2f palmLocation = PenTracker()->PalmLocation();
        distanceToPalm = (stroke0->FirstPoint() - palmLocation).norm();
    }

    float distanceToPen = 1e8;
    if (PenTracker()->TrackingPalmLocation() &&
        PenTracker()->Confidence() > 0.8f)
    {
        const Eigen::Vector2f penLocation = PenTracker()->PenLocation();
        distanceToPen = (stroke0->FirstPoint() - penLocation).norm();
    }

    Eigen::Vector2f s;
    Eigen::Vector2f d;
    Eigen::Vector2f mean;

    // We compute PCA to find how elongated the point cloud is.
    if (stroke0->Size() > 10)
    {
        Eigen::MatrixX2f strokeData = stroke0->XYMatrixMap().bottomRows<10>();
        PCA2f(strokeData, s, d, mean);
    }
    else
    {
        PCA2f(stroke0->XYMatrixMap(), s, d, mean);
    }

    // Find farthest point from the start point to report the maxDelta.
    int idx;
    (stroke0->XYMatrixMap().rowwise() - stroke0->FirstPoint().transpose()).rowwise().squaredNorm().maxCoeff(&idx);
    Vector2f farthestDelta = stroke0->XYMatrixMap().row(idx).transpose() - stroke0->FirstPoint();

    VectorXf result(10);
    result << pFinger0, kink, (s.y() / s.x()),
              d.x(), d.y(),
              farthestDelta.x(), farthestDelta.y(), arcLength,
              distanceToPalm, distanceToPen;

    return result;
}

// Peter -- whenever we get the transition matrix ready, we could use that code here.
// This function is used in a very specific place right now, to help the cluster tracker
// know when it is safe to remove clusters.
bool TouchClassificationProxy::IsReclassifiable(core::Touch::Ptr const & touch, Stroke::Ptr const & stroke)
{

    if (!touch)
    {
        return false;
    }

    if (CurrentClass(touch->Id()) == TouchClassification::RemovedFromClassification ||
        touch->Phase() == core::TouchPhase::Cancelled)
    {
        return false;
    }

    // the negative padding seems to be necessary to handle very fast short strokes on rare occasions.  I have not
    // been able to figure out which timestamps are in disagreement and it seems to depend
    // on the number of onscreen touches as well, so padding is necessary.
    // anything older than staleInterval could be part of a previous event.  .5f because we really only need
    // some tiny padding like one cycle.
    float dt = touch->FirstSample().TimestampSeconds() - _clusterTracker->CurrentEventBeganTime();

    bool currentEventOK = (dt >= -_clusterTracker->_staleInterval * .5f);

    float duration = _clusterTracker->CurrentTime() - touch->FirstSample().TimestampSeconds();

    bool durationOK =  duration < _noReclassifyDuration;

    if (currentEventOK && durationOK)
    {
        if (touch->IsPhaseEndedOrCancelled())
        {
            float  timeSinceEnded = _clusterTracker->CurrentTime() - touch->CurrentSample().TimestampSeconds();
            bool   endedRecently  =  timeSinceEnded < _noReclassifyTimeSinceEnded;
            return endedRecently;
        }
        else
        {
            return true;
        }
    }
    else
    {
        return false;
    }
}

TouchClassification TouchClassificationProxy::Classify(TouchId touchId)
{
    if (CurrentClass(touchId) == TouchClassification::RemovedFromClassification)
    {
        return TouchClassification::RemovedFromClassification;
    }

    return CurrentClass(touchId);
}

void TouchClassificationProxy::OnClusterEventEnded()
{
}

TouchClassification TouchClassificationProxy::CurrentClass(TouchId touchId)
{
    if (!_activeStylusConnected)
    {
        return TouchClassification::UnknownDisconnected;
    }

    if (_currentTypes.count(touchId))
    {
        return _currentTypes[touchId];
    }
    else
    {
        return TouchClassification::UntrackedTouch;
    }
}

void TouchClassificationProxy::ClearSessionStatistics()
{
    _sessionStatistics = fiftythree::core::make_shared<struct SessionStatistics>();
}

SessionStatistics::Ptr TouchClassificationProxy::SessionStatistics()
{
    return _sessionStatistics;
}

void TouchClassificationProxy::SetClusterType(Cluster::Ptr const & cluster, TouchClassification newType, IdTypeMap &changedTypes)
{

    bool onlyUpdateUnknownTouches = false;

    if (_activeStylusConnected)
    {
        float length   = cluster->TotalLength();
        float lifetime = cluster->LastTimestamp() - cluster->FirstTimestamp();

        float dt = _clusterTracker->Time() - cluster->LastTimestamp();
        if (cluster->_clusterTouchType == TouchClassification::Pen
            && newType != TouchClassification::Pen
            && TouchSize::IsPenGivenTouchRadius(*_clusterTracker->Data(cluster->_touchIds.back())))
        {
            //std::cerr << "\n dt = " << dt << ", score = " << cluster->_penScore << ", prior = " << cluster->_penPrior << ", L = " << length << ", palmEnd = " << cluster->_wasAtPalmEnd << ", interior = " << cluster->_wasInterior;
            //std::cerr << ", count = " << cluster->_touchIds.size();
        }

        if (cluster->_clusterTouchType == TouchClassification::Finger && newType != TouchClassification::Finger)
        {
            if (newType == TouchClassification::Pen || newType == TouchClassification::Eraser)
            {
                if (lifetime > _maxPenEventWaitTime)
                {
                    onlyUpdateUnknownTouches = true;
                }
            }
            else if ((length > _longFingerLength) || lifetime > _longDuration)
            {
                onlyUpdateUnknownTouches = true;

                // if we have a concurrent pen, this is definitely a palm.
                // however, a concurrent palm can just mean they brushed the screen with their hand.
                for (const auto & otherTouch : _clusterTracker->ConcurrentTouches(cluster->MostRecentTouch()))
                {
                    if (CurrentClass(otherTouch) == core::TouchClassification::Pen ||
                        CurrentClass(otherTouch) == core::TouchClassification::Eraser)
                    {
                        onlyUpdateUnknownTouches = false;
                    }
                }
            }
        }

        if (cluster->IsPenType() && (newType == TouchClassification::Palm || newType == TouchClassification::Finger))
        {

            float penDownDt = -1.0f;
            if (_touchStatistics.count(cluster->MostRecentTouch()))
            {
                penDownDt = _touchStatistics[cluster->MostRecentTouch()]._penDownDeltaT;
            }

            if ((! TouchRadiusAvailable()) &&
                _debounceWorkaroundEnabled &&
               HandednessLocked() &&
               _penTracker.AtPenEnd(cluster, _clusterTracker->FastOrderedClusters(), true) &&
               cluster->_totalLength > 0.0f &&
               penDownDt > _debounceWorkaroundMinPenDownDt)
            {
                onlyUpdateUnknownTouches = true;
                if (_showDebugLogMessages)
                {
                    std::cerr << "\n" << cluster->_id << ": BOGUS PEN -> PALM TRANSITION WORKAROUND";
                }
            }

            if (length > _longPenLength || lifetime > _longDuration)
            {
                onlyUpdateUnknownTouches = true;
            }
        }

        if (! onlyUpdateUnknownTouches)
        {
            cluster->_clusterTouchType =  newType;
        }

        for (TouchId touchId:cluster->_touchIds)
        {
            if (_currentTypes[touchId] == TouchClassification::RemovedFromClassification ||
               _currentTypes[touchId] == TouchClassification::UnknownDisconnected)
            {
                continue;
            }

            if (onlyUpdateUnknownTouches && _currentTypes[touchId] != TouchClassification::Unknown)
            {
                continue;
            }

            if (CurrentClass(touchId) != newType)
            {
                //std::cerr << "\n id = " << _clusterTracker->Cluster(touchId)->_id << " was " << static_cast<int>(CurrentClass(touchId));
                changedTypes[touchId] = newType;
            }
        }
    }
    else
    {
        // in the dumb-stylus case, we do nothing.
        for (TouchId touchId:cluster->_touchIds)
        {
            _currentTypes[touchId] = TouchClassification::Finger;
        }
    }
}

void TouchClassificationProxy::RecomputeClusterPriors()
{
    //_clusterPriors.clear();

    vector<Cluster::Ptr> event = _clusterTracker->CurrentEventAllClusters();

    VectorXf              clusterPriors = PenPriorForClusters(event);

    for (int j = 0; j < clusterPriors.size(); ++j)
    {
        // strokes can sometimes have vanishly small, but positive, priors.
        // if they exist in isolation at any point, they might get a positive score and the
        // domination rules will allow them to become pens.  however, they're always palms.
        float denoisedPrior = std::max(0.0f, clusterPriors[j] - .00001f);
        event[j]->_penPrior = denoisedPrior;
    }
}

VectorXf TouchClassificationProxy::PenPriorForTouches(TouchIdVector const &touchIds)
{
    VectorXf touchPriors = VectorXf::Constant(touchIds.size(), 1.0f / float(touchIds.size()));

    bool isolatedCountsOK = true;
    for (TouchId touchId:touchIds)
    {
        if (_isolatedStrokesClassifier.TouchIdIsolatedSize(touchId) <= 10) // Should this really be 10?
        {
            isolatedCountsOK = false;
            break;
        }
    }

    if (touchIds.empty())
    {
        DebugAssert(! touchIds.empty());
        return touchPriors;
    }

    size_t touchIndex = 0;

    for (TouchId touchId:touchIds)
    {
        Cluster::Ptr cluster = _clusterTracker->Cluster(touchId);

        if (! cluster)
        {
            std::cerr << "\nNO CLUSTER FOR " << touchId;
            touchPriors[touchIndex] = 0.0f;
            continue;
        }

        DebugAssert(cluster);

        float clusterPrior       = cluster->_penPrior;
        touchPriors[touchIndex]  = clusterPrior;

        Stroke::Ptr stroke = _clusterTracker->Stroke(touchId);

        if (stroke->Size() > 2)
        {
            float score = _isolatedStrokesClassifier.Score(*stroke);

            _touchStatistics[touchId]._curvatureScore = score;

            float curvaturePrior = std::max(0.0f, 1.0f - std::max(0.0f, score - .1f));

            touchPriors[touchIndex] *= curvaturePrior;

            if (isolatedCountsOK)
            {

                float isolatedScore = _isolatedStrokesClassifier.NPVoteScore(touchId);
                //float isolatedScore = _isolatedStrokesClassifier.ConvexScore(touchId);

//                std::cout << "scores for touch  " << touchId << "\n"
//                          << "ConvexScore: " << _isolatedStrokesClassifier.ConvexScore(touchId) << "\n"
//                          << "NPVoteScore: " << _isolatedStrokesClassifier.NPVoteScore(touchId) << "\n"
//                          << "NPVoteCount: " << _isolatedStrokesClassifier.NPVoteCount(touchId) << "\n"
//                          << "AdaboostScore: " << _isolatedStrokesClassifier.AdaboostScore(touchId) << "\n"
//                          << "BayesLikelihoodScore: " << _isolatedStrokesClassifier.BayesLikelihoodScore(touchId) << "\n" << std::endl;
//
//                    std::cout << "Raw max curvature is " << _isolatedStrokesClassifier.LogMaxCurvature(touchId) << " and normalized curvature is " << _isolatedStrokesClassifier.NormalizedMaxCurvature(touchId) << std::endl;

                // We want a score of 0.5 to not do anything -- so multiply by 2
                touchPriors[touchIndex] *= 2.0f * isolatedScore;

            }

        }

        touchIndex++;
    }

    // a simple length prior.  if there's one stroke which is much longer
    // then we are probably not a pen.
    int index = 0;
    float shrinkage     = 88.0f;

    for (TouchId touchId:touchIds)
    {
        float arcLength = _clusterTracker->Stroke(touchId)->ArcLength();
        arcLength       = std::max(shrinkage, arcLength);

        TouchIdVector concurrentTouches = _clusterTracker->ConcurrentTouches(touchId);

        float ratio = 1.0f;
        for (TouchId otherTouchId:concurrentTouches)
        {

            float otherLength = _clusterTracker->Stroke(otherTouchId)->ArcLength();

            otherLength = std::max(shrinkage, otherLength);

            float current = arcLength / otherLength;
            if (current < ratio)
            {
                ratio = current;
            }

            DebugAssert(ratio > 0.0f && ratio <= 1.0f);

        }

        touchPriors[index] *= ratio;

        _touchStatistics[touchId]._lengthPrior = ratio;

        index++;
    }

    if (touchPriors.array().sum() > 0.0f)
    {
        touchPriors /= touchPriors.array().sum();
    }

    index = 0;
    for (TouchId touchId:touchIds)
    {
        _touchStatistics[touchId]._touchPrior = touchPriors[index];
        index++;
    }

    DebugAssert(touchPriors.array().maxCoeff() <= 1.0f && touchPriors.minCoeff() >= 0.0f);

    return touchPriors;
}

bool TouchClassificationProxy::TouchRadiusAvailable()
{
    return (_clusterTracker->TouchWithId(_clusterTracker->MostRecentTouch()) &&
            _clusterTracker->TouchWithId(_clusterTracker->MostRecentTouch())->CurrentSample().TouchRadius());
}

VectorXf TouchClassificationProxy::PenPriorForClusters(vector<Cluster::Ptr> const & clusters)
{

    // AKIL
    // Use isolated strokes to aid which cluster is "best"
    // geometric mean for scores
    // scores don't have to be normalized: but high scores are "pens"
    // low scores are palms
    VectorXf prior(clusters.size());

    for (int j=0; j<clusters.size(); j++)
    {

        Cluster::Ptr const & cluster = clusters[j];

        if (cluster->_touchIds.size() > 1)
        {
            prior[j] *= .5f;
        }

        if (cluster->_wasInterior)
        {
            prior[j] = .5f;
        }
        else
        {
            prior[j] = 1.0f;
        }

    }

//    bool useIsolatedPrior = true;
//    for (int i = 0; i < clusters.size(); ++i)
//    {
//        std::cout << "Cluster " << i << std::endl;
//        float bayes = 0.0f;
//
//        for (const TouchId & touch:clusters[i]->_touchIds)
//        {
//            float bayesScore = _isolatedStrokesClassifier.BayesLikelihoodScore(touch);
//            float adaScore = _isolatedStrokesClassifier.AdaboostScore(touch);
//            float npScore = _isolatedStrokesClassifier.NPVoteScore(touch);
//            std::cout << " bayes score " << bayesScore << " ada " << adaScore << " npscore " << npScore << std::endl;
//        }
//
//        // Prior *= f(score).
//    }

    // use ended pens to classify palms.  we should ignore ended pens
    // when classifying pens.
    vector<Cluster::Ptr> orderedClusters = _clusterTracker->FastOrderedClusters();

    VectorXf directionPrior = _penTracker.UpdateDirectionPrior(orderedClusters);

    for (int k=0; k<orderedClusters.size(); k++)
    {

        Cluster & cluster = *(orderedClusters[k]);

        for (TouchId touchId:cluster._touchIds)
        {
            _touchStatistics[touchId]._handednessPrior = cluster._directionPrior;
        }
    }

    int k=0;
    for (Cluster::Ptr const & current:clusters)
    {

        prior[k] = prior[k] * current->_directionPrior;
        k++;

    }

    // now size prior...
    if (TouchRadiusAvailable())
    {
        for (int j = 0; j < prior.size(); j++)
        {

            Cluster::Ptr const & cluster = clusters[j];

            float penLikelihood = 0.0f;
            float r = cluster->_meanTouchRadius;
            float rMax = cluster->_maxTouchRadius;

            if (_clusterTracker->MostRecentPenTipType() == TouchClassification::Eraser)
            {
                constexpr float mu = 18.0f;
                constexpr float sigma = 6.0f;

                float dEraser = (r - mu) / sigma;
                penLikelihood = (1.0f / sigma) * std::exp(-.5f * dEraser * dEraser);
            }
            else
            {

                // model the pen tip as a mixture of two normal distributions,
                // one representing a pen held in writing position with a small contact patch,
                // and another a somewhat angled tip

                constexpr float muVerticalTip    = 6.0f;
                constexpr float sigmaVerticalTip = .25f;

                constexpr float muAngledTip    = 16.0f;
                constexpr float sigmaAngledTip = 10.0f;

                float dPenVertical     = (r - muVerticalTip) / sigmaVerticalTip;
                float dPenAngled       = (r - muAngledTip)   / sigmaAngledTip;

                float likelihoodVertical  = (1.0f / sigmaVerticalTip)  * std::exp(-.5f * dPenVertical * dPenVertical);
                float likelihoodAngled    = (1.0f / sigmaAngledTip) * std::exp(-.5f * dPenAngled * dPenAngled);

                penLikelihood = .5f * (likelihoodAngled + likelihoodVertical);
            }

            if (rMax > 32.0f)
            {
                penLikelihood = 0.0f;
            }

            constexpr float sigmaPalm      = 22.0f;
            constexpr float muPalm         = 53.0f;

            // min since we're using dumb normal distributions and we don't want to be penalized for being big.
            // if r exceeds muPalm, clamp dPalm to zero, which maximizes the likelihood.
            float dPalm = std::min(0.0f, (r - muPalm)) / sigmaPalm;

            float palmLikelihood = (1.0f / sigmaPalm) * std::exp(-.5f * dPalm * dPalm);

            float pPen = penLikelihood / (.0001f + penLikelihood + palmLikelihood);
            prior[j] *= pPen;

            DebugAssert(prior[j] >= 0.0f && prior[j] <= 1.0f);
        }
    }

    if (_trustHandednessOnceLocked && HandednessLocked())
    {

        float interiorPenalty = .1f;
        float palmEndPenalty  = .1f;

        // if radius is available, trust handedness completely
        if (TouchRadiusAvailable())
        {
            // .0001 allows some robustness to edge thumbs from the other hand in typical configurations
            // with your palm down
            interiorPenalty = 0.01f;
            palmEndPenalty  = 0.01f;
        }

        for (int j=0; j<clusters.size(); j++)
        {

            Cluster::Ptr const & cluster = clusters[j];

            // setting this to zero makes it impossible to rescue a pen touch which got stranded in
            // a palm cluster
            if (cluster->_wasInterior)
            {
                prior[j] *= interiorPenalty;
            }

            // we'd love to declare p = 0 in this case, but if you rotate your hand quickly by more than
            // 90 degrees this can happen pretty easily
            if (_penTracker.WasAtPalmEnd(cluster))
            {
                prior[j] *= palmEndPenalty;
            }
        }
    }

    int index = 0;
    for (Cluster::Ptr const & cluster:clusters)
    {
        for (TouchId touchId:cluster->_touchIds)
        {
            _touchStatistics[touchId]._clusterPrior = prior[index];
        }
        index++;
    }

    return prior;
}

void TouchClassificationProxy::UpdateIsolationStatistics()
{
    vector<TouchId> touchIds = _clusterTracker->TouchesForCurrentClusters(false);

    for (TouchId touchId:touchIds)
    {

        if (_touchStatistics[touchId]._preIsolation  == -1.0f)
        {
            // this is a moderately expensive function, so skip touches which already are marked as
            // having concurrent touches
            continue;
        }

        Stroke::Ptr const & stroke        = _clusterTracker->Stroke(touchId);
        double t1                         = stroke->FirstAbsoluteTimestamp();
        double t0                         = t1 - double(_fingerTapIsolationSeconds);
        vector<TouchId> previousIds  = _clusterTracker->TouchIdsEndedInTimeInterval(t0, t1);

        _touchStatistics[touchId]._tBegan = stroke->FirstAbsoluteTimestamp();
        if (_clusterTracker->Phase(touchId) == core::TouchPhase::Ended)
        {
            _touchStatistics[touchId]._tEnded = stroke->LastAbsoluteTimestamp();
        }

        if (!_clusterTracker->ConcurrentTouches(touchId).empty())
        {
            _touchStatistics[touchId]._preIsolation  = -1.0f;
            _touchStatistics[touchId]._postIsolation = -1.0f;
        }
        else
        {
            // we have no concurrent touches, so compute the isolations.
            _touchStatistics[touchId]._preIsolation = _fingerTapIsolationSeconds;
            for (TouchId previousId:previousIds)
            {
                double tPreviousEnd = _clusterTracker->Stroke(previousId)->LastAbsoluteTimestamp();
                float gap = t1 - tPreviousEnd;
                DebugAssert(gap >= 0.0f);

                _touchStatistics[touchId]._preIsolation = std::min(gap, _touchStatistics[touchId]._preIsolation);

            }

            if (_clusterTracker->Phase(touchId) == core::TouchPhase::Ended)
            {
                vector<TouchId> subsequentIds = _clusterTracker->TouchIdsBeganInTimeInterval(stroke->LastAbsoluteTimestamp(),
                                                                                           stroke->LastAbsoluteTimestamp() + _fingerTapIsolationSeconds);

                for (TouchId subsequentId:subsequentIds)
                {
                    if (subsequentId == touchId)
                    {
                        continue;
                    }

                    double tSubsequentBegan = _clusterTracker->Stroke(subsequentId)->FirstAbsoluteTimestamp();
                    float gap = tSubsequentBegan - stroke->LastAbsoluteTimestamp();
                    DebugAssert(gap >= 0.0f);

                    _touchStatistics[touchId]._postIsolation = std::min(gap, _touchStatistics[touchId]._postIsolation);
                }
            }
        }
    }
}

// the finger sequence logic doesn't take care of the transition from Finger back to Palm.
// this method does that.
void TouchClassificationProxy::FingerToPalmRules(IdTypeMap & newTypes)
{

    for (const auto & cluster : _clusterTracker->CurrentEventAllClusters())
    {
        if (cluster->_clusterTouchType == core::TouchClassification::Finger)
        {
            for (const auto & touch : cluster->Touches())
            {
                // pre and post isolation will get set to -1 if there's a concurrent touch, so this
                // will DWIW here.
                if (_touchStatistics[touch]._preIsolation < _fingerSmudgeIsolationSeconds)
                {
                    // if there's a concurrent touch, always make this a palm.
                    if (_touchStatistics[touch]._preIsolation < 0.0f)
                    {
                        SetClusterType(cluster, core::TouchClassification::Palm, newTypes);
                    }
                    else
                    {
                        // if the previous touch was also a finger, this is likely a rapid sequence of smudge
                        auto precedingTouch = _clusterTracker->TouchPrecedingTouch(touch);
                        if (CurrentClass(precedingTouch) != core::TouchClassification::Finger)
                        {
                            SetClusterType(cluster, core::TouchClassification::Palm, newTypes);
                        }
                    }
                }
            }
        }
    }
}

// enforce the 'no touches arrived too soon after a tap' rule
void TouchClassificationProxy::FingerTapIsolationRule(IdTypeMap & changedTypes)
{

    auto mostRecentId = _clusterTracker->MostRecentTouch();
    if (mostRecentId == InvalidTouchId())
    {
        return;
    }

    if (CurrentClass(mostRecentId) != TouchClassification::Finger ||
       (!_isolatedStrokesClassifier.IsTap(mostRecentId)))
    {
        return;
    }

    Stroke::Ptr const & stroke = _clusterTracker->Stroke(mostRecentId);
    double t1 = stroke->FirstAbsoluteTimestamp();
    double t0 = t1 - double(_fingerTapIsolationSeconds);
    vector<TouchId> previousIds = _clusterTracker->TouchIdsEndedInTimeInterval(t0, t1);

    // if any of the previousIds were non-finger taps, they need to be reclassified as palms
    for (TouchId touchId:previousIds)
    {
        if (CurrentClass(touchId) != TouchClassification::Finger &&
           _isolatedStrokesClassifier.IsTap(touchId))
        {
            _currentTypes[touchId] = TouchClassification::Palm;
            changedTypes[touchId]  = TouchClassification::Palm;
        }

    }

}

void TouchClassificationProxy::RemoveEdgeThumbs()
{

    for (TouchId touchId:_clusterTracker->ActiveIds())
    {
        if (IsReclassifiable(_clusterTracker->TouchWithId(touchId), _clusterTracker->Stroke(touchId)) && _isolatedStrokesClassifier.IsEdgeThumb(touchId))
        {

            RemoveTouchFromClassification(touchId);
        }
    }

}

IdTypeMap TouchClassificationProxy::ReclassifyCurrentEvent()
{

    /*
    if (_showDebugLogMessages)
    {
    for (TouchId touchId:_clusterTracker->TouchesForCurrentClusters(true))
    {
        Stroke::Ptr const & stroke = _clusterTracker->Stroke(touchId);

        if (stroke->Size() < 3)
        {
            continue;
        }

        if (stroke->Size() == 10)
        {
            Eigen::MatrixX2f XY = stroke->XYMatrixMap();
            Eigen::VectorXf  t  = stroke->RelativeTimestampMap();

            //Eigen::VectorXf weights = t;

            DebugAssert(t.rows() == XY.rows());

            float residual = 0.0f; // storage for residual
            //LinearlyParameterized2DLine<float> paramLine = LeastSquaresLinearlyParameterizedLine(t, XY, residual);
            //LinearlyParameterized2DLine<float> paramLine = LeastSquaresLinearlyParameterizedLine(t, XY, weights, residual);

            //float geometricResidual = 0.0f;
            //Geometric2DLine<float> geoLine = GeometricLeastSquaresLineFit(XY, geometricResidual);
            //Geometric2DLine<float> geoLine = GeometricLeastSquaresLineFit(XY, weights, geometricResidual);
            QuadraticallyParameterized2DLine<float> quadParamLine = LeastSquaresQuadraticallyParameterizedLine(t, XY, residual);
            //QuadraticallyParameterized2DLine<float> quadParamLine = LeastSquaresQuadraticallyParameterizedLine(t, XY, weights, residual);

            float normalization = (stroke->XY(0) - stroke->LastPoint()).norm();
            //normalization = stroke->Statistics()->_arcLength;
            std::cerr << "\n" << touchId << ": " << residual / normalization;

            //std::cerr << "\n" << "times: \n" << t;
            //std::cerr << "\n" << "XY: \n" << XY;
            //std::cerr << "\n" << "Geometric residual:" << geometricResidual << " and residual: " << residual << std::endl;
            //std::cerr << "\n" << "Linear param line values: speed:" << paramLine.Speed() << "and Direction: " << paramLine.Direction() << " and anchor point: " << paramLine.AnchorPoint() << std::endl;
            //std::cerr << "\n" << "Quad param line values: acceleration:" << quadParamLine.Acceleration() << " velocity0: " << quadParamLine.Velocity0() << " anchor point: " << quadParamLine.AnchorPoint() << std::endl;
        }

    }
    }
    */

    IdTypeMap types;

    // the clusters in order along the shortest curve joining them
    vector<Cluster::Ptr> orderedClusters     = _clusterTracker->FastOrderedClusters();

    // everybody in the current event, including stale clusters
    vector<Cluster::Ptr> timeOrderedClusters = _clusterTracker->CurrentEventTimeOrderedClusters();

    FingerTapIsolationRule(types);

    RemoveEdgeThumbs();

    if (!_activeStylusConnected)
    {

        // this code path exists mostly to test various flavors of isolated strokes classification
        if (_testingIsolated)
        {
            for (IdTypePair pair:types)
            {
                SetClusterType(_clusterTracker->Cluster(pair.first), pair.second, types);
            }
        }
    }
    else
    {

        FingerToPalmRules(types);

        // this will compute all the relevant probabilities so we have consistent information
        // in the loop below.
        for (Cluster::Ptr & cluster:timeOrderedClusters)
        {
            if (cluster->ContainsReclassifiableTouch())
            {
                _penEventClassifier.TypeAndScoreForCluster(*cluster);
            }
        }

        //if (orderedIds.empty())
        if (orderedClusters.empty())
        {
            return types;
        }

        // as a special case, we'll check for a finger if there's an "isolated touch".
        // the logic for identifying this case is slightly tricky due to the
        // temporal blurring that clusters use.  the touch is isolated, but the clusters might not be.
        // this may be excessively complicated, but it seems safer allow smudging in only a handful
        // of explicitly-specified cases.
        bool checkForFingerSequence = false;
        TouchIdVector liveTouches = _clusterTracker->LiveTouches();
        if (liveTouches.size() == 1 &&
            _clusterTracker->ConcurrentTouches(liveTouches[0]).empty() &&
            _commonData.proxy->ActiveStylusIsConnected() &&
            CurrentClass(liveTouches.back()) != TouchClassification::RemovedFromClassification)
        {

            Cluster::Ptr cluster = _clusterTracker->Cluster(liveTouches[0]);

            if (TouchSize::IsPenGivenTouchRadius(*_clusterTracker->Data(liveTouches[0])))
            {
                checkForFingerSequence = false;
            }
            else
            {
                if (_touchStatistics[liveTouches[0]]._preIsolation > _fingerSmudgeIsolationSeconds)
                {
                    // a single live cluster which satisifes a temporal isolation condition will trigger a sequence
                    // of finger smudges, unless it comes down in a palm cluster

                    if (cluster->_touchIds.size() == 1 || cluster->_clusterTouchType != TouchClassification::Palm)
                    {
                        checkForFingerSequence = true;
                    }
                }
                else
                {
                    // new smudges don't need to satisfy any condition if the previous touch was a smudge
                    TouchId previousId = _clusterTracker->TouchPrecedingTouch(liveTouches[0]);
                    if (previousId != InvalidTouchId() && CurrentClass(previousId) == TouchClassification::Finger)
                    {
                        checkForFingerSequence = true;
                    }
                }
            }
        }

        // if there's a pen connected, handle a single cluster as a special case.
        // if the switch classifier says it's a pen or eraser, use that decision.
        // however, if switch classifier says TouchClassification::Unknown then decide between finger and palm
        // using the IsolatedStrokesClassifier.
        if (checkForFingerSequence)
        {

            Cluster::Ptr    cluster       = _clusterTracker->Cluster(liveTouches[0]);
            std::pair<TouchClassification, float> pair = _penEventClassifier.TypeAndScoreForCluster(*cluster);

            TouchClassification newType = TouchClassification::Unknown;

            if (cluster->_simultaneousTouches)
            {
                newType = TouchClassification::Palm;
            }
            else if (pair.first == TouchClassification::Unknown)
            {
                cluster->_checkForFingerSequence = true;

                int fingerCount       = _clusterTracker->CurrentEventFingerCount();
                bool commitToSmudge   = fingerCount >= _smudgeCommitCount;

                if (commitToSmudge)
                {
                    newType = TouchClassification::Finger;
                    if (_showDebugLogMessages)
                    {
                        //std::cout << "\nCOMMIT -- finger";
                    }
                }
                else
                {
                    TouchId probeId = cluster->_touchIds.back();

                    if (_isolatedStrokesClassifier.IsTap(probeId))
                    {
                        Stroke::Ptr const & stroke = _clusterTracker->Stroke(probeId);

                        double t1 = stroke->FirstAbsoluteTimestamp();
                        double t0 = t1 - double(_smudgeTapIsolationSeconds);

                        vector<TouchId> recentIds = _clusterTracker->TouchIdsEndedInTimeInterval(t0, t1);

                        if (recentIds.empty())
                        {
                            newType = TouchClassification::Finger;
                            if (_showDebugLogMessages)
                            {
                                //std::cout << "\n" << probeId << "TAP - finger" <<std::endl;
                            }
                        }
                        else
                        {
                            newType = TouchClassification::Palm;
                            if (_showDebugLogMessages)
                            {
                                //std::cout << "\n" << probeId << "TAP - palm";
                            }
                        }
                    }
                    else
                    {
                        newType = _isolatedStrokesClassifier.TestFingerVsPalm(cluster);
                        if (_showDebugLogMessages)
                        {
                            if (TouchClassification::Palm == newType)
                            {
                                //std::cout << "\nNot TAP - Palm"<<std::endl;
                            }
                            else if (TouchClassification::Finger == newType)
                            {
                                //std::cout << "\nNot TAP Finger" <<std::endl;
                            }

                        }
                    }
                }
            }
            else
            {
                if (pair.second > .2f)
                {
                    newType = pair.first;
                }
            }

            if (newType == TouchClassification::Unknown || newType == TouchClassification::Finger)
            {
                cluster->_checkForFingerSequence = true;
            }
            else
            {
                cluster->_checkForFingerSequence = false;
            }

            if(newType == TouchClassification::Finger)
            {
                SetClusterType(cluster, newType, types);
            }

            if(! TouchRadiusAvailable())
            {
                SetClusterType(cluster, newType, types);
            }
        }
        else if(! TouchRadiusAvailable())
        {

            std::map<Cluster::Ptr, TouchClassification> newTypes;

            for (Cluster::Ptr const & probeCluster:timeOrderedClusters)
            {

                if (! probeCluster->ContainsReclassifiableTouch())
                {
                    continue;
                }

                if (! probeCluster->Stale())
                {

                    std::pair<TouchClassification, float> probePair  = _penEventClassifier.TypeAndScoreForCluster(*probeCluster);
                    float dominationScore                  = DominationScore(probeCluster);

                    auto mostRecentTouch     = _clusterTracker->TouchWithId(probeCluster->MostRecentTouch());

                    // simple threshold based on pen score.  score is the odds ratio: P(pen) / P(palm).
                    // we set it slightly less than 1.0 to allow for the occasional low-scoring pen, at the
                    // risk of leaving stray marks.
                    if (probePair.second > .8f)
                    {
                        // if somebody else is much better, don't allow this one to be the pen
                        if (dominationScore < .9f)
                        {
                            newTypes[probeCluster] = TouchClassification::Palm;
                        }
                        else
                        {
                            newTypes[probeCluster] = probePair.first;
                        }
                    }
                    else
                    {
                        bool atCorrectEnd = true;
                        if (HandednessLocked())
                        {
                            atCorrectEnd = ! probeCluster->_wasAtPalmEnd;
                        }

                        bool isBestConcurrent = dominationScore > 1.0f;
                        if ((! probeCluster->_wasInterior) && atCorrectEnd)
                        {
                            if ((isBestConcurrent && probePair.second > .2f))
                            {
                                newTypes[probeCluster] = probePair.first;
                            }
                            else if (TouchRadiusAvailable() &&
                                     TouchSize::IsPenGivenTouchRadius(*_clusterTracker->Data(probeCluster->MostRecentTouch())))
                            {
                                // this is just an early classification and will get overridden by PenEvents
                                // in the (probePair.second > .8f) clause above -- IF any events arrive.
                                // However, we should still
                                // make a good effort to figure pen vs. eraser, since eraser can look like
                                // pen tip, depending on how it is angled.

                                if (_clusterTracker->MostRecentPenTipType() == core::TouchClassification::Eraser)
                                {
                                    newTypes[probeCluster] = core::TouchClassification::Eraser;
                                }
                                else
                                {
                                    newTypes[probeCluster] = core::TouchClassification::Pen;
                                }
                            }
                        }
                        else
                        {
                            newTypes[probeCluster] = TouchClassification::Palm;
                        }
                    }
                }
            }

            // now for each pen, check to see if anybody else wants these pen events.
            // if somebody does, give the pen events to the better touch.
            for (Cluster::Ptr const & cluster:timeOrderedClusters)
            {

                if (cluster->IsPenType() && cluster->ContainsReclassifiableTouch())
                {
                    TouchId touchId = cluster->MostRecentTouch();

                    PenEventId upEvent, downEvent;
                    upEvent   = _penEventClassifier.BestPenUpEventForTouch(touchId);
                    downEvent = _penEventClassifier.BestPenDownEventForTouch(touchId);

                    for (Cluster::Ptr otherCluster:timeOrderedClusters)
                    {

                        if (cluster == otherCluster)
                        {
                            continue;
                        }

                        // only check against other pens -- is this a good idea?  what if
                        // we simply got something wrong on a previous pass?
                        if (! otherCluster->IsPenType())
                        {
                            continue;
                        }

                        auto otherTouchId = otherCluster->MostRecentTouch();

                        PenEventId otherUpEvent, otherDownEvent;
                        otherUpEvent   = _penEventClassifier.BestPenUpEventForTouch(otherTouchId);
                        otherDownEvent = _penEventClassifier.BestPenDownEventForTouch(otherTouchId);

                        //std::cerr << "\n up = " << static_cast<int>(upEvent);
                        //std::cerr << ", oUp = " << static_cast<int>(otherUpEvent);
                        //std::cerr << ", down = " << static_cast<int>(downEvent);
                        //std::cerr << ", oDown = " << static_cast<int>(otherDownEvent);

                        // if they share anything, make it winner-takes-all.
                        if ((upEvent >= 0 && upEvent == otherUpEvent) || (downEvent >= 0 && (downEvent == otherDownEvent)))
                        {
                            std::cerr << "\nsharing";

                            if(! TouchRadiusAvailable())
                            {
                                // a polite lie -- allowing touches to steal pen events from other touches actually
                                // is a convenient hack to help with missed pen events during rapid drawing and
                                // handwriting cases.
                                if (HandednessLocked() &&
                                    (! cluster->_wasInterior) &&
                                    (! cluster->_wasAtPalmEnd))
                                {
                                    continue;
                                }
                            }

                            if (TouchRadiusAvailable())
                            {
                                bool clusterSizeOK = TouchSize::IsPenGivenTouchRadius(*_clusterTracker->Data(cluster->_touchIds.back()));
                                bool otherSizeOK   = TouchSize::IsPenGivenTouchRadius(*_clusterTracker->Data(otherCluster->_touchIds.back()));

                                float radius       = _clusterTracker->Data(cluster->_touchIds.back())->_radiusMean;
                                float otherRadius  = _clusterTracker->Data(otherCluster->_touchIds.back())->_radiusMean;

                                if (clusterSizeOK || otherSizeOK)
                                {
                                    // decide based on size in this case
                                    // otherwise use the old "which one is better" code path
                                    if (! clusterSizeOK)
                                    {
                                        newTypes[cluster] = TouchClassification::Palm;
                                        std::cerr << " did something, r = " << radius;
                                    }
                                    else if(! otherSizeOK)
                                    {
                                        newTypes[otherCluster] = TouchClassification::Palm;
                                        std::cerr << " did something, rOther = " << otherRadius << " vs " << radius;
                                    }
                                    else
                                    {
                                        // both are OK based on size...
                                        std::cerr << " did nothing";
                                    }
                                    continue;
                                }
                                else
                                {
                                    // neither one is a clear winner -- choose the smaller one

                                    if(radius < otherRadius)
                                    {
                                        newTypes[otherCluster] = TouchClassification::Palm;
                                    }
                                    else
                                    {
                                        newTypes[cluster] = TouchClassification::Palm;
                                    }
                                    std::cerr << " chose smaller one, r = " << radius << ", rOther = " << otherRadius;
                                    continue;
                                }

                            }

                            if ((otherCluster->_penScore > cluster->_penScore))
                            {
                                newTypes[cluster] = TouchClassification::Palm;
                                std::cerr << " prevented";
                            }
                            else
                            {
                                std::cerr << " OK";
                            }

                        }

                    }

                }

            }

            typedef std::pair<Cluster::Ptr const &, TouchClassification> ClusterTypePair;
            for (ClusterTypePair pair:newTypes)
            {
                SetClusterType(pair.first, pair.second, types);
            }

        }

        if(TouchRadiusAvailable())
        {
            ReclassifyCurrentEventGivenSize(types);
        }

        // if there's not already a pen active, check each cluster to
        // see if a pen was accidentally added to the cluster.  if so, give it its own
        // cluster.  This typically happens during rapid drawing after a classification error
        // is made: a new pen touch gets stuck in a "palm" cluster.
        if ((! TouchRadiusAvailable() ) && (! PenActive()))
        {
            for (Cluster::Ptr const & cluster:timeOrderedClusters)
            {
                if (cluster->Stale())
                {
                    continue;
                }

                // size 1 clusters have already been checked.
                if (cluster->_touchIds.size() <= 1)// || cluster._wasInterior)
                {
                    continue;
                }

                auto mostRecentTouch = cluster->MostRecentTouch();

                if (mostRecentTouch == InvalidTouchId())
                {
                    continue;
                }

                std::pair<TouchClassification, float>  pair = _penEventClassifier.TypeAndScoreForTouch(mostRecentTouch);

                // todo -- when we refactor, make it possible to reclassify the clusters cheaply here.
                // the .8f should get replaced by a reclassification using the same code above.
                if (pair.second > .8f)
                {

                    Cluster::Ptr newCluster = _clusterTracker->NewClusterForTouch(mostRecentTouch);

                    SetClusterType(newCluster, pair.first, types);

                    // this cluster is clearly not relevant since the pen made its way in.
                    // Mark him stale if we can.  Otherwise, prevent him from gaining any new members.
                    _clusterTracker->MarkIfStale(cluster);
                    cluster->_closedToNewTouches = true;

                    RecomputeClusterPriors();
                }

            }

        }

    }

    DebugPrintClusterStatus();

    return types;

}

void TouchClassificationProxy::ReclassifyCurrentEventGivenSize(IdTypeMap &changedTypes)
{
    std::map<Cluster::Ptr, TouchClassification> newTypes;

    vector<Cluster::Ptr> timeOrderedClusters = _clusterTracker->CurrentEventTimeOrderedClusters();

    std::set<Cluster::Ptr> activeClusters = _clusterTracker->CurrentEventActiveClusters();

    for (Cluster::Ptr const & probeCluster:timeOrderedClusters)
    {

        if (! probeCluster->ContainsReclassifiableTouch())
        {
            continue;
        }

        if (! probeCluster->Stale())
        {

            std::pair<TouchClassification, float> probePair  = _penEventClassifier.TypeAndScoreForCluster(*probeCluster);
            float dominationScore                            = DominationScore(probeCluster);

            auto mostRecentTouch                             = _clusterTracker->TouchWithId(probeCluster->MostRecentTouch());

            // todo: consistent use of most recent vs. cluster types...
            TouchData::Ptr data = _clusterTracker->Data(probeCluster->MostRecentTouch());
            bool isPenSized     = TouchSize::IsPenGivenTouchRadius(*data);

            bool atCorrectEnd = true;
            if (false) //HandednessLocked())
            {
                atCorrectEnd = ! probeCluster->_wasAtPalmEnd;
            }

            
            
            bool locationOK = atCorrectEnd;  //(! probeCluster->_wasInterior);

            // in case of a pen, what tip should we use?  use the switch if available,
            // otherwise use most recent switch.
            TouchClassification tipType  = probePair.first;
            if (tipType == TouchClassification::Unknown)
            {
                tipType = _clusterTracker->MostRecentPenTipType();
            }

            // first, the easy case.  a small touch at the correct end.
            // subsequent clauses handle harder situations.
            if (locationOK &&
                isPenSized)
            {
                newTypes[probeCluster] = tipType;
            }
            else if(locationOK && probeCluster->_penScore > .8f )
            {
                newTypes[probeCluster] = tipType;
            }
            else
            {
                newTypes[probeCluster] = TouchClassification::Palm;
            }
        }
    }

    // Now resolve conflicts -- there can be only one.
    for (Cluster::Ptr const & probeCluster:timeOrderedClusters)
    {
        TouchId probeTouch = probeCluster->MostRecentTouch();
        if(probeTouch == InvalidTouchId())
        {
            continue;
        }
        
        std::vector<TouchId> concurrentTouches = _clusterTracker->ConcurrentTouches(probeTouch);
        
        
        TouchClassification probeClass = CurrentClass(probeTouch);
        if (newTypes.count(probeCluster))
        {
            probeClass = newTypes[probeCluster];
        }
        TouchData::Ptr const & probeData = _clusterTracker->Data(probeTouch);

        for (TouchId otherTouch : concurrentTouches)
        {
            Cluster::Ptr const & otherCluster = _clusterTracker->Cluster(otherTouch);
        
            TouchClassification otherClass = CurrentClass(otherTouch);
            if (newTypes.count(otherCluster))
            {
                otherClass = newTypes[otherCluster];
            }

            TouchData::Ptr const & otherData = _clusterTracker->Data(otherTouch);

            if (probeClass == TouchClassification::Pen &&
                otherClass == TouchClassification::Pen)
            {
                if (probeData->_radiusMean > otherData->_radiusMean)
                {
                    newTypes[probeCluster] = TouchClassification::Palm;
                }
            }
            else if(probeClass == TouchClassification::Eraser &&
                    otherClass == TouchClassification::Eraser)
            {

                constexpr float fullEraserSize = 24.0f;

                //float probeErr = std::abs(fullEraserSize - probeData->_radiusMean);
                //float otherErr = std::abs(fullEraserSize - otherData->_radiusMean);

                if (probeData->_radiusMean > otherData->_radiusMean)
                {
                    newTypes[probeCluster] = TouchClassification::Palm;
                }

            }

        }

    }

    typedef std::pair<Cluster::Ptr const &, TouchClassification> ClusterTypePair;
    for (ClusterTypePair pair:newTypes)
    {
        SetClusterType(pair.first, pair.second, changedTypes);
    }

    for (IdTypePair pair : changedTypes)
    {
        Cluster::Ptr probeCluster = _clusterTracker->Cluster(pair.first);
        TouchData::Ptr data = _clusterTracker->Data(probeCluster->MostRecentTouch());
        bool locationOK = ! probeCluster->_wasAtPalmEnd;
        //std::cerr << "\n id = " << probeCluster->_id << ", score = " << probeCluster->_penScore << ", prior = " << probeCluster->_penPrior << ", r = " << data->_radiusMean << ", loc = " << locationOK << ", type = " << static_cast<int>(newTypes[probeCluster]);
    }

}

bool TouchClassificationProxy::IsLongestConcurrentTouch(TouchId probeId)
{
    TouchIdVector concurrentTouches = _clusterTracker->ConcurrentTouches(probeId);

    float probeLength = _clusterTracker->Stroke(probeId)->Length();
    for (TouchId otherId:concurrentTouches)
    {
        if (_clusterTracker->Stroke(otherId)->Length() > probeLength)
        {
            return false;
        }
    }

    return true;
}

float TouchClassificationProxy::DominationScore(Cluster::Ptr const & probe)
{

    std::pair<TouchClassification, float> probePair  = _penEventClassifier.TypeAndScoreForCluster(*probe);

    float worstRatio = std::numeric_limits<float>::max();

    for (TouchId otherId:_clusterTracker->ConcurrentTouches(probe->MostRecentTouch()))
    {
        Cluster::Ptr const & otherCluster = _clusterTracker->Cluster(otherId);

        if(! otherCluster)
        {
            continue;
        }

        float ratio = probePair.second / (.0001f + otherCluster->_penScore);

#if USE_DEBUG_ASSERT
        float otherScore = _penEventClassifier.TypeAndScoreForCluster(*otherCluster).second;
        DebugAssert(otherCluster->_penScore == otherScore);
#endif

        if (ratio < worstRatio)
        {
            worstRatio = ratio;
        }
    }

    _touchStatistics[probe->MostRecentTouch()]._dominationScore = worstRatio;

    return worstRatio;
}

void      TouchClassificationProxy::DebugPrintClusterStatus()
{

    return;
    if (!_showDebugLogMessages)
    {
        return;
    }

    vector<Cluster::Ptr> timeOrderedClusters = _clusterTracker->CurrentEventAllClusters();

    // DEBUG printouts
    for (Cluster::Ptr const & cluster:timeOrderedClusters)
    {

        if (cluster->Stale() || cluster->_clusterTouchType == TouchClassification::RemovedFromClassification)
        {
            continue;
        }

        std::pair<TouchClassification, float> pair = _penEventClassifier.TypeAndScoreForCluster(*cluster);

        std::string strPhase = "M";
        core::TouchPhase phase = _clusterTracker->Phase(cluster->MostRecentTouch());
        if (_clusterTracker->TouchWithId(cluster->MostRecentTouch())->IsPhaseEndedOrCancelled())
        {
            strPhase = "E";
        }
        if (phase == core::TouchPhase::Began)
        {
            strPhase = "B";
        }

        std::string strType = "";
        if (cluster->_clusterTouchType == TouchClassification::Palm)
        {
            strType = " ";
        }
        else if (cluster->_clusterTouchType == TouchClassification::Unknown)
        {
            strType = "U";
        }
        else if (cluster->_clusterTouchType == TouchClassification::Pen ||
                cluster->_clusterTouchType == TouchClassification::Eraser)
        {
            strType = "*";
        }
        else if (cluster->_clusterTouchType == TouchClassification::Finger)
        {
            strType = "F";
        }

        //float r = cluster->_meanTouchRadius;
        float domScore = DominationScore(cluster);
        std::cerr << "([" << cluster->_id << ", " << strPhase << strType << "(" << cluster->_touchIds.size() << ")]: " <<
                      pair.second << ", " << cluster->_penPrior << ", dom = " << domScore << ") ";
    }
    std::cerr << "\n";

}

void TouchClassificationProxy::ReclassifyClusters()
{
    IdTypeMap types = ReclassifyCurrentEvent();

    TouchId touchId; TouchClassification type;
    for (const auto & pair :types)
    {
        tie(touchId, type) = pair;

        if (! IsLocked(touchId))
        {
            _currentTypes[touchId] = type;

            if (_clusterTracker->IsEnded(touchId))
            {
                _endedTouchesReclassified.push_back(touchId);
            }
            else
            {
                _activeTouchesReclassified.push_back(touchId);
            }

            if (type == TouchClassification::Palm)
            {
                //LockTypeForTouch(pair.first);
            }
        }
    }
    DebugPrintClusterStatus();
}

void TouchClassificationProxy::ClassifyIsolatedStrokes()
{
    IdTypeMap types = _isolatedStrokesClassifier.ReclassifyActiveTouches();
}

vector<float> TouchClassificationProxy::SizeDataForTouch(TouchId touchId)
{
    Stroke::Ptr stroke = _clusterTracker->Stroke(touchId);

    return stroke->TouchRadiusFloat();
}

void TouchClassificationProxy::OnTouchesChanged(const std::set<core::Touch::Ptr> & touches)
{
    // this updates the touchLog and the clusters, and sets the current time in the touchLog
    // from the most recent Touch timestamp.
    _clusterTracker->TouchesChanged(touches);

    UpdateSessionStatistics();

    SetCurrentTime(_clusterTracker->Time());

    // if iOS cancelled all the touches, because an alert popped up, phone call, etc.
    // then don't do any work.  cluster tracker will have cleared all clusters.
    if (!_clusterTracker->AllCancelledFlag())
    {
        _isolatedStrokesClassifier.MarkEdgeThumbs();

        _penTracker.UpdateLocations();

        // an empty touch set never happens at the moment.
        if (! touches.empty())
        {
            // default the touch type for any new touches.
            for (core::Touch::cPtr snapshot:touches)
            {
                if (!_currentTypes.count(snapshot->Id()))
                {
                    _currentTypes[snapshot->Id()] = TouchTypeForNewCluster();
                }
            }

            _needsClassification = true;
        }
    }

    auto it = _currentTypes.begin();

    while (it != _currentTypes.end())
    {
        TouchId touchId = it->first;

        if ((!_clusterTracker->IsIdLogged(touchId)) && (!_clusterTracker->Removed(touchId)))
        {
            it = _currentTypes.erase(it);
        }
        else
        {
            ++it;
        }
    }
}

void TouchClassificationProxy::SetUseDebugLogging(bool v)
{
    _showDebugLogMessages = v;
}

void TouchClassificationProxy::SetCurrentTime(double timestamp)
{
    _clusterTracker->UpdateTime(timestamp);
    _clusterTracker->MarkStaleClusters(timestamp);
}

void TouchClassificationProxy::SetOldUnknownTouchesToType(TouchClassification newType)
{
    for (Cluster::Ptr cluster:_clusterTracker->CurrentEventAllClusters())
    {
        if (cluster->Staleness() > .5f)
        {
            for (TouchId touchId:cluster->_touchIds)
            {
                if (CurrentClass(touchId) == TouchClassification::Unknown)
                {
                    _currentTypes[touchId] = newType;
                    _endedTouchesReclassified.push_back(touchId);
                }
            }
        }
    }
}

void TouchClassificationProxy::ProcessDebounceQueue()
{
    if (_debounceQueue.empty())
    {
        return;
    }

    float dt = _clusterTracker->CurrentTime() - _debounceQueue.front()._timestamp;
    if (dt > _debounceInterval)
    {
        _clusterTracker->LogPenEvent(_debounceQueue.front());
        _debounceQueue.pop_front();
        SetNeedsClassification();
    }
}

void TouchClassificationProxy::UpdateSessionStatistics()
{
    for (TouchId touchId:_clusterTracker->NewlyEndedTouches())
    {
        if (!_touchStatistics.count(touchId))
        {
            continue;
        }

        // TODO Matt:
        // Is this allowed to be null?
        if (_clusterTracker->Cluster(touchId) && _clusterTracker->Cluster(touchId)->IsPenType())
        {

            struct TouchStatistics const & stats = _touchStatistics[touchId];

            float downDt = stats._penDownDeltaT;
            float ratio  = (.0001f + stats._switchOnDuration) / (.0001f + stats._touchDuration);

            static const float cycle       = 1.0f / 60.0f;
            static const float dtEdges[]    = { 1.5f * cycle, 2.5f * cycle, 4.5f * cycle, 6.5f * cycle, .2f, .3f };
            static const float ratioEdges[] = {.2f, .4f, .6f, .8f, 1.0f};

            static const int   nDtBins     = 1 + sizeof(dtEdges) / sizeof(dtEdges[0]);
            static const int   nRatBins    = 1 + sizeof(ratioEdges) / sizeof(ratioEdges[0]);

            static const vector<float> dtBinEdges(dtEdges, dtEdges + (nDtBins - 1));
            static const vector<float> ratioBinEdges(ratioEdges, ratioEdges + (nRatBins - 1));

            if (_sessionStatistics->_tip1DownHistogram.empty())
            {
                _sessionStatistics->_tip1DownHistogram.resize(nDtBins, 0);
                _sessionStatistics->_tip1SwitchOnHistogram.resize(nRatBins, 0);
                _sessionStatistics->_tip2DownHistogram.resize(nDtBins, 0);
                _sessionStatistics->_tip2SwitchOnHistogram.resize(nRatBins, 0);
            }

            int dtBin  = HistogramBinIndex(downDt, dtBinEdges);
            int ratBin = HistogramBinIndex(ratio, ratioBinEdges);

            if (_clusterTracker->Cluster(touchId)->_clusterTouchType == TouchClassification::Pen)
            {
                _sessionStatistics->_tip1DownHistogram[dtBin]++;

                if (stats._touchDuration > .1f)
                {
                    _sessionStatistics->_tip1SwitchOnHistogram[ratBin]++;
                }
            }
            else if (_clusterTracker->Cluster(touchId)->_clusterTouchType == TouchClassification::Eraser)
            {
                _sessionStatistics->_tip2DownHistogram[dtBin]++;

                if (stats._touchDuration > .1f)
                {
                    _sessionStatistics->_tip2SwitchOnHistogram[ratBin]++;
                }
            }

        }
    }
}

void TouchClassificationProxy::ClearStaleTouchStatistics()
{

    if (!_clearStaleStatistics)
    {
        return;
    }

    TouchId touchId;

    for (auto it = _touchStatistics.begin();
         it != _touchStatistics.end();)
    {
        touchId = it->first;
        if (!_clusterTracker->IsIdLogged(touchId))
        {
            _touchStatistics.erase(it++);
        }
        else
        {
            ++it;
        }
    }
}

bool TouchClassificationProxy::ReclassifyIfNeeded(double timestamp)
{
    bool didSomething = false;

    ProcessDebounceQueue();
    UpdateIsolationStatistics();

    if (!_needsClassification)
    {
        ClearStaleTouchStatistics();

        if (timestamp > 0.0)
        {
            SetCurrentTime(timestamp);
        }
        else
        {
            SetCurrentTime(NSProcessInfoSystemUptime());
        }

        size_t countOnEntry = _clusterTracker->CurrentEventAllClusters().size();

        _clusterTracker->MarkStaleClusters(_clusterTracker->CurrentTime());
        _clusterTracker->RemoveUnusedStaleClusters();

        SetOldUnknownTouchesToType(TouchClassification::Palm);

        // if a cluster event just ended, clear the touch data.
        if (countOnEntry > 0 && _clusterTracker->CurrentEventAllClusters().size() == 0)
        {
            _clusterTracker->ClearAllData();
        }

    }
    else if (_needsClassification)
    {
        InitializeTouchTypes();

        _penEventClassifier.SetNeedsClassification();

        ClassifyIsolatedStrokes();

        _clusterTracker->MarkStaleClusters(_clusterTracker->CurrentTime());

        SetOldUnknownTouchesToType(TouchClassification::Palm);

        RecomputeClusterPriors();

        ReclassifyClusters();

        for (Cluster::Ptr cluster:_clusterTracker->CurrentEventActiveClusters())
        {

            for (TouchId touchId:cluster->_touchIds)
            {
                _touchStatistics[touchId]._finalPenScore = cluster->_penScore;
                _touchStatistics[touchId]._smoothLength  = _clusterTracker->Stroke(touchId)->NormalizedSmoothLength();
            }
        }

        _needsClassification = false;

        didSomething = true;
    }
    return didSomething;
}

// todo -- this doesn't mesh well with clusters... pull from the cluster
void TouchClassificationProxy::InitializeTouchTypes()
{
    TouchIdVector ids = _clusterTracker->IdsInPhase(core::TouchPhase::Began);

    if (!_activeStylusConnected)
    {
        for (TouchId id:ids)
        {
            if (_currentTypes.count(id) == 0 )
            {
                _currentTypes[id] = TouchClassification::UnknownDisconnected;
                _touchLocked[id] = false;
            }

        }
    }
    else
    {

        if (!_penEventsRequired)
        {
            for (TouchId id:ids)
            {
                if (_currentTypes.count(id) == 0 )
                {
                    _currentTypes[id] = TouchClassification::Pen;
                    _touchLocked[id] = false;
                }
            }
        }
        else
        {
            for (TouchId id:ids)
            {
                if (_currentTypes.count(id) == 0 )
                {
                    _currentTypes[id] = TouchClassification::Palm;
                    _touchLocked[id] = false;
                }
            }
        }
    }
}

void TouchClassificationProxy::StylusConnected()
{
    _activeStylusConnected = true;
}

void TouchClassificationProxy::StylusDisconnected()
{
    _activeStylusConnected = false;
}

void TouchClassificationProxy::AllowNonPenEventTouches()
{
    _penEventsRequired = false;
}

void TouchClassificationProxy::RejectNonPenEventTouches()
{
    _penEventsRequired = true;
}

void TouchClassificationProxy::IgnorePenEvents()
{
    _ignorePenEvents = true;
}

void TouchClassificationProxy::ListenForPenEvents()
{
    _ignorePenEvents = false;
}

vector<TouchId> TouchClassificationProxy::EndedTouchesReclassified()
{
    return _endedTouchesReclassified;
}

void TouchClassificationProxy::ClearEndedTouchesReclassified()
{
    _endedTouchesReclassified.clear();
}

vector<TouchId> TouchClassificationProxy::ActiveTouchesReclassified()
{
    return _activeTouchesReclassified;
}

void TouchClassificationProxy::ClearActiveTouchesReclassified()
{
    _activeTouchesReclassified.clear();
}

vector<TouchId> TouchClassificationProxy::TouchesReclassified()
{
    vector<TouchId> touches;

    touches.insert(touches.end(), _activeTouchesReclassified.begin(), _activeTouchesReclassified.end());
    touches.insert(touches.end(), _endedTouchesReclassified.begin(), _endedTouchesReclassified.end());

    return touches;
}

void TouchClassificationProxy::ClearTouchesReclassified()
{
    ClearActiveTouchesReclassified();
    ClearEndedTouchesReclassified();
}

void TouchClassificationProxy::SetIsolatedStrokes(bool value)
{
    _isolatedStrokesForClusterClassification = value;
}

Classifier::Ptr Classifier::New()
{
    return fiftythree::core::make_shared<TouchClassificationProxy>();
}

}
}
