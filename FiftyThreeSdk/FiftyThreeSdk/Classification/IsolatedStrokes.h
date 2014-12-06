//
//  IsolatedStrokes.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "Core/Touch/Touch.h"
#include "FiftyThreeSdk/Classification/Cluster.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/EigenLAB.h"
#include "FiftyThreeSdk/Classification/Stroke.h"
#include "FiftyThreeSdk/Classification/TouchLogger.h"

namespace fiftythree
{
namespace sdk
{
typedef std::pair<core::TouchClassification, bool> TypeBoolPair;

class PolynomialModel
{
protected:
    float _scale;
    float _shift;
    float _leftB;
    float _rightB;
    Eigen::VectorXf _coefficients;

public:
    Eigen::VectorXf Evaluate(Eigen::VectorXf x);
    float Evaluate(float x);
    inline PolynomialModel(float scale, float shift, float leftB, float rightB, Eigen::VectorXf coefficients) :
                            _scale(scale),
                            _shift(shift),
                            _leftB(leftB),
                            _rightB(rightB),
                            _coefficients(coefficients)
    {
    };
    inline PolynomialModel() :
                            _scale(1.0f),
                            _shift(0.0f),
                            _leftB(0.0f),
                            _rightB(1.0f),
                            _coefficients(Eigen::VectorXf::Zero(1))
    {
    };
};

// Calibration for determining how many scores we have, what their normalizations
// and likelihoods are, etc
struct ScoreCalibration
{
    ALIAS_PTR_TYPES(ScoreCalibration);
    ScoreCalibration();
    static ScoreCalibration::Ptr New();

    int _statScoreCount;
    int _chosenScoreCount;

    Eigen::VectorXi _chosenScoreIndices;
    Eigen::VectorXf _LExponents;
    Eigen::VectorXf _TExponents;

    // The indices correspond to the chosen score index
    std::vector<PolynomialModel> _penLikelihoods;
    std::vector<PolynomialModel> _palmLikelihoods;
};

// Calibration for the Neyman-Pearson statistical tests
struct NPCalibration
{
    ALIAS_PTR_TYPES(NPCalibration);
    NPCalibration();
    static NPCalibration::Ptr New();

    // Assumes null hypothesis (pen) until at least this many votes say otherwise
    int _vetoThreshold;

    // If user doesn't specify an individual testk false positive rate, use this one
    float _defaultFPRate;

    std::vector<PolynomialModel> _etaModel;
    std::vector<PolynomialModel> _scoreModels;
};

// Calibration for the Bayesian classification
struct BayesCalibration
{
    ALIAS_PTR_TYPES(BayesCalibration);
    BayesCalibration();
    static BayesCalibration::Ptr New();

    float _falsePositiveRate;

    PolynomialModel _penScore;
    PolynomialModel _palmScore;
    PolynomialModel _logLikelihoodThreshold;
};

// Calibration for Adaptive Boosting calibration
struct AdaboostCalibration
{
    ALIAS_PTR_TYPES(AdaboostCalibration);
    AdaboostCalibration();
    static AdaboostCalibration::Ptr New();

    // _NPData->_defaultFPRate = _finalizeFPRate;

    float _NPFalsePositiveRate;
    Eigen::VectorXf _NPBoostingCoefficients;

    float _penScore;
    float _palmScore;

    Eigen::VectorXf _convexCoefficients;
};

// Keeps data for touchId's for reclassification of strokes
struct StrokeChunkLog
{
    ALIAS_PTR_TYPES(StrokeChunkLog);
    StrokeChunkLog();
    static StrokeChunkLog::Ptr New();
    StrokeChunkLog(int chunkIndex);
    static StrokeChunkLog::Ptr New(int chunkIndex);

    int _index;
    bool _updateFlag;
    Eigen::MatrixX2f _logLikelihoods;
};

class IsolatedStrokesClassifier
{
protected:
    ClusterTracker::Ptr      _clusterTracker;
    const CommonData*        _commonData;

    // Calibration containers
    ScoreCalibration::Ptr       _scoreData;
    NPCalibration::Ptr          _NPData;
    BayesCalibration::Ptr       _BayesData;
    AdaboostCalibration::Ptr    _AdaboostData;

    std::vector<core::TouchId> _checkedTouches;

    std::map<ClusterId, core::TouchClassification> _classifiedClusters;

    // If a score is 0 we can't take log's
    // This is an additive nugget for base scores
    float _baseIsolatedScoreNugget = 1e-8f;

    std::map<core::TouchId, StrokeChunkLog::Ptr> _touchIdChunkData;

    bool _enableIsolatedStrokesClassifier;

public:
    // members

protected:
    // methods

    // The implementation for this is in IsolatedStrokesCalibration.cpp
    void InitializeLikelihoods();

    IdFloatMap _scores;

    std::vector<bool> WeakClassifierNullPen(Stroke &stroke);

    Eigen::VectorXf ArcLengthParameterization(Eigen::VectorXf t, Eigen::MatrixX2f xy);

public:
    inline IsolatedStrokesClassifier(ClusterTracker::Ptr clusterTracker,
                                    const CommonData* dataPtr) :
    _clusterTracker(clusterTracker),
    _commonData(dataPtr),
    _scoreData(ScoreCalibration::New()),
    _NPData(NPCalibration::New()),
    _BayesData(BayesCalibration::New()),
    _AdaboostData(AdaboostCalibration::New())
    {
        InitializeLikelihoods();

        // if the following is set to false it always returns
        // PenTip1 for TouchTypes, and 0.5 for scores
        _enableIsolatedStrokesClassifier = true;
    }

