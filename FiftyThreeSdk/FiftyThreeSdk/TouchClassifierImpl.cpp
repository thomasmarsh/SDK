//
//  TouchClassifierImpl.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//
#include <ios>
#include <vector>

#include "Common/Touch/PenManager.h"
#include "Core/Touch/Touch.h"
#include "Core/Touch/TouchTracker.h"
#include "FiftyThreeSdk/Classification//Classifier.h"
#include "FiftyThreeSdk/TouchClassifierImpl.h"

using namespace fiftythree::common;
using namespace fiftythree::core;
using namespace fiftythree::sdk;
using fiftythree::core::make_shared;
using std::cout;
using std::vector;

typedef fiftythree::sdk::Classifier Classifier;
using fiftythree::core::const_pointer_cast;

namespace fiftythree
{
namespace sdk
{
TouchClassifierImpl::TouchClassifierImpl() : _Classifier(Classifier::New()), _Connected(false), _ShowLog(false)
{
    _Classifier->SetUsePrivateAPI(false);
    _Classifier->SetUseDebugLogging(_ShowLog);
}

void TouchClassifierImpl::TouchesDidChanged(const std::set<Touch::cPtr> & touches)
{
    std::set<Touch::Ptr> nonConstTouches;
    for (const Touch::cPtr & t : touches)
    {
        nonConstTouches.insert(const_pointer_cast<Touch>(t));
    }
    _Classifier->OnTouchesChanged(nonConstTouches);
}

void TouchClassifierImpl::ClearSessionStatistics()
{
    _Classifier->ClearSessionStatistics();
}

SessionStatistics::Ptr TouchClassifierImpl::SessionStatistics()
{
    return _Classifier->SessionStatistics();
}

bool TouchClassifierImpl::IsPenConnected()
{
    return _Connected;
}

void TouchClassifierImpl::SetPenConnected(bool connected)
{
    if (connected)
    {
        _Classifier->StylusConnected();
    }
    else
    {
        _Classifier->StylusDisconnected();
    }
    _Connected = connected;
}

bool TouchClassifierImpl::IsPenOrEraserSwitchDown()
{
    return _Classifier->IsAnySwitchDown();
}

void TouchClassifierImpl::PenStateDidChanged(const PenEventArgs & args)
{
    fiftythree::sdk::PenEvent event;
    event._timestamp = args.Timestamp;
    event._type = args.Type;
    _Classifier->OnPenEvent(event);
}

void TouchClassifierImpl::RemoveTouchFromClassification(const Touch::cPtr & touch)
{
    _Classifier->RemoveTouchFromClassification(touch->Id());
    UpdateClassifications();
}

TouchClassification TouchClassifierImpl::ClassifyPair(const Touch::cPtr & t0, const Touch::cPtr & t1, const TwoTouchPairType & type)
{
    DebugAssert(t0);
    DebugAssert(t1);

    return _Classifier->ClassifyPair(t0->Id(), t1->Id(), type);
}

TouchClassification TouchClassifierImpl::ClassifyForSingleTouchGestureType(const Touch::cPtr & touch, const SingleTouchGestureType & type)
{
    return _Classifier->ClassifyForGesture(touch->Id(), type);
}

bool TouchClassifierImpl::AreAnyTouchesCurrentlyPenOrEraser()
{
    return _Classifier->AreAnyTouchesCurrentlyPenOrEraser();
}

bool TouchClassifierImpl::HasPenActivityOccurredRecently()
{
    return _Classifier->HasPenActivityOccurredRecently();
}

void TouchClassifierImpl::UpdateClassifications()
{
    _Classifier->ClearTouchesReclassified();
    _Classifier->ReclassifyIfNeeded();

    vector<TouchClassificationChangedEventArgs> eventArgs;
    vector<TouchClassificationChangedEventArgs> allChangedEventArgs;

    // OK now we need to get the data back out and onto the touch objects
    for (const Touch::cPtr & touch : TouchTracker::Instance()->RecentTouches())
    {
        TouchClassificationChangedEventArgs args;
        args.touch = touch;
        args.oldValue = touch->CurrentClassification()();

        bool shouldOverride = ShouldOverrideClassifications();
        if (shouldOverride)
        {
            boost::optional<TouchClassification> touchClassification = OverrideClassificationForTouch(touch);
            args.newValue = touchClassification ? *touchClassification : args.oldValue;

            *const_cast<Property<TouchClassification> *>(&touch->SingleTapClassification()) = args.newValue;
            *const_cast<Property<TouchClassification> *>(&touch->LongPressClassification()) = args.newValue;
        }
        else
        {
            *const_cast<Property<TouchClassification> *>(&touch->SingleTapClassification()) = _Classifier->ClassifyForGesture(touch->Id(), fiftythree::sdk::SingleTouchGestureType::Tap);
            *const_cast<Property<TouchClassification> *>(&touch->LongPressClassification()) = _Classifier->ClassifyForGesture(touch->Id(), fiftythree::sdk::SingleTouchGestureType::LongPress);

            args.newValue = _Classifier->Classify(touch->Id());
        }

        // The classifier let's us know if it stops tracking a touch. Don't expose this to the client
        // code -- it should just retain the last classification.
        bool shouldExposeClassification = (args.newValue != TouchClassification::UntrackedTouch);
        if (shouldExposeClassification)
        {
            *const_cast<Property<TouchClassification> *>(&touch->CurrentClassification()) = args.newValue;
        }

        if (args.oldValue != args.newValue)
        {
            if (shouldExposeClassification)
            {
                eventArgs.push_back(args);
            }
            allChangedEventArgs.push_back(args);
        }
    }

    if (!eventArgs.empty())
    {
        if (_ShowLog)
        {
            cout << "Reclassification (#:" << allChangedEventArgs.size() << ")" << std::endl;
            for (const auto & e : eventArgs)
            {
                cout << " id: " << e.touch->Id() << " was: " << ToString(e.oldValue) << " now: " << ToString(e.newValue) << std::endl;
            }
        }
        TouchClassificationsDidChange().Fire(eventArgs);
    }

    if (!allChangedEventArgs.empty())
    {
        if (_ShowLog)
        {
            cout << "ALL Reclassification (#:" << allChangedEventArgs.size() << ")" << std::endl;
            for (const auto & e : eventArgs)
            {
                cout << " id: " << e.touch->Id() << " was: " << ToString(e.oldValue) << " now: " << ToString(e.newValue) << std::endl;
            }
        }
    }
}

Classifier::Ptr TouchClassifierImpl::Classifier()
{
    return _Classifier;
}

bool TouchClassifierImpl::ShouldOverrideClassifications()
{
    return false;
}

boost::optional<TouchClassification> TouchClassifierImpl::OverrideClassificationForTouch(const Touch::cPtr & touch)
{
    return boost::none;
}

Eigen::VectorXf TouchClassifierImpl::GeometricStatistics(const Touch::cPtr & t0)
{
    return _Classifier->GeometricStatistics(t0->Id());
}

Event<const vector<TouchClassificationChangedEventArgs> &> & TouchClassifierImpl::TouchClassificationsDidChange()
{
    return _TouchClassificationsDidChange;
}
TouchClassifier::Ptr TouchClassifier::New()
{
    return make_shared<TouchClassifierImpl>();
}
}
}
