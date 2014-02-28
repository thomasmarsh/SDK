//
//  TouchLogger.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include <boost/any.hpp>
#include <boost/bind.hpp>
#include <boost/foreach.hpp>

#include "Core/Touch/Touch.h"
#include "Core/Touch/TouchTracker.h"
#include "FiftyThreeSdk/Classification/ClassificationProxy.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/Stroke.h"
#include "FiftyThreeSdk/Classification/TouchLogger.h"

// TODO: For some reason these asserts in these files cause
//       clang to crash. Only in Internal and Previe builds which are built rarely.
//       For now we disable asserts in this file.
#undef USE_DEBUG_ASSERT
#undef DebugAssert
#define USE_DEBUG_ASSERT FALSE
#define DebugAssert(X)

namespace
{
    static const char *kClassifierUseCancelledTouch = "classifierUseCancelled";
}

using namespace fiftythree::core;

namespace fiftythree {
namespace sdk {

//
//                  TouchData public methods                      //
//

void TouchData::SetPhase(core::TouchPhase phase) {
    _phaseHistory.push_back(phase);
    _phase = phase;
}

void TouchData::SetStroke(Stroke::Ptr stroke) {
    _stroke = stroke;
}

void TouchData::SetId(core::TouchId id) {
    _touchId = id;
}

void TouchData::TouchEnded() {
    _phase        = core::TouchPhase::Ended;
}

core::TouchPhase TouchData::Phase() {
    return _phase;
}

core::TouchPhase TouchData::Phase(int idx) {
    if (idx < 0) {
        return _phaseHistory[0];
    }
    else if ( idx > _phaseHistory.size()-1 ) {
        return _phaseHistory.back();
    }
    else {
        return _phaseHistory[idx];
    }
}

Stroke::Ptr const & TouchData::Stroke()
{
    return _stroke;
}

core::TouchId TouchData::Id() {
    return _touchId;
}

double TouchData::FirstTimestamp() {
    return _beganTime;
}

double TouchData::LastTimestamp() {
    return _endedTime;
}

Eigen::Vector2f TouchData::LastPoint() {
    return _stroke->LastPoint();
}

Eigen::Vector2f TouchData::FirstPoint() {
    return _stroke->FirstPoint();
}

TouchData::Ptr TouchData::New(core::TouchId touchId,
                              Stroke::Ptr stroke,
                              core::TouchPhase phase,
                              double beganTime)
{
    return TouchData::Ptr(new TouchData(touchId,
                                        stroke,
                                        phase,
                                        beganTime) );
}

TouchData::Ptr TouchData::New() {
    return TouchData::Ptr();
}

TouchData::TouchData(core::TouchId touchId, Stroke::Ptr stroke,
                     core::TouchPhase phase, double beganTime)
{
    _beganTime   = beganTime;
    _endedTime   = beganTime;

    _phase       = phase;
    _phaseHistory.push_back(phase);
    _stroke = stroke;
    _touchId = touchId;

    _arrivalTime = stroke->FirstAbsoluteTimestamp();
    _terminalTime = Inf;
}

TouchData::TouchData() {
    _phase = core::TouchPhase::Unknown;
    _touchId =  InvalidTouchId();
    _stroke = Stroke::Ptr();

    _beganTime = -Inf;
}

//
//                  PenEventData public methods                   //
//

PenEventType PenEventData::Type() {
    return _eventType;
}

double PenEventData::Time() {
    return _eventTime;
}

PenEventId PenEventData::Id() {
    return _eventId;
}

PenEventData::Ptr PenEventData::New(int eventId,
                                    PenEventType eventType,
                                    double eventTime)
{
    return PenEventData::Ptr(new PenEventData(eventId,
                                              eventType,
                                              eventTime)
                             );
}

PenEventData::Ptr PenEventData::New() {
    return PenEventData::Ptr();
}

PenEventData::PenEventData(int eventId,
                           PenEventType eventType,
                           double eventTime) {
    _eventId = eventId;
    _eventTime = eventTime;
    _eventType = eventType;
}

PenEventData::PenEventData() {
    _eventId = -1;
    _eventTime = -Inf;
    _eventType = PenEventType::Unknown;
}

//
//                  TouchLogger protected methods                 //
//
void TouchLogger::LogEndedTouch(core::TouchId id) {

    std::deque<core::TouchId>::iterator location = std::find(_endedTouches.begin(), _endedTouches.end(), id);
    if ( location != _endedTouches.end() ) {
        // Already ended this touch...abort.
        return;
    }
    else {
        _endedTouches.push_back(id);
    }

    std::sort(_endedTouches.begin(), _endedTouches.end());
}

bool TouchLogger::PenEventXBeforePenEventY(PenEventId idX, PenEventId idY) {
    return (PenTime(idX) < PenTime(idY));
}

void TouchLogger::FlushEndedTouchesFromActiveSet() {

    BOOST_FOREACH(core::TouchId id, _endedTouchesStaged)
    {
        _activeTouches.erase(id);
    }

    _endedTouchesStaged.clear();
}

//
//                  TouchLogger public methods                    //
//

core::TouchId TouchLogger::TouchPrecedingTouch(core::TouchId probeId)
{
    core::TouchId previousId = InvalidTouchId();
    BOOST_FOREACH(IdDataRefPair pair, _touchData)
    {
        core::TouchId touchId = pair.first;
        if (touchId == probeId)
        {
            return previousId;
        }
        previousId = touchId;
    }

    return InvalidTouchId();
}

core::TouchId     TouchLogger::MostRecentTouch()
{
    if(_touchData.empty())
    {
        return InvalidTouchId();
    }
    else
    {
        // uses flat_map's ordering to get the most recent
        return (*_touchData.rbegin()).first;
    }
}

// This uses the fact that flat_map is an ordered vector internally
// to extract the first reclassifiable touchId
core::TouchId TouchLogger::OldestReclassifiableTouch()
{

    BOOST_FOREACH(IdDataRefPair pair, _touchData)
    {
        if(_commonData->proxy->IsReclassifiable(pair.second->Touch(), pair.second->Stroke()))
        {
            return pair.first;
        }
    }
    return InvalidTouchId();
}

void TouchLogger::TouchesChanged(const std::set<core::Touch::Ptr> & touches) {
    FlushEndedTouchesFromActiveSet();

    _concurrentTouchesCache.clear();

    _allCancelledFlag = true;

    BOOST_FOREACH(core::Touch::cPtr touch, touches)
    {
        if(touch->Phase() != core::TouchPhase::Cancelled)
        {
            _allCancelledFlag = false;
            break;
        }

    }

    BOOST_FOREACH(core::Touch::Ptr touch, touches)
    {

        if (_currentTime < touch->CurrentSample().TimestampSeconds())
        {
            UpdateTime(touch->CurrentSample().TimestampSeconds());
        }

        if(_removedTouches.count(touch->Id()))
        {
            continue;
        }

        switch (touch->Phase()) {
            case core::TouchPhase::Began:
            {

                // we may get the Began event twice if the touch stays still after it begins, and
                // something else moves or otherwise changes.
                if (_touchData.count(touch->Id()) == 0)
                {
                    Stroke::Ptr stroke = Stroke::New();
                    double timestamp    = touch->CurrentSample().TimestampSeconds();
                    Eigen::Vector2f xy  = touch->CurrentSample().Location();

                    stroke->AddPoint(xy, timestamp);

                    TouchData::Ptr data = TouchData::New(touch->Id(),
                                                         stroke,
                                                         touch->Phase(),
                                                         timestamp);

                    _touchData.insert(TouchDataPair(touch->Id(), data));
                    _activeTouches.insert(touch->Id());

                    if(_commonData->proxy->UsePrivateAPI())
                    {
                        if (touch->CurrentSample().TouchRadius())
                        {
                            float r  = *(touch->CurrentSample().TouchRadius());
                            stroke->AddTouchRadius(r);
                        }
                    }

                }

                break;
            }

            case core::TouchPhase::Moved:
            {

                TouchData::Ptr touchData;

                try
                {
                    touchData = _touchData.at(touch->Id());
                }
                catch (...)
                {
                    DebugAssert(touchData);
                    continue;
                }

                double timestamp    = touch->CurrentSample().TimestampSeconds();
                Eigen::Vector2f xy  = touch->CurrentSample().Location();

                if(timestamp > touchData->LastTimestamp() + .001 &&
                   touchData->Stroke()->LastPoint() != xy)
                {
                    touchData->Stroke()->AddPoint(xy, timestamp);
                    touchData->SetPhase(core::TouchPhase::Moved);

                    touchData->SetEndedTime(timestamp);

                    if(_commonData->proxy->UsePrivateAPI())
                    {
                        if ( touch->CurrentSample().TouchRadius())
                        {
                            float r  = *(touch->CurrentSample().TouchRadius());
                            touchData->Stroke()->AddTouchRadius(r);
                        }
                    }

                }

                break;
            }

            case core::TouchPhase::Cancelled:
            {

                // iOS will cancel large palm touches sometimes to break them into 2 touches
                // and vice-versa. from our point of view, this is still valuable information
                // and should be treated as an ended touch.
                TouchData::Ptr touchData;

                boost::container::flat_map<core::TouchId, TouchData::Ptr>::const_iterator it = _touchData.find(touch->Id());

                if (it != _touchData.end())
                {
                    touchData = it->second;
                    DebugAssert(touchData);

                    if (touchData)
                    {
                        if (touchData->Phase() != core::TouchPhase::Cancelled)
                        {
                            double timestamp    = touch->CurrentSample().TimestampSeconds();
                            Eigen::Vector2f xy  = touch->CurrentSample().Location();

                            Stroke::Ptr stroke = touchData->Stroke();

                            if(timestamp > touchData->LastTimestamp() + .001)
                            {
                                touchData->Stroke()->AddPoint(xy, timestamp);
                            }

                            touchData->SetEndedTime(timestamp);
                            touchData->TouchEnded();

                            touchData->SetPhase(core::TouchPhase::Cancelled);

                            if(_allCancelledFlag)
                            {
                                touch->DynamicProperties()[kClassifierUseCancelledTouch] = boost::any(false);
                            }
                            else
                            {
                                touch->DynamicProperties()[kClassifierUseCancelledTouch] = boost::any(true);
                            }

                            LogEndedTouch(touch->Id());

                            _endedTouchesStaged.push_back(touch->Id());

                            if(_commonData->proxy->UsePrivateAPI())
                            {
                                if (touch->CurrentSample().TouchRadius())
                                {
                                    float r  = *(touch->CurrentSample().TouchRadius());
                                    touchData->Stroke()->AddTouchRadius(r);
                                }
                            }
                        }
                    }
                }
                else
                {
                    DebugAssert(touchData);
                    continue;
                }

                break;
            }

            case core::TouchPhase::Ended:
            {

                // iOS will cancel large palm touches under unclear circumstances.
                // from our point of view, this is still valuable information and should be treated
                // as an ended touch.
                TouchData::Ptr touchData;

                try
                {
                    touchData = _touchData.at(touch->Id());

                }
                catch(...) {
                    DebugAssert(touchData);
                    continue;
                }

                if (touchData->Phase() != core::TouchPhase::Ended)
                {
                    double timestamp    = touch->CurrentSample().TimestampSeconds();
                    Eigen::Vector2f xy  = touch->CurrentSample().Location();

                    Stroke::Ptr stroke = touchData->Stroke();

                    touchData->SetEndedTime(timestamp);

                    touchData->Stroke()->AddPoint(xy, timestamp);
                    touchData->TouchEnded();

                    LogEndedTouch(touch->Id());
                    _endedTouchesStaged.push_back(touch->Id());

                    if(_commonData->proxy->UsePrivateAPI())
                    {
                        if (touch->CurrentSample().TouchRadius())
                        {
                            float r  = *(touch->CurrentSample().TouchRadius());
                            touchData->Stroke()->AddTouchRadius(r);
                        }
                    }

                }

                break;

            }

            case core::TouchPhase::Unknown:
            {
                DebugAssert(false);
                break;
            }

            case core::TouchPhase::Stationary:
            default:
                break;
        }

    }

    BOOST_FOREACH(core::Touch::Ptr touch, touches)
    {
        if(! _removedTouches.count(touch->Id()))
        {
            _touchData.at(touch->Id())->SetTouch(touch);
        }
    }

}

void TouchLogger::LogPenEvent(PenEvent event) {
    ClearStalePenEvents();

    PenEventData::Ptr newEvent = PenEventData::New(_penEventCounter,
                                                   event._type,
                                                   event._timestamp);

    PenEventId eventId;
    eventId = _penEventCounter;

    _penEventData.insert(std::pair<PenEventId, PenEventData::Ptr>(eventId, newEvent));
    _penEventOrder.push_back(eventId);
    //std::sort(_penEventOrder.begin(), _penEventOrder.end(),
    //          boost::bind(&TouchLogger::PenEventXBeforePenEventY, this, _1, _2));

    _penEventCounter++;
}

core::TouchId   TouchLogger::MostRecentEndedPen()
{

    BOOST_REVERSE_FOREACH(IdDataRefPair pair, _touchData)
    {
        if (pair.second->Phase() == TouchPhase::Ended)
        {
            Cluster::Ptr const & cluster = pair.second->Cluster();
            if(cluster->IsPenType())
            {
                return pair.first;
            }
        }
    }
    return InvalidTouchId();
}

PenEventId TouchLogger::MostRecentPenEvent()
{
    if(_penEventData.empty())
    {
        return PenEventId(-1);
    }
    else
    {
        return (*_penEventData.rbegin()).first;
    }
}

void       TouchLogger::RemoveMostRecentPenEvent()
{
    if(! _penEventData.empty())
    {
        _penEventData.erase((*_penEventData.rbegin()).first);
        _penEventOrder.pop_back();
    }
}

void TouchLogger::ClearAllData()
{
    _penEventData.clear();
    _penEventOrder.clear();

    _touchData.clear();

    _activeTouches.clear();
    _cancelledTouches.clear();

    _endedTouches.clear();
    _endedTouchesStaged.clear();

    // now clear removed touches if they are ended
    std::set<core::TouchId>::iterator it = _removedTouches.begin();
    for(;it != _removedTouches.end();)
    {
        if (! TouchTracker::Instance()->TouchWithId(*it))
        {
            _removedTouches.erase(it++);
        }
        else
        {
            ++it;
        }
    }

    _concurrentTouchesCache.clear();
}

void TouchLogger::ClearUnclusteredEndedTouches() {

    while ( NumberOfTouches() > 0)
    {
        if ( _endedTouches.size() > 0 ) {

            core::TouchId touchId = _endedTouches.front();

            TouchData::Ptr data;
            try
            {
                data = Data(touchId);
            }
            catch (...)
            {
                DebugAssert(false);
                break;
            }

            Cluster::Ptr cluster  = data->Cluster();

            // the cluster tracker makes the decision to evict old touches from clusters.  if it is in
            // a cluster, it is relevant to classification, and if it is not in a cluster, it isn't relevant.
            bool clusterExists   = cluster && _commonData->proxy->ClusterTracker()->ContainsClusterForKey(cluster->_id);

            bool reclassifiable  = _commonData->proxy->IsReclassifiable(data->Touch(), data->Stroke());

            // this should never happen.
            // a reclassifiable touch should always be in a cluster
            if(reclassifiable && (! clusterExists))
            {
                DebugAssert(false);
            }

            if (clusterExists || reclassifiable)
            {
                break;
            }
            else
            {
                _touchData.erase(touchId);
                _endedTouches.pop_front();

                // IsolatedStrokes holds on to data until the logger tells it not to
                _commonData->proxy->IsolatedStrokesClassifier()->TouchIdNoLongerLogged(touchId);
            }
        }
        else {
            break;
        }

    }

    // now clear removed touches if they are ended
    std::set<core::TouchId>::iterator it = _removedTouches.begin();
    for(;it != _removedTouches.end();)
    {
        if (! TouchTracker::Instance()->TouchWithId(*it))
        {
            _removedTouches.erase(it++);
        }
        else
        {
            ++it;
        }
    }
}

void TouchLogger::ClearStalePenEvents() {

    if ( _penEventOrder.empty() ) {
        return;
    }

    // Assumes events are logged time-monotonically
    while ( LoggedPenEventCount() > 0 ) {

        PenEventId id = _penEventOrder.front();
        AssertPenEvents(id);

        if (_currentTime - PenTime(id) > _trailingPenEventTimeWindow) {
            _penEventOrder.erase(_penEventOrder.begin());
            _penEventData.erase(id);
        }
        else {
            break;
        }

    }

}

TouchIdVector TouchLogger::CancelledTouches()
{
    return _cancelledTouches;
}

void TouchLogger::ClearCancelledTouches()
{
    _cancelledTouches.clear();
}

void TouchLogger::UpdateTime(double time)
{
    _currentTime = time;
    _relativeTime = time - _startTime;
}

double TouchLogger::Time()
{
    return _currentTime;
}

// Basically just a convenient wrapper for std::set_intersection
TouchIdVector TouchLogger::IntersectTouchIdVectors(TouchIdVector* v1, TouchIdVector* v2) {
    TouchIdVector vOut(*v1);

    TouchIdVector::iterator it;
    it = std::set_intersection(v1->begin(), v1->end(), v2->begin(), v2->end(), vOut.begin());

    vOut.resize(it-vOut.begin());

    return vOut;
}

TouchIdVector TouchLogger::IntersectTouchIdVectors(TouchIdVector* v1, TouchIdSet* v2) {
    TouchIdVector vOut(*v1);

    TouchIdVector::iterator it;
    it = std::set_intersection(v1->begin(), v1->end(), v2->begin(), v2->end(), vOut.begin());

    vOut.resize(it-vOut.begin());

    return vOut;
}

core::Touch::Ptr const & TouchLogger::TouchWithId(core::TouchId touchId)
{
    if (_touchData.find(touchId) != _touchData.end())
    {
        return _touchData.at(touchId)->Touch();
    }
    else
    {
        static fiftythree::core::Touch::Ptr nullPtr;
        return nullPtr;
    }
}

bool TouchLogger::ContainsTouchWithId(core::TouchId touchId)
{
    return _touchData.find(touchId) != _touchData.end();
}

TouchData::Ptr const & TouchLogger::Data(core::TouchId id) {

    if(_touchData.count(id))
    {
        return _touchData.at(id);
    }
    else
    {
        DebugAssert(_touchData.count(id));
        // TODO: Is this an anti-pattern?  I've seen others doing it.
        static TouchData::Ptr sentinel = TouchData::New();
        return sentinel;
    }
}

std::vector<TouchData::Ptr> TouchLogger::Data(TouchIdVector ids) {

    std::vector<TouchData::Ptr> data;
    data.clear();

    for (int i=0; i<ids.size(); ++i)
    {
        data.push_back(_touchData.at(ids[i]));
    }

    return data;

}

ClusterPtr       TouchLogger::Cluster(core::TouchId touchId)
{
    if(_touchData.count(touchId))
    {
        return _touchData.at(touchId)->Cluster();
    }
    else
    {
        DebugAssert(false);
        return Cluster::New();
    }
}

Stroke::Ptr const & TouchLogger::Stroke(core::TouchId id) {

    if(_touchData.count(id))
    {
        return _touchData.at(id)->Stroke();
    }
    else
    {
        DebugAssert(false);
        static Stroke::Ptr errorCase;
        return errorCase;
    }

}

std::vector<Stroke::Ptr> TouchLogger::Stroke(TouchIdVector ids) {

    std::vector<Stroke::Ptr> strokes;
    strokes.clear();

    for (int i=0; i<ids.size(); ++i)
    {
        strokes.push_back(_touchData.at(ids[i])->Stroke());
    }

    return strokes;

}

core::TouchPhase TouchLogger::Phase(core::TouchId id)
{
    DebugAssert(_touchData.count(id));

    return _touchData.at(id)->Phase();
}

std::vector<core::TouchPhase> TouchLogger::Phase(TouchIdVector ids) {

    std::vector<core::TouchPhase> phases;
    phases.clear();

    for (int i=0; i<ids.size(); ++i)
    {
        phases.push_back(_touchData.at(ids[i])->Phase());
    }

    return phases;

}

PenEventIdVector TouchLogger::PenEventsInTimeInterval(double t0, double t1, bool includeEndpoints)
{

    PenEventIdVector out;

    // this gets hit a lot so i'm keeping the conditional out of the loop.
    if(includeEndpoints)
    {
        BOOST_FOREACH(IdPenEventDataPair const & pair, _penEventData)
        {
            double timestamp = pair.second->Time();
            if(timestamp <= t1 && timestamp >= t0 )
            {
                out.push_back(pair.first);
            }
        }
    }
    else
    {
        BOOST_FOREACH(IdPenEventDataPair const & pair, _penEventData)
        {
            double timestamp = pair.second->Time();
            if(timestamp < t1 && timestamp > t0 )
            {
                out.push_back(pair.first);
            }
        }

    }

    return out;

}

PenEventIdSet TouchLogger::PenEventSetInTimeInterval(double t0, double t1)
{
    PenEventIdSet out;

    BOOST_FOREACH(IdPenEventDataPair  const & pair, _penEventData)
    {
        if(pair.second->Time() <= t1 && pair.second->Time() >= t0 )
        {
            out.insert(pair.first);
        }
    }

    return out;

}

PenEventIdSet TouchLogger::PenBeganEventSetInTimeInterval(double t0, double t1)
{
    PenEventIdSet out;

    BOOST_FOREACH(IdPenEventDataPair  const & pair, _penEventData)
    {
        if((pair.second->Type() == PenEventType::Tip1Down || pair.second->Type() == PenEventType::Tip2Down) &&
           (pair.second->Time() <= t1 && pair.second->Time() >= t0) )
        {
            out.insert(pair.first);
        }
    }

    return out;
}

PenEventIdSet TouchLogger::PenEndedEventSetInTimeInterval(double t0, double t1)
{

    PenEventIdSet out;

    BOOST_FOREACH(IdPenEventDataPair  const & pair, _penEventData)
    {
        if((pair.second->Type() == PenEventType::Tip1Up || pair.second->Type() == PenEventType::Tip2Up) &&
           (pair.second->Time() <= t1 && pair.second->Time() >= t0) )
        {
            out.insert(pair.first);
        }
    }

    return out;
}

PenEventIdVector TouchLogger::PenBeganEventsInTimeInterval(double t0, double t1)
{

    PenEventIdVector out;

    BOOST_FOREACH(IdPenEventDataPair const & pair, _penEventData)
    {
        if((pair.second->Type() == PenEventType::Tip1Down || pair.second->Type() == PenEventType::Tip2Down) &&
           (pair.second->Time() <= t1 && pair.second->Time() >= t0) )
        {
            out.push_back(pair.first);
        }
    }

    return out;
}

PenEventIdVector TouchLogger::PenEndedEventsInTimeInterval(double t0, double t1)
{

    PenEventIdVector out;

    BOOST_FOREACH(IdPenEventDataPair  const & pair, _penEventData)
    {
        if((pair.second->Type() == PenEventType::Tip1Up || pair.second->Type() == PenEventType::Tip2Up) &&
           (pair.second->Time() <= t1 && pair.second->Time() >= t0) )
        {
            out.push_back(pair.first);
        }
    }

    return out;
}

PenEventData::Ptr const & TouchLogger::PenData(PenEventId id)
{
    AssertPenEvents(id);

    return _penEventData[id];
}

std::vector<PenEventData::Ptr> TouchLogger::PenData(PenEventIdVector ids) {

    std::vector<PenEventData::Ptr> events;
    events.clear();
    for (int i=0; i<ids.size(); ++i) {
        events.push_back(PenData(ids[i]));
    }

    return events;
}

double TouchLogger::PenTime(PenEventId id) {
    AssertPenEvents(id);
    return _penEventData[id]->Time();
}

std::vector<double> TouchLogger::PenTime(PenEventIdVector ids) {
    std::vector<double> times;
    times.clear();

    for (int i=0; i < ids.size(); ++i) {
        times.push_back(PenTime(ids[i]));
    }

    return times;
}

PenEventType TouchLogger::PenType(PenEventId id) {
    AssertPenEvents(id);

    return _penEventData[id]->Type();
}

std::vector<PenEventType> TouchLogger::PenType(PenEventIdVector ids) {
    std::vector<PenEventType> types;
    types.clear();

    for (int i=0; i < ids.size(); ++i) {
        types.push_back(PenType(ids[i]));
    }

    return types;
}

TouchIdVector TouchLogger::IdsInPhase(core::TouchPhase phase) {

    TouchIdVector ids;
    ids.clear();

    BOOST_FOREACH(TouchDataPair  const & pair, _touchData) {

        if ( pair.second->Phase() == phase ) {
            ids.push_back(pair.first);
        }

    }

    return ids;
}

bool TouchLogger::IsIdLogged(core::TouchId id) {
    return (_touchData.count(id) > 0);
}

int TouchLogger::LoggedPenEventCount() {
    return (int)_penEventData.size();
}

TouchIdVector TouchLogger::ActiveNonEndedIds() {
    TouchIdVector ids;

    BOOST_FOREACH(core::TouchId touchId, _activeTouches) {
        if(! TouchWithId(touchId)->IsPhaseEndedOrCancelled())
        {
            ids.push_back(touchId);
        }
    }

    return ids;
}

TouchIdVector TouchLogger::ActiveIds() {
    TouchIdVector ids;

    BOOST_FOREACH(core::TouchId touchId, _activeTouches) {
        ids.push_back(touchId);
    }

    return ids;
}

bool TouchLogger::IsEnded(core::TouchId touchId)
{

    BOOST_FOREACH(core::TouchId endedId, _endedTouches)
    {
        if (endedId == touchId)
        {
            return true;
        }
    }

    return false;

}

void TouchLogger::AssertIds(TouchIdVector ids) {
    for (int i=0; i<ids.size(); ++i) {
        AssertIds(ids[i]);
    }
}

void TouchLogger::AssertIds(core::TouchId id) {
    if (_touchData.count(id) < 1) {
        DebugAssert(false);
    }
}

void TouchLogger::AssertPenEvents(PenEventId id) {
    if (_penEventData.count(id) < 1) {
        DebugAssert(false);
    }
}

void TouchLogger::AssertPenEvents(PenEventIdVector ids) {
    for (int i=0; i < ids.size(); ++i) {
        AssertPenEvents(ids[i]);
    }
}

int TouchLogger::NumberOfTouches() {
    return (int)_touchData.size();
}

// Ids begun within specified (absolute) time interval
TouchIdSet   TouchLogger::TouchIdSetBeganInTimeInterval(double interval_start,
                                                        double interval_end)
{

    TouchIdSet ids;

    BOOST_FOREACH(TouchDataPair  const & pair, _touchData) {
        double touchStart = pair.second->FirstTimestamp();

        if ( ( touchStart <= interval_end ) &&
            ( touchStart >= interval_start )
            )
        {
            ids.insert(pair.first);
        }
    }

    return ids;
}

TouchIdSet   TouchLogger::TouchIdSetEndedInTimeInterval(double interval_start,
                                                        double interval_end)
{
    TouchIdSet ids;

    BOOST_FOREACH(TouchDataPair  const & pair, _touchData) {

        if(! TouchWithId(pair.first)->IsPhaseEndedOrCancelled())
        {
            continue;
        }

        double touchEnd = pair.second->LastTimestamp();

        if ( ( touchEnd <= interval_end ) &&
            ( touchEnd >= interval_start )
            )
        {
            ids.insert(pair.first);
        }
    }

    return ids;
}

void TouchLogger::RemoveTouch(core::TouchId touchId)
{
    _removedTouches.insert(touchId);

    _activeTouches.erase(touchId);
    _touchData.erase(touchId);

    // in case he was in here, remove him.
    _concurrentTouchesCache.clear();

    std::deque<TouchId>::iterator it2 = std::find(_endedTouches.begin(), _endedTouches.end(), touchId);
    if(it2 != _endedTouches.end())
    {
        _endedTouches.erase(it2);
    }

    std::vector<TouchId>::iterator it3 = std::find(_cancelledTouches.begin(), _cancelledTouches.end(), touchId);
    if(it3 != _cancelledTouches.end())
    {
        _cancelledTouches.erase(it3);
    }

    std::vector<TouchId>::iterator it4 = std::find(_endedTouchesStaged.begin(), _endedTouchesStaged.end(), touchId);
    if(it4 != _endedTouchesStaged.end())
    {
        _endedTouchesStaged.erase(it4);
    }

}

TouchIdVector TouchLogger::TouchIdsBeganInTimeInterval(double interval_start, double interval_end) {
    TouchIdVector ids;

    BOOST_FOREACH(TouchDataPair  const & pair, _touchData) {
        double touchStart = pair.second->FirstTimestamp();

        if (( touchStart <= interval_end )   &&
            ( touchStart >= interval_start )
            )
        {
            ids.push_back(pair.first);
        }
    }

    return ids;
}

TouchIdVector TouchLogger::TouchIdsEndedInTimeInterval(double interval_start,
                                                       double interval_end)
{

    TouchIdVector ids;
    ids.clear();

    BOOST_FOREACH(TouchDataPair  const & pair, _touchData) {

        if((! TouchWithId(pair.first)->IsPhaseEndedOrCancelled()) )
        {
            continue;
        }

        double touchEnd = pair.second->LastTimestamp();

        if ( ( touchEnd <= interval_end ) &&
            ( touchEnd >= interval_start )
            )
        {
            ids.push_back(pair.first);
        }
    }

    return ids;
}

TouchIdVector TouchLogger::ConcurrentTouches(core::TouchId probeId)
{
    if(_concurrentTouchesCache.count(probeId))
    {
        return _concurrentTouchesCache[probeId];
    }

    TouchIdVector out;

    double t0 = Data(probeId)->FirstTimestamp();
    double t1 = Data(probeId)->LastTimestamp();

    BOOST_FOREACH(IdDataRefPair const & pair, _touchData)
    {

        if (pair.first == probeId)
        {
            continue;
        }

        double s0 = pair.second->FirstTimestamp();
        double s1 = pair.second->LastTimestamp();

        if((s1 >= t0) && (s0 <= t1))
        {
            out.push_back(pair.first);
        }
    }

    _concurrentTouchesCache[probeId] = out;

    return out;
}

TouchClassification TouchLogger::MostRecentPenTipType()
{

    if(! _penEventData.empty())
    {
        // using the fact that maps are sorted by key and keys are increasing ints
        std::pair<PenEventId, PenEventData::Ptr> pair = *(_penEventData.rbegin());
        return pair.second->TouchType();
    }
    else
    {
        return TouchClassification::Pen;
    }

}

PenEventId TouchLogger::MostRecentPenUpEvent()
{
    PenEventId id;
    id = -1;

    for (std::vector<PenEventId>::reverse_iterator it=_penEventOrder.rbegin();
         it < _penEventOrder.rend(); ++it)
    {
        if (PenType(*it) == PenEventType::Tip1Up ||
            PenType(*it) == PenEventType::Tip2Up) {
            id = *it;
            break;
        }

    }

    return id;

}

PenEventId TouchLogger::MostRecentPenDownEvent() {
    PenEventId id;
    id = -1;

    for (std::vector<PenEventId>::reverse_iterator it=_penEventOrder.rbegin();
         it < _penEventOrder.rend(); ++it)
    {
        if (PenType(*it) == PenEventType::Tip1Down ||
            PenType(*it) == PenEventType::Tip2Down) {
            id = *it;
            break;
        }

    }

    return id;
}

TouchIdVector TouchLogger::LiveTouches() {
    TouchIdVector ids(_activeTouches.begin(), _activeTouches.end());

    return ids;
}

void TouchLogger::InsertStroke(core::TouchId touchId, Eigen::VectorXd t, Eigen::VectorXf x, Eigen::VectorXf y, int startIndex, int endIndex) {

    DebugAssert( (t.rows() >= startIndex+1) && (t.rows() >= endIndex+1) );

    Eigen::Vector2f xy;

    if (! IsIdLogged(touchId) ) {
        Stroke::Ptr stroke = Stroke::New();

        xy(0) = x(startIndex);
        xy(1) = y(startIndex);
        stroke->AddPoint(xy, t(startIndex));

        TouchData::Ptr data = TouchData::New(touchId,
                                             stroke,
                                             core::TouchPhase::Began,
                                             t(0));
        _touchData.insert(TouchDataPair(touchId, data));
    }

    TouchData::Ptr touchData = _touchData.at(touchId);

    for (int i = startIndex+1; i <= endIndex; ++i) {
        xy(0) = x(i);
        xy(1) = y(i);
        touchData->Stroke()->AddPoint(xy, t(i));
        touchData->SetPhase(core::TouchPhase::Moved);
    }

}

void TouchLogger::InsertStroke(core::TouchId touchId, Eigen::VectorXd t, Eigen::VectorXf x, Eigen::VectorXf y) {

    InsertStroke(touchId, t, x, y, 0, (int)t.rows()-1);

}

void TouchLogger::DeleteTouchId(core::TouchId id) {
    _touchData.erase(id);
}

core::TouchId InvalidTouchId()
{
    return core::TouchId(-1);
}

}
}
