//
//  DumbStylus.cpp
//  Classification
//
//  Created by matt on 12/9/13.
//  Copyright (c) 2013 Peter Sibley. All rights reserved.
//

#include "DumbStylus.h"
#include "ClassificationProxy.h"



using namespace fiftythree::common;
using namespace fiftythree::sdk;

TouchType DumbStylusClassifier::ClusterType(ClusterId clusterId)
{
    if(_clusterTypes.count(clusterId))
    {
        return _clusterTypes[clusterId];
    }
    else
    {
        return TouchType::UntrackedTouch;
    }
}


TouchType DumbStylusClassifier::CurrentType(TouchId touchId)
{
    if(_touchTypes.count(touchId))
    {
        return _touchTypes[touchId];
    }
    else
    {
        return TouchType::UntrackedTouch;
    }
}

// todo -- just stubbed this out and will implement when we unify clusters and touchlog
// it's a pretty tiny amount of data anyway, just a few bytes per touch.
// alternatively, just clear all and store all data on each call to Reclassify.
void DumbStylusClassifier::ClearStaleData()
{
    
}


IdTypeMap DumbStylusClassifier::ReclassifyByHandedness()
{

    IdTypeMap changedTypes;
    std::vector<Cluster::Ptr> timeOrderedClusters = _commonData->proxy->ClusterTracker()->CurrentEventTimeOrderedClusters();

    BOOST_FOREACH(Cluster::Ptr const & cluster, timeOrderedClusters)
    {

        bool wasAtPalmEnd = _commonData->proxy->PenTracker()->WasAtPalmEnd(cluster);
        
        if(cluster->IsPossibleEdgeThumb() ||
           cluster->_wasInterior ||
           wasAtPalmEnd)
        {
            SetClusterType(cluster, TouchType::Palm, changedTypes);
        }
        else
        {
            // it isn't a thumb, it was never interior, and it's at the correct end.
            SetClusterType(cluster, TouchType::PenTip1, changedTypes);
        }
    }
    
    return changedTypes;
}



IdTypeMap DumbStylusClassifier::ReclassifyCurrentEvent()
{

    ClearStaleData();
    
    IdTypeMap changedTypes;
    if(HandednessLocked())
    {
        changedTypes = ReclassifyByHandedness();
        return changedTypes;
    }
    
    std::map<Cluster::Ptr, TouchType> newTypes;
    
    std::vector<Cluster::Ptr> timeOrderedClusters = _commonData->proxy->ClusterTracker()->CurrentEventTimeOrderedClusters();
    
    BOOST_FOREACH(Cluster::Ptr const & cluster, timeOrderedClusters)
    {
        
        
        if(cluster->_probabilityOneFlag)
        {
            newTypes[cluster] = cluster->_clusterTouchType;
            continue;
        }
        
        if(cluster->_simultaneousTouches || (cluster->_touchIds.size() > 1))
        {
            newTypes[cluster] = TouchType::Palm;
            cluster->_probabilityOneFlag = true;
            continue;
        }
        
        
        if(cluster->_wasInterior)
        {
            newTypes[cluster] = TouchType::Palm;
            cluster->_probabilityOneFlag = true;
            continue;
        }
        
        
        
        BOOST_FOREACH(common::TouchId touchId, cluster->_touchIds)
        {
            bool isPalm              = cluster->_wasInterior;
            bool probabilityOneFlag  = cluster->_wasInterior;
            
            if(! isPalm)
            {
                std::pair<TouchType, bool> pair = _commonData->proxy->IsolatedStrokesClassifier()->ClassifyForPinchOrPanGesture(touchId);
                probabilityOneFlag = probabilityOneFlag || pair.second;
                isPalm = isPalm || (pair.first == TouchType::Palm);
            }
            
            if(probabilityOneFlag)
            {
                cluster->_probabilityOneFlag = true;
            }
            
            if(isPalm)
            {
                newTypes[cluster] = TouchType::Palm;
            }
            else
            {
                newTypes[cluster] = TouchType::PenTip1;
            }
        }
    }
    
    
    Cluster::Ptr cluster;
    TouchType type;
    BOOST_FOREACH(tie(cluster, type), newTypes)
    {
        if(type == TouchType::PenTip1)
        {
            
            StrokeStatistics::cPtr stats = _touchLog->Stroke(cluster->_touchIds.back())->Statistics();
            
            Cluster::Ptr otherCluster;
            TouchType    otherType;
            BOOST_FOREACH(Cluster::Ptr const &otherCluster, _commonData->proxy->ClusterTracker()->ConcurrentClusters(cluster, false))
            {
                if(cluster == otherCluster || otherCluster->_clusterTouchType != TouchType::PenTip1)
                {
                    continue;
                }
                
                std::vector<TouchId> allIds   = cluster->_touchIds;
                std::vector<TouchId> otherIds = otherCluster->_touchIds;
                allIds.insert(allIds.end(), otherIds.begin(), otherIds.end());
                
                StrokeStatistics::cPtr otherStats = _touchLog->Stroke(otherCluster->_touchIds.back())->Statistics();
                
                VectorXf prior = _commonData->proxy->PenPriorForTouches(allIds);
                
                if (prior(0) != prior.maxCoeff())
                {
                    newTypes[cluster] = TouchType::Palm;
                }
                
                /*
                 if(otherStats->_arcLength > 88.0f &&
                 stats->_arcLength < 44.0f )
                 {
                 newTypes[cluster] = TouchType::Palm;
                 }
                 */
            }
        }
    }
    
    
    typedef std::pair<Cluster::Ptr, TouchType> ClusterTypePair;
    BOOST_FOREACH(ClusterTypePair pair, newTypes)
    {
        SetClusterType(pair.first, pair.second, changedTypes);
    }
    
    return changedTypes;
}

