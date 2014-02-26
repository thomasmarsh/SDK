//
//  Cluster.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <boost/container/flat_map.hpp>
#include <boost/container/flat_set.hpp>
#include <boost/foreach.hpp>
#include <boost/unordered_set.hpp>
#include <tuple>

#include "Common/Touch/Touch.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/EigenLAB.h"
#include "FiftyThreeSdk/Classification/Stroke.h"
#include "FiftyThreeSdk/Classification/TouchLogger.h"

namespace fiftythree {
namespace sdk {

/*
 Cluster is the basic object we store.  _center is not actually the center of mass.
 it is a trailing average of the locations of all touches in the cluster.

 _score is not very useful -- it is simply the average score reported by the IsolatedStrokesClassifier
 over all times.

 _timestamp is the most recent timestamp.  this is set in UpdateClusters, which is invoked
 in every touchesChanged by the Proxy.  It also gets updated by the viewcontroller at the moment,
 so we can visualize staleness when a cluster loses all its touches.

 _count is the number of samples in the cluster.

 _touchIds contains the TouchId for every touch that was added to the cluster.

 _simultaneousTouches indicates whether or not two or more touches
 occur simultaneously over the life of the entire cluster.

 */

BOOST_STRONG_TYPEDEF(int, ClusterId);

struct ClusterEventStatistics
{

    ClusterEventStatistics() :
    _endedPenCount(0),
    _endedPalmCount(0),
    _endedPenSmoothLength(0.0f),
    _endedPalmSmoothLength(0.0f),
    _endedPenArcLength(0.0f),
    _endedPalmArcLength(0.0f),
    _endedPenDirectionScore(0.0f),
    _handednessLockFlag(false)
    {
    }

    typedef fiftythree::core::shared_ptr<ClusterEventStatistics> Ptr;

    // some stats used to help build confidence in the event
    // early on in an event we may need to consider orientation change,
    // but once we're rolling we can probably stop looking for switch events.
    int    _endedPenCount;
    int    _endedPalmCount;
    float  _endedPenSmoothLength;
    float  _endedPalmSmoothLength;

    float  _endedPenArcLength;
    float  _endedPalmArcLength;

    float  _endedPenDirectionScore;
    bool   _handednessLockFlag;
};

struct Cluster
{

    TouchLogger::Ptr   _touchLog;
    const CommonData*  _commonData;

    ClusterId         _id;

    Eigen::Vector2f _center;
    float           _score;
    float           _count;
    float           _totalLength;

    float           _penPrior;
    float           _directionPrior;

    double          _becameStaleTime;

    float           _meanTouchRadius;

    bool            _simultaneousTouches;
    bool            _wasInterior;
    bool            _ignorable;
    bool            _closedToNewTouches;
    bool            _checkForFingerSequence;
    bool            _wasAtPalmEnd;

    // the value of this cluster event statistic at the time the touch most recently ended or changed.
    float           _endedPenDirectionScore;

    // stored by endpoint clusters to allow more accurate reclassification of endpoints at cold start.
    // i.e. initially, both endpoints are probably declared pen at cold start, but after a short while
    // we lock handedness and we can then figure it out.
    Eigen::Vector2f _vOtherEndpoint;

    double          _firstTimestamp;
    double          _lastTimestamp;

    // indicate that we're really, really confident about _clusterTouchType.
    bool            _probabilityOneFlag;

    TouchType       _clusterTouchType;

    EdgeThumbState  _edgeThumbState;

    //std::set<common::TouchId> _touchIds;

    // While we do some set and map operations on these vectors, addition and removal of elements is uncommon.
    // The number of entries is so small that in every other circumstance it's a big win.
    // we also occasionally need arrival order, or at least first and last touches, so we need the vector.
    std::vector<common::TouchId> _touchIds;
    boost::container::flat_map<common::TouchId, TouchData::Ptr> _touchData;

    typedef fiftythree::core::shared_ptr<Cluster> Ptr;

    Cluster();

    static Cluster::Ptr New();

    // used to give rendering hints -- early in a touch's lifetime we may have strong
    // evidence that it is a pen of some kind but no firm idea about pen vs. eraser vs finger.
    bool            _waitingForPenEvent;

    // final score used in classification.  currently the odds ratio:
    // _penScore = P(all pen) / P(all palm).
    float _penScore;

    // the naive model we're using allows (mathematically) for clusters
    // which contain mixed types of touches.  however, the rules for classifying
    // do not allow for these cases.  the two cases the rules allow are
    // clusters which are all pen, or all palm.
    // these are geometric means.
    float _meanPenProbability;
    float _meanPalmProbability;

    // total probability mass explained by this cluster
    // can be artifically large if a cluster has a number of touches with small scores
    float _penTotalScore;

