//
//  PenEvent.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "Core/Enum.h"
#include "Core/Memory.h"
#include "Core/NoCopy.h"
#include "Core/Touch/InputSample.h"

namespace fiftythree
{
namespace sdk
{

DEFINE_ENUM(FTPenEventType,
            PenUp,
            PenDown);

DEFINE_ENUM(FTPenTip,
            Tip1,
            Tip2);

class PenEvent
{
public:
    typedef fiftythree::core::shared_ptr<PenEvent> Ptr;
    typedef fiftythree::core::shared_ptr<const PenEvent> cPtr;

    fiftythree::core::InputSample Sample;
    FTPenEventType Type;
    FTPenTip Tip;

protected:
    ~PenEvent() {}
    PenEvent() {}

public:
    static PenEvent::Ptr New(double timestamp, FTPenEventType type, FTPenTip tip);

    FT_NO_COPY(PenEvent)
};

}
}
