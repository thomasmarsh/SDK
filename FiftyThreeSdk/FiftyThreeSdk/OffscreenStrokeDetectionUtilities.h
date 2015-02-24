//
//  OffscreenStrokeDetectionUtilities.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <deque>
#include <vector>

#include "Core/Touch/Touch.h"

namespace fiftythree
{
namespace sdk
{
// This contains a collection of utilities used in offscreen strokes detection & extrapolation.

DEFINE_ENUM(OffscreenStrokesMode,
            ExitOffscreen,
            EnterFromOffscreen);

struct Settings {
    float OffscreenStrokes_MaxHistorySeconds;
    int OffscreenStrokes_MaxDiscardSamples;
    int OffscreenStrokes_MinSampleCount;
    int OffscreenStrokes_MaxExtraSampleCount;
    float OffscreenStrokes_UnreliableSampleEdgeDistance;
    float OffscreenStrokes_MinEdgeDistance;
    float OffscreenStrokes_MaxOffscreenExtrapolation;
    float OffscreenStrokes_FastSmoothingLambda;
    float OffscreenStrokes_SlowSmoothingLambda;
    float OffscreenStrokes_FastVelocity;
    float OffscreenStrokes_SlowVelocity;
    float OffscreenStrokes_MaxExtrapolationDurationSeconds;
    float OffscreenStrokes_MaxExtrapolationSampleCount;
    float OffscreenStrokes_AccelerationDecayLambda;
    float OffscreenStrokes_VelocityDecayLambda;
    int OffscreenStrokes_GroundingSampleCount;
    float OffscreenStrokes_MinTotalStrokeLength;
    float OffscreenTouches_MaxHistorySeconds;
    int OffscreenTouches_MaxDiscardSamples;
    int OffscreenTouches_MaxSampleCount;
    int OffscreenTouches_MinSampleCount;
    int OffscreenTouches_MaxExtraSampleCount;
    int OffscreenTouches_UnreliableSampleEdgeDistance;
    float OffscreenTouches_MinEdgeDistance;
    float OffscreenTouches_FastSmoothingLambda;
    float OffscreenTouches_SlowSmoothingLambda;
    float OffscreenTouches_FastVelocity;
    float OffscreenTouches_SlowVelocity;
    float OffscreenTouches_AccelerationDecayLambda;
    float OffscreenTouches_VelocityDecayLambda;
    float OffscreenTouches_MaxExtrapolationDurationSeconds;
    float OffscreenTouches_MaxExtrapolationSampleCount;
    float OffscreenTouches_MaxPenOffscreenDistance;
    float OffscreenTouches_MaxPenOffscreenSeconds;

    Settings();
};

struct ScreenEdges {
    bool IsNearTop;
    bool IsNearBottom;
    bool IsNearLeft;
    bool IsNearRight;

    ScreenEdges();
    bool IsEmpty() const;
};

struct OffscreenStroke {
    bool IsOffscreenStroke;

    // The remaining properties are only set if IsOffscreenStroke == true;
    core::InputSample LastSample;
    core::InputSample Velocity;
    core::InputSample Acceleration;
    int DiscardedSampleCount;
    int FirstOffscreenExtrapolatedSampleIdx;
    static OffscreenStroke NotAnOffscreenStroke();
    static OffscreenStroke IsAnOffscreenStroke(const core::InputSample &lastSample,
                                               const core::InputSample &velocity,
                                               const core::InputSample &acceleration,
                                               int discardedSampleCount,
                                               int firstOffscreenExtrapolatedSampleIdx);
};

float MaxHistorySeconds(bool isPermissive);

bool IsVelocityTowardScreenEdgesPermissive(const core::InputSample &velocity,
                                           const ScreenEdges &screenEdges);

// When extrapolating, ignore samples older than
// GlobalSettings::Instance()->OffscreenStrokes_MaxHistorySeconds().
//
// GlobalSettings::Instance()->OffscreenStrokes_MaxDiscardSamples() is the maximum number
// of unreliable samples near the edge of the screen that we can discard.
//
// GlobalSettings::Instance()->OffscreenStrokes_MinSampleCount() represents the minimum
// number of recent, reliable samples we need to extrapolate a stroke.
//
// OffscreenStrokes_MinSampleCount() must be (at a bare minimum) at least 3
// in order to have enough samples to calculate acceleration.
//
// An offscreen stroke's edge sample must be closer than
// OffscreenStrokes_MinEdgeDistance()
// pixels from the edge of the screen.
//
// Samples closer than GlobalSettings::Instance()->OffscreenStrokes_UnreliableSampleEdgeDistance()
// to an edge of the screen are considered unreliable and are discarded if possible.
void InputSampleSmoothedVelocityAndAcceleration(const std::vector<core::InputSample> &samples,
                                                const float smoothingLambda,
                                                core::InputSample &velocity,
                                                core::InputSample &acceleration);

void SmoothedVelocityAndAccelerationFromSamples(const std::vector<core::InputSample> &samples,
                                                core::InputSample &velocity,
                                                core::InputSample &acceleration);

core::InputSample NaiveVelocityFromSamples(const std::vector<core::InputSample> &samples);

core::optional<std::vector<core::InputSample>> FilterEdgeSamples(const std::vector<core::InputSample> &edgeSamples,
                                                                 OffscreenStrokesMode offscreenStrokesMode,
                                                                 int minSampleCount,
                                                                 int maxDiscardSamples,
                                                                 bool forceDecision,
                                                                 bool isPermissive,
                                                                 int &discardedSampleCount);

bool IsOnScreen(const core::InputSample &inputSample, const int margin);

bool IsUnreliableSample(const core::InputSample &inputSample);

core::optional<OffscreenStroke> IsOffscreenStrokePermissive(const std::deque<core::InputSample> &normalizedSamples,
                                                            OffscreenStrokesMode offscreenStrokesMode,
                                                            bool forceDecision);
int MaxDiscardSamples(bool isPermissive);

int MaxEdgeSampleWindowSize(bool isPermissive);

std::vector<core::InputSample> EdgeSamplesForNormalizedSamples(const std::deque<core::InputSample> &normalizedSamples,
                                                               OffscreenStrokesMode offscreenStrokesMode,
                                                               bool isPermissive);

std::deque<core::InputSample> NormalizedSamplesForTouch(const core::Touch::cPtr &touch);

ScreenEdges ScreenEdgesNearSample(const core::InputSample &inputSample, bool isPermissive);

core::optional<OffscreenStroke> IsOffscreenStrokePermissive(const core::Touch::cPtr &touch,
                                                            OffscreenStrokesMode offscreenStrokesMode,
                                                            bool forceDecision);
bool DidTouchExitOffscreenPermissive(const core::Touch::cPtr &touch);
core::optional<bool> WillTouchEnterFromOffscreenPermissive(const core::Touch::cPtr &touch);
}
}
