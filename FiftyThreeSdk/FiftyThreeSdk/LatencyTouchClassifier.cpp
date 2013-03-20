//
//  LatencyTouchClassifier.cpp
//  FiftyThreeSdk
//
//  Created by Adam on 3/19/13.
//  Copyright (c) 2013 FiftyThree. All rights reserved.
//

#include "LatencyTouchClassifier.h"

#include "Common/TouchManager.h"

using namespace fiftythree::sdk;

class LatencyTouchClassifierImpl : public LatencyTouchClassifier
{
public:
    LatencyTouchClassifierImpl() {};
    
    virtual void TouchesBegan(const fiftythree::common::TouchesSet & touches) {}
    virtual void TouchesMoved(const fiftythree::common::TouchesSet & touches) {}
    virtual void TouchesEnded(const fiftythree::common::TouchesSet & touches) {}
    virtual void TouchesCancelled(const fiftythree::common::TouchesSet & touches) {}
    
    virtual void ProcessPenEvent(const PenEvent & event) {}
    
    FT_NO_COPY(LatencyTouchClassifierImpl);
};

LatencyTouchClassifier::Ptr LatencyTouchClassifier::New()
{
    return boost::make_shared<LatencyTouchClassifierImpl>();
}
