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

const double MAX_DELAY_MSEC = 100.0;
const double MAX_DELAY_SEC = MAX_DELAY_MSEC / 1000;

template <class T>
void RemoveAll(std::vector<T> v, std::vector<T> removeVector)
{
    BOOST_FOREACH(const T & t, removeVector)
    {
        v.erase(std::remove(v.end(), v.begin(), t), v.end());
    }
}

template <class T>
void RemoveAll(std::vector<T> v, std::set<T> removeSet)
{
    BOOST_FOREACH(const T & t, removeSet)
    {
        v.erase(std::remove(v.end(), v.begin(), t), v.end());
    }
}


class LatencyTouchClassifierImpl : public LatencyTouchClassifier
{
private:
    double _PenDownTime;
    double _PenUpTime;

    PenEvent::cPtr _LastPenEvent;

    std::vector<Touch::cPtr> _UnknownTouches;
    std::vector<Touch::cPtr> _FingerTouches;
    Touch::cPtr _PenTouch;

    Event<const Touch::cPtr &> _TouchTypeChangedEvent;
    
private:
    bool IsPenDown()
    {
        return _LastPenEvent && _LastPenEvent->Type == PenEventType::PenDown;
    }

public:
    LatencyTouchClassifierImpl()
    :
    _PenDownTime(0),
    _PenUpTime(0)
    {};

    virtual bool HandlesPenInput()
    {
        return true;
    }

    virtual void TouchesBegan(const fiftythree::common::TouchesSet & touches)
    {
        //std::cout << "Touch, id = " << touch->Id() << std::endl;
        
        if (!_PenTouch && IsPenDown())
        {
            double min_delta = std::numeric_limits<double>::max();
            
            BOOST_FOREACH(const Touch::cPtr & touch, touches)
            {
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
            _LastPenEvent.reset();
            
            _UnknownTouches.assign(touches.begin(), touches.end());
        }
    }

    virtual void TouchesMoved(const fiftythree::common::TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            if (GetTouchType(touch) != TouchType::Unknown) continue;
            
            double delta = std::abs(touch->CurrentSample().TimestampSeconds() - touch->FirstSample().TimestampSeconds());
            std::cout << "Moved delta = " << delta << std::endl;
            if (delta > MAX_DELAY_SEC)
            {
                std::cout << "Touch expired, id = " << touch->Id() << std::endl;

                _UnknownTouches.erase(std::remove(_UnknownTouches.end(), _UnknownTouches.begin(), touch), _UnknownTouches.end());
                _FingerTouches.push_back(touch);
                
                FireTouchTypeChangedEvent(touch);
            }
        }
    }

    virtual void TouchesEnded(const fiftythree::common::TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            if (_PenTouch == touch)
            {
                _PenTouch.reset();
                continue;
            }
            
            if (GetTouchType(touch) != TouchType::Unknown) continue;
            
            _UnknownTouches.erase(std::remove(_UnknownTouches.end(), _UnknownTouches.begin(), touch), _UnknownTouches.end());
            
            // No pen event occured during the stroke, so it's a finger
            if (!_LastPenEvent)
            {
                _FingerTouches.push_back(touch);
                FireTouchTypeChangedEvent(touch);
            }

            _FingerTouches.erase(std::remove(_FingerTouches.end(), _FingerTouches.begin(), touch), _FingerTouches.end());
        }
    }

    virtual void TouchesCancelled(const fiftythree::common::TouchesSet & touches)
    {
        TouchesEnded(touches);
    }

    virtual void ProcessPenEvent(const PenEvent::Ptr & event)
    {
        _LastPenEvent = event;
        
        std::cout << "PenEvent" << std::endl;

        if (!_PenTouch && IsPenDown() && _UnknownTouches.size())
        {
            BOOST_FOREACH(const Touch::cPtr & touch, _UnknownTouches)
            {
                double delta = std::abs(_LastPenEvent->Sample.TimestampSeconds() - touch->FirstSample().TimestampSeconds());
                std::cout << "Pen after Touch, id = " << touch->Id() << " delta= " << delta << std::endl;

                _UnknownTouches.erase(std::remove(_UnknownTouches.end(), _UnknownTouches.begin(), touch), _UnknownTouches.end());
                
                if (delta < MAX_DELAY_SEC)
                {
                    std::cout << "Pen is Touch, id = " << touch->Id() << std::endl;

                    _PenTouch = touch;
                    FireTouchTypeChangedEvent(touch);
                }
                else
                {
                    std::cout << "Pen was down but time delta was " << delta << std::endl;
                    _FingerTouches.push_back(touch);
                }
            }
        }
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
        else
        {
            //DebugAssert(find(_UnknownTouches.begin(), _UnknownTouches.end(), touch) != _UnknownTouches.end());
            return TouchType::Unknown;
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
