//
//  Screen.h
//  FiftyThreeSdk
//
//  Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "Core/DeviceInfo.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"

namespace fiftythree
{
namespace sdk
{

class Stroke;

class Screen
{

private:

public:

    // DEFINE_ENUM doesn't apply to bitmask usage
    enum
    {
        kEdgeNone    = 0,
        kEdgeLeft    = 1,
        kEdgeRight   = 1 << 1,
        kEdgeTop     = 1 << 2,
        kEdgeBottom  = 1 << 3
    };

    typedef uint32_t Edge;

    float _scale;
    float _heightInPoints;
    float _widthInPoints;

    // these felt like device properties so i put them here but one could certainly argue
    // that they should go with the rest of the smoothing/interpolation stuff.
    float _offscreenStrokes_minEdgeDistance;
    float _offscreenStrokes_unreliableSampleEdgeDistance;

    Screen() :
    _scale(1.0f),
    _heightInPoints(fiftythree::core::DeviceInfo::SafeInstance()->GetDisplayMetrics().ScreenHeight),
    _widthInPoints(fiftythree::core::DeviceInfo::SafeInstance()->GetDisplayMetrics().ScreenWidth),
    _offscreenStrokes_minEdgeDistance(10.0f),
    _offscreenStrokes_unreliableSampleEdgeDistance(15.0f)
    {
    }

    static Screen & MainScreen();

    Edge NearbyEdges(Eigen::Vector2f const & p);

    bool IsOnScreen(Eigen::Vector2f const & p);

    float DistanceToNearestEdge(Eigen::Vector2f const & p);

    bool IsEdgePoint(Eigen::Vector2f const & p);

    bool IsEdgePoint(Vector1f const & p) { return false; }

    bool IsUnreliablePoint(Eigen::Vector2f const & p);

    Eigen::Vector2f FirstOnscreenPoint(Stroke const & stroke);

    Eigen::Vector2f DirectionToNearestEdge(Eigen::Vector2f const & p);

};
}
}
