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

const double MAX_DELAY_SEC = 0.100;

class LatencyTouchClassifierImpl : public LatencyTouchClassifier
{
private:
    PenEvent::cPtr _PenDownEvent;
    PenEvent::cPtr _PenUpEvent;

    std::vector<Touch::cPtr> _UnknownTouches;
    std::vector<Touch::cPtr> _FingerTouches;
    Touch::cPtr _PenTouch;
    long _TouchCount;

    Event<const Touch::cPtr &> _TouchTypeChangedEvent;
    
private:
    bool IsPenDown()
    {
        return _PenDownEvent->Sample.TimestampSeconds() > _PenUpEvent->Sample.TimestampSeconds();
    }

public:
    LatencyTouchClassifierImpl()
    :
    _TouchCount(0)
    {
        // Dummy so we don't need to check for null
        _PenDownEvent = PenEvent::New(0, PenEventType::PenDown, PenTip::Tip1);
        _PenUpEvent = PenEvent::New(0, PenEventType::PenUp, PenTip::Tip1);
    };

    virtual bool HandlesPenInput()
    {
        return true;
    }
    
    long CountTouches()
    {
        return _UnknownTouches.size() + _FingerTouches.size() + (!!_PenTouch ? 1 : 0);
    }
    
    void ComputeDeltas(const PenEvent::cPtr & penEvent, std::vector<Touch::cPtr> changedTouches)
    {
        double min_delta = std::numeric_limits<double>::max();
        Touch::cPtr oldPenTouch = _PenTouch;
        
        std::vector<Touch::cPtr>::iterator it = _UnknownTouches.begin();
        while (it != _UnknownTouches.end())
        {
            const Touch::cPtr & touch = *it;
            double delta = std::abs(penEvent->Sample.TimestampSeconds() - touch->FirstSample().TimestampSeconds());

            if (delta < MAX_DELAY_SEC)
            {
                if (delta < min_delta)
                {
                    min_delta = delta;
                    if (_PenTouch)
                    {
                        _UnknownTouches.push_back(_PenTouch);
                    }
                    
                    _PenTouch = touch;
                    it = _UnknownTouches.erase(it);
                }
                else
                {
                    it++;
                }
            }
            else
            {
                _FingerTouches.push_back(touch);
                changedTouches.push_back(touch);
                
                it = _UnknownTouches.erase(it);
            }
        }
        
        if (oldPenTouch && oldPenTouch != _PenTouch)
        {
            changedTouches.push_back(oldPenTouch);
            changedTouches.push_back(_PenTouch);
        }
    }

    virtual void TouchesBegan(const fiftythree::common::TouchesSet & touches)
    {
        DebugAssert(CountTouches() == _TouchCount);

        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            _UnknownTouches.push_back(touch);
        }
        
        if (!_PenTouch && IsPenDown())
        {
            std::vector<Touch::cPtr> changedTouches;
            ComputeDeltas(_PenDownEvent, changedTouches);
        }
        
