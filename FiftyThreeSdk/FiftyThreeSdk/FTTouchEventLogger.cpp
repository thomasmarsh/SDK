//
//  FTTouchEventLogger.m
//  FiftyThreeSdk
//
//  Created by Adam on 4/5/13.
//  Copyright (c) 2013 FiftyThree. All rights reserved.
//

#import "FTTouchEventLogger.h"

#include <boost/foreach.hpp>

const std::string TOUCH_PREFIX = "touch=";
const std::string PEN_PREFIX = "pen=";

using namespace fiftythree::common;
using namespace fiftythree::sdk;

class FTTouchEventLoggerImpl : public FTTouchEventLogger
{
public:
    FTTouchEventLoggerImpl() {}
    
    void TouchesBegan(const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            std::cout << TOUCH_PREFIX << touch->ToString() << std::endl;
        }
    }
    
    void TouchesMoved(const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            std::cout << TOUCH_PREFIX << touch->ToString() << std::endl;
        }
    }
    
    void TouchesEnded(const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            std::cout << TOUCH_PREFIX << touch->ToString() << std::endl;
        }
    }
    
    void TouchesCancelled(const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            std::cout << TOUCH_PREFIX << touch->ToString() << std::endl;
        }
    }
    
    virtual void HandlePenEvent(const PenEvent & event)
    {
         std::cout << PEN_PREFIX << event.ToString() << std::endl;
    }

    FT_NO_COPY(FTTouchEventLoggerImpl);
};

FTTouchEventLogger::Ptr FTTouchEventLogger::New()
{
    return boost::make_shared<FTTouchEventLoggerImpl>();
}
