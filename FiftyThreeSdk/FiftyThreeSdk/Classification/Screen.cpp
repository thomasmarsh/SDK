//
//  Screen.cpp
//  Curves
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#include "FiftyThreeSdk/Classification/Screen.h"
#include "FiftyThreeSdk/Classification/Stroke.h"

using namespace Eigen;

namespace fiftythree
{
namespace curves
{
Screen & Screen::MainScreen()
{
    static Screen *mainScreen = new Screen();
    return *mainScreen;
}

float Screen::DistanceToNearestEdge(Eigen::Vector2f const & p)
{

    float dLeft    = std::abs(p.x());
    float dRight   = std::abs(p.x() - _widthInPoints);
    float dTop     = std::abs(p.y());
    float dBottom  = std::abs(p.y() - _heightInPoints);

    return std::min(std::min(dLeft, dRight), std::min(dTop, dBottom));

}

Eigen::Vector2f Screen::FirstOnscreenPoint(Stroke const & stroke)
{
    for (int j=0; j<stroke.Size(); j++)
    {
        Vector2f p = stroke.XY(j);
        if (IsOnScreen(p))
        {
            return p;
        }
    }

    return Vector2f::Zero();
}

bool Screen::IsOnScreen(Vector2f const & p)
{
    return (p.x() >= 0) && (p.x() <= _widthInPoints) && (p.y() >= 0) && (p.y() <= _heightInPoints);
}

Screen::Edge Screen::NearbyEdges(Eigen::Vector2f const & p)
{

    float width  = _widthInPoints;
    float height = _heightInPoints;
    float tol    = _offscreenStrokes_minEdgeDistance;

    Edge listOfEdges = kEdgeNone;

    if (p.x() < tol)
    {
        listOfEdges = listOfEdges | kEdgeLeft;
    }

    if (p.x() > (width - tol))
    {
        listOfEdges = listOfEdges | kEdgeRight;

    }

    // top/bottom -- we're going with the Quartz convention, but it's just a name.
    // nothing in the code actually cares about top vs. bottom.
    if (p.y() < tol)
    {
        listOfEdges = listOfEdges | kEdgeTop;

    }

    if (p.y() > (height - tol))
    {
        listOfEdges = listOfEdges | kEdgeRight;

    }

    return listOfEdges;
}

// this assumes the point is on the screen.
bool Screen::IsEdgePoint(Vector2f const &p)
{
    return (NearbyEdges(p) != kEdgeNone);
}

bool Screen::IsUnreliablePoint(Eigen::Vector2f const &p)
{
    float width  = _widthInPoints;
    float height = _heightInPoints;
    float tol    = _offscreenStrokes_unreliableSampleEdgeDistance;

    if (p.x() < tol || p.x() > (width - tol) || p.y() < tol || p.y() > (height - tol))
    {
        return true;
    }
    else
    {
        return false;
    }
}

// unused at the moment -- but possible useful so leaving it in.
Vector2f Screen::DirectionToNearestEdge(Vector2f const & p)
{

    Vector2f d(0,0);

    float d_left  = p.x();
    float d_right = _widthInPoints - p.x();

    float d_up    = p.y();
    float d_down  = _heightInPoints - p.y();

    if (d_left < d_right)
    {
        d.x() = -d_left;
    }
    else
    {
        d.x() = d_right;
    }

    if (d_up < d_down)
    {
        d.y() = -d_up;
    }
    else
    {
        d.y() = d_down;
    }

    if (std::abs(d.y()) > std::abs(d.x()))
    {
        d.y() = 0;
    }
    else
    {
        d.x() = 0;
    }

    d.normalize();

    return d;

}
}
}