        _TouchCount += touches.size();
        DebugAssert(CountTouches() == _TouchCount);
    }

    virtual void TouchesMoved(const fiftythree::common::TouchesSet & touches)
    {
        DebugAssert(CountTouches() == _TouchCount);

        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            if (GetTouchType(touch) != TouchType::Unknown) continue;
            
            double delta = std::abs(touch->CurrentSample().TimestampSeconds() - touch->FirstSample().TimestampSeconds());
            std::cout << "Moved id = " << touch->Id() << " delta = " << delta << std::endl;

            if (delta > MAX_DELAY_SEC)
            {
                std::cout << "Touch expired, id = " << touch->Id() << std::endl;

                DebugAssert(find(_UnknownTouches.begin(), _UnknownTouches.end(), touch) != _UnknownTouches.end());
                _UnknownTouches.erase(std::remove(_UnknownTouches.begin(), _UnknownTouches.end(), touch), _UnknownTouches.end());
                _FingerTouches.push_back(touch);
                
                FireTouchTypeChangedEvent(touch);
            }
        }
        
        DebugAssert(CountTouches() == _TouchCount);
    }

    virtual void TouchesEnded(const fiftythree::common::TouchesSet & touches)
    {
        DebugAssert(CountTouches() == _TouchCount);
        
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            std::cout << "Ended id = " << touch->Id() << std::endl;
            
            _TouchCount--;
            
            TouchType type = GetTouchType(touch);
            if (type == TouchType::Pen)
            {
                _PenTouch.reset();
            }
            else if (type == TouchType::Finger)
            {
                // Finger touches are removed right away
                _FingerTouches.erase(std::remove(_FingerTouches.begin(), _FingerTouches.end(), touch), _FingerTouches.end());
            }
            else if (type == TouchType::Unknown)
            {
                _UnknownTouches.erase(std::remove(_UnknownTouches.begin(), _UnknownTouches.end(), touch), _UnknownTouches.end());
                
                // No pen event occured during the stroke, so it's a finger
                if (_PenDownEvent->Sample.TimestampSeconds() < touch->FirstSample().TimestampSeconds() - MAX_DELAY_SEC)
                {
                    _FingerTouches.push_back(touch);
                    FireTouchTypeChangedEvent(touch);   
                    _FingerTouches.erase(std::remove(_FingerTouches.begin(), _FingerTouches.end(), touch), _FingerTouches.end());
                }
            }
            else // Not Found
            {
                _TouchCount++; // Didn't actually remove anything
            }
        }

        DebugAssert(CountTouches() == _TouchCount);
    }

    virtual void TouchesCancelled(const fiftythree::common::TouchesSet & touches)
    {
        TouchesEnded(touches);
    }

    virtual void ProcessPenEvent(const PenEvent::Ptr & event)
    {
        DebugAssert(CountTouches() == _TouchCount);
        
        if (event->Type == PenEventType::PenDown)
        {
            _PenDownEvent = event;

            std::vector<Touch::cPtr> changedTouches;
            ComputeDeltas(_PenDownEvent, changedTouches);
            
            BOOST_FOREACH(const Touch::cPtr & touch, changedTouches)
            {
                FireTouchTypeChangedEvent(touch);
            }
        }
        else
        {
            _PenUpEvent = event;
        }
        
        DebugAssert(CountTouches() == _TouchCount);
    }
    
    virtual TouchType GetTouchType(const fiftythree::common::Touch::cPtr & touch)
    {
        if (_PenTouch == touch)
        {
            return TouchType::Pen;
        }
        else if (find(_FingerTouches.begin(), _FingerTouches.end(), touch) != _FingerTouches.end())
        {
            return TouchType::Finger;
        }
        else if (find(_UnknownTouches.begin(), _UnknownTouches.end(), touch) != _UnknownTouches.end())
        {
            return TouchType::Unknown;
        }
        else
        {
            return TouchType::NotFound;
        }
    }
    
    void FireTouchTypeChangedEvent(const Touch::cPtr & touch)
    {
        TouchType type = GetTouchType(touch);
        std::string typeName;
        if (type == TouchType::Unknown)
        {
            typeName = "UNKNOWN";
        }
        else if (type == TouchType::Pen)
        {
            typeName = "PEN";
        }
        else if (type == TouchType::Finger)
        {
            typeName = "FINGER";
        }
        
        std::cout << "Touch type changed, id = " << touch->Id() << " type = " << typeName << std::endl;
        
        _TouchTypeChangedEvent.Fire(touch);
    }
    
    Event<const Touch::cPtr &> & TouchTypeChanged()
    {
        return _TouchTypeChangedEvent;
    }

    FT_NO_COPY(LatencyTouchClassifierImpl);
};

LatencyTouchClassifier::Ptr LatencyTouchClassifier::New()
{
    return boost::make_shared<LatencyTouchClassifierImpl>();
}
