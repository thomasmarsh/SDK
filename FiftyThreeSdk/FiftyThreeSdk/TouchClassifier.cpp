//
//  TouchClassifier.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include <ios>

#include "Core/Touch/Touch.h"
#include "Core/Touch/TouchTracker.h"
#include "FiftyThreeSdk/TouchClassifier.h"
#include "FiftyThreeSdk/Classification//Classifier.h"

typedef fiftythree::sdk::Classifier Classifier;
using std::vector;
using std::cout;
using namespace fiftythree::sdk;
using namespace fiftythree::core;

namespace
{
class TouchClassifierImpl
    :
    public fiftythree::sdk::TouchClassifier
{

public:

    TouchClassifierImpl() : _classifier(Classifier::New()), _connected(false), _showLog(false)
    {
        _classifier->SetUsePrivateAPI(false);
        _classifier->SetUseDebugLogging(_showLog);
    }

    void TouchesDidChanged(const std::set<Touch::cPtr> & touches)
    {
        std::set<Touch::Ptr> nonConstTouches;
        for (const Touch::cPtr & t : touches)
        {
            nonConstTouches.insert(const_pointer_cast<Touch>(t));
        }
        _classifier->OnTouchesChanged(nonConstTouches);
    }

    void ClearSessionStatistics()
    {
        _classifier->ClearSessionStatistics();
    }

    SessionStatistics::Ptr SessionStatistics()
    {
        return _classifier->SessionStatistics();
    }

    bool IsPenConnected()
    {
        return _connected;
    }

    void SetPenConnected(bool connected)
    {
        if (connected)
        {
            _classifier->StylusConnected();
        }
        else
        {
            _classifier->StylusDisconnected();
        }
        _connected = connected;
    }

    bool IsPenOrEraserSwitchDown()
    {
        return _classifier->IsAnySwitchDown();
    }

    void PenStateDidChanged(const PenEventArgs & args)
    {
        fiftythree::sdk::PenEvent event;
        event._timestamp = args.Timestamp;
        event._type = args.Type;
        _classifier->OnPenEvent(event);
    }

    void RemoveTouchFromClassification(const Touch::cPtr & touch)
    {
        _classifier->RemoveTouchFromClassification(touch->Id());
        UpdateClassifications();
    }

    TouchClassification ClassifyPair(const Touch::cPtr & t0, const Touch::cPtr & t1, const TwoTouchPairType & type)
    {
        DebugAssert(t0);
        DebugAssert(t1);

        return _classifier->ClassifyPair(t0->Id(), t1->Id(), type);
    }

    TouchClassification ClassifyForSingleTouchGestureType(const Touch::cPtr & touch, const SingleTouchGestureType & type)
    {
        return _classifier->ClassifyForGesture(touch->Id(), type);
    }

    bool AreAnyTouchesCurrentlyPenOrEraser()
    {
        return _classifier->AreAnyTouchesCurrentlyPenOrEraser();
    }

    bool HasPenActivityOccurredRecently()
    {
        return _classifier->HasPenActivityOccurredRecently();
    }

    void UpdateClassifications()
    {
        _classifier->ClearTouchesReclassified();
        _classifier->ReclassifyIfNeeded();

        vector<TouchClassificationChangedEventArgs> eventArgs;
        vector<TouchClassificationChangedEventArgs> allChangedEventArgs;

        // OK now we need to get the data back out and onto the touch objects
        for (const Touch::cPtr & touch : TouchTracker::Instance()->RecentTouches())
        {
            TouchClassificationChangedEventArgs args;
            args.touch = touch;
            args.oldValue = touch->CurrentClassification();

            *const_cast<Property<TouchClassification> *>(&touch->SingleTapClassification()) = _classifier->ClassifyForGesture(touch->Id(), fiftythree::sdk::SingleTouchGestureType::Tap);
            *const_cast<Property<TouchClassification> *>(&touch->LongPressClassification()) = _classifier->ClassifyForGesture(touch->Id(), fiftythree::sdk::SingleTouchGestureType::LongPress);

            args.newValue = _classifier->Classify(touch->Id());

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
            if (_showLog)
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
            if (_showLog)
            {
                cout << "ALL Reclassification (#:" << allChangedEventArgs.size() << ")" << std::endl;
                for (const auto & e : eventArgs)
                {
                    cout << " id: " << e.touch->Id() << " was: " << ToString(e.oldValue) << " now: " << ToString(e.newValue) << std::endl;
                }
            }
        }
    }

    Eigen::VectorXf GeometricStatistics(const Touch::cPtr & t0)
    {
        return _classifier->GeometricStatistics(t0->Id());
    }

    Event<const vector<TouchClassificationChangedEventArgs> &> & TouchClassificationsDidChange()
    {
        return _TouchClassificationsDidChange;
    }

    FT_NO_COPY(TouchClassifierImpl)

private:
    Classifier::Ptr _classifier;
    bool _showLog;
    bool _connected;
    Event<const vector<TouchClassificationChangedEventArgs> &> _TouchClassificationsDidChange;
};
}

namespace fiftythree
{
namespace sdk
{
TouchClassifier::Ptr TouchClassifier::New()
{
    return make_shared<TouchClassifierImpl>();
}

TouchClassifier::Ptr ActiveClassifier::_Instance = TouchClassifier::Ptr();

void ActiveClassifier::Activate(const TouchClassifier::Ptr & classifier)
{
    _Instance = classifier;
}

TouchClassifier::Ptr ActiveClassifier::Instance()
{
    return _Instance;
}
}
}
