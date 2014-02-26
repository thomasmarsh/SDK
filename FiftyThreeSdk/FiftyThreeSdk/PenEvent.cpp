//
//  PenEvent.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include "Core/Memory.h"
#include "PenEvent.h"

using namespace fiftythree::core;
using namespace fiftythree::sdk;

class PenEventImpl : public PenEvent
{
public:
    PenEventImpl(double timestamp, FTPenEventType type, FTPenTip tip)
    {
        InputSample sample(Eigen::Vector2f::Zero(),
                           Eigen::Vector2f::Zero(),
                           timestamp);
        Sample = sample;
        Type = type;
        Tip = tip;
    }

    ~PenEventImpl() {}
};

PenEvent::Ptr PenEvent::New(double timestamp, FTPenEventType type, FTPenTip tip)
{
    return fiftythree::core::make_shared<PenEventImpl>(timestamp, type, tip);
}
