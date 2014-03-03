//
//  PenEvents.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include "Core/Eigen.h"
#include "Core/Touch/Touch.h"
#include "Core/Touch/TouchTracker.h"
#include "FiftyThreeSdk/Classification/ClassificationProxy.h"
#include "FiftyThreeSdk/Classification/Cluster.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/PenEvents.h"
#include "FiftyThreeSdk/Classification/Stroke.h"
#include "FiftyThreeSdk/Classification/TouchLogger.h"

using namespace Eigen;
using fiftythree::core::TouchClassification;

namespace fiftythree
{
namespace sdk
{

IdLikelihoodPair PenEventClassifier::BestPenDownEventForTouch(core::TouchId touchId, PenEventIdSet const &penDownEvents)
{
    IdLikelihoodPair bestPair(PenEventId(-1), 0.0f);

    for (PenEventId penEventId :  penDownEvents)
    {
        PenEventData::Ptr data = _clusterTracker->PenData(penEventId);

        float dt = data->Time() - _clusterTracker->Data(touchId)->FirstTimestamp();
        float score = SwitchDownLikelihoodForDeltaT(dt);

        if (score > bestPair.second)
        {
            bestPair.second = score;
            bestPair.first = penEventId;
        }
    }

    _bestPenDownEventForTouch[touchId] = bestPair.first;

    return bestPair;
}

IdLikelihoodPair PenEventClassifier::BestPenUpEventForTouch(core::TouchId touchId, PenEventIdSet const &penUpEvents)
{
    IdLikelihoodPair bestPair(PenEventId(-1), 0.0f);

    for (PenEventId penEventId :  penUpEvents)
    {
        PenEventData::Ptr data = _clusterTracker->PenData(penEventId);

        float dt = data->Time() - _clusterTracker->Data(touchId)->LastTimestamp();
        float score = SwitchUpLikelihoodForDeltaT(dt);

        if (score > bestPair.second)
        {
            bestPair.second  = score;
            bestPair.first   = penEventId;
        }
    }

    _bestPenUpEventForTouch[touchId] = bestPair.first;

    return bestPair;
}

PenEventId PenEventClassifier::BestPenDownEventForTouch(core::TouchId touchId)
{
    if (_bestPenDownEventForTouch.count(touchId))
    {
        return _bestPenDownEventForTouch[touchId];
    }
    else
    {
        return PenEventId(-1);
    }
}

PenEventId PenEventClassifier::BestPenUpEventForTouch(core::TouchId touchId)
{
    if (_bestPenUpEventForTouch.count(touchId))
    {
        return _bestPenUpEventForTouch[touchId];
    }
    else
    {
        // it's very possible there aren't any penevents at all
        return PenEventId(-1);
    }
}

// to convert likelihoods to pen probabilities, we first assemble all likelihoods (l_1, l_2, ... ,l_n) for touches
// that could possibly have produced the pen event.  A calculation with Bayes' rule shows that
// if T_j is the j-th touch, then
//
// P(T_j emitted the pen event) = l_j * Prior(j) / sum(l_i * Prior(i))
//
// where Prior(i) is a prior that T_i is a pen, given whatever else is known (e.g. touch geometry, previous pen
// locations, etc).
// at the moment we assume up and down events are independent, which is false:
//
// if P(T_j emitted down event) = 1
// then it almost certainly emitted an up event as well.  this doesn't seem to matter -- it's another of those
// places where our estimates for probabilities may be lousy but the classification is still good.
float PenEventClassifier::PenDownProbabilityForTouchGivenPenEvent(core::TouchId probeId,
                                                                  PenEventId downEventId,
                                                                  TouchIdVector touchesBegan,
                                                                  VectorXf prior)
{

    double tDown = _clusterTracker->PenData(downEventId)->Time();

    if (touchesBegan.empty())
    {
        DebugAssert(! touchesBegan.empty());
        return 0.0f;
    }

    float totalMass  = 0.0f;
    float probePrior = 0.0f;

    for (int j=0; j<touchesBegan.size(); j++)
    {
        core::TouchId beganId = touchesBegan[j];

        float likelihood  = SwitchDownLikelihoodForDeltaT(tDown - _clusterTracker->Data(beganId)->FirstTimestamp());
        totalMass += prior[j] * likelihood;

        if (probeId == beganId)
        {
            probePrior = prior[j];
        }
    }

    float probeDownLikelihood = probePrior * SwitchDownLikelihoodForDeltaT(tDown - _clusterTracker->Data(probeId)->FirstTimestamp());
    float pDown = 0.0f;

    if (totalMass > 0.0f)
    {
        pDown = probeDownLikelihood / totalMass;
    }

    return pDown;
}

float PenEventClassifier::PenUpProbabilityForTouchGivenPenEvent(core::TouchId probeId,
                                                                PenEventId upEventId,
                                                                TouchIdVector touchesEnded,
                                                                VectorXf prior)
{
    double tUp;
    if (upEventId >= 0)
    {
        tUp = _clusterTracker->PenData(upEventId)->Time();
    }
    else
    {
        tUp = _clusterTracker->CurrentTime();
    }

    if (touchesEnded.empty())
    {
        DebugAssert(!touchesEnded.empty());
        return 0.0f;
    }

    float totalMass  = 0.0f;
    float probePrior = 0.0f;
    for (int j=0; j<touchesEnded.size(); j++)
    {
        core::TouchId endedId = touchesEnded[j];

        float likelihood  = SwitchUpLikelihoodForDeltaT(tUp - _clusterTracker->Data(endedId)->LastTimestamp());
        totalMass += prior[j] * likelihood;

        if (probeId == endedId)
        {
            probePrior = prior[j];
        }

    }

    float probeUpLikelihood = probePrior * SwitchUpLikelihoodForDeltaT(tUp - _clusterTracker->Data(probeId)->LastTimestamp());
    float pUp = 0.0f;
    if (totalMass > 0.0f)
    {
        pUp = probeUpLikelihood / totalMass;
    }

    return pUp;

}

// todo: converting likelihoods to probabilities via Bayes' rule is becoming a common theme,
// make it into a helper.
float PenEventClassifier::DurationTimeErrorProbabilityForTouch(core::TouchId probeId,
                                                               float switchOnDuration,
                                                               const TouchIdVector & concurrentTouches,
                                                               const VectorXf & prior)
{

    if (concurrentTouches.empty())
    {
        DebugAssert(! concurrentTouches.empty());
        return 0.0f;
    }
    float probeDuration = 0.0f;
    for (int j=0; j<concurrentTouches.size(); j++)
    {
        core::TouchId otherId = concurrentTouches[j];

        float touchDuration;
        if (_clusterTracker->TouchWithId(otherId)->IsPhaseEndedOrCancelled())
        {
            touchDuration = _clusterTracker->Data(otherId)->LastTimestamp() - _clusterTracker->Data(otherId)->FirstTimestamp();
        }
        else
        {
            touchDuration = _clusterTracker->CurrentTime() - _clusterTracker->Data(otherId)->FirstTimestamp();
        }

        float timingError = std::abs(touchDuration - switchOnDuration);

        // we don't expect perfect timing, so we don't want to pay a penalty for small errors.
        // subtract off twice the median switch timing error.
        float shrinkage = 2.0f * .69f / lambda;
        timingError = std::max(0.0f, timingError - shrinkage);

        if (probeId == otherId)
        {
            probeDuration = touchDuration;
        }

    }

    // four-cycle padding
    float c = 4.0f / 60.0f;

    // and shrink a little bit to account for expected error
    float timingError    = std::max(0.0f, std::abs(probeDuration - switchOnDuration) - 6.0f / 60.0f);

    // this is not really a probability.  more like a goodness-of-fit score.
    float pUp = std::max(0.0f, c + probeDuration - timingError) / (c + probeDuration);
    pUp       = std::sqrt(pUp); // even gentler

    DebugAssert(pUp <= 1.0f && pUp >= 0.0f);

    return pUp;
}

// the score for each touch is the probability that the pen events were produced by the given stroke.
// the score for the cluster is just the total probability mass summed over all touches in the cluster.
std::pair<TouchClassification, float> PenEventClassifier::TypeAndScoreForCluster(Cluster & cluster)
{

    std::pair<TouchClassification, float> pair(TouchClassification::Unknown, 0.0f);

    // if the cluster is stale or can't be reclassified, just return the last known
    // state.  this prevents chewing up a lot of CPU for nothing.
    // NB: without this check, there will be crashes, since the cluster tracker will release
    // resources associated with these clusters and touches.
    if (cluster.Stale() || (! cluster.ContainsReclassifiableTouch()))
    {
        pair.first  = cluster._clusterTouchType;
        pair.second = cluster._penScore;
        return pair;
    }

    std::map< ClusterId, std::pair<TouchClassification, float> >::iterator it = _clusterTypesAndScores.find(cluster._id);

    // we cache the scores, clearing cache when SetNeedsClassification is called.
    if (it != _clusterTypesAndScores.end())
    {
        return it->second;
    }

    if (cluster._touchIds.empty())
    {
        DebugAssert(! cluster._touchIds.empty());
        return pair;
    }

    double t0 = _clusterTracker->Data(cluster.FirstTouch())->FirstTimestamp();
    double t1 = cluster.LastTimestamp();

    PenEventIdSet validPenEvents = _clusterTracker->PenEventSetInTimeInterval(t0 - _maxPenEventDelay, t1+_maxPenEventDelay);

    // each touch needs 2 pen events.
    if (cluster._touchIds.size() > 1 || (2 * int(cluster._touchIds.size()) - int(validPenEvents.size()) > 1))
    {

        cluster._meanPenProbability  = 0.0001f;
        cluster._meanPalmProbability = 1.0f;

        cluster._penScore      = pair.second;
        cluster._penTotalScore = 0.0001f;

        _clusterTypesAndScores[cluster._id] = pair;

        return pair;
    }

    //float temp         = 1.0f;
    float totalPenMass = 0.0f;
    float pAllPen      = 1.0f;
    float pAllPalm     = 1.0f;

    float N            = 0.0f;

    for (core::TouchId touchId :  cluster._touchIds)
    {
        std::pair<TouchClassification, float> curr = TypeAndScoreForTouch(touchId, validPenEvents);

        DebugAssert(curr.second <= 1.0001f);

        // all this does is prevent rendering flicker since the rendering updates every time the
        // touch changes type.  it is not necessary in a real app.
        bool waitingForPenDown = ((! _clusterTracker->TouchWithId(touchId)->IsPhaseEndedOrCancelled()) &&
                                  (_clusterTracker->CurrentTime() - _clusterTracker->Data(touchId)->FirstTimestamp()) < .1);

        if (waitingForPenDown && curr.first == TouchClassification::Unknown)
        {
            // just ignore this guy for now
            continue;
        }

        // geometric mean is more sensitive to bad fits than arithmetic mean.
        // in particular, a single zero-probability event
        // will kill the whole cluster.  to the extent that we're confident in our
        // methods and hardware, this is a good thing.  but one missed switch will kill the cluster.
        pAllPen        *= curr.second;
        pAllPalm       *= std::max(0.0f, 1.0f - curr.second);

        pair.first      = curr.first;

        totalPenMass   += curr.second;
        N              += 1.0f;

    }

    if (false) //pair.first == TouchClassification::Unknown || N == 0.0f)
    {
        pair.second = 0.0f; // should be true already; just for documentation
    }
    else
    {
        // compute the odds ratio.
        // this is handy because the raw probabilities allow for mixed cases,
        // as if clusters could contain both pen and palm touches (this is a consequence
        // of our independence assumptions).  comparing only the "all pen" vs. the "all palm"
        // cases via the odds ratio lets us reclaim much of what was lost, without complicating
        // the model.
        float oddsRatio = .5f * (1.0f + pAllPen) / (.0001f + pAllPalm);
        pair.second     = oddsRatio;

    }

    cluster._meanPenProbability  = pAllPen;  //std::pow(pAllPen,  1.0f / (.0001f + N));
    cluster._meanPalmProbability = pAllPalm; //std::pow(pAllPalm, 1.0f / (.0001f + N));

    //float meanPAllPen = std::pow(pAllPen, 1.0f / float(cluster._touchIds.size()));

    cluster._penScore      = pair.second;
    cluster._penTotalScore = totalPenMass;

    _clusterTypesAndScores[cluster._id] = pair;

    return pair;

}

std::pair<TouchClassification, float> PenEventClassifier::TypeAndScoreForTouch(core::TouchId touchId)
{

    std::pair<TouchClassification, float> pair(TouchClassification::Unknown, 0.0f);

    if (touchId == core::InvalidTouchId())
    {
        return pair;
    }

    if (! _commonData->proxy->IsReclassifiable(_clusterTracker->TouchWithId(touchId), _clusterTracker->Stroke(touchId)))
    {
        pair.first = _commonData->proxy->CurrentClass(touchId);
        return pair;
    }

    double t0 = _clusterTracker->Data(touchId)->FirstTimestamp();
    double t1 = _clusterTracker->Data(touchId)->LastTimestamp();

    PenEventIdSet validPenEvents = _clusterTracker->PenEventSetInTimeInterval(t0-_maxPenEventDelay, t1+_maxPenEventDelay);

    // each touch needs 2 pen events.  we tolerate a missing pen event during drawing, but the price
    // will be paid at the end.
    if (validPenEvents.size() < 1)
    {
        return pair;
    }

    pair = TypeAndScoreForTouch(touchId, validPenEvents);

    float pAllPen        = pair.second;
    float pAllPalm       = std::max(0.0f, 1.0f - pair.second);

    // don't need to pad anymore.  clusters are automatically killed if they have
    // more than one touch and we extract good strokes, so there's no reason to keep them
    // on life support.
    float oddsRatio = pAllPen / (.0001f + pAllPalm);

    pair.second = oddsRatio;

    return pair;

}

void PenEventClassifier::SetNeedsClassification()
{
    std::set<Cluster::Ptr> const & activeIds = _commonData->proxy->ClusterTracker()->CurrentEventActiveClusters();

    for (Cluster::Ptr cluster :  activeIds)
    {
        _clusterTypesAndScores.erase(cluster->_id);
    }
}

float PenEventClassifier::SwitchOnDurationInTimeInterval(double t0, double t1)
{
    PenEventIdVector penEvents = _clusterTracker->PenEventsInTimeInterval(t0, t1, true);

    // waitingForUpEvent is used only at the end, in case we have a tip down event
    // with no corresponding up event.
    bool   waitingForUpEvent = false;

    // sometimes we get multiple tip-downs in a row, in current firmware at least.
    // this flag is a workaround for this particular issue and should be removed, assuming
    // the issue gets resolved.
    bool  mostRecentEventWasTipDown = false;

    double tPrevious = t0;
    float  tTotal = 0.0f;

    for (PenEventId penEventId :  penEvents)
    {
        if (_clusterTracker->PenData(penEventId)->TipDownEvent())
        {

            if (! mostRecentEventWasTipDown)
            {
                tPrevious = _clusterTracker->PenData(penEventId)->Time();
            }
            else
            {
                //DebugAssert(false);
            }

            mostRecentEventWasTipDown = true;
            waitingForUpEvent = true;
        }

        if (_clusterTracker->PenData(penEventId)->TipUpEvent())
        {
            float dt  = std::max(0.0, _clusterTracker->PenData(penEventId)->Time() - tPrevious);
            tPrevious = std::numeric_limits<double>::max();

            mostRecentEventWasTipDown = false;

            tTotal += dt;
            waitingForUpEvent = false;
        }
    }

    if (waitingForUpEvent)
    {
        tTotal += t1 - tPrevious;
    }

    return tTotal;
}

double PenEventClassifier::IrrelevancyTimeWindow() const
{
    // timestamps do not seem to come at the same time, especially since pen events
    // come on a different clock.  we pad by two cycles, although one should be sufficient.
    const float pad = 2.0f / 60.0f;
    return _maxPenEventDelay + _commonData->proxy->ClusterTracker()->StaleInterval() + pad;
}

std::pair<TouchClassification, float> PenEventClassifier::TypeAndScoreForTouch(core::TouchId touchId, PenEventIdSet &validPenEvents)
{

    float     score    = 0.0f;
    TouchClassification type     = TouchClassification::Unknown;

    double touchFirstTimestamp = _clusterTracker->Data(touchId)->FirstTimestamp();
    double touchLastTimestamp  = _clusterTracker->Data(touchId)->LastTimestamp();

    // how far out in time to look for pen events, before/after a touch begins and/or ends.
    // we don't reclassify anything after this time period, so looking further out is just extra work
    // and might adversely affect likelihood computation (unlikely).
    double exteriorTimeWindow = _commonData->proxy->ClusterTracker()->StaleInterval();

    // when a stroke is being drawn, due to variations in pen pressure you can see pen events
    // happen long before drawing ends, for example.  this accounts for that.
    // second argument to std::min prevents us from looking too far past the end of a brief stroke
    double interiorTimeWindow = std::min(_maxPenEventDelay, (touchLastTimestamp - touchFirstTimestamp) + exteriorTimeWindow);

    PenEventIdSet penBeganSet = _clusterTracker->PenBeganEventSetInTimeInterval(touchFirstTimestamp - exteriorTimeWindow,
                                                                          touchFirstTimestamp + interiorTimeWindow);
    PenEventIdSet validPenBeganSet;

    std::set_intersection(penBeganSet.begin(), penBeganSet.end(),
                          validPenEvents.begin(), validPenEvents.end(),
                          std::inserter(validPenBeganSet, validPenBeganSet.begin()));

    if (validPenBeganSet.empty())
    {
        return std::pair<TouchClassification,float>(TouchClassification::Unknown, 0.0f);
    }

    IdLikelihoodPair downPair = BestPenDownEventForTouch(touchId,
                                                         validPenBeganSet);

    if (downPair.first < 0)
    {
        return std::pair<TouchClassification, float>(TouchClassification::Unknown, 0.0f);
    }

    validPenEvents.erase(downPair.first);

    double tEventBeganPad = _commonData->proxy->ClusterTracker()->CurrentEventBeganTime() - .5 * double(_commonData->proxy->ClusterTracker()->StaleInterval());

    DebugAssert(touchFirstTimestamp >= tEventBeganPad);

    // given the best PenDown event, compute the probability it came from the probe touch
    double tPenDown                  = _clusterTracker->PenData(downPair.first)->Time();
    TouchIdVector  touchesBegan      = _clusterTracker->TouchIdsBeganInTimeInterval(std::max(tPenDown - interiorTimeWindow, tEventBeganPad),
                                                                              tPenDown + exteriorTimeWindow);

    // this shouldn't happen but got hit in testing.
    // it's a workaround for a separate timestamp issue
    if (touchesBegan.empty())
    {
    //  Matt: Please investigate why this is happening.
        DebugAssert(false);
        touchesBegan.push_back(touchId);
    }

    VectorXf priorBegan = _commonData->proxy->PenPriorForTouches(touchesBegan);

    score = PenDownProbabilityForTouchGivenPenEvent(touchId, downPair.first, touchesBegan, priorBegan);
    type  = _clusterTracker->PenData(downPair.first)->TouchType();

    float dt = _clusterTracker->PenData(downPair.first)->Time() - _clusterTracker->Data(touchId)->FirstTimestamp();
    _commonData->proxy->TouchStatistics()[touchId]._penDownDeltaT = dt;

    DebugAssert(score <= 1.0f && score >= 0.0f);

    // time we got the up event.  if the touch isn't ended, use the current time.
    double tPenUp       = _clusterTracker->CurrentTime();
    double switchUpTime = tPenUp;

    if (_clusterTracker->TouchWithId(touchId)->IsPhaseEndedOrCancelled())
    {

        // sanity check -- don't consider penUp events which arrived prior to the pen down event
        // or prior to the stroke's first timestamp
        double intervalBegin      = std::max(touchFirstTimestamp+.0001, std::max(touchLastTimestamp-interiorTimeWindow, tPenDown + .0001));
        PenEventIdSet penEndedSet = _clusterTracker->PenEndedEventSetInTimeInterval(std::max(tEventBeganPad, intervalBegin),
                                                                              touchLastTimestamp + exteriorTimeWindow);
        PenEventIdSet validPenEndedSet;

        std::set_intersection(penEndedSet.begin(), penEndedSet.end(),
                              validPenEvents.begin(), validPenEvents.end(),
                              std::inserter(validPenEndedSet, validPenEndedSet.begin()));

        IdLikelihoodPair upPair = BestPenUpEventForTouch(touchId,
                                                         //penEndedSet);
                                                         validPenEndedSet);

        // there may be no PenUp events worth considering, particularly if this is not a pen touch.
        if (upPair.first >= 0)
        {
            tPenUp = _clusterTracker->PenData(upPair.first)->Time();
            validPenEvents.erase(upPair.first);

            TouchIdVector touchesEnded  = _clusterTracker->TouchIdsEndedInTimeInterval(std::max(tPenUp - exteriorTimeWindow, tEventBeganPad),
                                                                                    tPenUp + interiorTimeWindow);

            // touchesEnded may contain touches which began after this pen up event happened.
            // this does not happen so these should not be included in the calculation.
            // we can't do the same trick for touchesBegan (at least not so naively) because
            // for taps it can indeed happen that the touch ends before the began event occurred.
            TouchIdVector   validTouchesEnded;
            for (core::TouchId touchId :  touchesEnded)
            {
                //ClusterId otherCluster = _commonData->proxy->ClusterTracker()->ClusterIdForTouchId(touchId);
                //bool stale = (otherCluster == InvalidClusterId()) || _commonData->proxy->ClusterTracker()->Cluster(otherCluster).Stale();

                double otherBeganTime = _clusterTracker->Data(touchId)->FirstTimestamp();
                if (otherBeganTime < tPenUp) // && (! stale))
                {
                    validTouchesEnded.push_back(touchId);
                }
            }

            if (validTouchesEnded.empty())
            {
                DebugAssert(! validTouchesEnded.empty());
                return std::pair<TouchClassification,float>(TouchClassification::Unknown, 0.0f);
            }

            priorBegan = _commonData->proxy->PenPriorForTouches(touchesBegan);
            VectorXf priorEnded = _commonData->proxy->PenPriorForTouches(validTouchesEnded);

            float pDown = PenDownProbabilityForTouchGivenPenEvent(touchId, downPair.first, touchesBegan, priorBegan);
            float pUp   = PenUpProbabilityForTouchGivenPenEvent(touchId,   upPair.first,   validTouchesEnded, priorEnded);

            DebugAssert(pUp   <= 1.0f && pUp   >= 0.0f);
            DebugAssert(pDown <= 1.0f && pDown >= 0.0f);

            // probability that both Up and Down events were emitted by this touch.
            // this assumes independence, which is true for timings but not really true for
            // the events themselves.  geometric mean makes the product comparable
            // to the individual numbers for non-ended touches.
            score = sqrtf(pDown * pUp);

            switchUpTime = tPenUp;

            double tTouchEnd = _clusterTracker->Data(touchId)->LastTimestamp();
            float dt = tPenUp - tTouchEnd;

            _commonData->proxy->TouchStatistics()[touchId]._penUpDeltaT = dt;
        }
        else
        {
            // doing this is like assuming we're going to get a PenEvent soon (in a few cycles from now).
            // it'll cause probabilities to start decaying.  this is really just cosmetic, since
            // everything will get finalized once the relevant touches all end.
            tPenUp = _clusterTracker->CurrentTime();

            float dt = tPenUp - _clusterTracker->Data(touchId)->LastTimestamp();

            // this is sort of arbitrary -- if we do get a good touch up, the touch will get reclassified
            // to pen in the first if clause.
            // the .5 just means we'll wait for .5f * StaleInterval() seconds before changing to palm,
            // to prevent rendering flicker which would occur if we changed to palm immediately while we wait.
            if (dt > _commonData->proxy->ClusterTracker()->StaleInterval() * .5f)
            {
                score = 0.0f;
            }
            else
            {
                float alpha   = std::max(0.0f, 1.0f - dt);
                score        *= alpha;

                switchUpTime = _clusterTracker->CurrentTime();
            }

            _commonData->proxy->TouchStatistics()[touchId]._penUpDeltaT = std::numeric_limits<float>::max();
        }
    }

    float switchDuration = SwitchOnDurationInTimeInterval(tPenDown, switchUpTime);

    float pDuration      = DurationTimeErrorProbabilityForTouch(touchId, switchDuration,
                                                                touchesBegan, priorBegan);

    score *= pDuration;

    double tTouchEnd = _clusterTracker->Data(touchId)->LastTimestamp();
    double tTouchBegin = _clusterTracker->Data(touchId)->FirstTimestamp();

    _commonData->proxy->TouchStatistics()[touchId]._touchDuration    = tTouchEnd - tTouchBegin;
    _commonData->proxy->TouchStatistics()[touchId]._switchOnDuration = switchDuration;

    if (_clusterTracker->Stroke(touchId)->Size() > 1)
    {
        DebugAssert(tTouchEnd - tTouchBegin > 0.0f);
    }

    return std::pair<TouchClassification, float>(type, score);

}

float PenEventClassifier::SwitchDurationLikelihoodForTimingError(float timingError)
{
    // OK -- mildly amusing fact.  We model the received pen down and pen up event times
    // as the true times corrupted by exponential random variables.  The sum of two exponential
    // RV's is a RV which has an Erlang distribution.  The Erlang distribution has P(0) = 0, i.e.
    // the probability of having zero timing error is nil.
    //
    // Hence, if there are two touches with similar durations, and one of them matches
    // the received switch timestamps exactly (or nearly exactly),
    // this "perfect match" is considered so unlikely that the Erlang distribution
    // will tell us to assign the pen events to the other touch.
    //
    // This was simply too weird, so the std::max clause is a workaround for this.

    // Erlang for 2 exponentials with rate lambda looks like
    // P(x)  = lambda^2 * x * exp(-lambda * x)
    // and has maximum likelihood at x = 1 / lambda
    // which is also the expected wait time, fwiw.

    // Erlang pdf has a single maximum at 1/lambda (see above).
    timingError = std::max(1.0f / lambda, std::abs(timingError));

    float likelihood = (lambda * lambda) * timingError * expf(- lambda * timingError);

    DebugAssert(likelihood >= 0.0f);

    return likelihood;

}

float PenEventClassifier::SwitchDownLikelihoodForDeltaT(float deltaT)
{

    const float samplingInterval = 1.0f / 60.0f;
    const float numberOfCyclesAllowedBefore = _commonData->proxy->_penDownBeforeTouchCycleThreshold;
    if (deltaT < -numberOfCyclesAllowedBefore * samplingInterval)
    {
        return 0.0f;
    }
    else
    {
        float s = deltaT -  _expectedDownDelayCycles * samplingInterval;

        // hand-fit exponential based on training data.
        // in actual use it seems like any reasonable choice of decreasing function will work fine,
        // so long as there's significant decay by 3-4 cycles.
        // the lambda = 20 parameter models the average wait as (1 / 20) sec, or about 3 cycles.
        return lambda * expf(-lambda * fabsf(s));
    }

}

float PenEventClassifier::SwitchUpLikelihoodForDeltaT(float deltaT)
{

    const float samplingInterval = 1.0f / 60.0f;
    const float numberOfCyclesAllowedAfter = _commonData->proxy->_penUpAfterTouchCycleThreshold;

    if (deltaT > numberOfCyclesAllowedAfter * samplingInterval)
    {
        return 0.0f;
    }
    else
    {

        float s = deltaT - ( - _expectedUpPreDelayCycles * samplingInterval);

        // hand-fit exponential based on training data.
        // in actual use it seems like any reasonable choice of decreasing function will work fine.
        return lambda * expf(-lambda * fabsf(s));
    }

}

void PenEventClassifier::MarkTouchTypes(IdTypeMap* touches, core::TouchId id, TouchClassification type)
{
    if (touches->count(id) > 0)
    {
        touches->at(id) = type;
    }
    else
    {
        touches->insert(IdTypePair(id, type));
    }
}

void PenEventClassifier::MarkTouchTypes(IdTypeMap* touches, TouchIdVector ids, TouchClassification type)
{
    for (core::TouchId id :  ids)
    {
        MarkTouchTypes(touches, id, type);
    }
}

void PenEventClassifier::FoundPenEventTouch(PenEventId id)
{
     _penDownCleared.push_back(id);
}

bool PenEventClassifier::IsPenEventTouchFound(PenEventId id)
{
    return (std::find(_penDownCleared.begin(), _penDownCleared.end(), id) != _penDownCleared.end());
}
}
}
