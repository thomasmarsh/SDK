//
//  TouchClassifierManager.h
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

class TouchClassifierManager : public TouchClassifier
{
public:
    typedef fiftythree::core::shared_ptr<TouchClassifierManager> Ptr;
    typedef const fiftythree::core::shared_ptr<TouchClassifierManager> cPtr;

protected:
    ~TouchClassifierManager() {}

public:
    virtual void AddClassifier(TouchClassifier::Ptr classifier) = 0;
    virtual void RemoveClassifier(TouchClassifier::Ptr classifier) = 0;

    static Ptr New();
};

}
}
