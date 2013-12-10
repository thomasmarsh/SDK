//
//  TouchClassifierManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <boost/smart_ptr.hpp>

#include "Common/NoCopy.h"
#include "TouchClassifier.h"

namespace fiftythree
{
namespace sdk
{

class TouchClassifierManager : public TouchClassifier
{
public:
    typedef boost::shared_ptr<TouchClassifierManager> Ptr;
    typedef const boost::shared_ptr<TouchClassifierManager> cPtr;

protected:
    ~TouchClassifierManager() {}

public:
    virtual void AddClassifier(TouchClassifier::Ptr classifier) = 0;
    virtual void RemoveClassifier(TouchClassifier::Ptr classifier) = 0;

    static Ptr New();
};

}
}
