//
//  FTPenAndTouchManager.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include <boost/unordered_map.hpp>

#include "Common/DispatchTimer.h"
#include "Common/Mathiness.h"
#include "Common/Memory.h"
#include "Common/NoCopy.h"
#include "Common/Touch/TouchTracker.h"
#include "FTPenAndTouchManager.h"
#include "FTTouchEventLogger.h"
#include "LatencyTouchClassifier.h"
#include "TouchClassifierManager.h"

using namespace fiftythree::common;
using namespace fiftythree::sdk;
using boost::unordered_map;
using std::make_pair;
using std::pair;

typedef unordered_map<Touch::cPtr, FTTouchType> TouchToTypeMap;

class FTPenAndTouchManagerImpl : public FTPenAndTouchManager, public fiftythree::common::enable_shared_from_this<FTPenAndTouchManagerImpl>
{
private:
    TouchClassifierManager::Ptr _ClassifierManager;
    FTTouchEventLogger::Ptr _Logger;
    TouchToTypeMap _Touches;
    Event<const Touch::cPtr &> _TouchTypeChangedEvent;
    Event<Unit> _ShouldStartTrialSeparation;
    DispatchTimer::Ptr _TrialSeparationTimer;
    bool _PalmRejectionEnabled;

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

    void SetPalmRejectionEnabled(bool enabled)
    {
        _PalmRejectionEnabled = enabled;
    }

    void RegisterForEvents()
    {
        _ClassifierManager->TouchTypeChanged().AddListener(shared_from_this(), &FTPenAndTouchManagerImpl::HandleTouchTypeChanged);

        TouchTracker::Instance()->TouchesBegan().AddListener(shared_from_this(), &FTPenAndTouchManagerImpl::TouchesBegan);
        TouchTracker::Instance()->TouchesMoved().AddListener(shared_from_this(), &FTPenAndTouchManagerImpl::TouchesMoved);
        TouchTracker::Instance()->TouchesEnded().AddListener(shared_from_this(), &FTPenAndTouchManagerImpl::TouchesEnded);
        TouchTracker::Instance()->TouchesCancelled().AddListener(shared_from_this(), &FTPenAndTouchManagerImpl::TouchesCancelled);
    }

    void UnregisterForEvents()
    {
        _ClassifierManager->TouchTypeChanged().RemoveListener(shared_from_this());

        TouchTracker::Instance()->TouchesBegan().RemoveListener(shared_from_this());
        TouchTracker::Instance()->TouchesMoved().RemoveListener(shared_from_this());
        TouchTracker::Instance()->TouchesEnded().RemoveListener(shared_from_this());
        TouchTracker::Instance()->TouchesCancelled().RemoveListener(shared_from_this());
    }

    void SetLogger(FTTouchEventLogger::Ptr logger)
    {
        _Logger = logger;
    }

    void TouchesBegan(const TouchesSetEvent & sender, const TouchesSet & touches)
    {
        StopTimer(_TrialSeparationTimer);

        for (const Touch::cPtr & touch : touches)
        {
            _Touches[touch] = FTTouchType::Unknown;
        }

        if (_Logger)
        {
            _Logger->TouchesBegan(touches);
        }

        if (_PalmRejectionEnabled)
        {
            _ClassifierManager->TouchesBegan(touches);
        }
    }

    void TouchesMoved(const TouchesSetEvent & sender, const TouchesSet & touches)
    {
        if (_Logger)
        {
            _Logger->TouchesMoved(touches);
        }

        if (_PalmRejectionEnabled)
        {
            _ClassifierManager->TouchesMoved(touches);
        }
    }

    void TouchesEnded(const TouchesSetEvent & sender, const TouchesSet & touches)
    {
        for (const Touch::cPtr & touch : touches)
        {
            _Touches.erase(touch);
        }

        if (_Logger) _Logger->TouchesEnded(touches);

        if (_PalmRejectionEnabled)
        {
            _ClassifierManager->TouchesEnded(touches);
        }
    }

    void TouchesCancelled(const TouchesSetEvent & sender, const TouchesSet & touches)
    {
        for (const Touch::cPtr & touch : touches)
        {
            _Touches.erase(touch);
        }

        if (_Logger) _Logger->TouchesCancelled(touches);

        if (_PalmRejectionEnabled)
        {
            _ClassifierManager->TouchesCancelled(touches);
        }
    }

    virtual void HandlePenEvent(const PenEvent::Ptr & event)
    {
        // Consider trial separation
        if (event->Tip == PenTip::Tip1)
        {
            if (_Touches.size() == 0
                && event->Type == PenEventType::PenDown)
            {
                StopTimer(_TrialSeparationTimer);
                _TrialSeparationTimer->Start(1.0);
            }
            else if (event->Type == PenEventType::PenUp)
            {
                StopTimer(_TrialSeparationTimer);
            }
        }

        if (_Logger) _Logger->HandlePenEvent(event);

        if (_PalmRejectionEnabled)
        {
            _ClassifierManager->ProcessPenEvent(event);
        }
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

    virtual FTTouchType GetTouchType(const Touch::cPtr & touch)
    {
        return _ClassifierManager->GetTouchType(touch);
    }

    Event<const Touch::cPtr &> & TouchTypeChanged()
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

    void HandleTouchTypeChanged(const Event<const Touch::cPtr &> & event, const Touch::cPtr & touch)
    {
        _TouchTypeChangedEvent.Fire(touch);
    }

    FT_NO_COPY(FTPenAndTouchManagerImpl);
};

FTPenAndTouchManager::Ptr FTPenAndTouchManager::New()
{
    return fiftythree::common::make_shared<FTPenAndTouchManagerImpl>();
}
