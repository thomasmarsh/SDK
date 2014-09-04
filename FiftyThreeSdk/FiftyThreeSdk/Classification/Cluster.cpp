//
//  Cluster.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include <algorithm>
#include <list>
#include <tuple>
#include <vector>

#include "Core/Touch/Touch.h"
#include "Core/Touch/TouchTracker.h"
#include "FiftyThreeSdk/Classification/ClassificationProxy.h"
#include "FiftyThreeSdk/Classification/Cluster.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/EigenLAB.h"
#include "FiftyThreeSdk/Classification/TouchLogger.h"

using namespace Eigen;
using namespace fiftythree::core;
using std::list;
using std::tie;
using std::vector;

namespace fiftythree
{
namespace sdk
{

float Cluster::Staleness() const
{

    float dt = _commonData->proxy->ClusterTracker()->CurrentTime() - LastTimestamp();

    float staleTime = _commonData->proxy->ClusterTracker()->_staleInterval;
    if (this->IsPenType())
    {
        staleTime = _commonData->proxy->ClusterTracker()->_penStaleInterval;
    }

    return std::max(0.0f, std::min(1.0f, dt / (.000001f + staleTime)));

}

int Cluster::CountTouchesOfType(TouchClassification probeType) const
{
    int count = 0;
    for (core::TouchId touchId:_touchIds)
    {
        if (_commonData->proxy->CurrentClass(touchId) == probeType)
        {
            count++;
        }
    }
    return count;
}

core::TouchId Cluster::MostRecentTouch() const
{
    if (_touchIds.empty())
    {
        return InvalidTouchId();
    }
    else
    {
        return _touchIds.back();
    }
}

bool Cluster::AllTouchesEnded() const
{
    for (core::TouchId currId:_touchIds)
    {
        //Touch::Ptr touch = _touchLog->TouchWithId(currId);

        DebugAssert(_touchData.count(currId));

        TouchData::Ptr const & touch = _touchData.at(currId);
        if (touch && (! touch->IsPhaseEndedOrCancelled()))
        {
            return false;
        }
    }

    return true;
}

float Cluster::ConcurrentDuration(Cluster const &other) const
{

    double tBegin = std::max(FirstTimestamp(), other.FirstTimestamp());
    double tEnd   = std::min(std::min(other._becameStaleTime, _becameStaleTime), _touchLog->CurrentTime());

    return std::max(0.0, tEnd - tBegin);

}

bool Cluster::ContainsTouch(core::TouchId touchId) const
{
    return std::find(_touchIds.begin(), _touchIds.end(), touchId) != _touchIds.end();
}

bool Cluster::ConcurrentWith(core::TouchId touchId, bool useStaleInterval) const
{

    Cluster const &otherCluster = *(_touchLog->Cluster(touchId));
    DebugAssert(otherCluster._touchData.count(touchId));

    // _becameStaleTime is defaulted to the largest possible double.
    double t0 = FirstTimestamp();
    double t1 = _becameStaleTime;

    // there's really no notion of "Stale" for a touch, but the basic idea of
    // staleness is to allow some temporal blurring of lifetimes.  hence this
    // seems consistent with the intent.
    TouchData::Ptr const & data = otherCluster._touchData.at(touchId);
    double s0 = data->FirstTimestamp();
    double s1 = data->LastTimestamp() + (double) _commonData->proxy->ClusterTracker()->StaleInterval();

    if (! useStaleInterval)
    {
        if (AllTouchesEnded())
        {
            t1 = LastTimestamp();
        }
        else
        {
            t1 = _touchLog->CurrentTime();
        }

        if (_touchData.at(touchId)->Touch()->IsPhaseEndedOrCancelled())
        {
            s1 = data->LastTimestamp();
        }
        else
        {
            s1 = _touchLog->CurrentTime();
        }
    }

    return (s1 >= t0) && (s0 <= t1);

}

TouchIdVector Cluster::ActiveTouches()
{
    TouchIdVector activeIds = _touchLog->ActiveIds();
    return _touchLog->IntersectTouchIdVectors(&activeIds, &_touchIds);
}

TouchIdVector Cluster::Touches()
{
    return _touchIds;
}

bool Cluster::ConcurrentWith(Cluster::Ptr const & other, float temporalPadding) const
{
    double t0 = FirstTimestamp();
    double t1 = LastTimestamp() + temporalPadding;

    double s0 = other->FirstTimestamp();
    double s1 = other->LastTimestamp() + temporalPadding;

    return (s1 >= t0) && (s0 <= t1);
}

bool Cluster::ConcurrentWith(Cluster::Ptr const &other, bool useStaleInterval) const
{
    // _becameStaleTime is defaulted to the largest possible double.
    double t0 = FirstTimestamp();
    double t1 = _becameStaleTime;

    double s0 = other->FirstTimestamp();
    double s1 = other->_becameStaleTime;

    if (! useStaleInterval)
    {
        if (AllTouchesEnded())
        {
            t1 = LastTimestamp();
        }
        else
        {
            t1 = _touchLog->CurrentTime();
        }

        if (other->AllTouchesEnded())
        {
            s1 = other->LastTimestamp();
        }
        else
        {
            s1 = _touchLog->CurrentTime();
        }
    }

    return (s1 >= t0) && (s0 <= t1);

}

core::TouchId Cluster::FirstTouch() const
{
    if (_touchIds.empty())
    {
        return InvalidTouchId();
    }
    else
    {

        return *_touchIds.begin();
    }

}

// Note:  this potentially gets confused if clusters have been removed due to staleness.
// as part of the touchlogger/ClusterTracker integration we should take the opportunity
// to clean up bookkeeping and statistics.
int ClusterTracker::CurrentEventFingerCount()
{
    int count = 0;
    for (IdClusterPtrPair const & pair:_clusters)
    {
        count += pair.second->CountTouchesOfType(TouchClassification::Finger);
    }
    return count;
}

Cluster::Ptr ClusterTracker::NearestStaleCluster(Eigen::Vector2f p)
{

    Cluster::Ptr best;
    float d2Best = std::numeric_limits<float>::max();

    for (Cluster::Ptr const & cluster:_currentEventStaleClusters)
    {
        float d2 = (cluster->_center - p).squaredNorm();
        if (d2 < d2Best)
        {
            best   = cluster;
            d2Best = d2;
        }
    }

    return best;

}

Cluster::Ptr ClusterTracker::NearestActiveCluster(Vector2f p)
{
    Cluster::Ptr   best;
    float d2Best = std::numeric_limits<float>::max();

    for (Cluster::Ptr const & cluster:_currentEventActiveClusters)
    {

        if (cluster->_closedToNewTouches)
        {
            continue;
        }

        float d2 = (cluster->_center - p).squaredNorm();
        if (d2 < d2Best)
        {
            best = cluster;
            d2Best = d2;
        }
    }

    return best;

}

Cluster::Ptr ClusterTracker::NearestActiveNonPenCluster(Vector2f p)
{
    Cluster::Ptr   best;
    float d2Best = std::numeric_limits<float>::max();

    for (Cluster::Ptr cluster:_currentEventActiveClusters)
    {

        if (cluster->IsPenType() || cluster->IsFingerType() ||
            cluster->_closedToNewTouches)
        {
            continue;
        }

        float d2 = (cluster->_center - p).squaredNorm();
        if (d2 < d2Best)
        {
            best   = cluster;
            d2Best = d2;
        }
    }

    return best;
}

ClusterId InvalidClusterId()
{
    return ClusterId(-1);
}

vector<TouchId>::iterator Cluster::FindTouch(core::TouchId touchId)
{
    return std::find(_touchIds.begin(), _touchIds.end(), touchId);
}

// this removes it from the cluster, but not from classification
// the touch will still be known to the TouchLogger
bool Cluster::RemoveTouch(core::TouchId touchId)
{
    auto it = FindTouch(touchId);
    if (it == _touchIds.end())
    {
        return false;
    }

    _touchIds.erase(it);
    DebugAssert(!ContainsTouch(touchId));

    _touchData.erase(touchId);

    _touchLog->Data(touchId)->SetCluster(Cluster::Ptr());

    return true;
}

vector<core::TouchId> Cluster::ReclassifiableTouches() const
{
    vector<core::TouchId> out;

    for (IdDataRefPair pair:_touchData)
    {
        if (_commonData->proxy->IsReclassifiable(pair.second->Touch(), pair.second->Stroke()))
        {
            out.push_back(pair.first);
        }
    }

    return out;

}

// if a cluster contains a single reclassifiable touch, that makes the whole thing
// reclassifiable according to the current proxy's rules
bool Cluster::ContainsReclassifiableTouch() const
{
    for (IdDataRefPair pair:_touchData)
    {
        if (_commonData->proxy->IsReclassifiable(pair.second->Touch(), pair.second->Stroke()))
        {
            return true;
        }
    }

    return false;
}

bool Cluster::InsertTouch(core::TouchId touchId)
{
    if (!ContainsTouch(touchId))
    {
        _touchIds.push_back(touchId);
        _touchData[touchId] = _touchLog->Data(touchId);

        return true;
    }
    else
    {
        return false;
    }
}

Cluster::Cluster()
{
    _score       = 0.0f;
    _count       = 1.0f;
    _totalLength = 0.0f;
    _simultaneousTouches     = false;
    _wasInterior             = false;
    _ignorable               = false;
    _closedToNewTouches      = false;
    _checkForFingerSequence  = false;
    _edgeThumbState          = EdgeThumbState::NotThumb;

    _directionPrior = 1.0f;
    _penPrior       = 0.0f;
    _wasAtPalmEnd   = false;

    _penScore             = 0.0f;
    _meanTouchRadius      = 0.0f;
    _meanPenProbability   = 0.0f;
    _meanPalmProbability  = 0.0f;

    _maxTouchRadius       = 0.0f;
    _minTouchRadius       = std::numeric_limits<float>::max();

    _endedPenDirectionScore = 0.0f;

    _probabilityOneFlag = false;

    _becameStaleTime = std::numeric_limits<double>::max();
}

Cluster::Ptr Cluster::New()
{
    return make_shared<Cluster>();
}

Cluster::Ptr ClusterTracker::NewCluster(Vector2f center, double timestamp, TouchClassification defaultTouchType)
{

    if (_clusters.empty())
    {
        _currentEventBeganTimestamp = timestamp;
    }

    //DebugAssert(center.x() >= 0.0f && center.y() >= 0.0f);

    ClusterId id = ClusterId(_counter++);

    _clusters[id]       = Cluster::New();
    _clusters[id]->_id  = id;

    center.x() = std::max(center.x(), 0.0f);
    center.y() = std::max(center.y(), 0.0f);

    _clusters[id]->_center      = center;
    _clusters[id]->_touchLog    = _touchLog;
    _clusters[id]->_commonData  = _commonData;

    _clusters[id]->_clusterTouchType = defaultTouchType;

    _clusters[id]->_firstTimestamp = timestamp;
    _clusters[id]->_lastTimestamp  = timestamp;

    _currentEventActiveClusters.insert(_clusters[id]);

    _needComputeClusterOrder = true;

    return _clusters[id];
}

void ClusterTracker::Reset()
{
    _clusters.clear();
    _currentEventStaleClusters.clear();
    _currentEventActiveClusters.clear();

    _needComputeClusterOrder = true;
    _lastEventEndedTimestamp = CurrentTime();
    _currentEventBeganTimestamp = std::numeric_limits<double>::max();

    _currentEventStatistics = make_shared<ClusterEventStatistics>();

}

void ClusterTracker::RemoveUnusedStaleClusters()
{
    if (_currentEventActiveClusters.empty())
    {
        Reset();
        _commonData->proxy->OnClusterEventEnded();
    }
    else
    {
        std::set<Cluster::Ptr> removableClusters = _currentEventStaleClusters;

        // stale clusters can be removed so long as they are not concurrent with
        // reclassifiable clusters.
        for (Cluster::Ptr const & stale:_currentEventStaleClusters)
        {
            for (Cluster::Ptr const & cluster:_currentEventActiveClusters)
            {
                if (cluster->ContainsReclassifiableTouch())
                {
                    if (stale->ConcurrentWith(cluster, false))
                    {
                        removableClusters.erase(stale);
                    }
                }
            }
        }

        // now check the stale cluster for active touches or touches which
        // could be used by the PenEventClassifier.
        // if it could be, the cluster is not removable

        TouchId oldestReclassifiableTouch = _touchLog->OldestReclassifiableTouch();
        if (oldestReclassifiableTouch != InvalidTouchId())
        {
            Cluster::Ptr const &cluster = _touchLog->Cluster(oldestReclassifiableTouch);

            double  tCutoff                   = _touchLog->Data(oldestReclassifiableTouch)->FirstTimestamp();
            if (cluster)
            {
                tCutoff                        = cluster->FirstTimestamp();
            }

            // the entire cluster gets reclassified, so we need to use the timestamp from the earliest
            // touch in the cluster.
            tCutoff                          -= _commonData->proxy->PenEventClassifier()->_maxPenEventDelay;

            for (Cluster::Ptr const & cluster:_currentEventStaleClusters)
            {

                if (cluster->LastTimestamp() > tCutoff)
                {
                    removableClusters.erase(cluster);
                }
            }

        }

        for (Cluster::Ptr const & removable:removableClusters)
        {
            _currentEventStaleClusters.erase(removable);
            _clusters.erase(removable->_id);
        }

    }

}

void ClusterTracker::ForceAllClustersStale(double currentTimestamp)
{
    for (Cluster::Ptr const & cluster:_currentEventActiveClusters)
    {
        _currentEventStaleClusters.insert(cluster);
        cluster->_becameStaleTime = currentTimestamp;
        _needComputeClusterOrder = true;
    }

    _currentEventActiveClusters.clear();
}

