//
//  PenEvent.cpp
//  FiftyThreeSdk
//
//  Created by Adam on 3/20/13.
//  Copyright (c) 2013 FiftyThree. All rights reserved.
//

#include "PenEvent.h"

#include <boost/smart_ptr.hpp>

using namespace fiftythree::sdk;

class PenEventImpl : public PenEvent
{
public:
    PenEventImpl(fiftythree::common::InputSample sample, PenEventType type, PenTip tip) {}
    
    ~PenEventImpl() {}
};

PenEvent::Ptr PenEvent::New(fiftythree::common::InputSample sample, PenEventType type, PenTip tip)
{
    return boost::make_shared<PenEventImpl>(sample, type, tip);
}