bool DumbStylusClassifier::HandednessLocked()
{
    ClusterEventStatistics::Ptr const & stats = _commonData->proxy->ClusterTracker()->CurrentEventStatistics();
        
    float lPen = stats->_endedPenArcLength;
    
    return lPen >= 88.0f && (stats->_endedPenDirectionScore > 2.0f);

}

/*
 The rules in the dumb-stylus case will probably differ from the rules in the smart-stylus case.
 To the extent that they share logic it should be refactored into some additional class.
 For right now, I just cut-and-paste the active stylus code and we'll see what happens during tuning.
 NB: this doesn't update the touch type stored on the cluster.  It just updates the dumb-stylus classifier's
 opinion.
 */
void DumbStylusClassifier::SetClusterType(Cluster::Ptr const & cluster, TouchType newType, IdTypeMap &changedTypes)
{
    
    float length   = cluster->TotalLength();
    float lifetime = cluster->LastTimestamp() - cluster->FirstTimestamp();
    
    bool onlyUpdateUnknownTouches = false;
    
    // the dumb stylus classifier puts a lot of faith in handedness.  once it locks on, it locks on.
    // when handedness isn't locked, we don't have enough confidence to convert pens to palms.
    if(cluster->IsPenType() && newType == TouchType::Palm)
    {
        if(! HandednessLocked())
        {
            if((length   > _commonData->proxy->_longPenLength ||
               lifetime > _commonData->proxy->_longDuration) &&
               (! cluster->_wasInterior))
            {
                onlyUpdateUnknownTouches = true;
            }
        }
    }
    
    if(! onlyUpdateUnknownTouches)
    {
        _clusterTypes[cluster->_id] = newType;
    }
    
    BOOST_FOREACH(common::TouchId touchId, cluster->_touchIds)
    {
        if(_commonData->proxy->CurrentClass(touchId) == TouchType::RemovedFromClassification)
        {
            continue;
        }
        
        if(onlyUpdateUnknownTouches && _commonData->proxy->CurrentClass(touchId) != TouchType::Unknown)
        {
            continue;
        }

        if(_touchTypes[touchId] != newType)
        {
            changedTypes[touchId] = newType;
        }
        
        _touchTypes[touchId] = newType;
    }
}























