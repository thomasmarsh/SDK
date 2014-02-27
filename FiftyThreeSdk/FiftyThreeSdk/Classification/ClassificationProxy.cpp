//
//  ClassificationProxy.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include <boost/assign.hpp>
#include <boost/foreach.hpp>
#include <iomanip>
#include <tuple>

#include "Core/Touch/TouchTracker.h"
#include "Core/Eigen.h"
#include "Core/Touch/Touch.h"
#include "FiftyThreeSdk/Classification/ClassificationProxy.h"
#include "FiftyThreeSdk/Classification/FiniteDifferences.h"
#include "FiftyThreeSdk/Classification/Helpers.h"
#include "FiftyThreeSdk/Classification/LineFitting.h"
#include "FiftyThreeSdk/Classification/Stroke.h"

using namespace boost::assign;
using Eigen::Vector2f;
using std::tie;
using std::vector;

using namespace Eigen;
using namespace fiftythree::common;

namespace fiftythree
{
namespace sdk
{

void TouchClassificationProxy::RemoveTouchFromClassification(core::TouchId touchId)
{
    if(CurrentClass(touchId) != TouchType::RemovedFromClassification && _clusterTracker->Data(touchId))
    {
        _clusterTracker->RemoveTouchFromClassification(touchId);
        _currentTypes[touchId] = TouchType::RemovedFromClassification;
        SetNeedsClassification();
    }
}

bool TouchClassificationProxy::PenActive()
{
    BOOST_FOREACH(Cluster::Ptr const & cluster, _clusterTracker->CurrentEventActiveClusters())
    {

        if (cluster->IsPenType() && ! cluster->AllTouchesEnded())
        {
            return true;
        }
    }
    return false;
}

Event<Unit> & TouchClassificationProxy::LongPressWithPencilTip()
{
    return _LongPressWithPencilTip;
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

            if(! _debounceQueue.empty())
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
        else if(event.UpEvent())
        {
            // we'd like to assert this but it happens after pairing, for example
            //DebugAssert(_debounceQueue.empty());
            _debounceQueue.clear();
            _debounceQueue.push_back(event);
        }

        if(! ignoreFlag)
        {
            _clusterTracker->LogPenEvent(event);
        }

        _needsClassification = true;

        SetCurrentTime(_clusterTracker->Time());
     }

}

void      TouchClassificationProxy::LockTypeForTouch(core::TouchId touchId)
{
    _touchLocked[touchId] = true;
}

bool      TouchClassificationProxy::IsLocked(core::TouchId touchId)
{
    return _touchLocked[touchId];
}

bool TouchClassificationProxy::HandednessLocked()
{
    if(_activeStylusConnected)
    {
        ClusterEventStatistics::Ptr const & stats = _clusterTracker->CurrentEventStatistics();
        float lPen = stats->_endedPenArcLength;

        bool locked  = lPen >= 88.0f && (stats->_endedPenDirectionScore > 2.0f);

        if(stats->_handednessLockFlag != locked)
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
        BOOST_FOREACH(core::TouchId t, touches)
        {
            if (CurrentClass(t) == TouchType::PenTip1 || CurrentClass(t) == TouchType::PenTip2)
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

TouchType TouchClassificationProxy::ClassifyPair(core::TouchId touch0, core::TouchId touch1, const TwoTouchPairType & type)
{
    // goodness of fit of tangents over the first few points.
    // this is a sort of poor-man's correlation coefficient, optimized for the case of
    // short strokes (the case we're interested in for GR's).  correlation coefficients will
    // be unstable in this case, so simplifying to mean velocities is basically denoising.

    if (!_clusterTracker->ContainsTouchWithId(touch0) || !_clusterTracker->ContainsTouchWithId(touch1))
    {

        return TouchType::Unknown;
    }

    Stroke::Ptr stroke0 = _clusterTracker->Stroke(touch0);
    Stroke::Ptr stroke1 = _clusterTracker->Stroke(touch1);

    float corr = .5f;
    if(stroke0->Size() > 1 && stroke1->Size() > 1)
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

//    if (_showDebugLogMessages)
//    {
//        std::cout << " XX score " << score0 << " YY score " << score1 << std::endl;
//    }
//
    // this is used only in the 2-finger gesture case, so we assume finger
    float pFinger0     = std::max(0.0f, std::min(1.0f, 1.0f - score0));
    float pFinger1     = std::max(0.0f, std::min(1.0f, 1.0f - score1));

//    if (_showDebugLogMessages)
//    {
//        std::cout << " XX pFinger0 " << pFinger0 << " YY pFinger1 " << pFinger1 << std::endl;
//    }

    float pBothFinger  = pFinger0 * pFinger1;
//
//    if (_showDebugLogMessages)
//    {
//        std::cout << " XX pBothFinger " << pBothFinger << std::endl;
//    }

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
        Vector2f centroid = (stroke0->FirstPoint()  + stroke1->FirstPoint())/2.0f;
        distanceToPalm = (centroid - palmLocation).norm();
    }

//    if (_showDebugLogMessages)
//    {
//        std::cout << "\n(" << touch0 << ", " << touch1 << "): Corr = " << corr << ", pBothFinger = " << pBothFinger << ", product = " << pBothFinger * corr << ", length ratio" << lengthRatio << std::endl;
//        std::cout << " kink0 " << kinkFreeRatio0 << " kink1 " << kinkFreeRatio1 <<  " kinkFreeRatio " << kinkFreeRatio << " , startD " << startDistance << std::endl;
//        std::cout << " totalLengthScore " << totalLengthScore <<  " dot " << dot  << " distanceToPalm " << distanceToPalm << ", Pen Tracker Conf " << PenTracker()->Confidence() << std::endl;
//    }

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
                dot > _pairwisePinchAbsDotThreshold)
            {
                if (_showDebugLogMessages)
                {
                    //std::cout << "Pair = Finger for Pinch" << std::endl;
                }

                return TouchType::Finger;
            }
            else
            {
                if (_showDebugLogMessages)
                {
                    //std::cout << "Pair = Palm for Pinch" << std::endl;
                }
                return TouchType::Palm;
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
                distanceToPalm > _pairwisePanPalmCentroidThreshold)
            {
                if (_showDebugLogMessages)
                {
                    //std::cout << "Pair = Finger for Pan" << std::endl;
                }

                return TouchType::Finger;
            }
            else
            {
                if (_showDebugLogMessages)
                {
                    std::cout << "Pair = Palm for Pan" << std::endl;
                }

                return TouchType::Palm;
            }
        }
        break;

        default:
            DebugAssert(false);
            break;
    }
}

