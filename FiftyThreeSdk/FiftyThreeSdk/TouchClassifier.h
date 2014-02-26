//
//  TouchClassifier.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <set>

#include "Common/Touch/TouchManager.h"
#include "Core/Memory.h"
#include "FTPenAndTouchManager.h"
#include "PenEvent.h"

namespace fiftythree
{
namespace sdk
{

class TouchClassifier
{
public:
    typedef fiftythree::core::shared_ptr<TouchClassifier> Ptr;
    typedef const fiftythree::core::shared_ptr<TouchClassifier> cPtr;

protected:
    ~TouchClassifier() {}

public:
    virtual bool HandlesPenInput() = 0;

    virtual void TouchesBegan(const fiftythree::common::TouchesSet & touches) = 0;
    virtual void TouchesMoved(const fiftythree::common::TouchesSet & touches) = 0;
    virtual void TouchesEnded(const fiftythree::common::TouchesSet & touches) = 0;
    virtual void TouchesCancelled(const fiftythree::common::TouchesSet & touches) = 0;

    virtual void ProcessPenEvent(const PenEvent::Ptr & event) = 0;

    virtual FTTouchType GetTouchType(const fiftythree::common::Touch::cPtr & touch) = 0;
    virtual Event<const common::Touch::cPtr &> & TouchTypeChanged() = 0;
};

}
}
