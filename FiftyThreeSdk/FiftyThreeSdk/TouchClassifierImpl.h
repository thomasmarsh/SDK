//
//  TouchClassifierImpl.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <boost/optional.hpp>
#include <vector>

#include "Common/Enum.h"
#include "Common/Event.hpp"
#include "Common/Memory.h"
#include "Common/Touch/Touch.h"
#include "Common/Touch/TouchClassifier.h"
#include "FiftyThreeSdk/Classification/Classifier.h"

namespace fiftythree
{
namespace sdk
{
// This contains some common functionality.
class TouchClassifierImpl : virtual public common::TouchClassifier
{
public:
    TouchClassifierImpl();
    virtual bool IsPenConnected();
    virtual void SetPenConnected(bool connected);
    virtual bool IsPenOrEraserSwitchDown();
    virtual void PenStateDidChanged(const common::PenEventArgs & args);
    virtual void TouchesDidChanged(const std::set<common::Touch::cPtr> & touches);
    virtual void RemoveTouchFromClassification(const common::Touch::cPtr & touch);
    virtual common::TouchClassification ClassifyPair(const common::Touch::cPtr & t0,
                                                   const common::Touch::cPtr & t1,
                                                     const common::TwoTouchPairType & type);

    virtual common::TouchClassification ClassifyForSingleTouchGestureType(const common::Touch::cPtr & touch, const common::SingleTouchGesture & type);
    virtual Eigen::VectorXf GeometricStatistics(const common::Touch::cPtr & t0);
    virtual bool AreAnyTouchesCurrentlyPenOrEraser();
    virtual bool HasPenActivityOccurredRecently();
    virtual void UpdateClassifications();
    virtual Event<const std::vector<common::TouchClassificationChangedEventArgs> & > & TouchClassificationsDidChange();
    virtual void ClearSessionStatistics();
    virtual common::SessionStatistics::Ptr SessionStatistics();

protected:
    // Call this to get at the Classification parameters.
    Classifier::Ptr Classifier();

    // The following two methods let you customize the dispatch of classification events to
    // override the classifier. You might want to do this if you're supporting another stylus e.g., PogoConnect.

    // Default implementation returns false
    virtual bool ShouldOverrideClassifications();

    virtual boost::optional<common::TouchClassification> OverrideClassificationForTouch(const common::Touch::cPtr & touch);

    void SetCopyGestureClassifications(bool b);
private:
    Classifier::Ptr _Classifier;
    bool _ShowLog;
    bool _Connected;
    bool _CopyGestureClassifications;
    Event<const std::vector<common::TouchClassificationChangedEventArgs> &> _TouchClassificationsDidChange;
};

}
}
