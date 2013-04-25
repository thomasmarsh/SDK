//
//  FTPenAndTouchManager.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#include "FTPenAndTouchManager.h"

#include <boost/smart_ptr.hpp>
#include <boost/foreach.hpp>
#include <boost/unordered_map.hpp>

#include "Common/NoCopy.h"
#include "Common/TouchManager.h"
#include "Common/PenManager.h"
#include "Common/Mathiness.h"
#include "Common/DispatchTimer.h"

#include "TouchClassifierManager.h"
#include "LatencyTouchClassifier.h"
#include "FTTouchEventLogger.h"

using namespace fiftythree::sdk;
using namespace fiftythree::common;
using std::make_pair;
using std::pair;
using namespace boost;

typedef unordered_map<Touch::cPtr, TouchType> TouchToTypeMap;

class FTPenAndTouchManagerImpl : public FTPenAndTouchManager, public boost::enable_shared_from_this<FTPenAndTouchManagerImpl>
{
private:
    TouchClassifierManager::Ptr _ClassifierManager;
    FTTouchEventLogger::Ptr _Logger;
    TouchToTypeMap _Touches;
    Event<Touch::cPtr> _TouchTypeChangedEvent;
    Event<Unit> _ShouldStartTrialSeparation;
    DispatchTimer::Ptr _TrialSeparationTimer;

public:
    FTPenAndTouchManagerImpl()
    {
        _ClassifierManager = TouchClassifierManager::New();
        _ClassifierManager->AddClassifier(LatencyTouchClassifier::New());
        
        _TrialSeparationTimer = DispatchTimer::New();
        _TrialSeparationTimer->New();
        _TrialSeparationTimer->SetCallback(bind(&FTPenAndTouchManagerImpl::TrialSeparationTimerExpired, this));
    }

    ~FTPenAndTouchManagerImpl()
    {
    }

    void RegisterForEvents()
    {
        TouchManager::Instance()->TouchesBegan().AddListener(shared_from_this(), &FTPenAndTouchManagerImpl::TouchesBegan);
        TouchManager::Instance()->TouchesMoved().AddListener(shared_from_this(), &FTPenAndTouchManagerImpl::TouchesMoved);
        TouchManager::Instance()->TouchesEnded().AddListener(shared_from_this(), &FTPenAndTouchManagerImpl::TouchesEnded);
        TouchManager::Instance()->TouchesCancelled().AddListener(shared_from_this(), &FTPenAndTouchManagerImpl::TouchesCancelled);
    }

    void UnregisterForEvents()
    {
        TouchManager::Instance()->TouchesBegan().RemoveListener(shared_from_this());
        TouchManager::Instance()->TouchesMoved().RemoveListener(shared_from_this());
        TouchManager::Instance()->TouchesEnded().RemoveListener(shared_from_this());
        TouchManager::Instance()->TouchesCancelled().RemoveListener(shared_from_this());
    }

    void SetLogger(FTTouchEventLogger::Ptr logger)
    {
        _Logger = logger;
    }

    void TouchesBegan(const TouchesSetEvent & sender, const TouchesSet & touches)
    {
        StopTimer(_TrialSeparationTimer);
        
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            _Touches[touch] = TouchType::Unknown;
        }

        if (_Logger) _Logger->TouchesBegan(touches);

        _ClassifierManager->TouchesBegan(touches);
    }

    void TouchesMoved(const TouchesSetEvent & sender, const TouchesSet & touches)
    {
        if (_Logger) _Logger->TouchesMoved(touches);

        _ClassifierManager->TouchesMoved(touches);
    }

    void TouchesEnded(const TouchesSetEvent & sender, const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            _Touches.erase(touch);
        }

        if (_Logger) _Logger->TouchesEnded(touches);

        _ClassifierManager->TouchesEnded(touches);
    }

    void TouchesCancelled(const TouchesSetEvent & sender, const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            _Touches.erase(touch);
        }

        if (_Logger) _Logger->TouchesCancelled(touches);

        _ClassifierManager->TouchesCancelled(touches);
    }

    virtual void HandlePenEvent(const PenEvent & event)
    {
        // Consider trial separation
        if (event.Tip == PenTip::Tip1)
        {
            if (_Touches.size() == 0
                && event.Type == PenEventType::PenDown)
            {
                StopTimer(_TrialSeparationTimer);
                _TrialSeparationTimer->Start(1.0);
            }
            else if (event.Type == PenEventType::PenUp)
            {
                StopTimer(_TrialSeparationTimer);
            }
        }
        
        if (_Logger) _Logger->HandlePenEvent(event);

        _ClassifierManager->ProcessPenEvent(event);
    }
    
    void StopTimer(const DispatchTimer::Ptr & timer)
    {
        if (timer->IsActive())
        {
            timer->Stop();
        }
    }

    virtual void Clear()
    {
        _Touches.clear();
        if (_Logger)
        {
            _Logger->Clear();
        }
    }

    virtual TouchType GetTouchType(const Touch::cPtr & touch)
    {
        return _Touches[touch];
    }

    Event<Touch::cPtr> & TouchTypeChanged()
    {
        return _TouchTypeChangedEvent;
    }
    
    Event<Unit> & ShouldStartTrialSeparation()
    {
        return _ShouldStartTrialSeparation;
    }
    
    void TrialSeparationTimerExpired(void)
    {
        _TrialSeparationTimer->Stop();
        _ShouldStartTrialSeparation.Fire(Unit());
    }

private:
    void SetTouchType(const Touch::cPtr & touch, TouchType type)
    {
        TouchType oldType = _Touches[touch];
        _Touches[touch] = type;
        if (oldType != type)
        {
            _TouchTypeChangedEvent.Fire(touch);
        }
    }

    FT_NO_COPY(FTPenAndTouchManagerImpl);
};

FTPenAndTouchManager::Ptr FTPenAndTouchManager::New()
{
    return boost::make_shared<FTPenAndTouchManagerImpl>();
}