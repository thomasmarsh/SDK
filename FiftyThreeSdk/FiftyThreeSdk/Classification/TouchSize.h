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
}
}

namespace fiftythree
{
namespace sdk
{
class TouchSize
{

public:

    constexpr static float PenTipRadius = 10.4375f;

    // pen tip is very small -- this tells the caller if the size statistics
    // confidently indicate a pen.  with Pencil, the eraser tip can also look like
    // a pen when held at an angle with the short side making contact, so
    // IsPenGivenTouchRadius() will be fooled in that case.  the switch needs to save the day.
    static bool IsPenGivenTouchRadius(TouchData const &data);

};
}
}
