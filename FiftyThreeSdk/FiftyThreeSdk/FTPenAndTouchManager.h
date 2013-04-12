//
//  FTPenAndTouchManager.h
//  FiftyThreeSdk
//
//  Created by Adam on 3/29/13.
//  Copyright (c) 2013 FiftyThree. All rights reserved.
//

#pragma once

#include <boost/smart_ptr.hpp>

#include "Common/Touch.h"
#include "FTTouchEventLogger.h"

namespace fiftythree
{
namespace sdk
{
 
DEFINE_ENUM(TouchType,
            Finger,
            Pen,
            Unknown);
    
class FTPenAndTouchManager
{
public:
    typedef boost::shared_ptr<FTPenAndTouchManager> Ptr;
    typedef const boost::shared_ptr<FTPenAndTouchManager> cPtr;
    
protected:
    ~FTPenAndTouchManager() {}
    
public:
    virtual void SetLogger(FTTouchEventLogger::Ptr logger) = 0;
    virtual void RegisterForEvents() = 0;
    virtual void UnregisterForEvents() = 0;
    virtual void Clear() = 0;
    virtual fiftythree::common::Touch::cPtr NearestStrokeForTouch(fiftythree::common::Touch::cPtr touch) = 0;
    virtual void HandlePenEvent(const PenEvent & event) = 0; // TODO - should register for pen events as with touch events, for now pass them in
    
    virtual TouchType GetTouchType(const common::Touch::cPtr & touch) = 0;
    
    virtual Event<common::Touch::cPtr> & TouchTypeChanged() = 0;

    static Ptr New();
};

}
}