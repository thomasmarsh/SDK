//
//  PenEvent.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
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

DEFINE_ENUM(FTPenEventType,
            PenUp,
            PenDown);

DEFINE_ENUM(FTPenTip,
            Tip1,
            Tip2);

class PenEvent
{
public:
    typedef fiftythree::common::shared_ptr<PenEvent> Ptr;
    typedef fiftythree::common::shared_ptr<const PenEvent> cPtr;

    fiftythree::common::InputSample Sample;
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
