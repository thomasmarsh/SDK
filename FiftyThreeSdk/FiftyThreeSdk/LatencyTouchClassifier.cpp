//
//  LatencyTouchClassifier.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#include "LatencyTouchClassifier.h"

#include <ios>
#include <map>
#include <vector>
#include <boost/foreach.hpp>

#include "Common/TouchManager.h"

using namespace fiftythree::sdk;
using namespace fiftythree::common;

const double MAX_DELAY_MSEC = 50.0;
const double MAX_DELAY_SEC = MAX_DELAY_MSEC / 1000;

class LatencyTouchClassifierImpl : public LatencyTouchClassifier
{
private:
    double _LastTouchBeganTime;
    std::vector<Touch::cPtr> _TouchVector;
    std::map<const void*,Touch::cPtr> _TouchMap;
    bool _IsPenDown;
    
public:
    LatencyTouchClassifierImpl()
    :
    _IsPenDown(false),
    _LastTouchBeganTime(0)
    {};

    virtual bool HandlesPenInput()
    {
        return true;
    }

    virtual void TouchesBegan(const fiftythree::common::TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            _LastTouchBeganTime = touch->Sample.Timestamp();
            std::cout << "Touch Began: id=" << touch->Id << " " << touch->Sample.ToString() << std::endl;
            
//            _TouchVector.push_back(touch);
            _TouchMap[touch->Id] = touch;
        }
        
        if (_IsPenDown)
        {
            std::cout << "Touch Rejected (pen already down)\n";
        }
    }
    
    virtual void TouchesMoved(const fiftythree::common::TouchesSet & touches) {}
    
    virtual void TouchesEnded(const fiftythree::common::TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            std::cout << "Touch Ended: id=" << touch->Id << " " << touch->Sample.ToString() << std::endl;

            Touch::cPtr t = _TouchMap[touch->Id];
            _TouchMap.erase(touch->Id);
//            _TouchVector.erase(std::remove(_TouchMap.begin(), _TouchMap.end(), t), _TouchMap.end());
        }
    }
    
    virtual void TouchesCancelled(const fiftythree::common::TouchesSet & touches)
    {
    }

    virtual void ProcessPenEvent(const PenEvent & event)
    {
        _IsPenDown = event.Type == PenEventType::PenDown;
        
        if (_IsPenDown)
        {
            if (_TouchMap.empty())
            {
                std::cout << "WARNING: Pen event received before touch" << std::endl;
                return;
            }
            
            double timeDelta = event.Sample.Timestamp() - _LastTouchBeganTime;

            std::cout << "PenEvent " << event.Sample.ToString() << std::endl;
            
            if (timeDelta < MAX_DELAY_SEC)
            {
                std::cout << "Touch is Pen!" << std::endl;
            }
        }
    }

    FT_NO_COPY(LatencyTouchClassifierImpl);
};

LatencyTouchClassifier::Ptr LatencyTouchClassifier::New()
{
    return boost::make_shared<LatencyTouchClassifierImpl>();
}
