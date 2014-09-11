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
    
    float _residual;
    
    
public:
    TwoTouchFit() : _residual(-1.0f)
    {
    }
    
    float Fit(Stroke & Z, Stroke & W, int minPoints, int maxPoints, bool isPinch);
    
};

}
}

