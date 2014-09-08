//
//  TouchClassifier.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "Core/Enum.h"
#include "Core/Memory.h"
#include "Core/Touch/Touch.h"

namespace fiftythree
{
namespace sdk
{
DEFINE_ENUM(PenEventType,
            Tip1Down,
            Tip1Up,
            Tip2Down,
            Tip2Up,
            Unknown
            );

struct SessionStatistics
{
public:
    typedef fiftythree::core::shared_ptr<SessionStatistics> Ptr;
    typedef fiftythree::core::shared_ptr<const SessionStatistics> cPtr;

    std::vector<int> _tip1DownHistogram;
    std::vector<int> _tip1SwitchOnHistogram;

    std::vector<int> _tip2DownHistogram;
    std::vector<int> _tip2SwitchOnHistogram;

    SessionStatistics() :
    _tip1DownHistogram(0, 0),
    _tip1SwitchOnHistogram(0, 0),
    _tip2DownHistogram(0, 0),
    _tip2SwitchOnHistogram(0, 0)
    {
    }

};

struct PenEventArgs
{
    PenEventArgs() : Type(PenEventType::Tip1Down), Timestamp(0.0) {}
    PenEventType Type;
    double Timestamp;
};

DEFINE_ENUM(TwoTouchPairType,
            Pinch,
            Pan);

DEFINE_ENUM(SingleTouchGestureType,
            Tap,
            LongPress,
            Drag);

struct TouchClassificationChangedEventArgs
{
    core::Touch::cPtr touch;
    core::TouchClassification oldValue;
    core::TouchClassification newValue;
};

class TouchClassifier
{
public:
    typedef fiftythree::core::shared_ptr<TouchClassifier> Ptr;
    typedef fiftythree::core::shared_ptr<const TouchClassifier> cPtr;

    // If the classifier should have differing behavior if the pen is connected, this is signalled here.
    virtual bool IsPenConnected() = 0;
    virtual void SetPenConnected(bool connected) = 0;

    // Report switch events to the classifier & updates touch classifications
    virtual void PenStateDidChanged(const PenEventArgs & args) = 0;

    // Report touch events to the classifier & updates touch classifications.
    virtual void TouchesDidChanged(const std::set<core::Touch::cPtr> & touches) = 0;

    // Remove a touch.
    virtual void RemoveTouchFromClassification(const core::Touch::cPtr & touch) = 0;

    // GRs can call this to see which the classifier thinks the pair of touchs is.
    virtual core::TouchClassification ClassifyPair(const core::Touch::cPtr & t0,
                                             const core::Touch::cPtr & t1,
                                             const TwoTouchPairType & type) = 0;

    // GRs can call this.
    virtual core::TouchClassification ClassifyForSingleTouchGestureType(const core::Touch::cPtr & touch, const SingleTouchGestureType & type) = 0;

    // TODO: Revisit this API.
    //      GRs should really not be in the business of knowing the details about stats however due to submodules work it's a pain to
    //      work in both repos. Once we get a better idea of what the edge pan gesture needs we'll do what
    //      we did with ClassifyPair and move the details of the stats back behind this interface.
    virtual Eigen::VectorXf GeometricStatistics(const core::Touch::cPtr & t0) = 0;

    // Call this once per frame before you use classifications.
    virtual void UpdateClassifications() = 0;

    // Fired with a list of all classifications that have changed.
    // These touches may be expired and may transition classifications of Untracked or RemovedFromClassification.
    virtual Event<const std::vector<TouchClassificationChangedEventArgs> & > & TouchClassificationsDidChange() = 0;

    // Fired with a list of all classifications that have changed.
    // These touches may be expired and may transition classifications of Untracked or RemovedFromClassification.
    virtual Event<const std::vector<TouchClassificationChangedEventArgs> & > & TouchContinuedClassificationsDidChange() = 0;

    virtual void ClearSessionStatistics() = 0;
    virtual SessionStatistics::Ptr SessionStatistics() = 0;

    static TouchClassifier::Ptr New();
};

// TODO:
//       what's the clean way for
//       other parts of the system to get at this.
//       We could hang something here, or hang it off of TouchTracker??
class ActiveClassifier
{
private:
    static TouchClassifier::Ptr _Instance;

public:
    static void Activate(const TouchClassifier::Ptr & classifier);
    static TouchClassifier::Ptr Instance();
};

}
}
