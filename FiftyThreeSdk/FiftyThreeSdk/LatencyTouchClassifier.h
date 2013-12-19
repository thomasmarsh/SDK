//
//  LatencyTouchClassifier.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "Common/Memory.h"
#include "Common/NoCopy.h"
#include "TouchClassifier.h"

namespace fiftythree
{
namespace sdk
{

class LatencyTouchClassifier : public TouchClassifier
{
public:
    typedef fiftythree::common::shared_ptr<LatencyTouchClassifier> Ptr;
    typedef const fiftythree::common::shared_ptr<LatencyTouchClassifier> cPtr;

protected:
    ~LatencyTouchClassifier() {}

public:
    static Ptr New();
};

}
}
