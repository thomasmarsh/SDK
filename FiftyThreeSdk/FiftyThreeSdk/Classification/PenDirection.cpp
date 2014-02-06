//
//  PenDirection.cpp
//  Classification
//
//  Created by matt on 9/12/13.
//  Copyright (c) 2013 Peter Sibley. All rights reserved.
//

#include "FiftyThreeSdk/Classification/PenDirection.h"
#include <Eigen/Dense>
#include "FiftyThreeSdk/Classification/ClassificationProxy.h"
#include "FiftyThreeSdk/Classification/Cluster.h"
#include <boost/foreach.hpp>
#include "FiftyThreeSdk/Classification/Screen.h"
#include "FiftyThreeSdk/Classification/EigenLAB.h"
#include <algorithm>

using namespace Eigen;

namespace fiftythree
{
namespace classification
{

void PenTracker::UpdateLocations()
{
    
    std::vector<Cluster::Ptr> allClusters = _commonData->proxy->ClusterTracker()->FastOrderedClusters();
    
    
    float totalPenWeight  = 0.0f;
    float totalPalmWeight = 0.0f;
    
    Vector2f newPenLocation  = Vector2f::Zero();
    Vector2f newPalmLocation = Vector2f::Zero();
    
    // use weighted median -- means are too sensitive to outliers.
    // clustering doesn't really work since the palms don't cluster all that well.
    // we should probably add a special case for identifying thumbs near the edge.
    
    int N = allClusters.size();
    
    Vector2f medianPalm = Vector2f::Zero();
    
    if(N == 0)
    {
        
    }
    else if(N == 1)
    {
        
        medianPalm = allClusters[0]->_center;
    }
    else
    {
        
        VectorXf wPalm(N); // per-cluster palm weights
        std::vector<Vector2f> clusterCenters(N);
        
        for(int j=0; j<N; j++)
        {
            Cluster const& cluster = *(allClusters[j]);
            
            float palmWeight  = std::max(0.0f, cluster._meanPalmProbability / (.01f + cluster._meanPenProbability) -.3f );
            wPalm(j)          = palmWeight;
        
            clusterCenters[j] = cluster._center;
        }

        VectorXf knots(N);
        knots[0] = wPalm[0] * .5f;
        for(int j=1; j<N; j++)
        {
            knots[j] = knots[j-1] + .5f * wPalm[j-1] + .5f * wPalm[j];
        }
        
        
        float wEval = .5f * (knots[N-1] + knots[0]);
        
        VectorXf evalWeight(1);
        evalWeight[0] = wEval;
        std::vector<Vector2f> weightedMedianPalm = curves::Interp< std::vector<Vector2f> >(wPalm, clusterCenters, evalWeight);

        medianPalm = weightedMedianPalm[0];
    }
    
    bool onlyEdgeThumbs = true;
    BOOST_FOREACH(Cluster::Ptr const & clusterPtr, allClusters)
    {
        Cluster const& cluster = *clusterPtr;
        
        if(cluster._touchIds.empty())
        {
            continue;
        }
        
        curves::Stroke::Ptr stroke           = _clusterTracker->Stroke(cluster._touchIds.back());
        curves::StrokeStatistics::cPtr stats = stroke->Statistics();
        
        float palmWeight = 0.0f;
        float penWeight  = 0.0f;
        
        if((cluster._simultaneousTouches || cluster._wasInterior) && (! (cluster.IsPenType() || cluster.IsFingerType())))
        {
            palmWeight = 1.0f;
            penWeight  = 0.0f;
        }
        else
        {
            
            if(_commonData->proxy->ActiveStylusIsConnected())
            {
                // shrink by 1 to only use weights we're pretty confident about
                float penRatio   = std::max(0.0f, cluster._meanPenProbability  / (.01f + cluster._meanPalmProbability) - .3f);
                float palmRatio   = std::max(0.0f, cluster._meanPalmProbability / (.01f + cluster._meanPenProbability)  - .3f);
             
                penWeight  = penRatio;
                palmWeight = palmRatio;
            }
            else
            {
                if (cluster.IsPenType() || cluster.IsFingerType())
                {
                    penWeight = 1.0f;
                    palmWeight = 0.0f;
                }
                else
                {
                    penWeight = 0.0f;
                    palmWeight = 1.0f;
                }
            }
        }
        
        if((! cluster._touchIds.empty()) && (! (cluster.IsPenType() || cluster.IsFingerType())))
        {
            EdgeThumbState state = _commonData->proxy->IsolatedStrokesClassifier()->TestEdgeThumb(cluster._touchIds.back());
            
            
            // no matter what else we do, ignore possible edge palms
            if(state == EdgeThumbState::NotThumb)
            {
                onlyEdgeThumbs = false;
            }
            else
            {
                palmWeight = 0.0f;
            }
        }

        
        
        // ignore taps and strokes which don't carry enough info for stats to be reliable,
        // at least for pens
        const float tooShort   = 6.0f;
        const int   minPoints  = 8;
        const float longEnough = 22.0f;
        float lambda = 1.0f;
        if(stats->_arcLength < tooShort || (stroke->Size() < minPoints && true)) //(! stats->_arcLength > longEnough)))
        {
            lambda = 0.0f;
        }
        else if(stats->_arcLength < longEnough)
        {
            // increase linearly to one as stroke reaches threshold
            lambda = (cluster._totalLength - tooShort) / (longEnough - tooShort);
            lambda = lambda * lambda;
        }
        
        penWeight  *= lambda * stats->_smoothLength / 100.0f;

        
        newPenLocation  += penWeight * cluster._center;
        totalPenWeight  += penWeight;
        
        newPalmLocation += palmWeight * cluster._center;
        totalPalmWeight += palmWeight;
    
    }
    
    
    
    newPalmLocation /= (totalPalmWeight + .0001f);
    newPenLocation  /= (totalPenWeight + .0001f);
    
    if(onlyEdgeThumbs)
    {
        return;
    }
    
    if(totalPalmWeight > 0.0f)
    {
        _mruPalmWeight   = totalPalmWeight;
        _mruPalmLocation = newPalmLocation;
    }
    else
    {
        if (! onlyEdgeThumbs)
        {
            totalPalmWeight = _mruPalmWeight;
            newPalmLocation = _mruPalmLocation;
        }
    }
    
    Vector2f vPalm       = newPalmLocation - _palmLocation;
    Vector2f vRecentPalm = newPalmLocation - _recentPalmLocation;
    
    // controls how much faster the short timescale adapts than the normal one
    float recentMultiplier = 7.0f;
    
    float lambdaPalm;
    float lambdaRecentPalm;
    if(! TrackingPalmLocation())
    {
        lambdaPalm = 1.0f;
        lambdaRecentPalm = 1.0f;
    }
    else
    {
        lambdaPalm       = std::max(0.0f, std::min(.1f, 4.0f * std::sqrt(totalPalmWeight) / (.0001f + vPalm.norm())));
        lambdaRecentPalm = std::max(0.0f, std::min(recentMultiplier * .1f,
                                                   recentMultiplier * 4.0f * std::sqrt(totalPalmWeight) / (.0001f + vRecentPalm.norm())));
    }
    
    if(totalPalmWeight > 0.0f)
    {
        _palmLocation       = _palmLocation + lambdaPalm * vPalm;
        _recentPalmLocation = _recentPalmLocation + lambdaRecentPalm * vRecentPalm;

    }

    
    // ok, palm location is updated.
    // now update the direction vector for the pen.
    if(totalPenWeight > 0.0f && totalPalmWeight > 0.0f)
    {
        Vector2f newPenDisplacement = newPenLocation - newPalmLocation;

        Vector2f vPen       = newPenDisplacement - _penDisplacement;
        Vector2f vRecentPen = newPenDisplacement - _recentPenDisplacement;
        
        float lambdaPen       = std::max(0.0f, std::min(.1f, 4.0f * std::sqrt(std::sqrt(totalPalmWeight * totalPenWeight)) / (.0001f + vPen.norm())));
        float lambdaRecentPen = std::max(0.0f, std::min(recentMultiplier * .1f,
                                                        recentMultiplier * 4.0f * std::sqrt(std::sqrt(totalPalmWeight * totalPenWeight)) / (.0001f + vRecentPen.norm())));
        
        
        _penDisplacement       = _penDisplacement + lambdaPen * vPen;
        _recentPenDisplacement = _recentPenDisplacement + lambdaRecentPen * vRecentPen;
        
    }
    
       
    // force the pen to stay on screen.
    Vector2f penLocation = PenLocation();

    float screenWidth  = fiftythree::curves::Screen::MainScreen()._widthInPoints;
    float screenHeight = fiftythree::curves::Screen::MainScreen()._widthInPoints;
    
    _penDisplacement.x() = std::max(0.0f, std::min(screenWidth,  penLocation.x())) - _palmLocation.x();
    _penDisplacement.y() = std::max(0.0f, std::min(screenHeight, penLocation.y())) - _palmLocation.y();
    
}
    
bool      PenTracker::WasAtPalmEnd(Cluster::Ptr const &cluster)
{
    bool palmEnd = cluster->_wasAtPalmEnd;
    
    if(cluster->_endedPenDirectionScore < 2.0f)
    {
        Eigen::Vector2f vPalmToPen = _commonData->proxy->PenTracker()->PenDirection();
        Eigen::Vector2f vOtherEnd  = cluster->_vOtherEndpoint;
        
        // cluster's _wasAtPalmEnd is unreliable until we lock handedness, so we use another method
        if(vPalmToPen.norm() > 0.0f && vOtherEnd.norm() > 0.0f)
        {
            float dot = vPalmToPen.dot(vOtherEnd) / (vPalmToPen.norm() * vOtherEnd.norm());
            palmEnd   = dot > 0.0f;
        }
    }

    return palmEnd;
    
}

// when locations are very close together, the direction is hugely unstable.
// this happens, in particular, when they first start drawing on app launch.
// in such cases we don't want to put much faith in this prior.
// you could also encode this information in the length of the direction vector, but
// it seemed more readable to make Confidence() a method.
float PenTracker::Confidence() const
{
    
    float separation = _penDisplacement.squaredNorm();
    const float fullConfidence = 44.0f * 44.0f;
    
    // working with the square intentionally.  ramp up slowly.
    return std::min(separation / fullConfidence, 1.0f);
}
    
float PenTracker::DirectionChangingScore() const
{
    // if the recent displacement indicates a sudden change in direction
    float dot = _penDisplacement.dot(_recentPenDisplacement) / (.0001f + _penDisplacement.norm() * _recentPenDisplacement.norm());
    float dotScore = 1.0f - .5f * (1.0f + dot);

    return dotScore;
    
}

Eigen::Vector2f PenTracker::PenLocation() const
{
    return _palmLocation + _penDisplacement;
}

Eigen::Vector2f PenTracker::PalmLocation() const
{
    return _palmLocation;
}


Eigen::Vector2f PenTracker::PenDirection() const
{
    return _penDisplacement.normalized();
}

bool PenTracker::TrackingPalmLocation() const
{
    return _palmLocation != Vector2f::Zero();
}

bool PenTracker::TrackingPenDirection() const
{
    return _penDisplacement.norm() > 0.0f;
}
    
std::vector<Cluster::Ptr> PenTracker::CopyInPenToPalmOrder(std::vector<Cluster::Ptr> const & orderedClusters)
{
    if(orderedClusters.size() < 2)
    {
        return orderedClusters;
    }
    
    if(orderedClusters.size() < 2)
    {
        return orderedClusters;
    }
    
    Cluster const& cluster0 = *(orderedClusters[0]);
    Cluster const& clusterN = *(orderedClusters.back());
    
    Vector2f v0N = clusterN._center - cluster0._center;
    
    float dot    = v0N.normalized().dot(PenDirection());
    
    std::vector<Cluster::Ptr> penToPalm = orderedClusters;
    
    // we want pen end first, so reverse it.
    if(dot >= 0.0f)
    {
        std::reverse(penToPalm.begin(), penToPalm.end());
    }
    
    return penToPalm;    
}

    
bool PenTracker::AtPenEnd(Cluster::Ptr const & probeCluster, std::vector<Cluster::Ptr> const & orderedClusters, bool includePossibleThumbs)
{
    std::vector<Cluster::Ptr> penToPalm = CopyInPenToPalmOrder(orderedClusters);
    
    BOOST_FOREACH(Cluster::Ptr cluster, penToPalm)
    {
        if(cluster == probeCluster)
        {
            return true;
        }

        // ordered clusters may include ended pens, so we need to keep looking for our touch.
        if(cluster->IsPenType() ||
           (includePossibleThumbs && cluster->_edgeThumbState == EdgeThumbState::Possible) ||
           cluster->_edgeThumbState == EdgeThumbState::Thumb)
        {
            continue;
        }
        else
        {
            break;
        }
        
        
    }
    return false;
    
}
    
Cluster::Ptr PenTracker::PenEndCluster(std::vector<Cluster::Ptr> const & orderedClusters, bool ignorePossibleThumbs)
{
    Cluster::Ptr const& cluster0 = orderedClusters[0];
    Cluster::Ptr const& clusterN = orderedClusters.back();
    
    Vector2f v0N = clusterN->_center - cluster0->_center;
    
    float dot    = v0N.normalized().dot(PenDirection());
    
    Cluster::Ptr pen;
    if(dot > 0.0f)
    {
        for(int j=orderedClusters.size(); j--; )
        {
            
            EdgeThumbState state = orderedClusters[j]->_edgeThumbState;
            if (state != EdgeThumbState::Thumb && ((! ignorePossibleThumbs) || state != EdgeThumbState::Possible))
            {
                pen = orderedClusters[j];
            }
        }
    }
    else
    {
        for(int j=0; j < orderedClusters.size(); j++ )
        {
            EdgeThumbState state = orderedClusters[j]->_edgeThumbState;
            if (state != EdgeThumbState::Thumb && ((! ignorePossibleThumbs) || state != EdgeThumbState::Possible))
            {
                pen = orderedClusters[j];
            }
        }
    }
    
    return pen;
}

Cluster::Ptr PenTracker::PalmEndCluster(std::vector<Cluster::Ptr> const & orderedClusters)
{
    Cluster::Ptr const& cluster0 = orderedClusters[0];
    Cluster::Ptr const& clusterN = orderedClusters.back();
    
    Vector2f v0N = clusterN->_center - cluster0->_center;
    
    float dot    = v0N.normalized().dot(PenDirection());

    if(dot < 0.0f)
    {
        return clusterN;
    }
    else
    {
        return cluster0;
    }
    
}

Eigen::VectorXf PenTracker::UpdateDirectionPrior(std::vector<Cluster::Ptr> const &orderedClusters) const
{
    //Eigen::VectorXf directionPrior(orderedClusters.size(), .5f);
    
    Eigen::VectorXf directionPrior = VectorXf::Constant(orderedClusters.size(), 1.0f);
    
    if (orderedClusters.size() > 1 && Confidence() > 0.0f)
    {
        Vector2f penDirection   = PenDirection();
        
        Cluster const& cluster0 = *(orderedClusters[0]);
        Cluster const& clusterN = *(orderedClusters.back());
        
        Vector2f v0N = clusterN._center - cluster0._center;
        
        // if dot is positive, we feel that cluster N is the pen and 0 is the palm.
        // we interpret the magnitude of the dot as a measure of confidence.
        // if they're orthogonal, dot will be zero and this prior will have no effect.
        float dot    = Confidence() * v0N.normalized().dot(penDirection);
        
        std::vector<Vector2f> clusterCenters;
        BOOST_FOREACH(Cluster::Ptr const & cluster, orderedClusters)
        {
            clusterCenters.push_back(cluster->_center);
        }
        
        // an increasing vector starting at zero, providing an arclength coordinate on the curve
        VectorXf arcLength = curves::CumSum0NormDiff(clusterCenters);
        

        
        // for any ended pens we basically want to ignore them for the purpose of computing lengths
        // so equate arc lengths at either end of the curve
        for (int k=0; k<arcLength.size()-1; k++)
        {
            Cluster::Ptr cluster = orderedClusters[k];
            if (cluster->IsPenType() && cluster->AllTouchesEnded())
            {
                for (int j=0; j<=k; j++)
                {
                    arcLength[j] = arcLength[k+1];
                }
            }
            else
            {
                break;
            }
        }

        // now get the other end
        for (int k=arcLength.size()-1; k>0; k--)
        {
            Cluster::Ptr cluster = orderedClusters[k];
            if (cluster->IsPenType() && cluster->AllTouchesEnded())
            {
                for (int j=arcLength.size()-1; j>=k; j--)
                {
                    arcLength[j] = arcLength[k-1];
                }
            }
            else
            {
                break;
            }
        }

        
        
        // normalize from 0 to 1.
        arcLength.array() -= arcLength.minCoeff();
        if(arcLength.maxCoeff() > 0.0f)
        {
            arcLength /= arcLength.maxCoeff();
        }
        
        
        // flip direction when dot is telling us the pen is at the other end
        if(dot < 0.0f)
        {
            arcLength = 1.0f - arcLength.array();
        }
        
        // TUNING -- this is the smallest probability that handedness can assign.
        // probabilities will go from handednessWeight to 1.
        float handednessWeight = .3f;
        
        // shrink actual min probability towards 1 based on confidence.
        float confidence = Confidence();
        float pMin       = 1.0f - (confidence * (1.0f - handednessWeight));
        
        arcLength = pMin + arcLength.array() * (1.0f - pMin);
        
        float maxIndex = orderedClusters.size();
        for(int k=0; k<orderedClusters.size(); k++)
        {
            Cluster const & cluster = *(orderedClusters[k]);
            
            if (cluster.IsPenType() && cluster.AllTouchesEnded())
            {
                // if a rightie draws to the left of a not-yet-stale pen cluster, this will decrease
                // the prior unfairly.  don't make updates.
                directionPrior[k] = cluster._directionPrior;
                continue;
            }
            
            directionPrior[k] = powf(float(k+1) / maxIndex, dot);
            
        }
        
        if(directionPrior.maxCoeff() > 0.0f)
        {
            directionPrior /= directionPrior.maxCoeff();
        }
        
        for (int k=0; k<orderedClusters.size(); k++)
        {
            
            Cluster & cluster = *(orderedClusters[k]);
            
            if (! (cluster.IsPenType() && cluster.AllTouchesEnded()))
            {
                cluster._directionPrior = std::min(cluster._directionPrior, directionPrior[k]);
            }
            
        }
        
    }
    return directionPrior;
}



}
}













