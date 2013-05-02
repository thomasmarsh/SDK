//
//  TouchClassifierManager.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#include "TouchClassifierManager.h"
#include "LatencyTouchClassifier.h"

#include <boost/foreach.hpp>
#include <boost/shared_ptr.hpp>
#include <vector>
#include <set>
#include "Common/PenManager.h"
#include "Common/TouchManager.h"
#include "Common/Asserts.h"

#include "TouchClassifier.h"

using namespace fiftythree::sdk;
using namespace fiftythree::common;

class TouchClassifierManagerImpl : public TouchClassifierManager, public boost::enable_shared_from_this<TouchClassifierManagerImpl>
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
        BOOST_FOREACH(const TouchClassifier::Ptr & classifier, _Classifiers)
        {
            classifier->TouchesBegan(touches);
        }
    }

    virtual void TouchesMoved(const fiftythree::common::TouchesSet & touches)
    {
        BOOST_FOREACH(const TouchClassifier::Ptr & classifier, _Classifiers)
        {
            classifier->TouchesMoved(touches);
        }
    }

    virtual void TouchesEnded(const fiftythree::common::TouchesSet & touches)
    {
        BOOST_FOREACH(const TouchClassifier::Ptr & classifier, _Classifiers)
        {
            classifier->TouchesEnded(touches);
        }
    }

    virtual void TouchesCancelled(const fiftythree::common::TouchesSet & touches)
    {
        BOOST_FOREACH(const TouchClassifier::Ptr & classifier, _Classifiers)
        {
            classifier->TouchesCancelled(touches);
        }
    }

    virtual void ProcessPenEvent(const PenEvent::Ptr & event)
    {
        BOOST_FOREACH(const TouchClassifier::Ptr & classifier, _Classifiers)
        {
            if (classifier->HandlesPenInput())
            {
                classifier->ProcessPenEvent(event);
            }
        }
    }
    
    virtual TouchType GetTouchType(const fiftythree::common::Touch::cPtr & touch)
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
    return boost::make_shared<TouchClassifierManagerImpl>();
}