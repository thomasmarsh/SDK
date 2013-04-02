//
//  FTPenAndTouchLogger.m
//  FiftyThreeSdk
//
//  Created by Adam on 3/29/13.
//  Copyright (c) 2013 FiftyThree. All rights reserved.
//

#include "FTPenAndTouchLogger.h"

#include <boost/smart_ptr.hpp>
#include <boost/foreach.hpp>

#include "Common/NoCopy.h"
#include "Common/TouchManager.h"
#include "Common/PenManager.h"

using namespace fiftythree::sdk;
using namespace fiftythree::common;

const std::string TOUCH_PREFIX = "touch=";
const std::string PEN_PREFIX = "pen=";

class FTPenAndTouchLoggerImpl : public FTPenAndTouchLogger, public boost::enable_shared_from_this<FTPenAndTouchLoggerImpl>
{
public:
    FTPenAndTouchLoggerImpl()
    {        
    }
    
    void StartLogging()
    {
        TouchManager::Instance()->TouchesBegan().AddListener(shared_from_this(), &FTPenAndTouchLoggerImpl::TouchesBegan);
        TouchManager::Instance()->TouchesMoved().AddListener(shared_from_this(), &FTPenAndTouchLoggerImpl::TouchesMoved);
        TouchManager::Instance()->TouchesEnded().AddListener(shared_from_this(), &FTPenAndTouchLoggerImpl::TouchesEnded);
        TouchManager::Instance()->TouchesCancelled().AddListener(shared_from_this(), &FTPenAndTouchLoggerImpl::TouchesCancelled);
    }
    
    void StopLogging()
    {
        TouchManager::Instance()->TouchesBegan().RemoveListener(shared_from_this());
        TouchManager::Instance()->TouchesMoved().RemoveListener(shared_from_this());
        TouchManager::Instance()->TouchesEnded().RemoveListener(shared_from_this());
        TouchManager::Instance()->TouchesCancelled().RemoveListener(shared_from_this());
    }
    
    void TouchesBegan(const TouchesSetEvent & sender, const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            std::cout << TOUCH_PREFIX << touch->ToString() << std::endl;
        }
    }
    
    void TouchesMoved(const TouchesSetEvent & sender, const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            std::cout << TOUCH_PREFIX << touch->ToString() << std::endl;
        }
    }
    
    void TouchesEnded(const TouchesSetEvent & sender, const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            std::cout << TOUCH_PREFIX << touch->ToString() << std::endl;
        }
    }
    
    void TouchesCancelled(const TouchesSetEvent & sender, const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            std::cout << TOUCH_PREFIX << touch->ToString() << std::endl;
        }
    }
    
    FT_NO_COPY(FTPenAndTouchLoggerImpl);
};

FTPenAndTouchLogger::Ptr FTPenAndTouchLogger::New()
{
    return boost::make_shared<FTPenAndTouchLoggerImpl>();
}