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

template <class T>
void RemoveAll(std::vector<T> v, std::vector<T> removeVector)
{
    BOOST_FOREACH(const T & t, removeVector)
    {
        v.erase(std::remove(v.end(), v.begin(), t), v.end());
    }
}

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
            std::cout << "PenDown" << std::endl;

            _PenDownTime = event.Sample.Timestamp();
            _PenUpTime = 0;

            /*
            std::vector<Touch::cPtr> toRemove;
             
            BOOST_FOREACH(const Touch::cPtr & touch, _CandidateTouches)
            {
                double timeDelta = event.Sample.Timestamp() - touch->Sample.Timestamp();
            
                if (timeDelta > MAX_DELAY_SEC)
                {
                    std::cout << "Remove candidate touch: " << std::endl;
                    toRemove.push_back(touch);
                }
                
                std::cout << "PenEvent " << event.Sample.ToString() << std::endl;
            }
            
            RemoveAll(_CandidateTouches, toRemove);
             */
            
            std::vector<Touch::cPtr>::iterator it = _CandidateTouches.begin();
            for (;it != _CandidateTouches.end();)
            {
                const Touch::cPtr & touch = *it;
                double timeDelta = event.Sample.Timestamp() - touch->Sample.Timestamp();
                
                if (timeDelta > MAX_DELAY_SEC)
                {
                    std::cout << "Remove candidate touch: " << std::endl;
                    it = _CandidateTouches.erase(it);
                }
                else
                {
                    ++it;
                }
            }
        }
        else // PenUp
        {
            std::cout << "PenDown" << std::endl;
            
            _PenUpTime = event.Sample.Timestamp();
            
            /*
            std::vector<Touch::cPtr> toRemove;
            
            BOOST_FOREACH(const Touch::cPtr & touch, _CandidateTouches)
            {
                if (!touch->HasEndedOrCancelled) continue;
                
                // Measure from end-phase touch
                double timeDelta = event.Sample.Timestamp() - touch->History->back().Timestamp();
                
                if (timeDelta > MAX_DELAY_SEC)
                {
                    std::cout << "Remove candidate touch: " << std::endl;
                    toRemove.push_back(touch);
                }
                
                std::cout << "PenEvent " << event.Sample.ToString() << std::endl;
            }
            
            RemoveAll(_CandidateTouches, toRemove);
             */
            
            std::vector<Touch::cPtr>::iterator it = _CandidateTouches.begin();
            for (;it != _CandidateTouches.end();)
            {
                const Touch::cPtr & touch = *it;
                double timeDelta = event.Sample.Timestamp() - touch->History->back().Timestamp(); // Measure from end-phase touch

                if (!touch->HasEndedOrCancelled || timeDelta > MAX_DELAY_SEC)
                {
                    std::cout << "Remove candidate touch: " << std::endl;
                    it = _CandidateTouches.erase(it);
                }
                else
                {
                    ++it;
                }
            }
            
            if (_CandidateTouches.size())
            {
                // TODO - notify then remove candidates
            }
            
            _CandidateTouches.clear();
        }
    }

    FT_NO_COPY(LatencyTouchClassifierImpl);
};

LatencyTouchClassifier::Ptr LatencyTouchClassifier::New()
{
    return boost::make_shared<LatencyTouchClassifierImpl>();
}
