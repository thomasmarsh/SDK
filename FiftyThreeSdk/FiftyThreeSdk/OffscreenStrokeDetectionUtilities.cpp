//
//  OffscreenStrokeDetectionUtilities.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
//
#include "Core/Mathiness.h"
#include "Core/Touch/TouchTracker.h"
#include "OffscreenStrokeDetectionUtilities.h"

using namespace Eigen;
using namespace fiftythree::core;
using std::deque;
using std::vector;

namespace
{
    static fiftythree::sdk::Settings settings;
}
namespace fiftythree
{
namespace sdk
{
Settings::Settings() :
        OffscreenStrokes_MaxHistorySeconds(0.25f),
        OffscreenStrokes_MaxDiscardSamples(5),
        OffscreenStrokes_MinSampleCount(4),
        OffscreenStrokes_MaxExtraSampleCount(0),
        OffscreenStrokes_UnreliableSampleEdgeDistance(15),
        OffscreenStrokes_MinEdgeDistance(50),
        OffscreenStrokes_MaxOffscreenExtrapolation(30),
        OffscreenStrokes_FastSmoothingLambda(0.5f),
        OffscreenStrokes_SlowSmoothingLambda(0.25f),
        OffscreenStrokes_FastVelocity(420),
        OffscreenStrokes_SlowVelocity(180),
        OffscreenStrokes_MaxExtrapolationDurationSeconds(0.125f),
        OffscreenStrokes_MaxExtrapolationSampleCount(200),
        OffscreenStrokes_AccelerationDecayLambda(0.15f),
        OffscreenStrokes_VelocityDecayLambda(0.35f),
        OffscreenStrokes_GroundingSampleCount(10),
        OffscreenStrokes_MinTotalStrokeLength(30.f),
        OffscreenTouches_MaxHistorySeconds(0.25f),
        OffscreenTouches_MaxDiscardSamples(1),
        OffscreenTouches_MaxSampleCount(3),
        OffscreenTouches_MinSampleCount(2),
        OffscreenTouches_MaxExtraSampleCount(0),
        OffscreenTouches_UnreliableSampleEdgeDistance(15),
        OffscreenTouches_MinEdgeDistance(50),
        OffscreenTouches_FastSmoothingLambda(0.5f),
        OffscreenTouches_SlowSmoothingLambda(0.25f),
        OffscreenTouches_FastVelocity(420),
        OffscreenTouches_SlowVelocity(180),
        OffscreenTouches_AccelerationDecayLambda(0.15f),
        OffscreenTouches_VelocityDecayLambda(0.35f),
        OffscreenTouches_MaxExtrapolationDurationSeconds(0.125f),
        OffscreenTouches_MaxExtrapolationSampleCount(200),
        OffscreenTouches_MaxPenOffscreenDistance(300),
        OffscreenTouches_MaxPenOffscreenSeconds(0.6f)
{
}

ScreenEdges::ScreenEdges()
{
    IsNearTop = IsNearBottom = IsNearLeft = IsNearRight = false;
}

bool ScreenEdges::IsEmpty() const
{
    return !IsNearTop && !IsNearBottom && !IsNearLeft && !IsNearRight;
}

OffscreenStroke OffscreenStroke::NotAnOffscreenStroke()
{
    OffscreenStroke info;
    info.IsOffscreenStroke = false;
    return info;
}

OffscreenStroke OffscreenStroke::IsAnOffscreenStroke(const core::InputSample & lastSample,
                                                  const core::InputSample & velocity,
                                                  const core::InputSample & acceleration,
                                                  int discardedSampleCount,
                                                  int firstOffscreenExtrapolatedSampleIdx)
{
    OffscreenStroke info;
    info.IsOffscreenStroke = true;
    info.LastSample = lastSample;
    info.Velocity = velocity;
    info.Acceleration = acceleration;
    info.DiscardedSampleCount = discardedSampleCount;
    info.FirstOffscreenExtrapolatedSampleIdx = firstOffscreenExtrapolatedSampleIdx;
    return info;
}

bool IsVelocityTowardScreenEdgesPermissive(const InputSample & velocity,
                                           const ScreenEdges & screenEdges)
{
    // A very unrestrictive check about whether a given touch velocity is generally heading towards an
    // edge.
    //
    // We check a) the sign of the axis towards/away from the edge. and b) whether or not the velocity
    // along that axis is more-or-less greater than the velocity along the other axis.
    //
    // This is essentially a simplified horizontality/verticality test, of the ratio between the vertical
    // and horizontal movement.
    const float kPermissiveness = 2.f;
    if (screenEdges.IsNearLeft &&
        velocity.Location().x() < 0 &&
        std::abs(velocity.Location().x()) * kPermissiveness > std::abs(velocity.Location().y()))
    {
        return true;
    }
    if (screenEdges.IsNearRight &&
        velocity.Location().x() > 0 &&
        std::abs(velocity.Location().x()) * kPermissiveness > std::abs(velocity.Location().y()))
    {
        return true;
    }
    if (screenEdges.IsNearTop &&
        velocity.Location().y() < 0 &&
        std::abs(velocity.Location().y()) * kPermissiveness > std::abs(velocity.Location().x()))
    {
        return true;
    }
    if (screenEdges.IsNearBottom &&
        velocity.Location().y() > 0 &&
        std::abs(velocity.Location().y()) * kPermissiveness > std::abs(velocity.Location().x()))
    {
        return true;
    }
    return false;
}

void InputSampleSmoothedVelocityAndAcceleration(const vector<InputSample> & samples,
                                                const float smoothingLambda,
                                                InputSample & velocity,
                                                InputSample & acceleration)
{
    // Use exponential smoothing to determine the velocity and acceleration.

    // We need at least 2 samples to calculate velocity.
    // We need at least 3 samples to calculate acceleration.
    DebugAssert(samples.size() >= 2);

    acceleration = InputSample::Zero();

    InputSample prevVelocity;
    for (int i = 1; i < samples.size(); ++i)
    {
        // t may be negative if the order of samples may be reversed.
        InputSample sampleVelocity = samples[i] - samples[i - 1];

        if (i > 1)
        {
            // Exponential smoothing.
            velocity = Lerp(velocity, sampleVelocity, smoothingLambda);

            InputSample sampleAcceleration = velocity - prevVelocity;

            if (i > 2)
            {
                // Exponential smoothing.
                acceleration = Lerp(acceleration, sampleAcceleration, smoothingLambda);
            }
            else
            {
                // Initialize acceleration.
                acceleration = sampleAcceleration;
            }
        }
        else
        {
            // Initialize velocity.
            velocity = sampleVelocity;
        }
        prevVelocity = velocity;
    }
}

float MaxHistorySeconds(bool isPermissive)
{
    float result = settings.OffscreenStrokes_MaxHistorySeconds;
    if (isPermissive)
    {
        // Relax the constraint in the permissive case.
        result *= 2;
    }
    return result;
}

void SmoothedVelocityAndAccelerationFromSamples(const vector<InputSample> & samples,
                                                InputSample & velocity,
                                                InputSample & acceleration)
{
    // Find the velocity and acceleration of the stroke.
    //
    // Slower strokes have samples that are much closer together and are thus
    // much more vulnerable to noise in the touch sensors.  Therefore, we need to use
    // a higher degree of smoothing for slow strokes.
    //
    // Therefore, we do two passes of smoothing.

    // 1. First pass of smoothing to determine raw "overall" velocity of the samples.
    //
    // Use the slow smoothing lambda so that sudden, last minute acceleration or deceleration
    // doesn't skew the result.
    float rawSmoothingLambda = settings.OffscreenStrokes_SlowSmoothingLambda;
    InputSample rawVelocity, rawAcceleration;
    InputSampleSmoothedVelocityAndAcceleration(samples, rawSmoothingLambda, rawVelocity, rawAcceleration);

    // 2. Use the raw velocity to choose a smoothing lambda.
    float sampleHistoryRawLength = rawVelocity.Location().norm();
    // Velocity t value may be negative if order of samples has been reversed.
    float sampleHistoryRawVelocity = sampleHistoryRawLength / std::abs(rawVelocity.TimestampSeconds());

    float speedFactor = ((sampleHistoryRawVelocity - settings.OffscreenStrokes_SlowVelocity) /
                           (settings.OffscreenStrokes_FastVelocity -
                            settings.OffscreenStrokes_SlowVelocity));
    speedFactor = ClampedToUnitInterval<float>(speedFactor);
    float smoothingLambda = (settings.OffscreenStrokes_SlowSmoothingLambda +
                               speedFactor * (settings.OffscreenStrokes_FastSmoothingLambda -
                                              settings.OffscreenStrokes_SlowSmoothingLambda));

    // 3. Re-calculate velocity and acceleration with final smoothing lambda.
    InputSampleSmoothedVelocityAndAcceleration(samples, smoothingLambda, velocity, acceleration);
}

InputSample NaiveVelocityFromSamples(const vector<InputSample> & samples)
{
    DebugAssert(samples.size() > 1);
    InputSample lastSample = samples[samples.size() - 1];
    InputSample secondToLastSample = samples[samples.size() - 2];
    InputSample velocity = lastSample - secondToLastSample;
    return velocity;
}
    optional<vector<InputSample>> FilterEdgeSamples(const vector<InputSample> & edgeSamples,
                                                     OffscreenStrokesMode offscreenStrokesMode,
                                                     int minSampleCount,
                                                     int maxDiscardSamples,
                                                     bool forceDecision,
                                                     bool isPermissive,
                                                     int & discardedSampleCount)
    {
        // Expect "idealized" samples, ie. samples reordered such that the last sample is the sample closest
        // to the edge.
        DebugAssert(!edgeSamples.empty());

        // We should have already verified that the edge samples are near an edge.
        InputSample edgeSample = edgeSamples.back();
        DebugAssert(!ScreenEdgesNearSample(edgeSample, isPermissive).IsEmpty());

        vector<InputSample> filteredEdgeSamples;

        // We're only interested in samples from the last N seconds.
        {
            int firstSampleIdx = 0;
            while (firstSampleIdx < edgeSamples.size())
            {
                InputSample firstSample = edgeSamples[firstSampleIdx];

                // Use absolute value as the order of the samples may have been reversed.
                double windowDuration = std::abs(firstSample.TimestampSeconds() - edgeSample.TimestampSeconds());
                if (windowDuration <= MaxHistorySeconds(isPermissive))
                {
                    // We've found the first valid sample.
                    break;
                }

                firstSampleIdx++;
            }

            // Trim the samples from the front of the window have been discarded for reasons of time.
            for (int sampleIdx = firstSampleIdx; sampleIdx < edgeSamples.size(); ++sampleIdx)
            {
                filteredEdgeSamples.push_back(edgeSamples[sampleIdx]);
            }
        }

        // Now trim samples from the back of the window that are not reliable.
        discardedSampleCount = 0;
        while (filteredEdgeSamples.size() > 0 &&
               discardedSampleCount < maxDiscardSamples)
        {
            if (forceDecision &&
                filteredEdgeSamples.size() == minSampleCount)
            {
                // If we're forcing a decision, don't discard samples that will prevent us from making a
                // decision.
                break;
            }

            InputSample sample = filteredEdgeSamples.back();

            bool isLastSampleReliable = false;
            switch (offscreenStrokesMode)
            {
                case OffscreenStrokesMode::EnterFromOffscreen:
                    isLastSampleReliable = !IsUnreliableSample(sample);
                    break;
                case OffscreenStrokesMode::ExitOffscreen:
                    // Always try to discard the last sample, regardless of its location, because for strokes
                    // that do go offscreen iOS will fudge the last sample that we receive in TouchesEnded: by
                    // adding a badly fudged sample near the last sample.
                    isLastSampleReliable = !IsUnreliableSample(sample) && discardedSampleCount != 0;
                    break;
                default:
                    FTFail("Fell through case statement");
            }
            if (isLastSampleReliable)
            {
                // Stop; last sample is not near the edge.
                break;
            }

            // Discard last sample.
            filteredEdgeSamples.pop_back();
            discardedSampleCount++;
        }

        if (filteredEdgeSamples.size() < minSampleCount)
        {
            // Not enough valid samples found in the sample history.
            return fiftythree::core::none;
        }

        return filteredEdgeSamples;
    }

