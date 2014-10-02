//
//  PenDirection.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "Core/Touch/Touch.h"
#include "FiftyThreeSdk/Classification/Cluster.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/DataStream.hpp"
#include "FiftyThreeSdk/Classification/EigenLAB.h"
#include "FiftyThreeSdk/Classification/Stroke.h"
#include "FiftyThreeSdk/Classification/TouchLogger.h"

namespace fiftythree
{
namespace sdk
{
class PenTracker
{

public:
    ALIAS_PTR_TYPES(PenTracker);

protected:
    ClusterTracker::Ptr _clusterTracker;
    const CommonData*   _commonData;

    Eigen::Vector2f      _penDisplacement;
    Eigen::Vector2f      _palmLocation;

    // used to identify a possible change in direction -- a very short trailing average
    Eigen::Vector2f      _recentPenDisplacement;
    Eigen::Vector2f      _recentPalmLocation;

    // used when we don't have any palm touches at the moment.  most recently used.
    Eigen::Vector2f      _mruPalmLocation;
    float                _mruPalmWeight;

public:
    PenTracker(ClusterTracker::Ptr clusterTracker,
               const CommonData* dataPtr) :
    _clusterTracker(clusterTracker),
    _commonData(dataPtr),
    _penDisplacement(Eigen::Vector2f::Zero()),
    _palmLocation(Eigen::Vector2f::Zero()),
    _recentPenDisplacement(Eigen::Vector2f::Zero()),
    _recentPalmLocation(Eigen::Vector2f::Zero()),
    _mruPalmLocation(Eigen::Vector2f::Zero()),
    _mruPalmWeight(0.0f)
    {}

    void UpdateLocations();
    bool TrackingPenDirection() const;
    bool TrackingPalmLocation() const;

    float Confidence() const;

    // current best guess for the ordered clusters with the "Pen End" first.
    // the first cluster(s) could be edge thumbs.
    std::vector<Cluster::Ptr> CopyInPenToPalmOrder(std::vector<Cluster::Ptr> const & orderedClusters);

    Cluster::Ptr PenEndCluster(std::vector<Cluster::Ptr> const & orderedClusters, bool ignorePossibleThumbs);
    Cluster::Ptr PalmEndCluster(std::vector<Cluster::Ptr> const & orderedClusters);

    bool WasAtPalmEnd(Cluster::Ptr const &cluster);

    // typically there's only one pen at the pen end, but stray edge thumbs need to be considered
    // as begin at the pen end until they get marked as EdgeThumbType::Thumb
    bool AtPenEnd(Cluster::Ptr const & probeCluster,
                  std::vector<Cluster::Ptr> const & orderedClusters,
                  bool includePossibleThumbs);

    Eigen::Vector2f PenLocation() const;
    Eigen::Vector2f PalmLocation() const;

    Eigen::Vector2f PenDirection() const;

    // this compares the recent pen direction to the longer-timescale pen direction.
    // if the recent direction disagrees, DirectionChangingScore will approach 1.
    float DirectionChangingScore() const;

    // direction prior is actually stored in the clusters so the return value can be ignored if desired
    Eigen::VectorXf UpdateDirectionPrior(std::vector<Cluster::Ptr> const &orderedClusters) const;
};
}
}
