//
//  TwoTouchFit.h
//  FiftyThreeSdk
//
//  Created by matt on 9/10/14.
//  Copyright (c) 2014 FiftyThree. All rights reserved.
//

#pragma once

#include <vector>
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
    
    Eigen::MatrixXf _A;
    Eigen::MatrixXf _b;
    Eigen::MatrixXf _weight;
    
    Eigen::Vector2f _axisOfSymmetry;
    Eigen::Vector2f _targetDirection;
    
    void ConstructProblem(Stroke & Z, Stroke & W, int zCount, int wCount);
    
public:
    TwoTouchFit() : _score(-1.0f), _scale(0.0)
    {
    }
    
    float Fit(Stroke & Z, Stroke & W, int minPoints, int maxPoints, bool isPinch);
    
    float Curvature(float relativeTimestamp);
    
};

}
}

