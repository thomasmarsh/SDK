//
//  TouchSize.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

namespace fiftythree
{
namespace sdk
{
class TouchData;

class TouchSize
{
public:

    constexpr static float PenTipRadius = 6.0f;

    // pen tip is very small -- this tells the caller if the size statistics
    // confidently indicate a pen.  with Pencil, the eraser tip can also look like
    // a pen when held at an angle with the short side making contact, so
    // IsPenGivenTouchRadius() will be fooled in that case.  the switch needs to save the day.
    static bool IsPenGivenTouchRadius(TouchData const &data);

    // a weaker test than the strict test above.  more palms will pass this.
    static bool IsWeakPenGivenTouchRadius(float r);
    
    static bool IsPalmGivenTouchRadius(float r);
};
}
}