    void ClusterTracker::MarkIfStale(Cluster::Ptr const & cluster)
{
    double currentTime = CurrentTime();

    float dt = currentTime - cluster->LastTimestamp();

    if (dt >= _staleInterval && cluster->AllTouchesEnded())
    {
        _currentEventActiveClusters.erase(cluster);
        _currentEventStaleClusters.insert(cluster);

        cluster->_becameStaleTime = currentTime;

        _needComputeClusterOrder = true;
    }
}

void ClusterTracker::MarkStaleClusters(double currentTimestamp)
{

    vector<Cluster::Ptr> newlyStale;

    for (Cluster::Ptr const & cluster:_currentEventActiveClusters)
    {
        float dt = currentTimestamp - cluster->LastTimestamp();

        if (dt >= _staleInterval && cluster->AllTouchesEnded())
        {
            newlyStale.push_back(cluster);
        }
    }

    for (Cluster::Ptr const & cluster:newlyStale)
    {
        _currentEventActiveClusters.erase(cluster);
        _currentEventStaleClusters.insert(cluster);

        cluster->_becameStaleTime = currentTimestamp;
        _needComputeClusterOrder  = true;
    }
}

void ClusterTracker::AddPointToCluster(Vector2f p, double timestamp, Cluster::Ptr const & cluster, core::TouchId touchId)
{
    _needComputeClusterOrder = true;

    float score = _commonData->proxy->IsolatedStrokesClassifier()->NormalizedScore(touchId);

    // it is safe to use _touchLog here since the touch is active.  in other places
    // it is possible the touchLog will have discarded data so we use the cluster's ptr.
    Stroke::Ptr const & stroke = _touchLog->Stroke(touchId);
    if (stroke->Size() > 1)
    {
        int lastIndex = stroke->LastValidIndex();
        cluster->_totalLength += (stroke->XY(lastIndex) - stroke->XY(lastIndex-1)).norm();
    }

    cluster->_lastTimestamp = timestamp;

    // update the best match with the new point
    float lambda = .15;
    cluster->_center = lambda * p + cluster->_center * (1.0f - lambda);

    cluster->_count++;

    float weightNew = 1.0f / (.0001f + cluster->_count);
    cluster->_score = weightNew * score + (1.0f - weightNew) * cluster->_score;

    bool newTouchAdded = cluster->InsertTouch(touchId);

    // If a new touch is added, we check if there are other active touches in the cluster
    if ( newTouchAdded && (! cluster->_simultaneousTouches))
    {

        for (TouchId existingId:cluster->_touchIds)
        {
            if (existingId != touchId)
            {
                auto touch = _touchLog->TouchWithId(existingId);
                if (touch &&
                   (! touch->IsPhaseEndedOrCancelled()))
                {
                    // Then there are already active touches in the cluster but we just added a new touch point
                    cluster->_simultaneousTouches = true;
                    break;
                }
            }
        }
    }

     // update size stats

    core::Touch::Ptr touch = _touchLog->TouchWithId(touchId);

    if (touch && touch->CurrentSample().TouchRadius())
    {
        float r  = *(touch->CurrentSample().TouchRadius());

        float lambda = .02f;
        if (cluster->_meanTouchRadius == 0.0f)
        {
            lambda = 1.0f;
        }

        cluster->_meanTouchRadius = lambda * r + (1.0f - lambda) * cluster->_meanTouchRadius;

        cluster->_maxTouchRadius = std::max(cluster->_maxTouchRadius, r);
        cluster->_minTouchRadius = std::min(cluster->_maxTouchRadius, r);

    }

    _commonData->proxy->TouchStatistics()[touchId]._clusterId = cluster->_id;
}

void  Cluster::RemoveOldTouches(double cutoffTime)
{
    auto copy = _touchIds;
    for (core::TouchId touchId : copy)
    {
        DebugAssert(_touchData.count(touchId));

        TouchData::Ptr const & touch = _touchData.at(touchId);
        if (touch->IsPhaseEndedOrCancelled())
        {
            double endedTime = touch->LastTimestamp();
            if (endedTime < cutoffTime &&
               (! _commonData->proxy->IsReclassifiable(_touchLog->TouchWithId(touchId), _touchLog->Stroke(touchId))))
            {
                RemoveTouch(touchId);
                _touchLog->RemoveTouch(touchId);
            }

        }
    }

}

float Cluster::TotalLength() const
{
    float totalLength = 0.0f;

    for (core::TouchId touchId:_touchIds)
    {
        DebugAssert(_touchData.count(touchId));
        totalLength += _touchData.at(touchId)->Stroke()->ArcLength();
    }
    return totalLength;
}

Eigen::Vector2f Cluster::CenterOfMass() const
{

    float totalMass = 0.0f;
    Vector2f center = Vector2f::Zero();

    for (core::TouchId touchId:_touchIds)
    {
        Stroke::Ptr const & stroke = _touchData.at(touchId)->Stroke();
        float weight = stroke->Size();

        Vector2f c = stroke->WeightedCenterOfMass();

        totalMass += weight;
        center    += c * weight;

    }

    center /= (.0001f + totalMass);
    return center;

}

int Cluster::PointCount() const
{
    int N = 0;

    for (core::TouchId touchId:_touchIds)
    {
        Stroke::Ptr const & stroke = _commonData->proxy->ClusterTracker()->Stroke(touchId);
        N += stroke->Size();
    }
    return N;
}

bool ClusterTracker::IsEndpoint(Cluster::Ptr const & cluster)
{
    vector<Cluster::Ptr> orderedClusters = FastOrderedClusters();

    if (orderedClusters.empty())
    {
        return false;
    }
    else
    {
        return cluster == orderedClusters.front() || cluster == orderedClusters.back();
    }
}

void ClusterTracker::RemoveTouchFromClassification(core::TouchId touchId)
{

    Cluster::Ptr cluster = _touchLog->Cluster(touchId);

    if (_commonData && _commonData->proxy && _commonData->proxy->_showDebugLogMessages)
    {
        //std::cerr << "\nREMOVE FROM CLASSIFICATION: " << touchId;
    }

    if (cluster)
    {
        cluster->RemoveTouch(touchId);

        if (cluster->_touchIds.empty())
        {
            cluster->_clusterTouchType = TouchClassification::RemovedFromClassification;
            _currentEventActiveClusters.erase(cluster);
            _currentEventStaleClusters.erase(cluster);
            _needComputeClusterOrder = true;
        }

    }

    _touchLog->RemoveTouch(touchId);

}

Cluster::Ptr ClusterTracker::ClusterOfTypeForPenDownEvent(TouchClassification touchType, PenEventId probeEvent)
{

    for (IdClusterPtrPair const & pair:_clusters)
    {
        if (pair.second->_clusterTouchType == touchType)
        {

            for (TouchId touchId:pair.second->_touchIds)
            {

                PenEventId bestEvent = _commonData->proxy->PenEventClassifier()->BestPenDownEventForTouch(touchId);
                if (bestEvent == probeEvent)
                {
                    return pair.second;
                }
            }

        }
    }

    return Cluster::Ptr();
}

vector<Cluster::Ptr> ClusterTracker::ConcurrentClusters(Cluster::Ptr const & probe, float temporalPadding)
{

    vector<Cluster::Ptr> concurrent;

    ClusterId otherId;
    Cluster::Ptr otherCluster;
    for (const auto & pair : _clusters)
    {
        tie(otherId, otherCluster) = pair;

        if ((otherId != probe->_id) && probe->ConcurrentWith(otherCluster, temporalPadding))
        {
            concurrent.push_back(otherCluster);
        }
    }

    return concurrent;
}

vector<Cluster::Ptr> ClusterTracker::ConcurrentClusters(Cluster::Ptr const & probe, bool useStaleInterval)
{

    vector<Cluster::Ptr> concurrent;

    ClusterId otherId;
    Cluster::Ptr otherCluster;
    for (const auto & pair : _clusters)
    {
        tie(otherId, otherCluster) = pair;

        if ((otherId != probe->_id) && probe->ConcurrentWith(otherCluster, useStaleInterval))
        {
            concurrent.push_back(otherCluster);
        }
    }

    return concurrent;

}

Eigen::MatrixXf ClusterTracker::DistanceMatrix(std::set<Cluster::Ptr> const & clusters)
{
    int nClusters = (int) clusters.size();

    Eigen::MatrixXf D(nClusters, nClusters);

    int m = 0;
    int n = 0;

    // This matrix is small so I didn't bother exploiting symmetry in the loop.
    for (Cluster::Ptr const & row:clusters)
    {
        n=0;
        for (Cluster::Ptr const & col:clusters)
        {

            Vector2f p = row->_center;
            Vector2f q = col->_center;

            D(m,n) = (p-q).norm();
            ++n;
        }
        ++m;
    }

    return D;
}

vector<Cluster::Ptr> ClusterTracker::FastOrderedClusters()
{

    if (_needComputeClusterOrder)
    {
        int N = (int) _currentEventActiveClusters.size();

        vector<Cluster::Ptr> bestOrder;

        if (N <= 6)
        {
            bestOrder = ExactOrderedClusters(_currentEventActiveClusters);
        }
        else
        {
            // try each possible pair of endpoints and then run a greedy furthest-insertion algorithm
            // to produce a path.  this works pretty well even in nasty cases.

            Eigen::MatrixXf D = DistanceMatrix(_currentEventActiveClusters);

            list<int> bestPath;
            float bestPathLength = std::numeric_limits<float>::max();

            for (int start = 1; start < N; ++start)
            {
                for (int finish = 0; finish < start; ++finish)
                {
                    // the int's in these lists represent active clusters in the order
                    // in which they appear in _currentEventActiveClusters
                    list<int> path;
                    list<int> freeList;

                    for (int j = 0; j < N; ++j)
                    {
                        if (j != start && j != finish)
                        {
                            freeList.push_back(j);
                        }
                    }

                    path.push_back(start);
                    path.push_back(finish);

                    // we will construct a path from start to finish
                    // we have N-2 nodes to insert into the path.  at each iteration
                    // we find a faraway node to add into the path
                    for (int k = 0; k < N-2; ++k)
                    {
                        float dFurthest = 0.0f;
                        list<int>::iterator furthestNode;
                        list<int>::iterator currentNode;

                        // first, find the guy in freeList whose nearest neighbor in path
                        // lies furthest away
                        for (currentNode = freeList.begin(); currentNode != freeList.end(); ++currentNode)
                        {
                            for (auto it = path.begin(); it != path.end(); ++it)
                            {
                                if (D(*it, *currentNode) > dFurthest)
                                {
                                    dFurthest = D(*it, *currentNode);
                                    furthestNode = currentNode;
                                }
                            }
                        }

                        // and now, find the best place to insert him in the tour
                        float dBest = std::numeric_limits<float>::max();

                        // we'll try to insert him between node1 and node2 and compute the arc length
                        list<int>::iterator bestLocation;
                        auto node1 = path.begin();
                        auto node2 = path.begin();
                        ++node2;

                        for (; node2 != path.end(); ++node2, ++node1)
                        {
                            float d_total = D(*furthestNode, *node1) + D(*furthestNode, *node2);
                            if (d_total < dBest)
                            {
                                dBest = d_total;
                                bestLocation = node2;
                            }
                        }

                        path.insert(bestLocation, *furthestNode);
                        freeList.erase(furthestNode);
                    }

                    float pathLength = 0.0f;
                    auto node1 = path.begin();
                    auto node2 = path.begin();

                    for (std::advance(node2,1); node2 != path.end(); ++node2, ++node1)
                    {
                        pathLength += D(*node1, *node2);
                    }

                    if (pathLength < bestPathLength)
                    {
                        bestPathLength   = pathLength;
                        bestPath         = path;
                    }

                    DebugAssert(path.front() == start && path.back() == finish);

                }
            }  // END OUTER LOOP

            vector<Cluster::Ptr> activeClusters(_currentEventActiveClusters.begin(), _currentEventActiveClusters.end());

            for (const auto & index : bestPath)
            {
                bestOrder.emplace_back(activeClusters[index]);
            }

        }

        MarkInteriorClusters();

        _needComputeClusterOrder = false;
        _orderedClustersCache.swap(bestOrder);
    }

    return _orderedClustersCache;

}

void ClusterTracker::MarkInteriorClusters()
{
    // don't bother marking ended pens.  they shouldn't get marked in the first place
    // and they make the calculation slow if we run the shortest-curve stuff.
    std::set<Cluster::Ptr> clusters;
    for (Cluster::Ptr const & cluster:_currentEventActiveClusters)
    {
        if (! (cluster->IsPenType() && cluster->AllTouchesEnded()))
        {
            clusters.insert(cluster);
        }

        if (! cluster->AllTouchesEnded())
        {
            cluster->_endedPenDirectionScore = CurrentEventStatistics()->_endedPenDirectionScore;
        }
    }

    if (clusters.size() > 6)
    {
        return;
    }

    vector<Cluster::Ptr> orderedClusters = _commonData->proxy->PenTracker()->CopyInPenToPalmOrder(ExactOrderedClusters(clusters));

    for (int j=1; j<int(orderedClusters.size())-1; j++)
    {
        Cluster::Ptr const & cluster = orderedClusters[j];
        if (cluster->_edgeThumbState != EdgeThumbState::NotThumb)
        {
            continue;
        }

        cluster->_wasInterior = true;
    }

    if (orderedClusters.size() > 1)
    {
        Cluster::Ptr p = orderedClusters.front();
        Cluster::Ptr q = orderedClusters.back();

        q->_wasAtPalmEnd = true;

        Eigen::Vector2f v  = p->_center - q->_center;

        q->_vOtherEndpoint =  v;
        p->_vOtherEndpoint = -v;
    }
}

// brute-force search for the shortest open polygon connecting the clusters.
// this gives a nice curve joining them.  we can basically ignore
// any touches in the interior since the pen cluster is always an endpoint.
// with only a handful of touches, brute-force performance is fine.
vector<Cluster::Ptr> ClusterTracker::ExactOrderedClusters(std::set<Cluster::Ptr> const & clusters)
{

    Eigen::MatrixXf D = DistanceMatrix(clusters);

    int N = (int) clusters.size();

    vector<Cluster::Ptr> bestPerm;
    vector<Cluster::Ptr> allClusters;

    // the algorithm permutes these int's, which index into allClusters.
    vector<int> positions;
    vector<int> bestPositions(N);
    int index = 0;
    for (Cluster::Ptr const & cluster:clusters)
    {
        allClusters.push_back(cluster);
        positions.push_back(index);
        ++index;
    }

    if (N <= 2)
    {
        for (Cluster::Ptr const & cluster:allClusters)
        {
            bestPerm.push_back(cluster);
        }
        return bestPerm;
    }

    float d_best = std::numeric_limits<float>::max();

    do
    {

        float d_curr = 0.0f;
        for (int j = 0; j < N-1; ++j)
        {
            d_curr += D(positions[j], positions[j+1]);
        }

        if (d_curr < d_best)
        {
            bestPositions  = positions;
            d_best         = d_curr;
        }

    }
    while (std::next_permutation(positions.begin(), positions.end()));

    for (int k = 0; k < N; ++k)
    {
        bestPerm.push_back(allClusters[bestPositions[k]]);
    }

    return bestPerm;

}

vector<core::TouchId> ClusterTracker::TouchesForCurrentClusters(bool activeClustersOnly)
{
    vector<core::TouchId> touchIds;

    for (IdClusterPtrPair const & pair:_clusters)
    {
        if (activeClustersOnly && pair.second->Stale())
        {
            continue;
        }

        touchIds.insert(touchIds.end(), pair.second->_touchIds.begin(), pair.second->_touchIds.end());
    }

    return touchIds;
}

Stroke::Ptr const & ClusterTracker::Stroke(core::TouchId id)
{
    return _touchLog->Stroke(id);
}

Cluster::Ptr ClusterTracker::NewClusterForTouch(TouchId touchId)
{
    Cluster::Ptr oldCluster = _touchLog->Cluster(touchId);

    if (oldCluster)
    {
        oldCluster->RemoveTouch(touchId);
    }

    Stroke::Ptr stroke = _touchLog->Stroke(touchId);

    Cluster::Ptr newCluster = NewCluster(stroke->LastPoint(), CurrentTime(), _commonData->proxy->TouchTypeForNewCluster());

    _touchLog->Data(touchId)->SetCluster(newCluster);

    for (int j = 0; j < stroke->Size(); ++j)
    {
        AddPointToCluster(stroke->XY(j), stroke->AbsoluteTimestamp(j), newCluster, touchId);
    }

    return newCluster;

}

void ClusterTracker::UpdateEventStatistics()
{
    for (core::TouchId touchId:_touchLog->ActiveIds())
    {
        if (_touchLog->Phase(touchId) == TouchPhase::Ended)
        {
            TouchClassification type = _commonData->proxy->CurrentClass(touchId);

            if (type == TouchClassification::Pen || type == TouchClassification::Eraser)
            {
                _currentEventStatistics->_endedPenCount++;
                _currentEventStatistics->_endedPenSmoothLength += _touchLog->Stroke(touchId)->Statistics()->_smoothLength;
                _currentEventStatistics->_endedPenArcLength    += _touchLog->Stroke(touchId)->Statistics()->_arcLength;

                PenTracker* penTracker = _commonData->proxy->PenTracker();
                float sepConfidence    = penTracker->Confidence();
                float dirChangeScore   = 1.0f - penTracker->DirectionChangingScore();

                float trackingConfidence = sepConfidence * dirChangeScore;
                float isCorrectEnd       = penTracker->AtPenEnd(_touchLog->Cluster(touchId), FastOrderedClusters(), true);

                if (trackingConfidence > .5f && isCorrectEnd != 1.0f)
                {
                    isCorrectEnd       = penTracker->AtPenEnd(_touchLog->Cluster(touchId), FastOrderedClusters(), true);
                }

                _currentEventStatistics->_endedPenDirectionScore += trackingConfidence * 2.0f * (isCorrectEnd - .5f);

            }
            else if (type == TouchClassification::Palm)
            {
                _currentEventStatistics->_endedPalmCount++;
                _currentEventStatistics->_endedPalmSmoothLength += _touchLog->Stroke(touchId)->Statistics()->_smoothLength;
                _currentEventStatistics->_endedPalmArcLength    += _touchLog->Stroke(touchId)->Statistics()->_arcLength;
            }
        }
    }
}

float ClusterTracker::NearestEndedPenDistance(Eigen::Vector2f p)
{
    Cluster::Ptr   best;
    float d2Best = std::numeric_limits<float>::max();

    for (Cluster::Ptr const & cluster:_currentEventActiveClusters)
    {
        bool isPen = cluster->IsPenType() || cluster->IsFingerType();

        if ((! isPen) || cluster->_closedToNewTouches)
        {
            continue;
        }

        float d2 = (cluster->_center - p).squaredNorm();
        if (d2 < d2Best)
        {
            best = cluster;
            d2Best = d2;
        }
    }

    if (! best)
    {
        return std::numeric_limits<float>::max();
    }
    else
    {
        return (best->_center - p).norm();
    }

}

float ClusterTracker::NearestActiveClusterDistance(Eigen::Vector2f p)
{
    Cluster::Ptr cluster = NearestActiveCluster(p);
    if (! cluster)
    {
        return std::numeric_limits<float>::max();
    }
    else
    {
        return (cluster->_center - p).norm();
    }
}

// strictly speaking there could be more than one
vector<Cluster::Ptr> ClusterTracker::NonEndedPenClusters()
{
    vector<Cluster::Ptr> pens;

    for (Cluster::Ptr const & cluster:_currentEventActiveClusters)
    {
        if (cluster->IsPenType() && (! cluster->_touchIds.empty()))
        {
            auto touch = _touchLog->TouchWithId(cluster->_touchIds.back());
            if (touch && (! touch->IsPhaseEndedOrCancelled()))
            {
                pens.push_back(cluster);
            }
        }
    }
    return pens;
}

void ClusterTracker::TouchesChanged(const std::set<core::Touch::Ptr> & touches)
{
    _touchLog->TouchesChanged(touches);

    // iOS cancelled all the touches, because an alert popped up, phone call, etc.
    if (_touchLog->AllCancelledFlag())
    {
        ForceAllClustersStale(CurrentTime());

        // this removes the clusters.  should we notify the touchLogger it can release resources?
        RemoveUnusedStaleClusters();
    }
    else
    {

        MarkStaleClusters(CurrentTime());
        RemoveUnusedStaleClusters();

        UpdateClusters();
    }
}

void ClusterTracker::UpdateClusters()
{
    IdTypeMap types;

    UpdateEventStatistics();

    for (core::TouchId touchId:_touchLog->ActiveIds())
    {

        Stroke::Ptr stroke = _commonData->proxy->ClusterTracker()->Stroke(touchId);

        Cluster::Ptr knownCluster = _touchLog->Cluster(touchId);

        if (! knownCluster)
        {

            Vector2f q           = stroke->WeightedCenterOfMass();

            Cluster::Ptr nearestCluster  = NearestActiveCluster(q);
            Cluster::Ptr useCluster;

            const float dMax = 150.0f;

            bool nearestWasPen = false;
            if (nearestCluster)
            {

                float dPen = NearestEndedPenDistance(q);

                // pens don't cluster -- create a new cluster for this guy if it seems like he
                // could be a pen.
                bool nearPen = dPen < dMax && NonEndedPenClusters().empty();
                if (nearestCluster->IsPenType() || nearestCluster->IsFingerType() || nearPen)
                {
                    nearestCluster.reset();
                    nearestWasPen  = true;
                }
            }

            if (! nearestCluster)
            {
                useCluster = NewCluster(q, CurrentTime(), _commonData->proxy->TouchTypeForNewCluster());
            }
            else
            {
                float d2 = (nearestCluster->_center - q).squaredNorm();

                if ( (d2 > (dMax * dMax)) && (_currentEventActiveClusters.size() < 6 || nearestWasPen))
                {
                    useCluster = NewCluster(q, CurrentTime(), _commonData->proxy->TouchTypeForNewCluster());
                }
                else
                {
                    useCluster = nearestCluster;
                }

            }

            _touchLog->Data(touchId)->SetCluster(useCluster);

            DebugAssert(useCluster);
            for (int j=0; j<stroke->Size(); j++)
            {
                AddPointToCluster(stroke->XY(j), stroke->AbsoluteTimestamp(j), useCluster, touchId);
            }

        }
        else
        {
            // doing this each time means we give weight to each point whether stationary or moving.
            // this is actually a feature since palms will update to the right place more rapidly.
            Vector2f p  = stroke->LastPoint();
            AddPointToCluster(p, CurrentTime(), knownCluster, touchId);
        }

    }

    MarkStaleClusters(CurrentTime());

    // stale clusters may still be relevant to classification if they coincide
    // with reclassifiable touches.
    RemoveUnusedStaleClusters();

    RemoveUnusedTouches();

}

void ClusterTracker::RemoveUnusedTouches()
{

    // this comes up if a cluster has a long lifetime -- irrelevant touches which will not take part in
    // classification hang around long past their useful life.
    // this loop removes anobody who ended long before the oldest reclassifiable touch arrived.
    TouchId oldestId  = _touchLog->OldestReclassifiableTouch();
    if (oldestId != InvalidTouchId())
    {
        auto touch = _touchLog->TouchWithId(oldestId);
        if (touch)
        {
            double cutoffTime = touch->FirstSample().TimestampSeconds() - _commonData->proxy->PenEventClassifier()->IrrelevancyTimeWindow();
            for (IdClusterPtrPair const & pair:_clusters)
            {
                pair.second->RemoveOldTouches(cutoffTime);
            }

        }
    }

    // finally, remove anybody we have declared to be irrelevant
    _touchLog->ClearUnclusteredEndedTouches();

}

}
}
