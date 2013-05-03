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
    PenEvent::cPtr _LastPenEvent;

    std::vector<Touch::cPtr> _UnknownTouches;
    std::vector<Touch::cPtr> _FingerTouches;
    Touch::cPtr _PenTouch;
    long _TouchCount;

    Event<const Touch::cPtr &> _TouchTypeChangedEvent;
    
private:
    bool IsPenDown()
    {
        return _LastPenEvent->Type == PenEventType::PenDown;
    }

public:
    LatencyTouchClassifierImpl()
    :
    _TouchCount(0)
    {
        // Dummy so we don't need to check for null
        _LastPenEvent = PenEvent::New(0, PenEventType::PenUp, PenTip::Tip1);
    };

    virtual bool HandlesPenInput()
    {
        return true;
    }
    
    long CountTouches()
    {
        return _UnknownTouches.size() + _FingerTouches.size() + (!!_PenTouch ? 1 : 0);
    }

    virtual void TouchesBegan(const fiftythree::common::TouchesSet & touches)
    {
        DebugAssert(CountTouches() == _TouchCount);
        
        if (!_PenTouch && IsPenDown())
        {
            double min_delta = std::numeric_limits<double>::max();
            
            BOOST_FOREACH(const Touch::cPtr & touch, touches)
            {
                std::cout << "Touch BEGAN, id = " << touch->Id() << std::endl;
                
                double delta = std::abs(_LastPenEvent->Sample.TimestampSeconds() - touch->FirstSample().TimestampSeconds());
                std::cout << "Touch after Pen, id = " << touch->Id() << " delta = " << delta << std::endl;
                if (delta < MAX_DELAY_SEC)
                {
                    if (delta < min_delta)
                    {
                        std::cout << "Touch is pen!" << std::endl;
                    
                        min_delta = delta;
                        if (_PenTouch)
                        {
                            _UnknownTouches.push_back(_PenTouch);
                        }
                        
                        _PenTouch = touch;
                    }
                    else
                    {
                        _UnknownTouches.push_back(touch);
                    }
                }
                else
                {
                    std::cout << "Pen was down but time delta was " << delta << std::endl;

                    _FingerTouches.push_back(touch);
                }
            }
        }
        else
        {
            BOOST_FOREACH(const Touch::cPtr & touch, touches)
            {
                std::cout << "Touch BEGAN, id = " << touch->Id() << std::endl;
                
                _UnknownTouches.push_back(touch);
            }
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
            //std::cout << "Moved id = " << touch->Id() << " delta = " << delta << std::endl;
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
                DebugAssert(find(_FingerTouches.begin(), _FingerTouches.end(), touch) != _FingerTouches.end());
                _FingerTouches.erase(std::remove(_FingerTouches.begin(), _FingerTouches.end(), touch), _FingerTouches.end());
            }
            else if (type == TouchType::Unknown)
            {
                DebugAssert(find(_UnknownTouches.begin(), _UnknownTouches.end(), touch) != _UnknownTouches.end());
                _UnknownTouches.erase(std::remove(_UnknownTouches.begin(), _UnknownTouches.end(), touch), _UnknownTouches.end());
                
                // No pen event occured during the stroke, so it's a finger
                if (_LastPenEvent->Sample.TimestampSeconds() < touch->FirstSample().TimestampSeconds() - MAX_DELAY_SEC)
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

        _LastPenEvent = event;
        
        std::cout << "PenEvent: " << event->ToString() << std::endl;

        if (!_PenTouch && IsPenDown())
        {
            std::vector<Touch::cPtr>::iterator it = _UnknownTouches.begin();
            while (it != _UnknownTouches.end())
            {
                const Touch::cPtr & touch = *it;
                
                double delta = std::abs(_LastPenEvent->Sample.TimestampSeconds() - touch->FirstSample().TimestampSeconds());
                std::cout << "Pen after Touch, id = " << touch->Id() << " delta= " << delta << std::endl;
                
                if (delta < MAX_DELAY_SEC)
                {
                    std::cout << "Pen is Touch, id = " << touch->Id() << std::endl;
                    if (_PenTouch)
                    {
                        _FingerTouches.push_back(_PenTouch);
                    }

                    _PenTouch = touch;
                    FireTouchTypeChangedEvent(touch);
                }
                else
                {
                    std::cout << "Pen was down but time delta was " << delta << std::endl;
                    _FingerTouches.push_back(touch);
                }
                
                it = _UnknownTouches.erase(it);
            }
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