    common::TouchId MostRecentTouch() const;
    common::TouchId FirstTouch() const;

    float Staleness() const;

    bool AllTouchesEnded() const;

    double FirstTimestamp() const
    {
        return _firstTimestamp;
    }

    void  RemoveOldTouches(double cutoffTime);

    double LastTimestamp() const
    {
        return _lastTimestamp;
    }

    bool Stale() const
    {
        return (_becameStaleTime != std::numeric_limits<double>::max());
    }

    bool IsPenType() const
    {
        return _clusterTouchType == TouchType::PenTip1 || _clusterTouchType == TouchType::PenTip2;
    }

    bool IsFingerType() const
    {
        return _clusterTouchType == TouchType::Finger;
    }

    // returns true if it is a thumb or it could be a thumb.
    // writing all that out makes the name really long though.
    bool IsPossibleEdgeThumb() const
    {
        return (_edgeThumbState == EdgeThumbState::Possible) || (_edgeThumbState == EdgeThumbState::Thumb);
    }

    // every so often we want to check if a cluster has received its final touch and will soon expire.
    // you can get a pen on screen before the old pen cluster has expired, for example.
    bool InFinalExpirationWindowAtTime(double time) const
    {
        if(! Stale())
        {
            return false;
        }
        else
        {
            return time >= LastTimestamp() && time <= _becameStaleTime;
        }
    }

    Eigen::Vector2f CenterOfMass() const;
    int             PointCount() const;
    float           TotalLength() const;

    // returns true if the touch was added to the vector, false if it was already there.
    bool InsertTouch(common::TouchId touchId);

    // true if touch was erased, false if not found
    bool RemoveTouch(common::TouchId touchId);

    std::vector<common::TouchId>::iterator FindTouch(common::TouchId touchId);

    bool ContainsTouch(common::TouchId probeId) const;

    bool ConcurrentWith(Cluster::Ptr const &other, bool useStaleInterval = true) const;

    bool ConcurrentWith(common::TouchId touchId, bool useStaleInterval = true) const;

    bool ConcurrentWith(Cluster::Ptr const & other, float temporalPadding) const;

    TouchIdVector ActiveTouches();
    TouchIdVector Touches();

    int CountTouchesOfType(TouchType probeType) const;

    float ConcurrentDuration(Cluster const &other) const;

    bool ContainsReclassifiableTouch() const;

    std::vector<common::TouchId> ReclassifiableTouches() const;

};

ClusterId InvalidClusterId();

typedef boost::container::flat_map<ClusterId, Cluster::Ptr>  IdClusterPtrMap;

typedef std::pair<ClusterId, Cluster::Ptr> IdClusterPtrPair;
typedef std::pair<ClusterId, Cluster::Ptr &> IdClusterPtrRefPair;

/*
 ClusterTracker maintains a set of clusters using the following
 greedy method.

 Each cluster has a "center" which is really a trailing average location.

 When a touch begins:
   1. find the nearest cluster (using the distance to the center)
   2. if it is "near enough", or if there are already 4 clusters, add this touch to the cluster
   3. if it is not near and there are fewer than 4 clusters, create a new cluster for this touch

 When a cluster has no touches, it gradually becomes stale.  If its timestamp is older than
 _staleInterval seconds, the cluster is removed from the system.

 */

class ClusterTracker {

public:
    typedef fiftythree::core::shared_ptr<ClusterTracker> Ptr;

protected:

    ClusterId         _counter;

    //TouchLogger       _touchLog;

    TouchLogger::Ptr  _touchLog;

    const CommonData* _commonData;

    IdClusterPtrMap   _clusters;

    double _lastEventEndedTimestamp;
    double _currentEventBeganTimestamp;

    // computing cluster order can be a fairly expensive computation,
    // particularly without optimization in Debug mode, so we cache it
    // for performance during debugging.
    std::vector<Cluster::Ptr> _orderedClustersCache;

    bool _needComputeClusterOrder;

    // a cluster event is to clusters what UIEvent is to UITouch.
    // the difference is that clusters stick around for staleInterval seconds after the corresponding
    // touches have disappeared, so the cluster event can include touches from several UIEvents
    std::set<Cluster::Ptr> _currentEventActiveClusters;
    std::set<Cluster::Ptr> _currentEventStaleClusters;

    ClusterEventStatistics::Ptr _currentEventStatistics;

protected:
    // methods

    Cluster::Ptr NewCluster(Eigen::Vector2f center, double timestamp, TouchType defaultTouchType);
    void UpdateEventStatistics();

public:
    ClusterTracker(const CommonData* dataPtr) :
    _commonData(dataPtr),
    _touchLog(TouchLogger::Ptr::make_shared(dataPtr))
    {
        _staleInterval    = .275f;

        _counter = 0;
        _lastEventEndedTimestamp = 0.0;
        _needComputeClusterOrder = true;

        Reset();

    }

