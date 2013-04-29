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
    std::vector<Touch::cPtr> _PenTouches;
    std::vector<Touch::cPtr> _FingerTouches;

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

            _PenDownTime = event.Sample.TimestampSeconds();
            _PenUpTime = 0;

            std::vector<Touch::cPtr>::iterator it = _CandidateTouches.begin();
            for (;it != _CandidateTouches.end();)
            {
                const Touch::cPtr & touch = *it;
                double timeDelta = event.Sample.TimestampSeconds() - touch->CurrentSample().TimestampSeconds();

                if (timeDelta > MAX_DELAY_SEC)
                {
                    std::cout << "Remove touch #" << it - _CandidateTouches.begin() << std::endl;
                    _FingerTouches.push_back(*it);
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
            std::cout << "PenUp" << std::endl;

            _PenUpTime = event.Sample.TimestampSeconds();

            std::vector<Touch::cPtr>::iterator it = _CandidateTouches.begin();
            for (;it != _CandidateTouches.end();)
            {
                const Touch::cPtr & touch = *it;
                double timeDelta = event.Sample.TimestampSeconds() - touch->History()->back().TimestampSeconds(); // Measure from end-phase touch

                if (!touch->HasEndedOrCancelledInView || timeDelta > MAX_DELAY_SEC)
                {
                    std::cout << "Remove touch #" << it - _CandidateTouches.begin() << std::endl;
                    _FingerTouches.push_back(*it);
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
    
    virtual TouchType GetTouchType(const fiftythree::common::Touch::cPtr & touch)
    {
        if (find(_PenTouches.begin(), _PenTouches.end(), touch) != _PenTouches.end())
        {
            return TouchType::Pen;
        }
        else if (find(_FingerTouches.begin(), _FingerTouches.end(), touch) != _FingerTouches.end())
        {
            return TouchType::Finger;
        }
        else
        {
            return TouchType::Unknown;
        }
    }

    FT_NO_COPY(LatencyTouchClassifierImpl);
};

LatencyTouchClassifier::Ptr LatencyTouchClassifier::New()
{
    return boost::make_shared<LatencyTouchClassifierImpl>();
}
