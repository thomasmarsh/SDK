//
//  OffscreenTouchClassificationLinker.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include "Core/Log.h"
#include "Core/Touch/Touch.h"
#include "Core/Touch/TouchTracker.h"
#include "FiftyThreeSdk/FTLogPrivate.h"
#include "FiftyThreeSdk/OffscreenStrokeDetectionUtilities.h"
#include "FiftyThreeSdk/OffscreenTouchClassificationLinker.h"

using namespace Eigen;
using namespace fiftythree::core;
using namespace fiftythree::sdk;
using std::vector;

namespace
{
static const char *kTouchDidEnterFromOffscreen = "touchDidEnterFromOffscreen";
static const char *kTouchDidExitOffscreen = "touchDidExitOffscreen";

class OffscreenTouchClassificationLinkerImpl : public fiftythree::sdk::OffscreenTouchClassificationLinker
{
private:
    Event<std::vector<Touch::cPtr>> _TouchesReclassified;
    Settings settings;

public:
    OffscreenTouchClassificationLinkerImpl() {}

    static bool GetTouchBooleanProperty(const Touch::cPtr & touch,
                                        const char *propertyKey,
                                        bool defaultValue)
    {
        DebugAssert(touch);

        auto it = touch->DynamicProperties().find(propertyKey);
        if (it != touch->DynamicProperties().end())
        {
            return any_cast<bool>(it->second);
        }
        return defaultValue;
    }

    static bool HasTouchProperty(const Touch::cPtr & touch,
                                 const char *propertyKey)
    {
        DebugAssert(touch);

        auto it = touch->DynamicProperties().find(propertyKey);
        return it != touch->DynamicProperties().end();
    }

