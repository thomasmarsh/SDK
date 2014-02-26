//
//  FTPenAndTouchManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "Common/Touch/Touch.h"
#include "Core/Memory.h"
#include "FiftyThreeSdk/PenEvent.h"

namespace fiftythree
{
namespace sdk
{

// TODO:
//      This class is barely used. We should axe it and the event logger.

DEFINE_ENUM(FTTouchType,
            Finger,
            Pen,
            Unknown,
            NotFound);

class FTPenAndTouchManager
{
public:
    typedef fiftythree::core::shared_ptr<FTPenAndTouchManager> Ptr;
    typedef const fiftythree::core::shared_ptr<FTPenAndTouchManager> cPtr;

protected:
    ~FTPenAndTouchManager() {}

public:
    virtual void SetPalmRejectionEnabled(bool enabled) = 0;

    virtual void RegisterForEvents() = 0;
    virtual void UnregisterForEvents() = 0;
    virtual void Clear() = 0;
    virtual void HandlePenEvent(const PenEvent::Ptr & event) = 0; // TODO - should register for pen events as with touch events, for now pass them in

    virtual FTTouchType GetTouchType(const common::Touch::cPtr & touch) = 0;
    virtual Event<const common::Touch::cPtr &> & TouchTypeChanged() = 0;
    virtual Event<Unit> & ShouldStartTrialSeparation() = 0;

    static Ptr New();
};

}
}
