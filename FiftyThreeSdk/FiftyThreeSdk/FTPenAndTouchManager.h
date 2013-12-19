//
//  FTPenAndTouchManager.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "Common/Memory.h"
#include "Common/Touch/Touch.h"
#include "FTTouchEventLogger.h"

namespace fiftythree
{
namespace sdk
{

DEFINE_ENUM(TouchType,
            Finger,
            Pen,
            Unknown,
            NotFound);

class FTPenAndTouchManager
{
public:
    typedef fiftythree::common::shared_ptr<FTPenAndTouchManager> Ptr;
    typedef const fiftythree::common::shared_ptr<FTPenAndTouchManager> cPtr;

protected:
    ~FTPenAndTouchManager() {}

public:
    virtual void SetLogger(FTTouchEventLogger::Ptr logger) = 0;
    virtual void SetPalmRejectionEnabled(bool enabled) = 0;

    virtual void RegisterForEvents() = 0;
    virtual void UnregisterForEvents() = 0;
    virtual void Clear() = 0;
    virtual void HandlePenEvent(const PenEvent::Ptr & event) = 0; // TODO - should register for pen events as with touch events, for now pass them in

    virtual TouchType GetTouchType(const common::Touch::cPtr & touch) = 0;
    virtual Event<const common::Touch::cPtr &> & TouchTypeChanged() = 0;
    virtual Event<Unit> & ShouldStartTrialSeparation() = 0;

    static Ptr New();
};

}
}
