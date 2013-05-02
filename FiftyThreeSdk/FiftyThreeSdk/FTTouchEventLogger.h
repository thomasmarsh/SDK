//
//  FTTouchEventLogger.h
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <boost/smart_ptr.hpp>

#include "Common/Touch.h"
#include "PenEvent.h"

namespace fiftythree
{
namespace sdk
{

class FTTouchEventLogger
{
public:
    typedef boost::shared_ptr<FTTouchEventLogger> Ptr;
    typedef const boost::shared_ptr<FTTouchEventLogger> cPtr;

protected:
    FTTouchEventLogger() {}

public:
    virtual void TouchesBegan(const fiftythree::common::TouchesSet & touches) = 0;
    virtual void TouchesMoved(const fiftythree::common::TouchesSet & touches) = 0;
    virtual void TouchesEnded(const fiftythree::common::TouchesSet & touches) = 0;
    virtual void TouchesCancelled(const fiftythree::common::TouchesSet & touches) = 0;
    virtual void HandlePenEvent(const PenEvent::Ptr & event) = 0;

    virtual void Clear() = 0;

    static Ptr New();
};

#ifdef __OBJC__

#import <Foundation/Foundation.h>

class FTTouchEventLoggerObjc : public FTTouchEventLogger
{
public:
    FTTouchEventLoggerObjc() {}

    virtual NSMutableData* GetData() = 0;
    virtual common::Touch::cPtr NearestStrokeForTouch(common::Touch::cPtr touch) = 0;

    FT_NO_COPY(FTTouchEventLoggerObjc);
};

#endif

}
}
