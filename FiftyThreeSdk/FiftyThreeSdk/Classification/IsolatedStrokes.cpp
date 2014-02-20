//
//  IsolatedStrokes.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include <math.h>
#include <numeric>

#include "Common/Eigen.h"
#include "FiftyThreeSdk/Classification/ClassificationProxy.h"
#include "FiftyThreeSdk/Classification/EigenLAB.h"
#include "FiftyThreeSdk/Classification/FiniteDifferences.h"
#include "FiftyThreeSdk/Classification/IsolatedStrokes.h"
#include "FiftyThreeSdk/Classification/Quadrature.h"
#include "FiftyThreeSdk/Classification/Screen.h"

using namespace Eigen;

namespace fiftythree {
namespace sdk {

ScoreCalibration::ScoreCalibration() {

}

ScoreCalibration::Ptr ScoreCalibration::New()
{
    return ScoreCalibration::Ptr(new ScoreCalibration);
}

NPCalibration::NPCalibration() {

}

NPCalibration::Ptr NPCalibration::New()
{
    return NPCalibration::Ptr(new NPCalibration);
}

BayesCalibration::BayesCalibration() {

}

BayesCalibration::Ptr BayesCalibration::New()
{
    return BayesCalibration::Ptr(new BayesCalibration);
}

AdaboostCalibration::AdaboostCalibration() {

}

AdaboostCalibration::Ptr AdaboostCalibration::New()
{
    return AdaboostCalibration::Ptr(new AdaboostCalibration);
}

StrokeChunkLog::Ptr StrokeChunkLog::New() {
    return StrokeChunkLog::Ptr(new StrokeChunkLog);
}

StrokeChunkLog::StrokeChunkLog() {
    _index = -1;
    _updateFlag = false;
    _logLikelihoods = Eigen::MatrixXf::Zero(1, 2);
}

StrokeChunkLog::StrokeChunkLog(int chunkIndex) {
    _index = chunkIndex;
    _updateFlag = true;
    _logLikelihoods = Eigen::MatrixXf::Zero(1, 2);
}

StrokeChunkLog::Ptr StrokeChunkLog::New(int chunkIndex) {
    return StrokeChunkLog::Ptr(new StrokeChunkLog(chunkIndex));
}

std::pair<TouchType, bool> IsolatedStrokesClassifier::ClassifyForPinchOrPanGesture(common::TouchId touchId)
{
    Stroke::Ptr stroke            = _clusterTracker->Stroke(touchId);

    Cluster::Ptr cluster          = _clusterTracker->Cluster(touchId);

    if(! cluster)
    {
        DebugAssert(false);
        return TypeBoolPair(TouchType::Palm, false);
    }

    StrokeStatistics::cPtr stats  = stroke->EarlyStatistics();

    float totalAbsK              = stats->_totalAbsoluteD2InSpace;
    float L                      = stats->_arcLength;

    float normalD2   = stats->_normalD2  / (.0001f + L);

    float totalKScore  = std::max(1.0f - totalAbsK / (.0001f + L), 0.0f);

    float normalKScore  = std::max(1.0f - normalD2, 0.0f);

    float normalJerk   = stats->_normalD3     / (.0001f + L);
    float tangentJerk  = stats->_tangentialD3 / (.0001f + L);

    float normalD4     = stats->_normalD4     / (.0001f + L);
    float tangentD4    = stats->_tangentialD4 / (.0001f + L);

    float jerkOverK    = normalJerk / totalAbsK;
    if(totalAbsK == 0.0f)
    {
        jerkOverK = 0.0f;
    }

    float jerkNOverT = normalJerk / tangentJerk;
    if(tangentJerk == 0.0f)
    {
        if(normalJerk > 0.0f)
        {
            jerkNOverT = 1000.0f;
        }
        else
        {
            jerkNOverT = 0.0f;
        }
    }

    float d4NOverT = normalD4 / tangentD4;
    if(tangentD4 == 0.0f)
    {
        if(normalD4 > 0.0f)
        {
            d4NOverT = 1000.0f;
        }
        else
        {
            d4NOverT = 0.0f;
        }
    }

    float d4TOverK;
    float d4NOverK;

    float jerkTOverK;
    float jerkNOverK;

    d4TOverK   = stats->_tangentialD4   /   (1.0f + stats->_normalD2);
    d4NOverK   = stats->_normalD4       /   (1.0f + stats->_normalD2);

    jerkTOverK = stats->_tangentialD3   /   (1.0f + stats->_normalD2);
    jerkNOverK = stats->_normalD3       /   (1.0f + stats->_normalD2);

    float pFinger = sqrtf(totalKScore * normalKScore);
    if(normalKScore < totalKScore)
    {
        // kScore is a uses only normal acceleration so if it is more confident, use it.
        pFinger = normalKScore;
    }

    if(! _clusterTracker->TouchWithId(touchId)->IsPhaseEndedOrCancelled())
    {
        std::max(stats->_maxDeltaT, float(_clusterTracker->CurrentTime() - stroke->LastAbsoluteTimestamp()));
    }
    float dt    = stroke->LastAbsoluteTimestamp() - stroke->FirstAbsoluteTimestamp();
    float vMean = L / (.0001f + dt);

    float lifespan   = _clusterTracker->CurrentTime() - stroke->FirstAbsoluteTimestamp();

    bool okZeroLength = true;
    if(stats->_arcLength < 0.00001f && lifespan > 1.5f / 60.0f)
    {
        okZeroLength = false;
    }

    float npVoteScore = 1.0f;
    float bayesScore  = 1.0f;
    float convexScore = 1.0f;
    float boostScore  = 1.0f;
    if(TouchIdIsolatedSize(touchId) >= 4)
    {
        bayesScore  = BayesLikelihoodScore(touchId);
        npVoteScore = NPVoteScoreWithFalsePositiveRate(touchId, .02f);
        convexScore = ConvexScore(touchId);
        boostScore  = AdaboostScore(touchId);
    }

    if(true
       && okZeroLength
       && (! cluster->_wasInterior)
       && (stats->_smoothLength > 0.0f || stroke->Size() < 5)
       && (stats->_arcLength > 0.0f || stroke->Size() <= 3)
       && (lifespan > .02f)
       && vMean > 5.0f
       && npVoteScore > .01f
       )
    {

        float confidence = std::max(0.0f, stats->_arcLength - 11.0f);
        confidence       = confidence / (1.0f + confidence);

        if(L > 22.0f && npVoteScore > .99f)
        {
            return TypeBoolPair(TouchType::PenTip1, true);
        }
        else
        {
            return TypeBoolPair(TouchType::PenTip1, false);
        }
    }
    else
    {

        if(npVoteScore < .01f)
        {
            return TypeBoolPair(TouchType::Palm, true);
        }
        else
        {
            return TypeBoolPair(TouchType::Palm, false);
        }
    }

}

EdgeThumbState IsolatedStrokesClassifier::TestEdgeThumb(common::TouchId touchId)
{
    Cluster::Ptr cluster = _clusterTracker->Cluster(touchId);
    if(! cluster || (! _commonData->proxy->ClusterTracker()->IsEndpoint(cluster)))
    {
        return EdgeThumbState::NotThumb;
    }

    Stroke::Ptr stroke           = _clusterTracker->Stroke(touchId);
    if(! stroke)
    {
        return EdgeThumbState::NotThumb;
    }

    StrokeStatistics::cPtr stats = stroke->Statistics();
    if(! stats)
    {
        return EdgeThumbState::NotThumb;
    }

    float dt = _clusterTracker->CurrentTime() - stroke->FirstAbsoluteTimestamp();

    float maxTravel   = stats->_maxTravel;
    float npVoteScore = 1.0f;

    float deltaTScore = stats->_maxDeltaT;

    deltaTScore = std::max(deltaTScore, float(_clusterTracker->CurrentTime() - stroke->LastAbsoluteTimestamp()));

    float score = maxTravel * npVoteScore / (.2f + dt);

    float dEdge = Screen::MainScreen().DistanceToNearestEdge(stroke->LastPoint());

    if(dEdge < 44.0f)
    {

        // istap probably does nothing here since dt > .3f rules it out.  leaving in case the rules change.
        if(dt > .3f && ( (score < 10.0f && (! IsTap(touchId))) || deltaTScore > .2f))
        {
            return EdgeThumbState::Thumb;
        }
        else
        {
            if (_clusterTracker->Phase(touchId) != common::TouchPhase::Ended)
            {
                return EdgeThumbState::Possible;
            }
            else
            {
                // could still be palm, we just don't think it's a thumb
                return EdgeThumbState::NotThumb;

            }
        }
    }
    else
    {
        return EdgeThumbState::NotThumb;
    }

}

void IsolatedStrokesClassifier::MarkEdgeThumbs()
{
    std::vector<Cluster::Ptr> orderedClusters = _commonData->proxy->ClusterTracker()->FastOrderedClusters();
    std::vector<Cluster::Ptr> penToPalm       = _commonData->proxy->PenTracker()->CopyInPenToPalmOrder(orderedClusters);

    // reset everything in case orientation changed and we changed our minds
    BOOST_FOREACH(Cluster::Ptr const & cluster, penToPalm)
    {
        cluster->_edgeThumbState = EdgeThumbState::NotThumb;
    }

    BOOST_FOREACH(Cluster::Ptr const & cluster, penToPalm)
    {

        if(! cluster->_touchIds.empty())
        {
            common::TouchId touchId  = cluster->_touchIds.back();
            cluster->_edgeThumbState = TestEdgeThumb(touchId);

            // go until we hit something other than a thumb
            if (cluster->_edgeThumbState == EdgeThumbState::NotThumb)
            {
                break;
            }
        }
    }

    // we don't care about edge thumbs on the "palm" side.  they cause no harm.
    // the ones we want to get rid of are thumbs which make the pen look like an interior cluster.
    // in the dumb-stylus case it is even worse since we hard-classify interior clusters to palm.

    if(_commonData->proxy->HandednessLocked())
    {
        BOOST_REVERSE_FOREACH(Cluster::Ptr const & cluster, penToPalm)
        {
            if(! cluster->_touchIds.empty())
            {
                common::TouchId touchId  = cluster->_touchIds.back();
                cluster->_edgeThumbState = TestEdgeThumb(touchId);

                // go until we hit something other than a thumb
                if (cluster->_edgeThumbState == EdgeThumbState::NotThumb)
                {
                    break;
                }
            }
        }
    }

}

bool IsolatedStrokesClassifier::IsEdgeThumb(common::TouchId touchId)
{

    Cluster::Ptr cluster = _clusterTracker->Cluster(touchId);
    if(! cluster)
    {
        return false;
    }

    return cluster->_edgeThumbState == EdgeThumbState::Thumb;

}

IdTypeMap IsolatedStrokesClassifier::ReclassifyActiveTouches()
{
    std::vector<common::TouchId> ids = _clusterTracker->ActiveIds();

    IdTypeMap types;

    bool useNPVotingClassifier = false;

    if (useNPVotingClassifier) {
        for (int i=0; i<ids.size(); ++i) {
            //types.insert(IdTypePair(ids[i], NPLikelihoodTest(ids[i])));
            types.insert(IdTypePair(ids[i], NPVotingTest(ids[i])));
        }
    }
    else {
        for (int i=0; i<ids.size(); ++i) {

            Stroke::Ptr stroke = _clusterTracker->Stroke(ids[i]);

            float score = Score(*stroke);

            _scores[ids[i]] = score;

            // above this, it is a palm.
            // basically pen strokes don't go much above it, but sometimes palm strokes do go below it.
            // we could get a rule which weeded out the obvious palms by raising the threshold; i don't think
            // i ever saw a pen go above 1.5 and palms go all the way to 2.
            const float thresh = .957f;

            if(score > thresh)
            {
                types.insert(IdTypePair(ids[i],TouchType::Palm));
            }
            else
            {
                types.insert(IdTypePair(ids[i], TouchType::PenTip1));
            }
        }
    }

    return types;
}

float IsolatedStrokesClassifier::Score(common::TouchId id)
{
    return _scores[id];
}

float IsolatedStrokesClassifier::NormalizedScore(common::TouchId id)
{

    float score = Score(*(_clusterTracker->Stroke(id)));

    return std::max(0.0f, std::min(1.0f, score));
}

bool IsolatedStrokesClassifier::IsTap(common::TouchId touchId)
{
    common::Touch::Ptr touch = _clusterTracker->TouchWithId(touchId);

    if(!touch || touch->Phase() != common::TouchPhase::Ended)
    {
        return false;
    }

    Stroke::Ptr const & stroke = _clusterTracker->Stroke(touchId);

    float dt = stroke->LastAbsoluteTimestamp() - stroke->FirstAbsoluteTimestamp();
    float L  = stroke->ArcLength();

    float lambda = std::min(1.0f, std::max(0.0f, (dt - _commonData->proxy->_minTapDuration) / (_commonData->proxy->_maxTapDuration - _commonData->proxy->_minTapDuration)));
    float maxLength = lambda * _commonData->proxy->_maxTapArcLengthAtMaxDuration + (1.0f - lambda) * _commonData->proxy->_maxTapArcLengthAtMinDuration;

    return (L < maxLength) && (dt > _commonData->proxy->_minTapDuration) && (dt < _commonData->proxy->_maxTapDuration);
}

TouchType IsolatedStrokesClassifier::TestFingerVsPalm(Cluster::Ptr const & cluster)
{
    // todo: use some short-stroke isolated stuff here.
    if (cluster->_totalLength >= _commonData->proxy->_minFingerIsolatedStrokeTravel)
    {
        return TouchType::Finger;
    }
    else
    {
        return TouchType::Palm;
    }
}

bool IsolatedStrokesClassifier::IsPalmCluster(Cluster::Ptr const & cluster)
{

    // PARAMETER -- what's the optimal rule here?  the second clause handles
    // short strokes as a separate case, but we should learn a joint distribution based on score
    // and length to better account for this.

    if(cluster->_score > .33)
    {
        return true;
    }
    else if(cluster->_totalLength < 44.0f && cluster->_score > .25)
    {
        return true;
    }

    return false;

}

float IsolatedStrokesClassifier::Score(Stroke  & stroke)
{
    int N = (int) stroke.Size();
    if(N < 3) return 1.5f;

    StrokeStatistics::cPtr stats = stroke.Statistics();
    float totalAbsK              = stats->_totalSquaredD2InSpace;
    //float totalAbsK              = stats->_totalNormalAcceleration;
    float L                      = stats->_arcLength;

    float totalAbsKOverL         = totalAbsK / (.0001f + L*L);

    float varT                   = stats->_dtVariance;

    // magic from MATLAB brute force search over the training corpus
    // this blend with a threshold of .957 does well
    float score = totalAbsKOverL + 0.0f * varT;

    return score;

}

Eigen::VectorXf IsolatedStrokesClassifier::ScoresForId(common::TouchId id) {

    //if (_touchIdChunkIndexMap.count(id) < 1) {
    if (_touchIdChunkData.count(id) < 1) {
        UpdateIdStoredData(id);
    }

    if (TouchIdIsolatedSize(id) < 4) {
        // You shouldn't be calling this function on this id
        DebugAssert(false);
    }

    // I'm not sure that anything bad will happen if this fails,
    // but my guess is that numbers are garbage
    //DebugAssert(stroke.Size() > 3);

    Stroke::Ptr stroke = _clusterTracker->Stroke(id);

    Eigen::VectorXf baseScores(_scoreData->_statScoreCount);
    Eigen::VectorXf chosenScores(_scoreData->_chosenScoreCount);
    int lastIndex = isolatedBatchThresholds[_touchIdChunkData[id]->_index] - 1;

    Eigen::VectorXf s = stroke->ArclengthParameterMap(lastIndex);
    if ( ( (Diff(s)).array() <= 1e-4f ).any() ) {
        // I've only seen this happen with palms, and it's very rare anyway (~ 1 / 3e4)
        chosenScores.fill(1e6f);
        return chosenScores;
    }

    Eigen::VectorXf t = stroke->RelativeTimestampMap(lastIndex);

    // We call the array that we continuously update "data". This is to
    // minimize allocations
    Eigen::MatrixX2f data = stroke->XYMatrixMap(lastIndex);

    float logL = log(s(s.size()-1));
    float logT = log(t(t.size()-1));

    // Can probably optimize Quadrature.h so that computing weights is unnecessary
    Eigen::VectorXf weights = TrapezoidRuleWeights(t);

    //std::vector<Eigen::MatrixX2f> derivatives = CumNthDerivative(t, XY, 3);

    //Eigen::MatrixX2f velocity = derivatives[1];
    //Eigen::MatrixX2f acceleration = derivatives[2];
    //Eigen::MatrixX2f jerk = derivatives[3];

    // We don't use 1-2
    //MaxAndL2Norm(velocity, weights, baseScores, 0);

    // Turn data to velocity
    IncrementalDerivative(t, data, 0, 1);
    Eigen::MatrixX2f velocity = data;

    // Turn data to acceleration
    IncrementalDerivative(t, data, 1, 2);
    MaxAndL2Norm(data, weights, baseScores, 2);

    // Acceleration orthogonalized against velocity
    Eigen::MatrixX2f orthTemp = OrthogonalizeXAgainstY(data, velocity);
    MaxAndL2Norm(orthTemp, weights, baseScores, 6);

    // Turn data to jerk
    IncrementalDerivative(t, data, 2, 3);
    MaxAndL2Norm(data, weights, baseScores, 4);

    // Jerk orthogonalized against velocity
    orthTemp = OrthogonalizeXAgainstY(data, velocity);

    MaxAndL2Norm(orthTemp, weights, baseScores, 8);

    // We don't use 10-11
    //jtemp = curves::OrthogonalizeXAgainstY(jerk, acceleration);
    //MaxAndL2Norm(jtemp, weights, baseScores, 10);

    // Normalized to cross-validation error
    // We Don't use 12-13
    //NthDerivativeToCrossValidation(t, acceleration, 2);
    //MaxAndL2Norm(acceleration, weights, baseScores, 12);

    // We don't use 14-15
    //NthDerivativeToCrossValidation(t, jerk, 3);
    //MaxAndL2Norm(jerk, weights, baseScores, 14);

    ////// Using arclength
    data = stroke->XYMatrixMap(lastIndex);
    weights = TrapezoidRuleWeights(s);
    //Eigen::MatrixX2f arclengthXY = stroke->ArclengthXYMatrixMap();

    //std::vector<Eigen::MatrixX2f> sderivatives = CumNthDerivative(s, XY, 3);

    // We don't use 16-17
    //velocity = sderivatives[1];
    //MaxAndL2Norm(velocity, weights, baseScores, 16);

    //acceleration = sderivatives[2];
    // We don't use 18-19
    //MaxAndL2Norm(acceleration, weights, baseScores, 18);

    // We don't use 20-21
    //jerk = sderivatives[3];
    //MaxAndL2Norm(jerk, weights, baseScores, 20);

    // Orthogonalized against each other
    // We don't use 22-23
    //atemp = curves::OrthogonalizeXAgainstY(acceleration, velocity);
    //MaxAndL2Norm(atemp, weights, baseScores, 22);

    // We don't use 24-25
    //jtemp = curves::OrthogonalizeXAgainstY(jerk, velocity);
    //MaxAndL2Norm(jtemp, weights, baseScores, 24);

    // We don't use 26-27
    //jtemp = curves::OrthogonalizeXAgainstY(jerk, acceleration);
    //MaxAndL2Norm(jtemp, weights, baseScores, 26);

    // Data to acceleration
    IncrementalDerivative(s, data, 0, 2);

    // Normalized to cross-validation error
    NthDerivativeToCrossValidation(s, data, 2);
    MaxAndL2Norm(data, weights, baseScores, 28);
    NthDerivativeFromCrossValidation(s, data, 2);

    // Data to jerk
    IncrementalDerivative(s, data, 2, 3);

    NthDerivativeToCrossValidation(s, data, 3);
    MaxAndL2Norm(data, weights, baseScores, 30);

    ///// Now stats for s(t)
    //t = stroke->ArclengthRelativeTimestampMap();
    //s = stroke->UpsampledArclengthParameterMap();
    //DebugAssert(s.size() == t.size());

    baseScores(39) = Variance(Diff(s));

    weights = TrapezoidRuleWeights(t);
    //std::vector<Eigen::VectorXf> stderivatives = CumNthDerivative(t, s, 3);

    //Eigen::VectorXf svelocity = stderivatives[1];

    // Data to velocity
    IncrementalDerivative(t, s, 0, 1);
    MaxAndL2Norm(s, weights, baseScores, 32);

    //Eigen::VectorXf sacceleration = stderivatives[2];

    // Data to accleration
    IncrementalDerivative(t, s, 1, 2);
    MaxAndL2Norm(s, weights, baseScores, 34);

    // We don't use 36-37
    //Eigen::VectorXf sjerk = stderivatives[3];
    //MaxAndL2Norm(sjerk, weights, baseScores, 36);

    //t = stroke->RelativeTimestampMap(stroke->IsolatedMaxLoggedIndex());

    //baseScores(38) = curves::Variance(curves::Diff(t));

    baseScores = (baseScores.array() + _baseIsolatedScoreNugget).array().log();

    //stroke->SetIsolatedScores(baseScores);

    for (int i = 0; i < _scoreData->_chosenScoreCount; ++i) {
        chosenScores(i) = baseScores(_scoreData->_chosenScoreIndices(i)) +
                          logL*_scoreData->_LExponents(i) +
                          logT*_scoreData->_TExponents(i);
    }

    return chosenScores;

}

float IsolatedStrokesClassifier::PenLogDensity(float score, int chunkSize, int scoreId) {
    //ScoreAssert(scoreId,chunkSize);
    return _scoreData->_penLikelihoods[score].Evaluate(score);
}

float IsolatedStrokesClassifier::PalmLogDensity(float score, int scoreId, int chunkSize) {
    //ScoreAssert(scoreId,chunkSize);
    return _scoreData->_palmLikelihoods[scoreId].Evaluate(score);
}

Eigen::VectorXf IsolatedStrokesClassifier::PenLogDensity(Eigen::VectorXf scores, int chunkSize) {
    Eigen::VectorXf output;
    output.resize(_scoreData->_chosenScoreCount);

    for (int i = 0; i < _scoreData->_chosenScoreCount; ++i) {
        output(i) = _scoreData->_penLikelihoods[i].Evaluate(scores(i));
    }

    return output;
}

Eigen::VectorXf IsolatedStrokesClassifier::PalmLogDensity(Eigen::VectorXf scores, int chunkSize) {
    Eigen::VectorXf output;
    output.resize(_scoreData->_chosenScoreCount);

    for (int i = 0; i < _scoreData->_chosenScoreCount; ++i) {
        output(i) = _scoreData->_palmLikelihoods[i].Evaluate(scores(i));
    }

    return output;
}

void IsolatedStrokesClassifier::UpdateIdStoredData(common::TouchId id) {

    if (TouchIdIsolatedSize(id) < 4) {
        // We ignore the touch in this case
        return;
    }

    //if (_touchIdChunkIndexMap.count(id) < 1) {
    if (_touchIdChunkData.count(id) < 1) {
        // We haven't processed this id yet

        _touchIdChunkData[id] = StrokeChunkLog::New(FindChunkIndexStartingWithIndex(id,0));
        _touchIdChunkData[id]->_logLikelihoods = Eigen::MatrixXf::Zero(_scoreData->_chosenScoreCount,2);

    }
    else {
        // Just see if we need to do anything
        int newIndex = FindChunkIndexStartingWithIndex(id, 0);
        if (newIndex > _touchIdChunkData[id]->_index) {

            _touchIdChunkData[id]->_updateFlag = true;
            _touchIdChunkData[id]->_index = newIndex;

        }
        // Otherwise we don't have enough points to warrant recomputing yet
    }

}

int IsolatedStrokesClassifier::FindChunkIndexStartingWithIndex(common::TouchId id, int startIndex) {
    int touchSize = TouchIdIsolatedSize(id);

    // Failsafe for debugging
    if (startIndex >= sizeof(isolatedBatchThresholds)/sizeof(isolatedBatchThresholds[0])) {
        DebugAssert(false);
    }

    while (touchSize > isolatedBatchThresholds[startIndex+1]) {

        startIndex += 1;

        // Failsafe for debugging
        if (startIndex >= sizeof(isolatedBatchThresholds)/sizeof(isolatedBatchThresholds[0])) {
            DebugAssert(false);
        }

    }

    return startIndex;
}

Eigen::MatrixX2f IsolatedStrokesClassifier::StrokeLogLikelihoods(common::TouchId id) {
    // column 1: Pen log-densities
    // column 2: Palm log-densities

    if (! _enableIsolatedStrokesClassifier) {
        return Eigen::MatrixX2f::Zero(_scoreData->_chosenScoreCount, 2);
    }

    UpdateIdStoredData(id);

    if (TouchIdIsolatedSize(id) < 4)
    {
        // You shouldn't be calling this method with fewer than 4 distinct samples
        DebugAssert(false);
    }

    //if (! _touchIdScoreUpdateFlagMap[id]) {
    if (! _touchIdChunkData[id]->_updateFlag) {
        return _touchIdChunkData[id]->_logLikelihoods;
    }

    // Otherwise...let's do some math
    Eigen::VectorXf scores = ScoresForId(id);

    _touchIdChunkData[id]->_logLikelihoods.resize(_scoreData->_chosenScoreCount,2); // Just in case

    Eigen::Map<Eigen::MatrixX2f> output((float*) &_touchIdChunkData[id]->_logLikelihoods(0),
                                        _touchIdChunkData[id]->_logLikelihoods.rows(),
                                        _touchIdChunkData[id]->_logLikelihoods.cols());

    output.block(0,0,_scoreData->_chosenScoreCount, 1) = PenLogDensity(scores, 0);
    output.block(0,1,_scoreData->_chosenScoreCount, 1) = PalmLogDensity(scores, 0);

    _touchIdChunkData[id]->_updateFlag = false;
    return output;
}

int IsolatedStrokesClassifier::NPVoteCount(common::TouchId id) {

    //return NPVoteCountWithFalsePositiveRate(id, 0.02f);
    return NPVoteCountWithFalsePositiveRate(id, _NPData->_defaultFPRate);

}

int IsolatedStrokesClassifier::NPVoteCountWithFalsePositiveRate(common::TouchId id, float falsePositiveRate) {

    AssertFalsePositiveRate(falsePositiveRate);

    Eigen::MatrixX2f likelihoods = StrokeLogLikelihoods(id);

    Eigen::Matrix<bool,Dynamic,1> votes;
    votes.resize(_scoreData->_chosenScoreCount, 1);

    Eigen::VectorXf penLikelihoods = likelihoods.block(0,0,_scoreData->_chosenScoreCount,1) - likelihoods.block(0,1,_scoreData->_chosenScoreCount, 1);

    votes = penLikelihoods.array() >= LogEtas(falsePositiveRate).array();

    return votes.cast<int>().sum();
}

TouchType IsolatedStrokesClassifier::NPVotingTest(common::TouchId id) {
    //return NPVotingTestWithFalsePositiveRate(id, 0.02f);
    return NPVotingTestWithFalsePositiveRate(id, _NPData->_defaultFPRate);
}

TouchType IsolatedStrokesClassifier::NPVotingTestWithFalsePositiveRate(common::TouchId id, float falsePositiveRate) {

    if (! _enableIsolatedStrokesClassifier) {
        return TouchType::PenTip1;
    }

    if (TouchIdIsolatedSize(id) < 4) {
        return TouchType::PenTip1;
    }

    int voteCount = NPVoteCountWithFalsePositiveRate(id, falsePositiveRate);

    TouchType output = TouchType::PenTip1; // Null

    // Voting
    if (voteCount <= _scoreData->_chosenScoreCount - _NPData->_vetoThreshold)
    {
        output = TouchType::Palm;
    }

    return output;
}

float IsolatedStrokesClassifier::NPVoteScore(common::TouchId id) {

    //return NPVoteScoreWithFalsePositiveRate(id, 0.02f);
    return NPVoteScoreWithFalsePositiveRate(id, _NPData->_defaultFPRate);

}

float IsolatedStrokesClassifier::NPVoteScoreWithFalsePositiveRate(common::TouchId id, float falsePositiveRate)
{

    if (! _enableIsolatedStrokesClassifier) {
        return 0.5f;
    }

    int voteCount = NPVoteCountWithFalsePositiveRate(id, falsePositiveRate);

    if (voteCount >= _NPData->_scoreModels.size()) {
        DebugAssert(false);
        return 0.5;
    }

    return std::exp(_NPData->_scoreModels[voteCount].Evaluate(std::log(falsePositiveRate)));
}

void IsolatedStrokesClassifier::AssertFalsePositiveRate(float alpha) {

    DebugAssert(alpha > 0.0f);
    // Don't ask for large false positive rates. Just....don't
    DebugAssert(alpha <= 0.5f);

}

TouchType IsolatedStrokesClassifier::BayesLikelihoodTestWithFalsePositiveRate(common::TouchId id, float falsePositiveRate) {

    if (! _enableIsolatedStrokesClassifier) {
        return TouchType::PenTip1;
    }

    AssertFalsePositiveRate(falsePositiveRate);

    Eigen::MatrixX2f likelihoods = StrokeLogLikelihoods(id);

    Eigen::VectorXf penLikelihoods = likelihoods.block(0,0,_scoreData->_chosenScoreCount,1) - likelihoods.block(0,1,_scoreData->_chosenScoreCount, 1);

    float bayesScore = penLikelihoods.sum();

    float eta = _BayesData->_logLikelihoodThreshold.Evaluate(std::log(falsePositiveRate));

    TouchType output = TouchType::PenTip1;
    if (bayesScore < eta) {
        output = TouchType::Palm;
    }

    return output;
}

TouchType IsolatedStrokesClassifier::BayesLikelihoodTest(common::TouchId id) {
    return BayesLikelihoodTestWithFalsePositiveRate(id, _BayesData->_falsePositiveRate);
}

float IsolatedStrokesClassifier::BayesLikelihoodScoreWithFalsePositiveRate(common::TouchId id, float falsePositiveRate) {

    if (! _enableIsolatedStrokesClassifier) {
        return 0.5f;
    }

    TouchType result = BayesLikelihoodTestWithFalsePositiveRate(id, falsePositiveRate);

    float output;

    if (result == TouchType::PenTip1) {
        output = std::exp(_BayesData->_penScore.Evaluate(std::log(falsePositiveRate)));
    }
    else {
        output = std::exp(_BayesData->_palmScore.Evaluate(std::log(falsePositiveRate)));
    }

    return output;
}

float IsolatedStrokesClassifier::BayesLikelihoodScore(common::TouchId id) {
    return BayesLikelihoodScoreWithFalsePositiveRate(id, _BayesData->_falsePositiveRate);
}

TouchType IsolatedStrokesClassifier::AdaboostTest(common::TouchId id) {

    if (! _enableIsolatedStrokesClassifier) {
        return TouchType::PenTip1;
    }

    Eigen::MatrixX2f likelihoods = StrokeLogLikelihoods(id);

    Eigen::Matrix<bool,Dynamic,1> votes;
    votes.resize(_scoreData->_chosenScoreCount, 1);

    Eigen::VectorXf penLikelihoods = likelihoods.block(0,0,_scoreData->_chosenScoreCount,1) - likelihoods.block(0,1,_scoreData->_chosenScoreCount, 1);

    votes = penLikelihoods.array() >= LogEtas(_AdaboostData->_NPFalsePositiveRate).array();

    Eigen::VectorXf classifiers = (2*(votes.cast<float>())).array() - 1.0f;

    float result = _AdaboostData->_NPBoostingCoefficients.dot(classifiers);

    TouchType output = TouchType::PenTip1;

    if (result < 0) {
        output = TouchType::Palm;
    }

    return output;
}

float IsolatedStrokesClassifier::AdaboostScore(common::TouchId id) {

    if (! _enableIsolatedStrokesClassifier) {
        return 0.5f;
    }

    TouchType type = AdaboostTest(id);

    float output;

    if (type == TouchType::PenTip1) {
        output = _AdaboostData->_penScore;
    }
    else {
        output = _AdaboostData->_palmScore;
    }

    return output;
}

float IsolatedStrokesClassifier::ConvexScoreWithFalsePositiveRate(common::TouchId id, float falsePositiveRate) {

    if (! _enableIsolatedStrokesClassifier) {
        return 0.5f;
    }

    Eigen::VectorXf scores;
    scores.resize(3);

    scores(0) = NPVoteScoreWithFalsePositiveRate(id, falsePositiveRate);
    scores(1) = BayesLikelihoodScoreWithFalsePositiveRate(id, falsePositiveRate);
    scores(2) = AdaboostScore(id);

    float output = _AdaboostData->_convexCoefficients.dot(scores);
    DebugAssert( ( output >= 0) & (output <= 1) );

    return output;
}

float IsolatedStrokesClassifier::ConvexScore(common::TouchId id) {

    if (! _enableIsolatedStrokesClassifier) {
        return 0.5f;
    }

    Eigen::VectorXf scores;
    scores.resize(3);

    scores(0) = NPVoteScore(id);
    scores(1) = BayesLikelihoodScore(id);
    scores(2) = AdaboostScore(id);

    float output = _AdaboostData->_convexCoefficients.dot(scores);
    DebugAssert( ( output >= 0) & (output <= 1) );

    return output;
}

float IsolatedStrokesClassifier::EtaEvaluation(float falsePositiveRate, int scoreId) {
    //DebugAssert( (scoreId > -1) & (scoreId < likelihoodScoreCount) );

    float x = log(falsePositiveRate);

    return _NPData->_etaModel[scoreId].Evaluate(x);
}

Eigen::VectorXf IsolatedStrokesClassifier::LogEtas(float falsePositiveRate) {

    Eigen::VectorXf output = Eigen::MatrixXf::Zero(_scoreData->_chosenScoreCount, 1);

    for (int i = 0; i < _scoreData->_chosenScoreCount; ++i) {
        output(i) = EtaEvaluation(falsePositiveRate, i);
    }

    return output;
}

float IsolatedStrokesClassifier::LogMaxCurvature(common::TouchId id) {

    int touchSize = TouchIdIsolatedSize(id);

    if (TouchIdIsolatedSize(id) < 3) {
        // There aren't enough points to compute a curvature
        return 0.0f;
    }

    // Otherwise, we'll superscede the direct score computation because all
    // we need is the s(XY) map
    Stroke::Ptr stroke = _clusterTracker->Stroke(id);
    Eigen::VectorXf s = stroke->ArclengthParameterMap(touchSize-1);

    if ( ( (Diff(s)).array() <= 1e-4f ).any() ) {
        // Um...the max curvature is inf
        return std::log(1e6f);
    }

    Eigen::MatrixX2f XY = stroke->XYMatrixMap(touchSize-1);

    Eigen::MatrixX2f D2XY = XY;
    IncrementalDerivative(s, D2XY, 0, 2);

    return std::log(RowWiseComponentNorm(D2XY).cwiseAbs().maxCoeff());
    //return std::log(RowWiseComponentNorm(NthDerivative(s, XY, 2)).cwiseAbs().maxCoeff());
}

float IsolatedStrokesClassifier::NormalizedMaxCurvature(common::TouchId id) {

    int touchSize = TouchIdIsolatedSize(id);

    Stroke::Ptr stroke = _clusterTracker->Stroke(id);

    float score = LogMaxCurvature(id);
    float L = stroke->ArcLength(touchSize-1);
    float T = stroke->StrokeTime(touchSize-1);

    score += -6.0f*log(L) + 1.0f*log(T);

    return score;
}

int IsolatedStrokesClassifier::TouchIdIsolatedSize(common::TouchId id) {

    static float tol = 1e-6f;

    Stroke::Ptr const & stroke = _clusterTracker->Stroke(id);
    int N = stroke->Size();

    if (N < 2) {
        return N;
    }

    if ( (_clusterTracker->Phase(id) == common::TouchPhase::Ended) ) {

        // No need to compute ds unless we're at TouchEnded
        float ds = (stroke->XY(N) - stroke->XY(N-1)).norm();

        if (ds < tol) {
            N -= 1;
        }
    }

    return N;
}

Eigen::VectorXf PolynomialModel::Evaluate(Eigen::VectorXf x) {

    Eigen::VectorXf XLeft = Eigen::VectorXf::Ones(x.rows(), x.cols());
    Eigen::VectorXf XRight(XLeft);

    XLeft *= _leftB;
    XRight *= _rightB;

    // (R.array() < s).select(P,Q);  // (R < s ? P : Q)
    // Truncate
    x = (x.array() >= _leftB).select(x, XLeft);
    x = (x.array() <= _rightB).select(x, XRight);

    x.array() -= _shift;
    x /= _scale;

    Eigen::MatrixXf V = VandermondeMatrix(x, _coefficients.rows()-1);
    std::cerr << "\nVandermonde = " << V;

    return (V*_coefficients).array();
}

float PolynomialModel::Evaluate(float x) {

    //Eigen::VectorXf xvec(1);
    //xvec << x;
    //float sanity = Evaluate(xvec)(0);

    x -= _shift;
    x /= _scale;

    float xPow = 1;
    float sum  = 0.0f;
    for (int j=0; j<_coefficients.size(); j++)
    {
        sum  += xPow * _coefficients(j);
        xPow *= x;
    }

    return sum;

}

void IsolatedStrokesClassifier::TouchIdNoLongerLogged(common::TouchId touchId) {

    _touchIdChunkData.erase(touchId);
}

}
}
