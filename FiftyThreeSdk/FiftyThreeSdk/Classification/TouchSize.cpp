//
//  TouchSize.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include "Core/Eigen.h"
#include "Core/Touch/Touch.h"
#include "Core/Touch/TouchTracker.h"
#include "FiftyThreeSdk/Classification/ClassificationProxy.h"
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

    bool TouchSize::IsPenGivenTouchRadius(TouchData const &data)
    {
        return (data._radiusMax < 2.1f * PenTipRadius) &&
        std::abs(data._radiusMean - PenTipRadius) < 1.5f &&
        data._radiusVariance < 3.0f;
    }

}
}

/*

 Ideal:

 eraser: 41.7812, with 31.3438 at a moderate angle

 pen: 10.4375

 finger smudge: ~56 if I try to use the flat

 ===================================================

 From some limited testing with my own hands only (Matt):

 palm:

 mu = 87.3004, stdev = 37.6031, min = 0, max = 292.562

 finger smudge:

 mu = 42.0513, stdev = 15.6046, min = 20.8906, max = 83.5781

 pen tip, writing only:

 mu = 10.5144, stdev = 0.893047, min = 10.4375, max = 20.8906

 pen tip, mixed angles:

 mu = 27.4228, stdev = 16.283, min = 10.4375, max = 52.2344

 pen tip, max angle:

 mu = 51.6808, stdev = 3.0921, min = 10.4375, max = 52.2344

 eraser tip, straight up:

 mu = 28.8324, stdev = 6.15827, min = 10.4375, max = 41.7812

 eraser tip, mixed angles:

 mu = 19.9978, stdev = 8.53942, min = 10.4375, max = 31.3438

 */