    Touch::Ptr FindPenExitOffscreenTouchForEnterFromOffscreenTouch(const Touch::cPtr & touch,
                                                                   const vector<Touch::Ptr> & recentTouchesSortedByEndTime,
                                                                   const vector<Touch::Ptr> & ignoreTouches)
    {
        // Try to find a matching pen touch that "exited offscreen" that this "enter from offscreen" touch
        // continues.
        DebugAssert(touch);

        const InputSample & enterFirstSample = touch->FirstSample();
        const Vector2f & enterLocation = enterFirstSample.Location();
        const double & enterTimestampSeconds = enterFirstSample.TimestampSeconds();

        Touch::Ptr closestExitTouch;
        float closestEnterToExitDistance;
        float closestEnterToExitElapsedSeconds;
        for (const Touch::Ptr & recentTouch : recentTouchesSortedByEndTime)
        {
            if (touch->Id() == recentTouch->Id())
            {
                // A touch can't continue itself.
                //
                // The "recent touches" are presorted by end time, so we can safely ignore the rest of the
                // touches as well.
                DebugAssert(touch == recentTouch);
                MLOG_INFO(FTLogSDKClassificationLinker, "\t\t touch[%d] %s %s ->? touch[%d] %s %s reject 1 \n",
                       (int) touch->Id(),
                       ToString(touch->Phase()).c_str(),
                       ToString(touch->CurrentClassification()()).c_str(),
                       (int) recentTouch->Id(),
                       ToString(recentTouch->Phase()).c_str(),
                       ToString(recentTouch->CurrentClassification()()).c_str());
                break;
            }

            if (recentTouch->Phase() != TouchPhase::Ended)
            {
                // Only continue touches that have already ended.
                MLOG_INFO(FTLogSDKClassificationLinker, "\t\t touch[%d] %s %s ->? touch[%d] %s %s reject 2 \n",
                       (int) touch->Id(),
                       ToString(touch->Phase()).c_str(),
                       ToString(touch->CurrentClassification()()).c_str(),
                       (int) recentTouch->Id(),
                       ToString(recentTouch->Phase()).c_str(),
                       ToString(recentTouch->CurrentClassification()()).c_str());
                continue;
            }

            if (std::find(ignoreTouches.begin(), ignoreTouches.end(), recentTouch) != ignoreTouches.end())
            {
                // Ignore touches that have already been involved in a linkage.

                MLOG_INFO(FTLogSDKClassificationLinker,"\t\t touch[%d] %s %s ->? touch[%d] %s %s reject 3 \n",
                       (int) touch->Id(),
                       ToString(touch->Phase()).c_str(),
                       ToString(touch->CurrentClassification()()).c_str(),
                       (int) recentTouch->Id(),
                       ToString(recentTouch->Phase()).c_str(),
                       ToString(recentTouch->CurrentClassification()()).c_str());

                continue;
            }

            const InputSample & exitLastSample = recentTouch->CurrentSample();
            const double & exitTimestampSeconds = exitLastSample.TimestampSeconds();

            if (exitTimestampSeconds > enterTimestampSeconds)
            {
                // Ignore touches that ended after the current touch began.
                //
                // The "recent touches" are presorted by end time, so we can safely ignore the rest of the
                // touches as well.

                MLOG_INFO(FTLogSDKClassificationLinker,"\t\t touch[%d] %s %s ->? touch[%d] %s %s reject 4 \n",
                       (int) touch->Id(),
                       ToString(touch->Phase()).c_str(),
                       ToString(touch->CurrentClassification()()).c_str(),
                       (int) recentTouch->Id(),
                       ToString(recentTouch->Phase()).c_str(),
                       ToString(recentTouch->CurrentClassification()()).c_str());

                break;
            }

            if (TouchClassification::Pen != recentTouch->ContinuedClassification() &&
                TouchClassification::Eraser != recentTouch->ContinuedClassification())
            {
                // Only continue Pen and eraser touches.

                MLOG_INFO(FTLogSDKClassificationLinker,"\t\t touch[%d] %s %s ->? touch[%d] %s %s reject 5 \n",
                       (int) touch->Id(),
                       ToString(touch->Phase()).c_str(),
                       ToString(touch->CurrentClassification()()).c_str(),
                       (int) recentTouch->Id(),
                       ToString(recentTouch->Phase()).c_str(),
                       ToString(recentTouch->CurrentClassification()()).c_str());

                continue;
            }

            bool touchDidExitOffscreen = false;
            if (HasTouchProperty(recentTouch, kTouchDidExitOffscreen))
            {
                touchDidExitOffscreen = GetTouchBooleanProperty(recentTouch, kTouchDidExitOffscreen, false);
            }
            else
            {
                touchDidExitOffscreen = fiftythree::sdk::DidTouchExitOffscreenPermissive(recentTouch);
                Touch::Ptr nonConstTouch = cpc<Touch>(recentTouch);
                nonConstTouch->DynamicProperties()[kTouchDidExitOffscreen] = any(touchDidExitOffscreen);

                MLOG_INFO(FTLogSDKClassificationLinker,"\t\t\t touch[%d] %s %s touchDidExitOffscreen decision: %d \n",
                       (int) touch->Id(),
                       ToString(touch->Phase()).c_str(),
                       ToString(touch->CurrentClassification()()).c_str(),
                       touchDidExitOffscreen);

            }

            if (!touchDidExitOffscreen)
            {
                // Only continue touches the "exited offscreen."

                MLOG_INFO(FTLogSDKClassificationLinker,"\t\t touch[%d] %s %s ->? touch[%d] %s %s reject 6 \n",
                       (int) touch->Id(),
                       ToString(touch->Phase()).c_str(),
                       ToString(touch->CurrentClassification()()).c_str(),
                       (int) recentTouch->Id(),
                       ToString(recentTouch->Phase()).c_str(),
                       ToString(recentTouch->CurrentClassification()()).c_str());

                continue;
            }

            double enterToExitElapsedSeconds = enterTimestampSeconds - exitTimestampSeconds;
            // TODO: Tune this value.
            const double kMaxEnterToExitElapsedSeconds = settings.OffscreenTouches_MaxPenOffscreenSeconds;

            // Use a tolerance adjustment so that we prefer linkage to slightly older touches if they are
            // closer in space.
            const double kEnterToExitElapsedToleranceSeconds = 0.1f;

            if (enterToExitElapsedSeconds > kMaxEnterToExitElapsedSeconds)
            {
                // Ignore touches that were offscreen for "too long."

                MLOG_INFO(FTLogSDKClassificationLinker,"\t\t touch[%d] %s %s ->? touch[%d] %s %s reject 7 \n",
                       (int) touch->Id(),
                       ToString(touch->Phase()).c_str(),
                       ToString(touch->CurrentClassification()()).c_str(),
                       (int) recentTouch->Id(),
                       ToString(recentTouch->Phase()).c_str(),
                       ToString(recentTouch->CurrentClassification()()).c_str());

                continue;
            }

            const Vector2f & exitLocation = exitLastSample.Location();
            // Use the "manhattan distance."  Offscreen touches by definition can't move along the shortest
            // path while offscreen.
            float enterToExitDistance = (enterLocation - exitLocation).array().abs().sum();
            // TODO: Tune this value.
            const double kMaxEnterToExitDistance = settings.OffscreenTouches_MaxPenOffscreenDistance;

            if (enterToExitDistance > kMaxEnterToExitDistance)
            {
                // Ignore touches that would have travelled too far in space offscreen.

                MLOG_INFO(FTLogSDKClassificationLinker,"\t\t touch[%d] %s %s ->? touch[%d] %s %s reject 8 (%f > %f) \n",
                       (int) touch->Id(),
                       ToString(touch->Phase()).c_str(),
                       ToString(touch->CurrentClassification()()).c_str(),
                       (int) recentTouch->Id(),
                       ToString(recentTouch->Phase()).c_str(),
                       ToString(recentTouch->CurrentClassification()()).c_str(),
                       enterToExitDistance,
                       kMaxEnterToExitDistance);

                continue;
            }

            // Treat the "new" touch as a continuation of the "old" touch.
            //
            // If more than one match is found, use the closest in space and time.
            // Time trumps space, although we are slightly forgiving about time.
            if (!closestExitTouch ||
                (closestEnterToExitElapsedSeconds + kEnterToExitElapsedToleranceSeconds > enterToExitElapsedSeconds) ||
                (closestEnterToExitDistance > enterToExitDistance &&
                 closestEnterToExitElapsedSeconds + kEnterToExitElapsedToleranceSeconds == enterToExitElapsedSeconds))
            {
                closestExitTouch = recentTouch;
                closestEnterToExitDistance = enterToExitDistance;
                closestEnterToExitElapsedSeconds = enterToExitElapsedSeconds;
            }
        }

        return closestExitTouch;
    }