    Eigen::MatrixXf DistanceMatrix(std::set<Cluster::Ptr> const & clusters);

    void UpdateClusters();
    void AddPointToCluster(Eigen::Vector2f p, double timestamp, Cluster::Ptr const & cluster, common::TouchId touchId);

    Cluster::Ptr NewClusterForTouch(common::TouchId touchId);

    ClusterEventStatistics::Ptr CurrentEventStatistics()
    {
        return _currentEventStatistics;
    }

    int CurrentEventFingerCount();

    Cluster::Ptr ClusterOfTypeForPenDownEvent(TouchType touchType, PenEventId penEventId);

    void RemoveTouchFromClassification(common::TouchId touchId);

    std::vector<Cluster::Ptr> NonEndedPenClusters();

    void ForceAllClustersStale(double timestamp);

    void MarkStaleClusters(double currentTimestamp);

    void RemoveUnusedStaleClusters();

    void RemoveUnusedTouches();

    void Reset();

    double CurrentEventBeganTime() const
    {
        if(_clusters.empty())
        {
            return std::numeric_limits<double>::max();
        }
        else
        {
            return _currentEventBeganTimestamp;
        }
    }

    double CurrentTime() const
    {
        return _touchLog->CurrentTime();
    }

    std::set<Cluster::Ptr> const & CurrentEventActiveClusters() const
    {
        return _currentEventActiveClusters;
    }

    void MarkInteriorClusters();

    bool IsEndpoint(Cluster::Ptr const & cluster);

    std::set<Cluster::Ptr> const & CurrentEventStaleClusters() const
    {
        return _currentEventStaleClusters;
    }

    // this method currently uses the orderedness of flat_map to do its job.
    // if we change to another container type, we must update this method.
    std::vector<Cluster::Ptr> CurrentEventTimeOrderedClusters()
    {
        std::vector<Cluster::Ptr> all;
        Cluster::Ptr ptr;
        BOOST_FOREACH(std::tie(std::ignore, ptr), _clusters)
        {
            all.push_back(ptr);
        }

        return all;
    }

    std::vector<Cluster::Ptr> CurrentEventAllClusters()
    {
        std::vector<Cluster::Ptr> all;

        all.insert(all.end(), _currentEventStaleClusters.begin(), _currentEventStaleClusters.end());
        all.insert(all.end(), _currentEventActiveClusters.begin(), _currentEventActiveClusters.end());

        return all;
    }

    std::vector<common::TouchId> TouchesForCurrentClusters(bool activeClustersOnly);

    bool ContainsClusterForKey(ClusterId key) const
    {
        return _clusters.count(key);
    }

    Cluster::Ptr NearestStaleCluster(Eigen::Vector2f p);

    Cluster::Ptr NearestActiveCluster(Eigen::Vector2f p);
    Cluster::Ptr NearestActiveNonPenCluster(Eigen::Vector2f p);

    float NearestEndedPenDistance(Eigen::Vector2f p);
    float NearestActiveClusterDistance(Eigen::Vector2f p);

    std::vector<Cluster::Ptr> ExactOrderedClusters(std::set<Cluster::Ptr> const & clusters);
    std::vector<Cluster::Ptr> FastOrderedClusters();

    // it would generally be possible to avoid the need for vector vs. set
    // by implementing stuff using iterators, or templating these methods, but these are
    // the only two cases needed.
    std::vector<Cluster::Ptr> ConcurrentClusters(Cluster::Ptr const & probe, bool useStaleInterval = true);
    std::vector<Cluster::Ptr> ConcurrentClusters(Cluster::Ptr const & probe, float temporalPadding);

    float _staleInterval;
    float _penStaleInterval;

    float StaleInterval()
    {
        return _staleInterval;
    }

    void MarkIfStale(Cluster::Ptr const & cluster);

    //////////////////////////////////////////////////////////////////////////////

    TouchData::Ptr    const &        Data(common::TouchId id)
    {
        return _touchLog->Data(id);
    }

    //std::vector<TouchData::Ptr>      Data(TouchIdVector ids);

    // if/when TouchTracker gets modified to hold the ended touches the classifier needs
    // we can remove this call and replace it with the like-named TouchTracker call.
    common::Touch::Ptr const &       TouchWithId(common::TouchId touchId)
    {
        return _touchLog->TouchWithId(touchId);
    }

    //bool                             ContainsTouchWithId(common::TouchId touchId);

    Stroke::Ptr const &      Stroke(common::TouchId id);