    bool IsOnScreen(const InputSample & inputSample, const int margin)
    {
        const Vector2f screenSize = TouchTracker::Instance()->ViewSize();

        const Vector2f location = inputSample.Location();
        return ((location.x() >= margin) &&
                (location.x() < screenSize.x() - margin) &&
                (location.y() >= margin) &&
                (location.y() < screenSize.y() - margin));
    }

    bool IsUnreliableSample(const InputSample & inputSample)
    {
        return !IsOnScreen(inputSample, settings.OffscreenStrokes_UnreliableSampleEdgeDistance);
    }

    optional<OffscreenStroke> IsOffscreenStrokePermissive(const deque<InputSample> & normalizedSamples,
                                                          OffscreenStrokesMode offscreenStrokesMode,
                                                          bool forceDecision)
    {
        // Return none if a decision cannot be rendered.
        //
        // The permissive mode is intended to be used for offscreen touch linkage.
        // The restrictive mode is intended to be used for offscreen stroke rendering.

        // The edge samples are just the window of samples near the edge.  They are reordered if necessary so
        // that the last sample is the sample nearest the edge.
        vector<InputSample> edgeSamples = EdgeSamplesForNormalizedSamples(normalizedSamples,
                                                                          offscreenStrokesMode,
                                                                          true);

        // This is the sample that should be closest to the edge.
        const InputSample & edgeSample = edgeSamples.back();
        const ScreenEdges screenEdges = ScreenEdgesNearSample(edgeSample, true);
        if (screenEdges.IsEmpty())
        {
            return OffscreenStroke::NotAnOffscreenStroke();
        }

        int minSampleCount = 2;
        optional<vector<InputSample>> filteredEdgeSamples = fiftythree::core::none;
        // Try multiple values of maxDiscardSamples, walking back from the "max max" value to zero.
        //
        // In this way, we prefer making the decision with a higher degree of confidence (ie. discarding
        // as many unreliable samples as possible), but fall back to making the decision while discarding
        // fewer samples.  We only have a weak heuristic for whether or not a sample is unreliable - it's
        // distance from the edge - so we want to consider all cases from discarding the maximum number of
        // samples to discarding none.  Samples are unreliable with a predictable pattern that causes touches
        // to veer away from edges, so we permissive in this regard.
        int maxMaxDiscardSamples = MaxDiscardSamples(true);

        for (int maxDiscardSamples = maxMaxDiscardSamples; maxDiscardSamples >= 0; maxDiscardSamples--)
        {
            int discardedSampleCount;
            filteredEdgeSamples = FilterEdgeSamples(edgeSamples,
                                                    offscreenStrokesMode,
                                                    minSampleCount,
                                                    maxDiscardSamples,
                                                    forceDecision,
                                                    true,
                                                    discardedSampleCount);

            if (!filteredEdgeSamples &&
                maxDiscardSamples == maxMaxDiscardSamples &&
                !forceDecision)
            {
                // We don't yet have enough samples to decide.
                return fiftythree::core::none;
            }

            if (filteredEdgeSamples)
            {
                // Find the smoother velocity and acceleration of the samples in the window.
                InputSample edgeVelocity;
                InputSample edgeAcceleration;
                SmoothedVelocityAndAccelerationFromSamples(edgeSamples, edgeVelocity, edgeAcceleration);

                InputSample filteredEdgeVelocity;
                InputSample filteredEdgeAcceleration;
                SmoothedVelocityAndAccelerationFromSamples(*filteredEdgeSamples, filteredEdgeVelocity, filteredEdgeAcceleration);

                InputSample naiveEdgeVelocity = NaiveVelocityFromSamples(edgeSamples);
                InputSample naiveFilteredEdgeVelocity = NaiveVelocityFromSamples(*filteredEdgeSamples);

                // Apply a very permissive test for whether or not the touch entered/exited from offscreen.
                if (IsVelocityTowardScreenEdgesPermissive(edgeVelocity, screenEdges) ||
                    IsVelocityTowardScreenEdgesPermissive(filteredEdgeVelocity, screenEdges) ||
                    IsVelocityTowardScreenEdgesPermissive(naiveEdgeVelocity, screenEdges) ||
                    IsVelocityTowardScreenEdgesPermissive(naiveFilteredEdgeVelocity, screenEdges))
                {
                    const InputSample & lastSample = edgeSamples.back();
                    return OffscreenStroke::IsAnOffscreenStroke(lastSample,
                                                                filteredEdgeVelocity,
                                                                filteredEdgeAcceleration,
                                                                discardedSampleCount,
                                                                0);
                }
            }
        }

        if (!filteredEdgeSamples)
        {
            // We don't yet have enough samples to decide.
            return fiftythree::core::none;
        }

        return OffscreenStroke::NotAnOffscreenStroke();
    }

