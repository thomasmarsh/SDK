//
//  FTTouchEventLogger.m
//  FiftyThreeSdk
//
//  Created by Adam on 4/5/13.
//  Copyright (c) 2013 FiftyThree. All rights reserved.
//

#include "FTTouchEventLogger.h"

#include <boost/foreach.hpp>
#include <sstream>
#import <Foundation/Foundation.h>

const std::string TOUCH_PREFIX = "touch=";
const std::string PEN_PREFIX = "pen=";

using namespace fiftythree::common;
using namespace fiftythree::sdk;
using std::string;
using std::stringstream;

class FTTouchEventLoggerImpl : public FTTouchEventLoggerObjc
{
private:
    NSMutableData* data;
    
public:
    FTTouchEventLoggerImpl()
    {
        data = [NSMutableData data];
    }
    
    void TouchesBegan(const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            stringstream ss;
            ss << TOUCH_PREFIX << touch->ToString() << std::endl;
            
            std::cout << ss.str();
            
            [data appendBytes:ss.str().c_str() length:ss.tellp()];
        }
    }
    
    void TouchesMoved(const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            stringstream ss;
            ss << TOUCH_PREFIX << touch->ToString() << std::endl;
            
            std::cout << ss.str();
            
            [data appendBytes:ss.str().c_str() length:ss.tellp()];
        }
    }
    
    void TouchesEnded(const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            stringstream ss;
            ss << TOUCH_PREFIX << touch->ToString() << std::endl;
            
            std::cout << ss.str();
            
            [data appendBytes:ss.str().c_str() length:ss.tellp()];
        }
    }
    
    void TouchesCancelled(const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            stringstream ss;
            ss << TOUCH_PREFIX << touch->ToString() << std::endl;
            
            std::cout << ss.str();
            
            [data appendBytes:ss.str().c_str() length:ss.tellp()];
        }
    }
    
    virtual void HandlePenEvent(const PenEvent & event)
    {
        stringstream ss;
        ss << PEN_PREFIX << event.ToString() << std::endl;
        
        std::cout << ss.str();
        
        [data appendBytes:ss.str().c_str() length:ss.tellp()];
    }
    
    virtual void Clear()
    {
        data = [NSMutableData data];
    }
    
    virtual NSMutableData* GetData()
    {
        return data;
    }
    
    FT_NO_COPY(FTTouchEventLoggerImpl);
};

FTTouchEventLogger::Ptr FTTouchEventLogger::New()
{
    return boost::make_shared<FTTouchEventLoggerImpl>();
}