TouchType TouchClassificationProxy::ClassifyForGesture(core::TouchId touch0, const SingleTouchGesture & type)
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

            return TouchType::Unknown;
        }
        else
        {
            TouchType touchType = CurrentClass(touch0);

            if (touchType == TouchType::PenTip1 || touchType == TouchType::PenTip2)
            {
                return touchType;
            }

            core::Touch::Ptr touch = _clusterTracker->TouchWithId(touch0);

            if (!touch)
            {
                DebugAssert(false);
                return TouchType::Unknown;
            }

            TouchData::Ptr touchData = _clusterTracker->Data(touch0);
            Stroke::Ptr const & stroke = touchData->Stroke();

            switch (type)
            {
                case SingleTouchGesture::Tap:
                {
                    if(touch->Phase() != core::TouchPhase::Ended)
                    {
                        return TouchType::Unknown;
                    }

                    bool isStartIsolated = _touchStatistics[touch0]._preIsolation  > 0.05f;;
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
                        return TouchType::Finger;
                    }
                    else
                    {
                        return TouchType::Palm;
                    }

                    break;
                }
                case SingleTouchGesture::LoupeDragStart:
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
                        return TouchType::Unknown;
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

#if 0
                    if (stroke->Size() >= 5)
                    {
                        std::cout << "scores for touch  " << touch0 << "\n"
                                   << "nSamples:" << stroke->Size() << "\n"
                                   << "ConvexScore: " << _isolatedStrokesClassifier.ConvexScore(touch0) << "\n"
                                   << "NPVoteScore: " << _isolatedStrokesClassifier.NPVoteScore(touch0) << "\n"
                                   << "NPVoteCount: " << _isolatedStrokesClassifier.NPVoteCount(touch0) << "\n"
                                   << "AdaboostScore: " << _isolatedStrokesClassifier.AdaboostScore(touch0) << "\n"
                                   << "BayesLikelihoodScore: " << _isolatedStrokesClassifier.BayesLikelihoodScore(touch0) << "\n"
                                   << "dt: "  << dt<< "\n"
                                   << "L: " << L << "\n"
                                   << "maxTravelOverL: " << maxTravelOverL
                                   << "Raw max curvature is " << _isolatedStrokesClassifier.LogMaxCurvature(touch0)
                                   << "normalized curvature is " << _isolatedStrokesClassifier.NormalizedMaxCurvature(touch0) << std::endl;
                    }
                    else if (stroke->Size() >= 4)
                    {
                        std::cout << "scores for touch  " << touch0 << "\n"
                        << "nSamples:" << stroke->Size() << "\n"
                        << "ConvexScore: " << _isolatedStrokesClassifier.ConvexScore(touch0) << "\n"
                       // << "NPVoteScore: " << _isolatedStrokesClassifier.NPVoteScore(touch0) << "\n"
                      //  << "NPVoteCount: " << _isolatedStrokesClassifier.NPVoteCount(touch0) << "\n"
                        << "AdaboostScore: " << _isolatedStrokesClassifier.AdaboostScore(touch0) << "\n"
                        << "BayesLikelihoodScore: " << _isolatedStrokesClassifier.BayesLikelihoodScore(touch0) << "\n"
                        << "dt: "  << dt<< "\n"
                        << "L: " << L << "\n"
                        << "maxTravelOverL: " << maxTravelOverL
                        << "Raw max curvature is " << _isolatedStrokesClassifier.LogMaxCurvature(touch0)
                        << "normalized curvature is " << _isolatedStrokesClassifier.NormalizedMaxCurvature(touch0) << std::endl;
                    }
                    else if (stroke->Size() >= 3)
                    {
                        std::cout << "scores for touch  " << touch0 << "\n"
                        << "nSamples:" << stroke->Size() << "\n"
                        // << "ConvexScore: " << _isolatedStrokesClassifier.ConvexScore(touch0) << "\n"
                        // << "NPVoteScore: " << _isolatedStrokesClassifier.NPVoteScore(touch0) << "\n"
                        //  << "NPVoteCount: " << _isolatedStrokesClassifier.NPVoteCount(touch0) << "\n"
                        //<< "AdaboostScore: " << _isolatedStrokesClassifier.AdaboostScore(touch0) << "\n"
                        //<< "BayesLikelihoodScore: " << _isolatedStrokesClassifier.BayesLikelihoodScore(touch0) << "\n"
                        << "dt: "  << dt<< "\n"
                        << "L: " << L << "\n"
                        << "maxTravelOverL: " << maxTravelOverL
                        << "Raw max curvature is " << _isolatedStrokesClassifier.LogMaxCurvature(touch0)
                        << "normalized curvature is " << _isolatedStrokesClassifier.NormalizedMaxCurvature(touch0) << std::endl;
                    }
                    else
                    {
                        std::cout << "scores for touch  " << touch0 << "\n"
                        << "nSamples:" << stroke->Size() << "\n"
                        //<< "ConvexScore: " << _isolatedStrokesClassifier.ConvexScore(touch0) << "\n"
                        // << "NPVoteScore: " << _isolatedStrokesClassifier.NPVoteScore(touch0) << "\n"
                        //  << "NPVoteCount: " << _isolatedStrokesClassifier.NPVoteCount(touch0) << "\n"
                        // << "AdaboostScore: " << _isolatedStrokesClassifier.AdaboostScore(touch0) << "\n"
                        //<< "BayesLikelihoodScore: " << _isolatedStrokesClassifier.BayesLikelihoodScore(touch0) << "\n"
                        << "dt: "  << dt<< "\n"
                        << "L: " << L << "\n";
                        //<< "Raw max curvature is " << _isolatedStrokesClassifier.LogMaxCurvature(touch0)
                        //<< "normalized curvature is " << _isolatedStrokesClassifier.NormalizedMaxCurvature(touch0) << std::endl;
                    }
#endif

                    return  (t0 || t1 || t2 || t3 || t4 || t5 || t6 || t7) ?TouchType::Finger : TouchType::Unknown;

                    break;
                }
                case SingleTouchGesture::Longpress:
                {
                    if (touch->IsPhaseEndedOrCancelled())
                    {
                        return TouchType::Unknown;
                    }

                    float dt = stroke->LastAbsoluteTimestamp() - stroke->FirstAbsoluteTimestamp();
                    float L  = stroke->ArcLength();

//                    if (_showDebugLogMessages)
//                    {
//                        std::cout << "LongPRESS" << std::endl;
//                        std::cout << " dt " << dt << std::endl;
//                       // std::cout << stats->ToString();
//                    }
//

                    float _minLongPressDuration = 0.5f;
                    float _maxLongPressDuration = 3.0f;
                    float _maxLongPressArcLength = 10.0f;
                    bool timeOK = dt >= _minLongPressDuration && dt < _maxLongPressDuration;
                    bool distanceOK = L < _maxLongPressArcLength;

                    if (timeOK && distanceOK)
                    {
                        return TouchType::Finger;
                    }
                    else if (dt < _minLongPressDuration)
                    {
                        return TouchType::Unknown;
                    }
                    else
                    {
                        return TouchType::Unknown;
                    }
                    break;
                }
                default:
                {
                    DebugAssert(false);
                    return TouchType::UnknownDisconnected;
                    break;
                }
            }
        }
    }
    else
    {
        return TouchType::UnknownDisconnected;
    }
}