    //std::vector<curves::Stroke::Ptr> Stroke(TouchIdVector ids);

    //ClusterPtr                       Cluster(common::TouchId touchId);

    //common::TouchPhase               Phase(common::TouchId id);
    //std::vector<common::TouchPhase>  Phase(TouchIdVector ids);

    PenEventData::Ptr const &        PenData(PenEventId id)
    {
        return _touchLog->PenData(id);
    }

    //std::vector<PenEventData::Ptr>   PenData(PenEventIdVector ids);

    TouchIdVector                   TouchIdsBeganInTimeInterval(double interval_start,
                                                                double interval_end)
    {
        return _touchLog->TouchIdsBeganInTimeInterval(interval_start, interval_end);
    }

    TouchIdVector                   TouchIdsEndedInTimeInterval(double interval_start,
                                                                double interval_end)
    {
        return _touchLog->TouchIdsEndedInTimeInterval(interval_start,
                                                      interval_end);
    }

    // Ids begun within specified (absolute) time interval
    TouchIdSet                      TouchIdSetBeganInTimeInterval(double interval_start,
                                                                  double interval_end)
    {
        return _touchLog->TouchIdSetBeganInTimeInterval(interval_start,
                                                        interval_end);
    }

    TouchIdSet                      TouchIdSetEndedInTimeInterval(double interval_start,
                                                                  double interval_end)
    {
        return _touchLog->TouchIdSetEndedInTimeInterval(interval_start,
                                                        interval_end);
    }

    TouchIdVector                   ConcurrentTouches(common::TouchId probeId)
    {
        return _touchLog->ConcurrentTouches(probeId);
    }

    common::TouchId                 TouchPrecedingTouch(common::TouchId probeId)
    {
        return _touchLog->TouchPrecedingTouch(probeId);
    }

    PenEventIdSet                   PenBeganEventSetInTimeInterval(double t0, double t1)
    {
        return _touchLog->PenBeganEventSetInTimeInterval(t0,t1);
    }
    PenEventIdSet                   PenEndedEventSetInTimeInterval(double t0, double t1)
    {
        return _touchLog->PenEndedEventSetInTimeInterval(t0,t1);
    }

    PenEventIdSet                   PenEventSetInTimeInterval(double t0, double t1)
    {
        return _touchLog->PenEventSetInTimeInterval(t0, t1);
    }

    PenEventIdVector                PenEventsInTimeInterval(double t0, double t1, bool includeEndpoints)
    {
        return _touchLog->PenEventsInTimeInterval(t0, t1, includeEndpoints);
    }

    ClusterPtr                       Cluster(common::TouchId touchId)
    {
        return _touchLog->Cluster(touchId);
    }

    common::TouchPhase               Phase(common::TouchId id)
    {
        return _touchLog->Phase(id);
    }

    TouchIdVector                   ActiveIds()
    {
        return _touchLog->ActiveIds();
    }

    PenEventId                      MostRecentPenEvent()
    {
        return _touchLog->MostRecentPenEvent();
    }

    bool                            IsIdLogged(common::TouchId id)
    {
        return _touchLog->IsIdLogged(id);
    }

    TouchType                       MostRecentPenTipType()
    {
        return _touchLog->MostRecentPenTipType();
    }

    common::TouchId                 MostRecentTouch()
    {
        return _touchLog->MostRecentTouch();
    }

    TouchIdVector                   LiveTouches()
    {
        return _touchLog->LiveTouches();
    }

    bool                            IsEnded(common::TouchId touchId)
    {
        return _touchLog->IsEnded(touchId);
    }

    void TouchesChanged(const std::set<common::Touch::Ptr> & touches);

    bool                            AllCancelledFlag()
    {
        return _touchLog->AllCancelledFlag();
    }

    double          Time()
    {
        return _touchLog->Time();
    }

    PenEventType                     PenType(PenEventId id)
    {
        return _touchLog->PenType(id);
    }

    void LogPenEvent(PenEvent event)
    {
        return _touchLog->LogPenEvent(event);
    }

    bool                             ContainsTouchWithId(common::TouchId touchId)
    {
        return _touchLog->ContainsTouchWithId(touchId);
    }

    bool Removed(common::TouchId touchId)
    {
        return _touchLog->Removed(touchId);
    }

    void UpdateTime(double t)
    {
        return _touchLog->UpdateTime(t);
    }

    std::vector<common::TouchId> const & NewlyEndedTouches()
    {
        return _touchLog->NewlyEndedTouches();
    }

    void ClearAllData()
    {
        return _touchLog->ClearAllData();
    }

    TouchIdVector                   IdsInPhase(common::TouchPhase phase)
    {
        return _touchLog->IdsInPhase(phase);
    }

};

}
}
