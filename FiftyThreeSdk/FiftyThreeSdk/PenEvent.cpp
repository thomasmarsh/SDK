//
//  PenEvent.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#include "PenEvent.h"

#include <boost/smart_ptr.hpp>

using namespace fiftythree::sdk;
using namespace fiftythree::common;

std::string PenEvent::ToString() const
{
    std::stringstream ss ;
    ss.precision(20);
    ss << (int)this->Type << ","
    << this->Tip << ","
    << this->Sample.ToString();
    return ss.str();
}

PenEvent::Ptr PenEvent::FromString(const std::string & s)
{
    std::vector<std::string> parts;
    boost::algorithm::split(parts, s, boost::is_any_of("=,"));

    std::vector<std::string> remainder(parts.begin() + 2, parts.end());

    PenEvent::Ptr event = PenEvent::New(
                                        InputSample::FromString(boost::algorithm::join(remainder, ",")),
                                        PenEventType((PenEventType::PenEventTypeEnum)boost::lexical_cast<int>(parts[0])),
                                        PenTip((PenTip::PenTipEnum)boost::lexical_cast<int>(parts[1])));

    return event;
}

bool PenEvent::operator==(const PenEvent &other) const
{
    return Type == other.Type &&
    Tip == other.Tip &&
    Sample == other.Sample;
}

class PenEventImpl : public PenEvent
{
public:
    PenEventImpl(fiftythree::common::InputSample sample, PenEventType type, PenTip tip)
    {
        Sample = sample;
        Type = type;
        Tip = tip;
    }

    ~PenEventImpl() {}
};

PenEvent::Ptr PenEvent::New(fiftythree::common::InputSample sample, PenEventType type, PenTip tip)
{
    return boost::make_shared<PenEventImpl>(sample, type, tip);
}
