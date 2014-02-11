//
//  TouchClassifierManager.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include <set>
#include <vector>

#include "Common/Asserts.h"
#include "Common/Memory.h"
#include "Common/Touch/TouchManager.h"
#include "LatencyTouchClassifier.h"
#include "TouchClassifier.h"
#include "TouchClassifierManager.h"

using namespace fiftythree::common;
using namespace fiftythree::sdk;

class TouchClassifierManagerImpl : public TouchClassifierManager, public fiftythree::common::enable_shared_from_this<TouchClassifierManagerImpl>
{
private:
    std::vector<TouchClassifier::Ptr> _Classifiers;
    Event<const Touch::cPtr &> _TouchTypeChangedEvent;

public:
    TouchClassifierManagerImpl() {}

    virtual bool HandlesPenInput()
    {
        return true;
    }

    virtual void AddClassifier(TouchClassifier::Ptr classifier)
    {
        classifier->TouchTypeChanged().AddListener(shared_from_this(), &TouchClassifierManagerImpl::HandleTouchTypeChanged);
        _Classifiers.push_back(classifier);
    }

    virtual void RemoveClassifier(TouchClassifier::Ptr classifier)
    {
        _Classifiers.erase(std::remove(_Classifiers.begin(), _Classifiers.end(), classifier), _Classifiers.end());
    }

    virtual void TouchesBegan(const fiftythree::common::TouchesSet & touches)
    {
        for (const TouchClassifier::Ptr & classifier : _Classifiers)
        {
            classifier->TouchesBegan(touches);
        }
    }

    virtual void TouchesMoved(const fiftythree::common::TouchesSet & touches)
    {
        for (const TouchClassifier::Ptr & classifier : _Classifiers)
        {
            classifier->TouchesMoved(touches);
        }
    }

    virtual void TouchesEnded(const fiftythree::common::TouchesSet & touches)
    {
        for (const TouchClassifier::Ptr & classifier : _Classifiers)
        {
            classifier->TouchesEnded(touches);
        }
    }

    virtual void TouchesCancelled(const fiftythree::common::TouchesSet & touches)
    {
        for (const TouchClassifier::Ptr & classifier : _Classifiers)
        {
            classifier->TouchesCancelled(touches);
        }
    }

    virtual void ProcessPenEvent(const PenEvent::Ptr & event)
    {
        for (const TouchClassifier::Ptr & classifier : _Classifiers)
        {
            if (classifier->HandlesPenInput())
            {
                classifier->ProcessPenEvent(event);
            }
        }
    }

    virtual FTTouchType GetTouchType(const fiftythree::common::Touch::cPtr & touch)
    {
        return _Classifiers[0]->GetTouchType(touch); // BUGBUG - figure out how to combine
    }

    Event<const Touch::cPtr &> & TouchTypeChanged()
    {
        return _TouchTypeChangedEvent;
    }

    void HandleTouchTypeChanged(const Event<const Touch::cPtr &> & event, const Touch::cPtr & touch)
    {
        _TouchTypeChangedEvent.Fire(touch);
    }

    FT_NO_COPY(TouchClassifierManagerImpl);
};

TouchClassifierManager::Ptr TouchClassifierManager::New()
{
    return fiftythree::common::make_shared<TouchClassifierManagerImpl>();
}
