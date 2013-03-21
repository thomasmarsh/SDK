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
#include "LatencyTouchClassifier.h"

using namespace fiftythree::sdk;
using namespace fiftythree::common;

class TouchClassifierManagerImpl : public TouchClassifierManager
{
private:
    std::vector<TouchClassifier::Ptr> _Classifiers;

public:
    TouchClassifierManagerImpl()
    {
        _Classifiers.push_back(LatencyTouchClassifier::New());

        DebugAssert(_Classifiers.size());
    };

    virtual bool HandlesPenInput()
    {
        return true;
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
            classifier->TouchesEnded(touches);
        }
    }

    virtual void TouchesEnded(const fiftythree::common::TouchesSet & touches)
    {
        BOOST_FOREACH(const TouchClassifier::Ptr & classifier, _Classifiers)
        {
            classifier->TouchesMoved(touches);
        }
    }

    virtual void TouchesCancelled(const fiftythree::common::TouchesSet & touches)
    {
        BOOST_FOREACH(const TouchClassifier::Ptr & classifier, _Classifiers)
        {
            classifier->TouchesCancelled(touches);
        }
    }

    virtual void ProcessPenEvent(const PenEvent & event)
    {
        BOOST_FOREACH(const TouchClassifier::Ptr & classifier, _Classifiers)
        {
            classifier->ProcessPenEvent(event);
        }
    }

    FT_NO_COPY(TouchClassifierManagerImpl);
};

TouchClassifierManager::Ptr TouchClassifierManager::New()
{
    return boost::make_shared<TouchClassifierManagerImpl>();
}