Eigen::VectorXf TouchClassificationProxy::GeometricStatistics(core::TouchId  touch0)
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

    if(CurrentClass(touch->Id()) == TouchType::RemovedFromClassification ||
        touch->Phase() == core::TouchPhase::Cancelled)
    {
        return false;
    }

    // the negative padding seems to be necessary to handle very fast short strokes on rare occasions.  I have not
    // been able to figure out which timestamps are in disagreement and it seems to depend
    // on the number of onscreen touches as well, so padding is necessary.
    // anything older than staleInterval could be part of a previous event.  .5f because we really only need
    // some tiny padding like one cycle.
    float dt            = touch->FirstSample().TimestampSeconds() - _clusterTracker->CurrentEventBeganTime();

    bool currentEventOK = (dt >= -_clusterTracker->_staleInterval * .5f);

    float  duration   = _clusterTracker->CurrentTime() - touch->FirstSample().TimestampSeconds();

    bool   durationOK =  duration < _noReclassifyDuration;

    if(currentEventOK && durationOK)
    {
        if(touch->IsPhaseEndedOrCancelled())
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

TouchType TouchClassificationProxy::Classify(core::TouchId touchId)
{
    if(CurrentClass(touchId) == TouchType::RemovedFromClassification)
    {
        return TouchType::RemovedFromClassification;
    }

    return CurrentClass(touchId);
}

void     TouchClassificationProxy::OnClusterEventEnded()
{
}

TouchType TouchClassificationProxy::CurrentClass(core::TouchId touchId)
{
    if (! _activeStylusConnected)
    {
        return TouchType::UnknownDisconnected;
    }

    if (_currentTypes.count(touchId))
    {
        return _currentTypes[touchId];
    }
    else
    {
        return TouchType::UntrackedTouch;
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

void TouchClassificationProxy::SetClusterType(Cluster::Ptr const & cluster, TouchType newType, IdTypeMap &changedTypes)
{
    bool onlyUpdateUnknownTouches = false;

    if(_activeStylusConnected)
    {
        float length   = cluster->TotalLength();
        float lifetime = cluster->LastTimestamp() - cluster->FirstTimestamp();

        if(cluster->_clusterTouchType == TouchType::Finger && newType != TouchType::Finger)
        {

            if(newType == TouchType::PenTip1 || newType == TouchType::PenTip2)
            {
                if (lifetime > _maxPenEventWaitTime)
                {
                    onlyUpdateUnknownTouches = true;
                }
            }
            else if((length > _longFingerLength) || lifetime > _longDuration)
            {
                onlyUpdateUnknownTouches = true;
            }
        }

        if(cluster->IsPenType() && (newType == TouchType::Palm || newType == TouchType::Finger))
        {
            float penDownDt = -1.0f;
            if(_touchStatistics.count(cluster->MostRecentTouch()))
            {
                penDownDt = _touchStatistics[cluster->MostRecentTouch()]._penDownDeltaT;
            }

            if(_debounceWorkaroundEnabled &&
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

            if(length > _longPenLength || lifetime > _longDuration)
            {
                onlyUpdateUnknownTouches = true;
            }
        }

        if(! onlyUpdateUnknownTouches)
        {
            cluster->_clusterTouchType        =  newType;
        }

        BOOST_FOREACH(core::TouchId touchId, cluster->_touchIds)
        {
            if(_currentTypes[touchId] == TouchType::RemovedFromClassification ||
               _currentTypes[touchId] == TouchType::UnknownDisconnected)
            {
                continue;
            }

            if(onlyUpdateUnknownTouches && _currentTypes[touchId] != TouchType::Unknown)
            {
                continue;
            }

            if(CurrentClass(touchId) != newType)
            {
                changedTypes[touchId] = newType;
            }
        }
    }
    else
    {
        // in the dumb-stylus case, we do nothing.
        BOOST_FOREACH(core::TouchId touchId, cluster->_touchIds)
        {
            _currentTypes[touchId] = TouchType::Finger;
        }

    }
}

void TouchClassificationProxy::RecomputeClusterPriors()
{
    //_clusterPriors.clear();

    std::vector<Cluster::Ptr> event = _clusterTracker->CurrentEventAllClusters();

    VectorXf              clusterPriors = PenPriorForClusters(event);

    for (int j=0; j<clusterPriors.size(); j++)
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
    BOOST_FOREACH(core::TouchId touchId, touchIds)
    {
        if(_isolatedStrokesClassifier.TouchIdIsolatedSize(touchId) <= 10) // Should this really be 10?
        {
            isolatedCountsOK = false;
            break;
        }
    }

    if(touchIds.empty())
    {
        DebugAssert(! touchIds.empty());
        return touchPriors;
    }

    size_t   touchIndex = 0;

    BOOST_FOREACH(core::TouchId touchId, touchIds)
    {

        Cluster::Ptr cluster = _clusterTracker->Cluster(touchId);

        if(! cluster)
        {
            std::cerr << "\nNO CLUSTER FOR " << touchId;
            touchPriors[touchIndex] = 0.0f;
            continue;
        }

        DebugAssert(cluster);

        float clusterPrior       = cluster->_penPrior;
        touchPriors[touchIndex]  = clusterPrior;

        Stroke::Ptr stroke = _clusterTracker->Stroke(touchId);

        if(stroke->Size() > 2)
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

    BOOST_FOREACH(core::TouchId touchId, touchIds)
    {
        float arcLength = _clusterTracker->Stroke(touchId)->ArcLength();
        arcLength       = std::max(shrinkage, arcLength);

        TouchIdVector concurrentTouches = _clusterTracker->ConcurrentTouches(touchId);

        float ratio = 1.0f;
        BOOST_FOREACH(core::TouchId otherTouchId, concurrentTouches)
        {

            float otherLength = _clusterTracker->Stroke(otherTouchId)->ArcLength();

            otherLength = std::max(shrinkage, otherLength);

            float current = arcLength / otherLength;
            if(current < ratio)
            {
                ratio = current;
            }

            DebugAssert(ratio > 0.0f && ratio <= 1.0f);

        }

        touchPriors[index] *= ratio;

        _touchStatistics[touchId]._lengthPrior = ratio;

        index++;
    }

    if(touchPriors.array().sum() > 0.0f)
    {
        touchPriors /= touchPriors.array().sum();
    }

    index = 0;
    BOOST_FOREACH(core::TouchId touchId, touchIds)
    {
        _touchStatistics[touchId]._touchPrior = touchPriors[index];
        index++;
    }

    DebugAssert(touchPriors.array().maxCoeff() <= 1.0f && touchPriors.minCoeff() >= 0.0f);

    return touchPriors;
}

VectorXf TouchClassificationProxy::PenPriorForClusters(std::vector<Cluster::Ptr> const & clusters)
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

        if(cluster->_touchIds.size() > 1)
        {
            prior[j] *= .5f;
        }

        if(cluster->_wasInterior)
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
//        BOOST_FOREACH(const TouchId & touch, clusters[i]->_touchIds)
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
    std::vector<Cluster::Ptr> orderedClusters = _clusterTracker->FastOrderedClusters();

    VectorXf directionPrior = _penTracker.UpdateDirectionPrior(orderedClusters);

    for (int k=0; k<orderedClusters.size(); k++)
    {

        Cluster & cluster = *(orderedClusters[k]);

        BOOST_FOREACH(core::TouchId touchId, cluster._touchIds)
        {
            _touchStatistics[touchId]._handednessPrior = cluster._directionPrior;
        }
    }

    int k=0;
    BOOST_FOREACH(Cluster::Ptr const & current, clusters)
    {

        prior[k] = prior[k] * current->_directionPrior;
        k++;

    }

    // now size prior...
    if(_usePrivateTouchSizeAPI)
    {
        for (int j=0; j<prior.size(); j++)
        {

            Cluster::Ptr const & cluster = clusters[j];

            float muPen  = 5.2f;
            float muPalm = 11.0f;

            float sigmaPen  = .25f;
            float sigmaPalm = 3.0f;

            if(_clusterTracker->MostRecentPenTipType() == TouchType::PenTip2)
            {
                sigmaPen = .5f;
                muPen    = 7.5f;
            }

            float r = cluster->_meanTouchRadius;

            float dPen  = (r - muPen) / sigmaPen;

            // min since we're using dumb normal distributions and we don't want to be penalized for being big.
            // if r exceeds muPalm, clamp dPalm to zero, which maximizes the likelihood.
            float dPalm = std::min(0.0f, (r - muPalm)) / sigmaPalm;

            float penLikelihood  = (1.0f / sigmaPen)  * expf(-.5f * dPen * dPen);
            float palmLikelihood = (1.0f / sigmaPalm) * expf(-.5f * dPalm * dPalm);

            float pPen = penLikelihood / (.0001f + penLikelihood + palmLikelihood);
            prior[j] *= pPen;

            DebugAssert(prior[j] >= 0.0f && prior[j] <= 1.0f);

        }
    }

    if(_trustHandednessOnceLocked && HandednessLocked())
    {

        for (int j=0; j<clusters.size(); j++)
        {

            Cluster::Ptr const & cluster = clusters[j];

            // setting this to zero makes it impossible to rescue a pen touch which got stranded in
            // a palm cluster
            if (cluster->_wasInterior)
            {
                prior[j] *= 0.1f;
            }

            // we'd love to declare p = 0 in this case, but if you rotate your hand quickly by more than
            // 90 degrees this can happen pretty easily
            if(_penTracker.WasAtPalmEnd(cluster))
            {
                prior[j] *= .1f;
            }

        }

    }

    int index = 0;
    BOOST_FOREACH(Cluster::Ptr const & cluster, clusters)
    {
        BOOST_FOREACH(core::TouchId touchId, cluster->_touchIds)
        {
            _touchStatistics[touchId]._clusterPrior = prior[index];
        }
        index++;
    }

    return prior;

}

void TouchClassificationProxy::UpdateIsolationStatistics()
{
    std::vector<core::TouchId> touchIds = _clusterTracker->TouchesForCurrentClusters(false);

    BOOST_FOREACH(core::TouchId touchId, touchIds)
    {

        if(_touchStatistics[touchId]._preIsolation  == -1.0f)
        {
            // this is a moderately expensive function, so skip touches which already are marked as
            // having concurrent touches
            continue;
        }

        Stroke::Ptr const & stroke        = _clusterTracker->Stroke(touchId);
        double t1                         = stroke->FirstAbsoluteTimestamp();
        double t0                         = t1 - double(_fingerTapIsolationSeconds);
        std::vector<core::TouchId> previousIds  = _clusterTracker->TouchIdsEndedInTimeInterval(t0, t1);

        _touchStatistics[touchId]._tBegan = stroke->FirstAbsoluteTimestamp();
        if(_clusterTracker->Phase(touchId) == core::TouchPhase::Ended)
        {
            _touchStatistics[touchId]._tEnded = stroke->LastAbsoluteTimestamp();
        }

        if (! _clusterTracker->ConcurrentTouches(touchId).empty())
        {
            _touchStatistics[touchId]._preIsolation  = -1.0f;
            _touchStatistics[touchId]._postIsolation = -1.0f;
        }
        else
        {
            // we have no concurrent touches, so compute the isolations.
            _touchStatistics[touchId]._preIsolation = _fingerTapIsolationSeconds;
            BOOST_FOREACH(core::TouchId previousId, previousIds)
            {
                double tPreviousEnd = _clusterTracker->Stroke(previousId)->LastAbsoluteTimestamp();
                float gap = t1 - tPreviousEnd;
                DebugAssert(gap >= 0.0f);

                _touchStatistics[touchId]._preIsolation = std::min(gap, _touchStatistics[touchId]._preIsolation);

            }

            if(_clusterTracker->Phase(touchId) == core::TouchPhase::Ended)
            {
                std::vector<core::TouchId> subsequentIds = _clusterTracker->TouchIdsBeganInTimeInterval(stroke->LastAbsoluteTimestamp(),
                                                                                           stroke->LastAbsoluteTimestamp() + _fingerTapIsolationSeconds);

                BOOST_FOREACH(core::TouchId subsequentId, subsequentIds)
                {
                    if(subsequentId == touchId)
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

// enforce the 'no touches arrived too soon after a tap' rule
void TouchClassificationProxy::FingerTapIsolationRule(IdTypeMap& changedTypes)
{

    auto mostRecentId = _clusterTracker->MostRecentTouch();
    if(mostRecentId == InvalidTouchId())
    {
        return;
    }

    if(CurrentClass(mostRecentId) != TouchType::Finger ||
       (! _isolatedStrokesClassifier.IsTap(mostRecentId)))
    {
        return;
    }

    Stroke::Ptr const & stroke = _clusterTracker->Stroke(mostRecentId);
    double t1 = stroke->FirstAbsoluteTimestamp();
    double t0 = t1 - double(_fingerTapIsolationSeconds);
    std::vector<core::TouchId> previousIds = _clusterTracker->TouchIdsEndedInTimeInterval(t0, t1);

    // if any of the previousIds were non-finger taps, they need to be reclassified as palms
    BOOST_FOREACH(core::TouchId touchId, previousIds)
    {
        if(CurrentClass(touchId) != TouchType::Finger &&
           _isolatedStrokesClassifier.IsTap(touchId))
        {
            std::cerr << "\n finger tap isolation rule";
            _currentTypes[touchId] = TouchType::Palm;
            changedTypes[touchId]  = TouchType::Palm;
        }

    }

}

void TouchClassificationProxy::RemoveEdgeThumbs()
{

    BOOST_FOREACH(core::TouchId touchId, _clusterTracker->ActiveIds())
    {
        if(IsReclassifiable(_clusterTracker->TouchWithId(touchId), _clusterTracker->Stroke(touchId)) && _isolatedStrokesClassifier.IsEdgeThumb(touchId))
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
    BOOST_FOREACH(TouchId touchId, _clusterTracker->TouchesForCurrentClusters(true))
    {
        Stroke::Ptr const & stroke = _clusterTracker->Stroke(touchId);

        if(stroke->Size() < 3)
        {
            continue;
        }

        if(stroke->Size() == 10)
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
    std::vector<Cluster::Ptr> orderedClusters     = _clusterTracker->FastOrderedClusters();

    // everybody in the current event, including stale clusters
    std::vector<Cluster::Ptr> timeOrderedClusters = _clusterTracker->CurrentEventTimeOrderedClusters();

    FingerTapIsolationRule(types);

    RemoveEdgeThumbs();

    if(! _activeStylusConnected)
    {

        // this code path exists mostly to test various flavors of isolated strokes classification
        if(_testingIsolated)
        {
            BOOST_FOREACH(IdTypePair pair, types)
            {
                SetClusterType(_clusterTracker->Cluster(pair.first), pair.second, types);
            }
        }
    }
    else
    {

        // this will compute all the relevant probabilities so we have consistent information
        // in the loop below.
        BOOST_FOREACH(Cluster::Ptr & cluster, timeOrderedClusters)
        {
            if(cluster->ContainsReclassifiableTouch())
            {
                _penEventClassifier.TypeAndScoreForCluster(*cluster);
            }
        }

        //if(orderedIds.empty())
        if(orderedClusters.empty())
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
            CurrentClass(liveTouches.back()) != TouchType::RemovedFromClassification)
        {

            if (_touchStatistics[liveTouches[0]]._preIsolation > _fingerSmudgeIsolationSeconds)
            {
                // a single live cluster which satisifes a temporal isolation condition will trigger a sequence
                // of finger smudges
                checkForFingerSequence = true;
            }
            else
            {
                // new smudges don't need to satisfy any condition if the previous touch was a smudge
                core::TouchId previousId = _clusterTracker->TouchPrecedingTouch(liveTouches[0]);
                if(previousId != InvalidTouchId() && CurrentClass(previousId) == TouchType::Finger)
                {
                    checkForFingerSequence = true;
                }
            }
        }

        // if there's a pen connected, handle a single cluster as a special case.
        // if the switch classifier says it's a pen or eraser, use that decision.
        // however, if switch classifier says TouchType::Unknown then decide between finger and palm
        // using the IsolatedStrokesClassifier.
        if(checkForFingerSequence)
        {

            Cluster::Ptr    cluster       = timeOrderedClusters.back();
            std::pair<TouchType, float> pair = _penEventClassifier.TypeAndScoreForCluster(*cluster);

            TouchType newType = TouchType::Unknown;

            if(cluster->_simultaneousTouches)
            {
                newType = TouchType::Palm;
            }
            else if(pair.first == TouchType::Unknown)
            {
                cluster->_checkForFingerSequence = true;

                int fingerCount       = _clusterTracker->CurrentEventFingerCount();
                bool commitToSmudge   = fingerCount >= _smudgeCommitCount;

                if(commitToSmudge)
                {
                    newType = TouchType::Finger;
                    if (_showDebugLogMessages)
                    {
                        //std::cout << "\nCOMMIT -- finger";
                    }
                }
                else
                {
                    core::TouchId probeId = cluster->_touchIds.back();

                    if(_isolatedStrokesClassifier.IsTap(probeId))
                    {
                        Stroke::Ptr const & stroke = _clusterTracker->Stroke(probeId);

                        double t1 = stroke->FirstAbsoluteTimestamp();
                        double t0 = t1 - double(_smudgeTapIsolationSeconds);

                        std::vector<core::TouchId> recentIds = _clusterTracker->TouchIdsEndedInTimeInterval(t0, t1);

                        if(recentIds.empty())
                        {
                            newType = TouchType::Finger;
                            if (_showDebugLogMessages)
                            {
                                //std::cout << "\n" << probeId << "TAP - finger" <<std::endl;
                            }
                        }
                        else
                        {
                            newType = TouchType::Palm;
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
                            if (TouchType::Palm == newType)
                            {
                                //std::cout << "\nNot TAP - Palm"<<std::endl;
                            }
                            else if (TouchType::Finger == newType)
                            {
                                //std::cout << "\nNot TAP Finger" <<std::endl;
                            }

                        }
                    }
                }
            }
            else
            {
                if(pair.second > .2f)
                {
                    newType = pair.first;
                }
            }

            if(newType == TouchType::Unknown || newType == TouchType::Finger)
            {
                cluster->_checkForFingerSequence = true;
            }
            else
            {
                cluster->_checkForFingerSequence = false;
            }

            SetClusterType(cluster, newType, types);
        }
        else
        {

            std::map<Cluster::Ptr, TouchType> newTypes;

            BOOST_FOREACH(Cluster::Ptr const & probeCluster, timeOrderedClusters)
            {

                if(! probeCluster->ContainsReclassifiableTouch())
                {
                    continue;
                }

                if(! probeCluster->Stale())
                {

                    std::pair<TouchType, float> probePair  = _penEventClassifier.TypeAndScoreForCluster(*probeCluster);
                    float dominationScore                  = DominationScore(probeCluster);

                    auto mostRecentTouch     = _clusterTracker->TouchWithId(probeCluster->MostRecentTouch());
                    bool waitingForPenEvent =   (probeCluster->_touchIds.size() == 1 &&
                                                 probePair.second == 0.0f &&
                                                 (probeCluster->_clusterTouchType == TouchType::Palm || probeCluster->_clusterTouchType == TouchType::Unknown) &&
                                                 (! mostRecentTouch->IsPhaseEndedOrCancelled()) &&
                                                 _clusterTracker->Stroke(*probeCluster->_touchIds.begin())->Lifetime() < _maxPenEventWaitTime);

                    // this clause exists to help prevent rendering flicker while we are waiting for a stray
                    // pen event.
                    if(waitingForPenEvent)
                    {
                        probeCluster->_waitingForPenEvent = true;
                    }
                    else
                    {
                        probeCluster->_waitingForPenEvent = false;
                    }

                    // simple threshold based on pen score.  score is the odds ratio: P(pen) / P(palm).
                    // we set it slightly less than 1.0 to allow for the occasional low-scoring pen, at the
                    // risk of leaving stray marks.
                    if(probePair.second > .8f)
                    {
                        // if somebody else is much better, don't allow this one to be the pen
                        if (dominationScore < .9f)
                        {
                            newTypes[probeCluster] = TouchType::Palm;
                        }
                        else
                        {
                            newTypes[probeCluster] = probePair.first;
                        }
                    }
                    else
                    {
                        bool atCorrectEnd = true;
                        if(HandednessLocked())
                        {
                            atCorrectEnd = ! probeCluster->_wasAtPalmEnd;
                        }

                        bool isBestConcurrent = dominationScore > 1.0f;
                        if(isBestConcurrent && probePair.second > .2f &&
                           (! probeCluster->_wasInterior) &&
                           atCorrectEnd)
                        {
                            newTypes[probeCluster] = probePair.first;
                        }
                        else
                        {
                            newTypes[probeCluster] = TouchType::Palm;
                        }

                    }

                }

            }

            // now for each pen, check to see if anybody else wants these pen events.
            // if somebody does, give the pen events to the better touch.
            BOOST_FOREACH(Cluster::Ptr const & cluster, timeOrderedClusters)
            {

                if (cluster->IsPenType() && cluster->AllTouchesEnded() && cluster->ContainsReclassifiableTouch())
                {
                    core::TouchId touchId = cluster->MostRecentTouch();

                    PenEventId upEvent, downEvent;
                    upEvent   = _penEventClassifier.BestPenUpEventForTouch(touchId);
                    downEvent = _penEventClassifier.BestPenDownEventForTouch(touchId);

                    BOOST_FOREACH(Cluster::Ptr otherCluster, timeOrderedClusters)
                    {

                        if(cluster == otherCluster)
                        {
                            continue;
                        }

                        // only check against other pens -- is this a good idea?  what if
                        // we simply got something wrong on a previous pass?
                        if(! otherCluster->IsPenType())
                        {
                            continue;
                        }

                        auto otherTouchId = otherCluster->MostRecentTouch();

                        PenEventId otherUpEvent, otherDownEvent;
                        otherUpEvent   = _penEventClassifier.BestPenUpEventForTouch(otherTouchId);
                        otherDownEvent = _penEventClassifier.BestPenDownEventForTouch(otherTouchId);

                        // if they share anything, make it winner-takes-all.
                        if(downEvent >= 0 && ((upEvent >= 0 && upEvent == otherUpEvent) || (downEvent >= 0 && (downEvent == otherDownEvent))))
                        {

                            // a polite lie -- allowing touches to steal pen events from other touches actually
                            // is a convenient hack to help with missed pen events during rapid drawing and
                            // handwriting cases.
                            if(HandednessLocked() &&
                               (! cluster->_wasInterior) &&
                               (! cluster->_wasAtPalmEnd))
                            {
                                continue;
                            }

                            if(otherCluster->_penScore > cluster->_penScore)
                            {
                                newTypes[cluster] = TouchType::Palm;

                            }

                        }

                    }

                }

            }

            typedef std::pair<Cluster::Ptr const &, TouchType> ClusterTypePair;
            BOOST_FOREACH(ClusterTypePair pair, newTypes)
            {
                SetClusterType(pair.first, pair.second, types);
            }

        }

        // if there's not already a pen active, check each cluster to
        // see if a pen was accidentally added to the cluster.  if so, give it its own
        // cluster.  This typically happens during rapid drawing after a classification error
        // is made: a new pen touch gets stuck in a "palm" cluster.
        if(! PenActive())
        {
            BOOST_FOREACH(Cluster::Ptr const & cluster, timeOrderedClusters)
            {
                if(cluster->Stale())
                {
                    continue;
                }

                // size 1 clusters have already been checked.
                if(cluster->_touchIds.size() <= 1)// || cluster._wasInterior)
                {
                    continue;
                }

                auto mostRecentTouch = cluster->MostRecentTouch();

                if(mostRecentTouch == InvalidTouchId())
                {
                    continue;
                }

                std::pair<TouchType, float>  pair = _penEventClassifier.TypeAndScoreForTouch(mostRecentTouch);

                // todo -- when we refactor, make it possible to reclassify the clusters cheaply here.
                // the .8f should get replaced by a reclassification using the same code above.
                if(pair.second > .8f)
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

bool TouchClassificationProxy::IsLongestConcurrentTouch(core::TouchId probeId)
{
    TouchIdVector concurrentTouches = _clusterTracker->ConcurrentTouches(probeId);

    float probeLength = _clusterTracker->Stroke(probeId)->Length();
    BOOST_FOREACH(core::TouchId otherId, concurrentTouches)
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

    std::pair<TouchType, float> probePair  = _penEventClassifier.TypeAndScoreForCluster(*probe);

    float worstRatio = std::numeric_limits<float>::max();

    BOOST_FOREACH(core::TouchId otherId, _clusterTracker->ConcurrentTouches(probe->MostRecentTouch()))
    {
        Cluster::Ptr const & otherCluster = _clusterTracker->Cluster(otherId);
        float ratio = probePair.second / (.0001f + otherCluster->_penScore);

        float otherScore = _penEventClassifier.TypeAndScoreForCluster(*otherCluster).second;
        DebugAssert(otherCluster->_penScore == otherScore);

        if(ratio < worstRatio)
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
    if(! _showDebugLogMessages)
    {
        return;
    }

    std::vector<Cluster::Ptr> timeOrderedClusters = _clusterTracker->CurrentEventAllClusters();

    // DEBUG printouts
    BOOST_FOREACH(Cluster::Ptr const & cluster, timeOrderedClusters)
    {

        if (cluster->Stale() || cluster->_clusterTouchType == TouchType::RemovedFromClassification)
        {
            continue;
        }

        std::pair<TouchType, float> pair = _penEventClassifier.TypeAndScoreForCluster(*cluster);

        std::string strPhase = "M";
        core::TouchPhase phase = _clusterTracker->Phase(cluster->MostRecentTouch());
        if(_clusterTracker->TouchWithId(cluster->MostRecentTouch())->IsPhaseEndedOrCancelled())
        {
            strPhase = "E";
        }
        if(phase == core::TouchPhase::Began)
        {
            strPhase = "B";
        }

        std::string strType = "";
        if(cluster->_clusterTouchType == TouchType::Palm)
        {
            strType = " ";
        }
        else if(cluster->_clusterTouchType == TouchType::Unknown)
        {
            strType = "U";
        }
        else if(cluster->_clusterTouchType == TouchType::PenTip1 ||
                cluster->_clusterTouchType == TouchType::PenTip2)
        {
            strType = "*";
        }
        else if(cluster->_clusterTouchType == TouchType::Finger)
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

    core::TouchId touchId; TouchType type;
    BOOST_FOREACH(tie(touchId, type), types)
    {

        if(! IsLocked(touchId))
        {
            _currentTypes[touchId] = type;

            if(_clusterTracker->IsEnded(touchId))
            {
                _endedTouchesReclassified.push_back(touchId);
            }
            else
            {
                _activeTouchesReclassified.push_back(touchId);
            }

            if(type == TouchType::Palm)
            {
                //LockTypeForTouch(pair.first);
            }

        }

    }

}

void TouchClassificationProxy::ClassifyIsolatedStrokes()
{
    IdTypeMap types = _isolatedStrokesClassifier.ReclassifyActiveTouches();

}

std::vector<float> TouchClassificationProxy::SizeDataForTouch(core::TouchId touchId)
{
    Stroke::Ptr stroke = _clusterTracker->Stroke(touchId);

    return stroke->TouchRadiusFloat();

}

void TouchClassificationProxy::OnTouchesChanged(const std::set<core::Touch::Ptr> & touches)
{
    // this updates the touchLog and the clusters
    _clusterTracker->TouchesChanged(touches);

    UpdateSessionStatistics();

    SetCurrentTime(_clusterTracker->Time());

    // if iOS cancelled all the touches, because an alert popped up, phone call, etc.
    // then don't do any work.  cluster tracker will have cleared all clusters.
    if(! _clusterTracker->AllCancelledFlag())
    {
        _isolatedStrokesClassifier.MarkEdgeThumbs();

        _penTracker.UpdateLocations();

        // an empty touch set never happens at the moment.
        if(! touches.empty())
        {
            // default the touch type for any new touches.
            BOOST_FOREACH(core::Touch::cPtr snapshot, touches)
            {
                if(! _currentTypes.count(snapshot->Id()))
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
        core::TouchId touchId = it->first;

        if((! _clusterTracker->IsIdLogged(touchId)) && (! _clusterTracker->Removed(touchId)))
        {
            it = _currentTypes.erase(it);
        }
        else
        {
            ++it;
        }
    }

    /*
    for (std::map<core::TouchId, TouchType>::iterator it = _currentTypes.begin();
         it != _currentTypes.end();)
    {
        core::TouchId touchId = it->first;
        if((! _clusterTracker->IsIdLogged(touchId)) && (! _clusterTracker->Removed(touchId)))
        {
            _currentTypes.erase(it++);
        }
        else
        {
            ++it;
        }
    }
     */
}

void TouchClassificationProxy::SetUsePrivateAPI(bool v)
{
    SetUsePrivateTouchSizeAPI(v);
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

void TouchClassificationProxy::SetOldUnknownTouchesToType(TouchType newType)
{
    BOOST_FOREACH(Cluster::Ptr cluster, _clusterTracker->CurrentEventAllClusters())
    {
        if(cluster->Staleness() > .5f)
        {
            BOOST_FOREACH(core::TouchId touchId, cluster->_touchIds)
            {
                if(CurrentClass(touchId) == TouchType::Unknown)
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
    if(_debounceQueue.empty())
    {
        return;
    }

    float dt = _clusterTracker->CurrentTime() - _debounceQueue.front()._timestamp;
    if(dt > _debounceInterval)
    {
        _clusterTracker->LogPenEvent(_debounceQueue.front());
        _debounceQueue.pop_front();
        SetNeedsClassification();
    }
}

void TouchClassificationProxy::UpdateSessionStatistics()
{
    BOOST_FOREACH(core::TouchId touchId, _clusterTracker->NewlyEndedTouches())
    {
        if(! _touchStatistics.count(touchId))
        {
            continue;
        }

        if(_clusterTracker->Cluster(touchId)->IsPenType())
        {

            struct TouchStatistics const & stats = _touchStatistics[touchId];

            float downDt = stats._penDownDeltaT;
            float ratio  = (.0001f + stats._switchOnDuration) / (.0001f + stats._touchDuration);

            static const float cycle       = 1.0f / 60.0f;
            static const float dtEdges[]    = { 1.5f * cycle, 2.5f * cycle, 4.5f * cycle, 6.5f * cycle, .2f, .3f };
            static const float ratioEdges[] = {.2f, .4f, .6f, .8f, 1.0f};

            static const int   nDtBins     = 1 + sizeof(dtEdges) / sizeof(dtEdges[0]);
            static const int   nRatBins    = 1 + sizeof(ratioEdges) / sizeof(ratioEdges[0]);

            static const std::vector<float> dtBinEdges(dtEdges, dtEdges + (nDtBins - 1));
            static const std::vector<float> ratioBinEdges(ratioEdges, ratioEdges + (nRatBins - 1));

            if(_sessionStatistics->_tip1DownHistogram.empty())
            {
                _sessionStatistics->_tip1DownHistogram.resize(nDtBins, 0);
                _sessionStatistics->_tip1SwitchOnHistogram.resize(nRatBins, 0);
                _sessionStatistics->_tip2DownHistogram.resize(nDtBins, 0);
                _sessionStatistics->_tip2SwitchOnHistogram.resize(nRatBins, 0);
            }

            int dtBin  = HistogramBinIndex(downDt, dtBinEdges);
            int ratBin = HistogramBinIndex(ratio, ratioBinEdges);

            if (_clusterTracker->Cluster(touchId)->_clusterTouchType == TouchType::PenTip1)
            {
                _sessionStatistics->_tip1DownHistogram[dtBin]++;

                if(stats._touchDuration > .1f)
                {
                    _sessionStatistics->_tip1SwitchOnHistogram[ratBin]++;
                }
            }
            else if(_clusterTracker->Cluster(touchId)->_clusterTouchType == TouchType::PenTip2)
            {
                _sessionStatistics->_tip2DownHistogram[dtBin]++;

                if(stats._touchDuration > .1f)
                {
                    _sessionStatistics->_tip2SwitchOnHistogram[ratBin]++;
                }
            }

        }
    }
}

void TouchClassificationProxy::ClearStaleTouchStatistics()
{

    if(! _clearStaleStatistics)
    {
        return;
    }

    core::TouchId touchId;

    for (auto it = _touchStatistics.begin();
         it != _touchStatistics.end();)
    {
        touchId = it->first;
        if (! _clusterTracker->IsIdLogged(touchId))
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

    if(! _needsClassification)
    {

        ClearStaleTouchStatistics();

        if(timestamp > 0.0)
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

        SetOldUnknownTouchesToType(TouchType::Palm);

        // if a cluster event just ended, clear the touch data.
        if(countOnEntry > 0 && _clusterTracker->CurrentEventAllClusters().size() == 0)
        {
            _clusterTracker->ClearAllData();
        }

    }
    else if(_needsClassification)
    {

        InitializeTouchTypes();

        _penEventClassifier.SetNeedsClassification();

        ClassifyIsolatedStrokes();

        _clusterTracker->MarkStaleClusters(_clusterTracker->CurrentTime());

        SetOldUnknownTouchesToType(TouchType::Palm);

        RecomputeClusterPriors();

        ReclassifyClusters();

        BOOST_FOREACH(Cluster::Ptr cluster, _clusterTracker->CurrentEventActiveClusters())
        {

            BOOST_FOREACH(core::TouchId touchId, cluster->_touchIds)
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
void TouchClassificationProxy::InitializeTouchTypes() {
    TouchIdVector ids = _clusterTracker->IdsInPhase(core::TouchPhase::Began);

    if (! _activeStylusConnected)
    {
        BOOST_FOREACH(core::TouchId id, ids)
        {
            if (_currentTypes.count(id) == 0 )
            {
                _currentTypes[id] = TouchType::UnknownDisconnected;
                _touchLocked[id] = false;
            }

        }
    }
    else
    {

        if (! _penEventsRequired) {
            BOOST_FOREACH(core::TouchId id, ids) {
                if (_currentTypes.count(id) == 0 ) {
                    _currentTypes[id] = TouchType::PenTip1;
                    _touchLocked[id] = false;
                }
            }
        }
        else {
            BOOST_FOREACH(core::TouchId id, ids) {
                if (_currentTypes.count(id) == 0 ) {
                    _currentTypes[id] = TouchType::Palm;
                    _touchLocked[id] = false;
                }
            }
        }
    }
}

void TouchClassificationProxy::StylusConnected() {
    _offscreenPenLongPressGR.SetPaused(false);
    _activeStylusConnected = true;
}

void TouchClassificationProxy::StylusDisconnected() {
    _offscreenPenLongPressGR.SetPaused(true);
    _activeStylusConnected = false;
}

void TouchClassificationProxy::AllowNonPenEventTouches() {
    _penEventsRequired = false;
}

void TouchClassificationProxy::RejectNonPenEventTouches() {
    _penEventsRequired = true;
}

void TouchClassificationProxy::IgnorePenEvents() {
    _ignorePenEvents = true;
}

void TouchClassificationProxy::ListenForPenEvents() {
    _ignorePenEvents = false;
}

std::vector<core::TouchId> TouchClassificationProxy::EndedTouchesReclassified() {
    return _endedTouchesReclassified;
}

void TouchClassificationProxy::ClearEndedTouchesReclassified() {
    _endedTouchesReclassified.clear();
}

std::vector<core::TouchId> TouchClassificationProxy::ActiveTouchesReclassified() {
    return _activeTouchesReclassified;
}

void TouchClassificationProxy::ClearActiveTouchesReclassified() {
    _activeTouchesReclassified.clear();
}

std::vector<core::TouchId> TouchClassificationProxy::TouchesReclassified() {
    std::vector<core::TouchId> touches;

    touches.insert(touches.end(), _activeTouchesReclassified.begin(), _activeTouchesReclassified.end());
    touches.insert(touches.end(), _endedTouchesReclassified.begin(), _endedTouchesReclassified.end());

    return touches;
}

void TouchClassificationProxy::ClearTouchesReclassified() {
    ClearActiveTouchesReclassified();
    ClearEndedTouchesReclassified();
}

void TouchClassificationProxy::SetIsolatedStrokes(bool value) {
    _isolatedStrokesForClusterClassification = value;
}

Classifier::Ptr Classifier::New()
{
    return fiftythree::core::make_shared<TouchClassificationProxy>();
}

}
}
