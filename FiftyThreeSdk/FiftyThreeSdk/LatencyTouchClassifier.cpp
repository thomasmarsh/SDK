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
    bool _IsPenDown;
    double _LastTouchBeganTime;
    double _PenDownTime;
    double _PenUpTime;
    
    std::vector<Touch::cPtr> _CandidateTouches;
    
public:
    LatencyTouchClassifierImpl()
    :
    _IsPenDown(false),
    _LastTouchBeganTime(0),
    _PenDownTime(0),
    _PenUpTime(0)
    {};

    virtual bool HandlesPenInput()
    {
        return true;
    }

    virtual void TouchesBegan(const fiftythree::common::TouchesSet & touches)
    {
        if (_IsPenDown)
        {
            std::cout << "Pen is already down, rejecting new touches\n";
            return;
        }

        _CandidateTouches.assign(touches.begin(), touches.end());
    }
    
    virtual void TouchesMoved(const fiftythree::common::TouchesSet & touches) {}
    
    virtual void TouchesEnded(const fiftythree::common::TouchesSet & touches) {}
    
    virtual void TouchesCancelled(const fiftythree::common::TouchesSet & touches) {}

    virtual void ProcessPenEvent(const PenEvent & event)
    {
        _IsPenDown = event.Type == PenEventType::PenDown;
            
        if (_CandidateTouches.empty())
        {
            std::cout << "WARNING: Pen event received before touch, ignoring\n";
            return;
        }
        
        if (_IsPenDown)
        {
            _PenDownTime = event.Sample.Timestamp();
            _PenUpTime = 0;
            
            BOOST_FOREACH(const Touch::cPtr & touch, _CandidateTouches)
            {
                double timeDelta = event.Sample.Timestamp() - touch->Sample.Timestamp();
            
                if (timeDelta > MAX_DELAY_SEC)
                {
                    std::cout << "Not a candidate: " << std::endl;
                }
                
                std::cout << "PenEvent " << event.Sample.ToString() << std::endl;
            }
        }
        else // PenUp
        {
            _PenUpTime = event.Sample.Timestamp();
            
            BOOST_FOREACH(const Touch::cPtr & touch, _CandidateTouches)
            {
                if (!touch->HasEndedOrCancelled) continue;
                
                // Measure from end touch
                double timeDelta = event.Sample.Timestamp() - touch->History->back().Timestamp();
                
                if (timeDelta > MAX_DELAY_SEC)
                {
                    std::cout << "Not a candidate: " << std::endl;
                }
                
                std::cout << "PenEvent " << event.Sample.ToString() << std::endl;
            }

            // BUGBUG - need to clear out cancelled touches eventually
        }
    }

    FT_NO_COPY(LatencyTouchClassifierImpl);
};

LatencyTouchClassifier::Ptr LatencyTouchClassifier::New()
{
    return boost::make_shared<LatencyTouchClassifierImpl>();
}