    int MaxDiscardSamples(bool isPermissive)
    {
        int result = settings.OffscreenStrokes_MaxDiscardSamples;
        if (isPermissive)
        {
            // Relax the constraint in the permissive case.
            result *= 2;
        }
        return result;
    }

    int MaxEdgeSampleWindowSize(bool isPermissive)
    {
        return (settings.OffscreenStrokes_MinSampleCount +
                MaxDiscardSamples(isPermissive) +
                settings.OffscreenStrokes_MaxExtraSampleCount);
    }

    vector<InputSample> EdgeSamplesForNormalizedSamples(const deque<InputSample> & normalizedSamples,
                                                        OffscreenStrokesMode offscreenStrokesMode,
                                                        bool isPermissive)
    {
        // Return the N samples to use to detect "enter from offscreen" or "exit offscreen."
        // For "enter from offscreen", return the first N samples of the touch's sample
        // history in reverse order.
        // For "exit offscreen", return the last N samples in the same order.

        DebugAssert(normalizedSamples.size() > 0);

        // Determine how many samples to retain for offscreen consideration.
        // We keep up to the (the maximum number of samples we will consider + the maximum number of invalid
        // samples we will discard).
        int windowSize = std::min((int) normalizedSamples.size(),
                                  MaxEdgeSampleWindowSize(isPermissive));

        int startSampleIdx;
        int sampleIdxDelta;

        switch (offscreenStrokesMode)
        {
            case OffscreenStrokesMode::EnterFromOffscreen:
                startSampleIdx = windowSize - 1;
                sampleIdxDelta = -1;
                break;
            case OffscreenStrokesMode::ExitOffscreen:
                startSampleIdx = (int) normalizedSamples.size() - windowSize;
                sampleIdxDelta = +1;
                break;
            default:
                FTFail("Fell through case statement");
        }
        vector<InputSample> edgeSamples;
        for (int idx = 0; idx < windowSize; ++idx)
        {
            int sampleIdx = startSampleIdx + idx * sampleIdxDelta;
            edgeSamples.push_back(normalizedSamples[sampleIdx]);
        }

        return edgeSamples;
    }

