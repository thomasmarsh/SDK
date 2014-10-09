//
//  TwoTouchFit.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "FiftyThreeSdk/Classification/Eigen.h"
#include "FiftyThreeSdk/Classification/Stroke.h"

namespace fiftythree
{
namespace sdk
{

class TwoTouchFit
{
    float _ax, _bx, _cx;
    float _ay, _by, _cy;

    float _score;
    float _scale;

    bool  _sizeOKFlag;

    Eigen::MatrixXf _A;
    Eigen::MatrixXf _b;
    Eigen::MatrixXf _weight;

    Eigen::Vector2f _axisOfSymmetry;
    Eigen::Vector2f _targetDirection;

    void ConstructProblem(Stroke & Z, Stroke & W, int zCount, int wCount, bool doReflection);

    float Fit(Stroke & Z, Stroke & W, int minPoints, int maxPoints, bool isPinch);

public:
    TwoTouchFit() : _score(-1.0f), _scale(0.0), _sizeOKFlag(false)
    {
    }

    float FitPinch(Stroke & Z, Stroke & W, int minPoints, int maxPoints);
    float FitPan(Stroke & Z, Stroke & W, int minPoints, int maxPoints);

    float Curvature(float relativeTimestamp);

    bool SizeOKFlag() const
    {
        return _sizeOKFlag;
    }

};

}
}
