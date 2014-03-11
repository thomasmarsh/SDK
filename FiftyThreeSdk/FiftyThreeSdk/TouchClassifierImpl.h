//
//  TouchClassifierImpl.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <boost/optional.hpp>
#include <vector>

#include "Core/Enum.h"
#include "Core/Event.hpp"
#include "Core/Memory.h"
#include "Core/Touch/Touch.h"
#include "FiftyThreeSdk/Classification/Classifier.h"
#include "FiftyThreeSdk/TouchClassifier.h"

namespace fiftythree
{
namespace sdk
{
// This contains some common functionality.
class TouchClassifierImpl : virtual public TouchClassifier
{
public:
    TouchClassifierImpl();
    virtual bool IsPenConnected();
    virtual void SetPenConnected(bool connected);
    virtual bool IsPenOrEraserSwitchDown();
    virtual void PenStateDidChanged(const PenEventArgs & args);
    virtual void TouchesDidChanged(const std::set<core::Touch::cPtr> & touches);
    virtual void RemoveTouchFromClassification(const core::Touch::cPtr & touch);
    virtual core::TouchClassification ClassifyPair(const core::Touch::cPtr & t0,
                                                   const core::Touch::cPtr & t1,
                                                   const TwoTouchPairType & type);

    virtual core::TouchClassification ClassifyForSingleTouchGestureType(const core::Touch::cPtr & touch, const SingleTouchGestureType & type);
    virtual Eigen::VectorXf GeometricStatistics(const core::Touch::cPtr & t0);
    virtual bool AreAnyTouchesCurrentlyPenOrEraser();
    virtual bool HasPenActivityOccurredRecently();
    virtual void UpdateClassifications();
    virtual Event<const std::vector<TouchClassificationChangedEventArgs> & > & TouchClassificationsDidChange();
    virtual void ClearSessionStatistics();
    virtual SessionStatistics::Ptr SessionStatistics();

protected:
    // Call this to get at the Classification parameters.
    Classifier::Ptr Classifier();

    // The following two methods let you customize the dispatch of classification events to
    // override the classifier. You might want to do this if you're supporting another stylus e.g., PogoConnect.

    // Default implementation returns false
    virtual bool ShouldOverrideClassifications();

    virtual boost::optional<core::TouchClassification> OverrideClassificationForTouch(const core::Touch::cPtr & touch);

    void SetCopyGestureClassifications(bool b);
private:
    Classifier::Ptr _Classifier;
    bool _ShowLog;
    bool _Connected;
    bool _CopyGestureClassifications;
    Event<const std::vector<TouchClassificationChangedEventArgs> &> _TouchClassificationsDidChange;
};

}
}
