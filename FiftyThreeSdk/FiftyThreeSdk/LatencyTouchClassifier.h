//
//  LatencyTouchClassifier.h
//  FiftyThreeSdk
//
//  Created by Adam on 3/19/13.
//  Copyright (c) 2013 FiftyThree. All rights reserved.
//

#pragma once

#include "TouchClassifier.h"

#include <boost/smart_ptr.hpp>

#include "Common/NoCopy.h"

namespace fiftythree
{
namespace sdk
{

class LatencyTouchClassifier : public TouchClassifier
{
public:
    typedef boost::shared_ptr<LatencyTouchClassifier> Ptr;
    typedef const boost::shared_ptr<LatencyTouchClassifier> cPtr;
    
protected:
    ~LatencyTouchClassifier() {}
    
public:
    static Ptr New();
};

}
}