//
//  LatencyTouchClassifier.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "Core/Memory.h"
#include "Core/NoCopy.h"
#include "TouchClassifier.h"

namespace fiftythree
{
namespace sdk
{

class LatencyTouchClassifier : public TouchClassifier
{
public:
    typedef fiftythree::core::shared_ptr<LatencyTouchClassifier> Ptr;
    typedef const fiftythree::core::shared_ptr<LatencyTouchClassifier> cPtr;

protected:
    ~LatencyTouchClassifier() {}

public:
    static Ptr New();
};

}
}