    deque<InputSample> NormalizedSamplesForTouch(const Touch::cPtr & touch)
    {
        // Return the N samples to use to detect "enter from offscreen" or "exit offscreen."
        // For "enter from offscreen", return the first N samples of the touch's sample
        // history in reverse order.
        // For "exit offscreen", return the last N samples in the same order.

        const vector<InputSample> & sampleHistory = *touch->History();
        DebugAssert(sampleHistory.size() > 0);

        deque<InputSample> normalizedSamples;
        InputSample lastSample;
        for (auto iterator = sampleHistory.begin(); iterator != sampleHistory.end(); ++iterator)
        {
            InputSample inputSample = *iterator;

            if (!normalizedSamples.empty())
            {
                bool isTimestampSequenceValid = inputSample.TimestampSeconds() > lastSample.TimestampSeconds();
                if (!isTimestampSequenceValid)
                {
                    // Subsequent sample must have a later timestamp.
                    //
                    // Forge the timestamp by adding a small arbitrary value.
                    const double kDefaultSampleTimeDifference = 0.0001;
                    inputSample.SetTimestampSeconds(lastSample.TimestampSeconds() + kDefaultSampleTimeDifference);
                }

                if (inputSample.Location() == lastSample.Location())
                {
                    // Ignore duplicate samples.
                    continue;
                }
            }

            normalizedSamples.push_back(inputSample);
            lastSample = inputSample;
        }

        return normalizedSamples;
    }

