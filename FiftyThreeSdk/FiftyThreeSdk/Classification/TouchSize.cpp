//
//  TouchSize.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
//

#include "FiftyThreeSdk/Classification/TouchLogger.h"
#include "FiftyThreeSdk/Classification/TouchSize.h"

using namespace fiftythree::core;

namespace fiftythree
{
namespace sdk
{
bool TouchSize::IsPenGivenTouchRadius(TouchData const &data)
{
    // really want equality, i.e. the pen tip size is typically exactly equal to PenTipRadius.
    // but we allow a little bit of flexibility.
    return (data._leadingRadiusMax < 2.1f * PenTipRadius) &&
           data._leadingRadiusMean - PenTipRadius < .2f * PenTipRadius &&
           std::sqrt(data._leadingRadiusVariance) < (.25f * PenTipRadius);
}

bool TouchSize::IsWeakPenGivenTouchRadius(float r, float arcLength)
{
    constexpr float notPenTipScaleFactor = 1.9f;
    if (r > notPenTipScaleFactor * PenTipRadius) {
        return false;
    } else {
        // require more length at larger radii.  they are more likely to be palms
        // and the artifacts are also much worse: the dreaded blotches.
        return arcLength > r;
    }
}

bool TouchSize::IsPalmGivenTouchRadius(float r)
{
    constexpr float threshold = 30.29f;
    return r > threshold;
}
}
}

// clang-format off
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
// clang-format on
