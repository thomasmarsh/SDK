//
//  PenEvent.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "Common/Enum.h"
#include "Common/Memory.h"
#include "Common/NoCopy.h"
#include "Common/Touch/PenManager.h"

namespace fiftythree
{
namespace sdk
{

DEFINE_ENUM(PenEventType,
            PenUp,
            PenDown);

DEFINE_ENUM(PenTip,
            Tip1,
            Tip2);

class PenEvent
{
public:
    typedef fiftythree::common::shared_ptr<PenEvent> Ptr;
    typedef fiftythree::common::shared_ptr<const PenEvent> cPtr;

    fiftythree::common::InputSample Sample;
    PenEventType Type;
    PenTip Tip;

    std::string ToString() const;
    static PenEvent::Ptr FromString(const std::string & s);

protected:
    ~PenEvent() {}
    PenEvent() {}

public:
    static PenEvent::Ptr New(double timestamp, PenEventType type, PenTip tip);

    FT_NO_COPY(PenEvent)
};

}
}