    ScreenEdges ScreenEdgesNearSample(const InputSample & inputSample,
                                      bool isPermissive)
    {
        ScreenEdges result = ScreenEdges::ScreenEdges();
        const Vector2f screenSize = TouchTracker::Instance()->ViewSize();
        const Vector2f location = inputSample.Location();
        int distanceThreshold = settings.OffscreenStrokes_MinEdgeDistance;
        if (isPermissive)
        {
            // Relax the constraint in the permissive case.
            distanceThreshold *= 2.5;
        }
        result.IsNearLeft =  location.x() < distanceThreshold;
        result.IsNearRight = location.x() > screenSize.x() - distanceThreshold;
        result.IsNearTop = location.y() < distanceThreshold;
        result.IsNearBottom = location.y() > screenSize.y() - distanceThreshold;
        return result;
    }

    optional<OffscreenStroke> IsOffscreenStrokePermissive(const Touch::cPtr & touch,
                                                          OffscreenStrokesMode offscreenStrokesMode,
                                                          bool forceDecision)
    {
        // Return none if a decision cannot be rendered.

        bool isPermissive = true;

        {
            // Normalizing the entire sample history for a touch can be expensive for "exit offscreen" strokes,
            // so do a quick test first to ensure the edge sample is in fact near at least one edge.

            const vector<InputSample> & touchSamples = *touch->History();
            // This is the sample that should be closest to the edge.
            const InputSample & edgeSample = (offscreenStrokesMode == OffscreenStrokesMode::EnterFromOffscreen
                                              ? touchSamples.front()
                                              : touchSamples.back());

            const ScreenEdges screenEdges = ScreenEdgesNearSample(edgeSample, isPermissive);
            if (screenEdges.IsEmpty())
            {
                return fiftythree::core::none;
            }
        }

        // The normalized samples are deduplicated, their timestamps are rectified, etc.
        deque<InputSample> normalizedSamples = NormalizedSamplesForTouch(touch);

        return IsOffscreenStrokePermissive(normalizedSamples, offscreenStrokesMode, forceDecision);
    }

    bool DidTouchExitOffscreenPermissive(const fiftythree::core::Touch::cPtr & touch)
    {
        DebugAssert(touch->Phase() == TouchPhase::Ended);

        bool forceDecision = true;
        optional<OffscreenStroke> offscreenStroke = IsOffscreenStrokePermissive(touch,
                                                                                OffscreenStrokesMode::ExitOffscreen,
                                                                                forceDecision);
        if (forceDecision && !offscreenStroke)
        {
            // We should have forced a decision but couldn't.
            return false;
        }
        return offscreenStroke && offscreenStroke->IsOffscreenStroke;
    }

    optional<bool> WillTouchEnterFromOffscreenPermissive(const Touch::cPtr & touch)
    {
        bool forceDecision = touch->Phase() == TouchPhase::Ended;
        optional<OffscreenStroke> offscreenStroke = IsOffscreenStrokePermissive(touch,
                                                                                OffscreenStrokesMode::EnterFromOffscreen,
                                                                                forceDecision);
        if (forceDecision && !offscreenStroke)
        {
            // We should have forced a decision but couldn't.
            return false;
        }
        if (offscreenStroke)
        {
            return offscreenStroke->IsOffscreenStroke;
        }
        return fiftythree::core::none;
    }
}
}
