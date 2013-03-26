//
//  PenEvent.h
//  FiftyThreeSdk
//
//  Created by Adam on 3/20/13.
//  Copyright (c) 2013 FiftyThree. All rights reserved.
//

#pragma once

#include <boost/shared_ptr.hpp>
#include "Common/NoCopy.h"
#include "Common/Enum.h"

#include "Common/PenManager.h"

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
    typedef boost::shared_ptr<PenEvent> Ptr;
    typedef boost::shared_ptr<const PenEvent> cPtr;
    
    fiftythree::common::InputSample Sample;
    PenEventType Type;
    PenTip Tip;
    
protected:
    ~PenEvent() {}
    PenEvent() {}
    
public:
    static PenEvent::Ptr New(fiftythree::common::InputSample sample, PenEventType type, PenTip tip);
    
    FT_NO_COPY(PenEvent)
};

}
}