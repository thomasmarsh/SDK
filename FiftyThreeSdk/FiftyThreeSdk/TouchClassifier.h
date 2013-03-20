//
//  TouchClassifier.h
//  FiftyThreeSdk
//
//  Created by Adam on 3/19/13.
//  Copyright (c) 2013 FiftyThree. All rights reserved.
//

#pragma once

#include <boost/smart_ptr.hpp>
#include <set>
#include "Common/TouchManager.h"

class PenEvent;

namespace fiftythree
{
namespace sdk
{

class TouchClassifier
{
public:
    typedef boost::shared_ptr<TouchClassifier> Ptr;
    typedef const boost::shared_ptr<TouchClassifier> cPtr;
    
protected:
    ~TouchClassifier() {}
    
public:
    virtual bool HandlesPenInput() = 0;
    
    virtual void TouchesBegan(const fiftythree::common::TouchesSet & touches) = 0;
    virtual void TouchesMoved(const fiftythree::common::TouchesSet & touches) = 0;
    virtual void TouchesEnded(const fiftythree::common::TouchesSet & touches) = 0;
    virtual void TouchesCancelled(const fiftythree::common::TouchesSet & touches) = 0;
    
    virtual void ProcessPenEvent(const PenEvent & event) = 0;
};

}
}