    virtual void UpdateTouchContinuationLinkage()
    {
        // Recaculate linkages between all recent touches.
        //
        // If linkage changes affect "continued classification", undo & re-render as necessary.
        const auto & recentTouches = TouchTracker::Instance()->RecentTouches();

        // Take a snapshot of current "continued classification" state.
        std::unordered_map<Touch::Ptr, TouchClassification> oldTouchClassificationMap;
        for (const Touch::Ptr & recentTouch : recentTouches)
        {
            oldTouchClassificationMap[recentTouch] = recentTouch->ContinuedClassification();
        }

        // Prepare collections of the touches sorted by start and end time.
        vector<Touch::Ptr> recentTouchesSortedByStartTime(recentTouches.begin(), recentTouches.end());
        vector<Touch::Ptr> recentTouchesSortedByEndTime(recentTouches.begin(), recentTouches.end());
        std::sort(recentTouchesSortedByStartTime.begin(), recentTouchesSortedByStartTime.end(),[](const Touch::Ptr & left, const Touch::Ptr & right)
                  {
                      return (left->FirstSample().TimestampSeconds() < right->FirstSample().TimestampSeconds());
                  });

        std::sort(recentTouchesSortedByEndTime.begin(), recentTouchesSortedByEndTime.end(), [](const Touch::Ptr & left, const Touch::Ptr & right)
                  {
                      return (left->CurrentSample().TimestampSeconds() < right->CurrentSample().TimestampSeconds());
                  });

        // Update touch linkages.
        vector<Touch::Ptr> continuedTouches;
        for (const Touch::Ptr & newTouch : recentTouchesSortedByStartTime)
        {
            // Avoid recalculating "touch enters from offscreen" for the touch once it has been determined by
            // stashing the determination in dynamic properties.
            bool touchEntersFromOffscreen = false;
            if (HasTouchProperty(newTouch, kTouchDidEnterFromOffscreen))
            {
                touchEntersFromOffscreen = GetTouchBooleanProperty(newTouch, kTouchDidEnterFromOffscreen, false);
            }
            else
            {
                optional<bool> touchEntersFromOffscreenOptional = fiftythree::sdk::WillTouchEnterFromOffscreenPermissive(newTouch);

                if (touchEntersFromOffscreenOptional)
                {
                    touchEntersFromOffscreen = *touchEntersFromOffscreenOptional;
                    Touch::Ptr nonConstTouch = cpc<Touch>(newTouch);
                    nonConstTouch->DynamicProperties()[kTouchDidEnterFromOffscreen] = any(touchEntersFromOffscreen);

                    MLOG_INFO(FTLogSDKClassificationLinker,"EnsurePenTouchContinuationLinkage newTouch[%d] %s %s, *touchEntersFromOffscreen: %d \n",
                           (int) newTouch->Id(),
                           ToString(newTouch->Phase()).c_str(),
                           ToString(newTouch->CurrentClassification()()).c_str(),
                           *touchEntersFromOffscreenOptional);

                }
            }

            bool newTouchHasLinkablePhase = (newTouch->Phase() == TouchPhase::Began ||
                                             newTouch->Phase() == TouchPhase::Moved ||
                                             newTouch->Phase() == TouchPhase::Ended ||
                                             newTouch->Phase() == TouchPhase::Stationary);

            Touch::Ptr oldTouch = Touch::Ptr();

            if (touchEntersFromOffscreen &&
                newTouchHasLinkablePhase)
            {
                if (newTouch->ContinuationTouch()() &&
                    recentTouches.find(newTouch->ContinuationTouch()()) == recentTouches.end())
                {
                    // We want to preserve linkages to old touches that are no longer recent.  Put another
                    // way, linkages to touches are "committed" once the old touch is no longer recent.
                    continue;
                }

                // Try to find a matching pen touch that "exited offscreen" that this "enter from offscreen"
                // touch continues.
                oldTouch = FindPenExitOffscreenTouchForEnterFromOffscreenTouch(newTouch,
                                                                               recentTouchesSortedByEndTime,
                                                                               continuedTouches);

                MLOG_INFO(FTLogSDKClassificationLinker,"EnsurePenTouchContinuationLinkage newTouch[%d] %s %s -> oldTouch[%d] %s %s \n",
                       (int) newTouch->Id(),
                       ToString(newTouch->Phase()).c_str(),
                       ToString(newTouch->CurrentClassification()()).c_str(),
                       oldTouch ? (int) oldTouch->Id() : -1,
                       oldTouch ? ToString(oldTouch->Phase()).c_str() : "None",
                       oldTouch ? ToString(oldTouch->CurrentClassification()()).c_str() : "None");

            }

            if (oldTouch)
            {
                // Create new linkage.
                continuedTouches.push_back(oldTouch);
                newTouch->ContinuationTouch() = cpc<Touch>(oldTouch);
            }
            else if (newTouch->ContinuationTouch()())
            {
                // If the new touch has existing linkage to a touch that is still recent, remove it.
                DebugAssert(recentTouches.find(newTouch->ContinuationTouch()()) != recentTouches.end());
                newTouch->ContinuationTouch() = Touch::Ptr();
            }
        }

        // Determine which touches' classification has changed due to linkage changes.
        //
        // Note that we do _NOT_ care about linkage changes that do not affect classification.
        vector<Touch::cPtr> reclassifiedTouches;
        for (const Touch::Ptr & touch : recentTouchesSortedByStartTime)
        {
            if (oldTouchClassificationMap[touch] != touch->ContinuedClassification())
            {
                reclassifiedTouches.push_back(touch);
                break;
            }
        }

        if (!reclassifiedTouches.empty())
        {
            // If we have reclassified a touch through linkage changes, we need to re-render it and any
            // subsequent strokes.
            _TouchesReclassified.Fire(reclassifiedTouches);
        }
    }

    virtual Event<std::vector<Touch::cPtr>> & TouchesReclassified()
    {
        return _TouchesReclassified;
    }
};
}

fiftythree::sdk::OffscreenTouchClassificationLinker::Ptr fiftythree::sdk::OffscreenTouchClassificationLinker::New()
{
    return fiftythree::core::make_shared<OffscreenTouchClassificationLinkerImpl>();
}
