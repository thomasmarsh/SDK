//
//  TouchClassifierManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "TouchClassifier.h"

#include <boost/smart_ptr.hpp>

#include "Common/NoCopy.h"

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
    static Ptr New();
};

}
}