    IdTypeMap ReclassifyActiveTouches();

    float Score(core::TouchId id);
    float Score(Stroke  & stroke);

    EdgeThumbState TestEdgeThumb(core::TouchId touchId);
    void MarkEdgeThumbs();
    bool IsEdgeThumb(core::TouchId touchId);

    // this gives a number in [0,1] where larger values indicate "badness"
    // (i.e. likelihood of being a palm), since that's the way most of the weak
    // classifiers work -- larger values mean palm.
    float NormalizedScore(core::TouchId id);

    core::TouchClassification TestFingerVsPalm(Cluster::Ptr const & cluster);
    bool IsPalmCluster(Cluster::Ptr const & cluster);

    void ScoreAssert(int scoreId, int chunkSize);

    float PenLogDensity(float score, int scoreId, int chunkSize);
    Eigen::VectorXf PenLogDensity(Eigen::VectorXf scores, int chunkSize);

    float PalmLogDensity(float score, int scoreId, int chunkSize);
    Eigen::VectorXf PalmLogDensity(Eigen::VectorXf scores, int chunkSize);

    // This returns loglikelihoods, hiding all the crap under the hood
    // column 1: log-prob that stroke data came from a pen
    // column 2: log-prob that stroke data came from a palm
    Eigen::MatrixX2f StrokeLogLikelihoods(core::TouchId id);

    void AssertFalsePositiveRate(float alpha);

    core::TouchClassification NPVotingTest(core::TouchId id);
    core::TouchClassification NPVotingTestWithFalsePositiveRate(core::TouchId id, float falsePositiveRate);
    // The number of votes for the null hypothesis (pen)
    int NPVoteCount(core::TouchId id);
    int NPVoteCountWithFalsePositiveRate(core::TouchId id, float falsePositiveRate);
    float NPVoteScore(core::TouchId id);
    float NPVoteScoreWithFalsePositiveRate(core::TouchId id, float falsePositiveRate);

    core::TouchClassification BayesLikelihoodTestWithFalsePositiveRate(core::TouchId id, float falsePositiveRate);
    core::TouchClassification BayesLikelihoodTest(core::TouchId id);

    float BayesLikelihoodScoreWithFalsePositiveRate(core::TouchId id, float falsePositiveRate);
    float BayesLikelihoodScore(core::TouchId id);

    // Adaboost doesn't support specification of false positive rates
    core::TouchClassification AdaboostTest(core::TouchId id);
    float AdaboostScore(core::TouchId id);

    // For now, this false positive rate isn't a false positive rate in the standard sense.
    float ConvexScoreWithFalsePositiveRate(core::TouchId id, float falsePositiveRate);
    float ConvexScore(core::TouchId id);

    float EtaEvaluation(float falsePositiveRate, int scoreId);

    // Neyman-Pearson stuff
    Eigen::VectorXf LogEtas(float falsePositiveRate);

    // Updates statistics held in Curves::Stroke
    Eigen::VectorXf ScoresForId(core::TouchId id);

    // Peter: computes raw log-(max curvature) from the isolated scores.
    float LogMaxCurvature(core::TouchId id);

    // Peter: My computation of max curvature tends to not be a good indicator
    // of much. But you can be pretty darn near sure that something's a palm if
    // this normalized score is bigger than -17.9164453792496
    // If you're trying to differentiate gestures, I don't know what to use
    float NormalizedMaxCurvature(core::TouchId id);

    // Prunes the last sample if it's both TouchPhase::Ended and has coincident
    // location to penultimate sample.
    int TouchIdIsolatedSize(core::TouchId id);

    int FindChunkIndexStartingWithIndex(core::TouchId id, int startIndex);

    // Deals with most accounting in _touchId*Map's
    void UpdateIdStoredData(core::TouchId id);

    std::pair<core::TouchClassification, bool> ClassifyForPinchOrPanGesture(core::TouchId touchId);
    bool IsTap(core::TouchId touchId);

    void TouchIdNoLongerLogged(core::TouchId touchId);
};

// We take maxes + integrate vector norms so much here's a convenience method to do it
// Actually it's L2 norm squared
template<typename DerivedA, typename DerivedB, typename DerivedC>
void MaxAndL2Norm(const Eigen::MatrixBase<DerivedA> &x, const Eigen::MatrixBase<DerivedB> &weights, Eigen::MatrixBase<DerivedC> &results, int startIndex)
{
    results(startIndex) = (typename DerivedC::Scalar) RowwiseMaxNorm(x);
    results(startIndex+1) = (typename DerivedC::Scalar) weights.dot(x.cwiseAbs2().rowwise().sum());
}

template<typename DerivedA, typename DerivedB>
std::pair<typename DerivedA::Scalar, typename DerivedA::Scalar> MaxAndL2Norm(const Eigen::MatrixBase<DerivedA> &x, const Eigen::MatrixBase<DerivedB> &weights)
{
    return {RowwiseMaxNorm(x), weights.dot(x.cwiseAbs2().rowwise().sum())};
}

template<typename DerivedA, typename DerivedB>
typename DerivedA::Scalar ComputeL2Norm(const Eigen::MatrixBase<DerivedA> &x,
                                        const Eigen::MatrixBase<DerivedB> &weights)
{
    return weights.dot(x.cwiseAbs2().rowwise().sum());
}
}
}
