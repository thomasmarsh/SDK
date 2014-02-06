//
//  TouchLogger.h
//  Classification
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <boost/container/flat_map.hpp>
#include "Common/Memory.h"
#include <iostream>

#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "Common/Touch/Touch.h"
#include "FiftyThreeSdk/Classification/Stroke.h"

namespace fiftythree {
namespace classification {

typedef std::pair<common::TouchId, bool> IdBoolPair;
typedef std::vector<common::TouchId> TouchIdVector;
typedef std::set<common::TouchId> TouchIdSet;
typedef std::vector<PenEventId> PenEventIdVector;
typedef std::set<PenEventId> PenEventIdSet;

// break circular dependence
class Cluster;
typedef fiftythree::common::shared_ptr<Cluster> ClusterPtr;
typedef fiftythree::common::shared_ptr<const Cluster> ClusterCPtr;

// A container of data for each touch
class TouchData {
protected:
    common::TouchId     _touchId;
    common::TouchPhase  _phase;

    curves::Stroke::Ptr _stroke;
    common::Touch::Ptr  _touch;

    ClusterPtr          _cluster;
    
    // In theory, this should have the same size as the stroke
    std::vector<common::TouchPhase> _phaseHistory;

    // if the touch is still alive, _endedTime will be the current timestamp as passed
    // in to OnTouchesChanged
    double              _beganTime;
    double              _endedTime;
    double              _arrivalTime;
    double              _terminalTime;

    int                 _isolatedIncrementalUpdateIndex;  // Index determining incremental updates
    
public:
    typedef fiftythree::common::shared_ptr<TouchData> Ptr;

protected:
    // methods

public:

    static TouchData::Ptr New(common::TouchId touchId,
                              curves::Stroke::Ptr stroke,
                              common::TouchPhase phase,
                              double beganTime);
    static TouchData::Ptr New();

    TouchData();
    TouchData(common::TouchId id,
              curves::Stroke::Ptr stroke,
              common::TouchPhase phase,
              double beganTime);

    void SetPhase(common::TouchPhase phase);
    void SetStroke(curves::Stroke::Ptr stroke);
    void SetId(common::TouchId id);

    void SetIsolatedIncrementalUpdateIndex(int index) {
        _isolatedIncrementalUpdateIndex = index;
    }
    int GetIsolatedIncrementalUpdateIndex() {
        return _isolatedIncrementalUpdateIndex;
    }

    void SetEndedTime(double t)
    {
        _endedTime = t;
    }

    void SetTouch(common::Touch::Ptr touch)
    {
        _touch = touch;
    }
    
   
    void SetCluster(ClusterPtr cluster)
    {
        _cluster = cluster;
    }
    
    ClusterCPtr Cluster() const
    {
        return _cluster;
    }
    
    ClusterPtr Cluster()
    {
        return _cluster;
    }
    
    void TouchEnded();

    double LastTimestamp();
    double FirstTimestamp();
    Eigen::Vector2f LastPoint();
    Eigen::Vector2f FirstPoint();

    bool IsPhaseEndedOrCancelled()
    {
        return _touch->IsPhaseEndedOrCancelled();
    }

    common::TouchPhase  Phase();
    common::TouchPhase  Phase(int idx);
    curves::Stroke::Ptr const & Stroke();
    common::TouchId     Id();

    common::Touch::Ptr const & Touch()
    {
        DebugAssert(_touch);
        return _touch;
    }

};

typedef std::pair<common::TouchId, TouchData::Ptr> IdDataPair;

typedef std::pair<common::TouchId, TouchData::Ptr const &> IdDataRefPair;

// A container of data for each PenEvent
class PenEventData {
protected:
    // members
    double _eventTime;
    PenEventId _eventId;
    PenEventType _eventType;

public:
    typedef fiftythree::common::shared_ptr<PenEventData> Ptr;

protected:
    // methods

public:
    PenEventData();
    PenEventData(int          eventId,
                 PenEventType eventType,
                 double       eventTime);

    static PenEventData::Ptr New(int          eventId,
                                 PenEventType event,
                                 double time);
    static PenEventData::Ptr New();

    double          Time();
    PenEventId      Id();
    PenEventType    Type();

    bool TipDownEvent()
    {
        return _eventType == PenEventType::Tip1Down || _eventType == PenEventType::Tip2Down;
    }

    bool TipUpEvent()
    {
        return _eventType == PenEventType::Tip1Up || _eventType == PenEventType::Tip2Up;
    }

    TouchType       TouchType()
    {
        switch (_eventType)
        {
            case PenEventType::Tip1Down:
            case PenEventType::Tip1Up:
                return TouchType::PenTip1;
                break;

            case PenEventType::Tip2Down:
            case PenEventType::Tip2Up:
                return TouchType::PenTip2;
                break;

            default:
                return TouchType::Unknown;
                break;

        }
    }

};

typedef std::pair<PenEventId, PenEventData::Ptr> IdPenEventDataPair;

// Keeps all TouchData's, and does elementary processing for classifier queries
class TouchLogger {
protected:

    boost::container::flat_map<common::TouchId, TouchData::Ptr> _touchData;

    //std::map<common::TouchId, TouchData::Ptr> _touchData;

    // ConcurrentTouches is called a ton, and it's slow.  Cache the results.
    boost::container::flat_map<common::TouchId, TouchIdVector>  _concurrentTouchesCache;

    double _currentTime;
    double _startTime;     // Start time for first recorded touch
    double _relativeTime;  // Just _currenttime - _startTime

    
    // Only remove touches if *both* ended more than _trailingTouchTimeWindow seconds in the past,
    // *and* have currently stored more than _trailingTouchCount touches.
    // this should be made aware of the clusterTracker's need for data as well
    // seems a good place for shared pointers.
    const double _trailingTouchTimeWindow = 20.0;
    const int    _trailingTouchCount = 50;

    // Remove PenEvents that happened more than _trailingPenEventTimeWindow seconds ago
    const double _trailingPenEventTimeWindow = 20.0;

    // Keeps ordered logs of touch ended's, so we can figure out when to boot touch data
    std::set<common::TouchId>      _activeTouches;  //
    std::deque<common::TouchId>    _endedTouches;

    std::vector<common::TouchId>   _cancelledTouches;  // Staging container for cancelled touches
    std::vector<common::TouchId>   _endedTouchesStaged; // Staging container for ended touches

    std::set<common::TouchId>      _removedTouches; // touches which have been removed by the app
    
    // PenEvent logs
    boost::container::flat_map<PenEventId, PenEventData::Ptr> _penEventData;
    std::vector<PenEventId> _penEventOrder;

    // Silly way to translate ints to PenEvent Id's: manual counting
    int _penEventCounter = 0;

    const CommonData* _commonData;

    // detect the case where iOS cancels all touches because a phone call arrives, etc.
    // it gets updated on each call to touchesChanged.  Classifier can use it to detect this
    // situation and update/cancel clusters, etc.
    bool _allCancelledFlag;

public:
    typedef fiftythree::common::shared_ptr<TouchLogger> Ptr;
    typedef std::pair<common::TouchId, TouchData::Ptr> TouchDataPair;

protected:
    void LogEndedTouch(common::TouchId id);
    bool PenEventXBeforePenEventY(PenEventId idX, PenEventId idY);

    void FlushEndedTouchesFromActiveSet();

public:
    inline TouchLogger(CommonData const* commonData) :
                            _commonData(commonData),
                            _currentTime(0.0)
    {
    };

    
    /////////////////////////////////
    //
    // BEGIN convenience accessors and misc.
    //
    // Peter -- a lot of these convenience methods on top here might not be needed once you
    // integrate with TouchTracker, although it's possible easier to integrate, or just less typing,
    // if you add something similar to TouchTracker.
    //
    ///////////////////////////////

    std::vector<common::TouchId> const & NewlyEndedTouches()
    {
        return _endedTouchesStaged;
    }
    
    double CurrentTime()
    {
        return _currentTime;
    }

    // remove the touch and ignore and subsequent events for it.
    void RemoveTouch(common::TouchId touchId);
    
    bool Removed(common::TouchId touchId)
    {
        return _removedTouches.count(touchId);
    }
    
    common::TouchId OldestReclassifiableTouch();

    // Logging methods
    void TouchesChanged(const std::set<common::Touch::Ptr> & touches);
    void ClearUnclusteredEndedTouches();

    void LogPenEvent(PenEvent event);
    void ClearStalePenEvents();

    void ClearAllData();
    
    TouchIdVector   CancelledTouches();
    void            ClearCancelledTouches();

    void UpdateTime(double t);
    double Time();

    // Returns a TouchIdVector containing common elements
    TouchIdVector IntersectTouchIdVectors(TouchIdVector* v1, TouchIdVector* v2);
    TouchIdVector IntersectTouchIdVectors(TouchIdVector* v1, TouchIdSet* v2);

    // Accessors for Touch and PenEvent data
    TouchData::Ptr    const &        Data(common::TouchId id);
    std::vector<TouchData::Ptr>      Data(TouchIdVector ids);

    // if/when TouchTracker gets modified to hold the ended touches the classifier needs
    // we can remove this call and replace it with the like-named TouchTracker call.
    common::Touch::Ptr const &       TouchWithId(common::TouchId touchId);
    bool                             ContainsTouchWithId(common::TouchId touchId);

    curves::Stroke::Ptr const &      Stroke(common::TouchId id);
    std::vector<curves::Stroke::Ptr> Stroke(TouchIdVector ids);
    
    ClusterPtr                       Cluster(common::TouchId touchId);

    common::TouchPhase               Phase(common::TouchId id);
    std::vector<common::TouchPhase>  Phase(TouchIdVector ids);

    PenEventData::Ptr const &        PenData(PenEventId id);
    std::vector<PenEventData::Ptr>   PenData(PenEventIdVector ids);

    double                           PenTime(PenEventId id);
    std::vector<double>              PenTime(PenEventIdVector ids);

    PenEventType                     PenType(PenEventId id);
    std::vector<PenEventType>        PenType(PenEventIdVector ids);

    // For debugging
    void                            AssertIds(TouchIdVector ids);
    void                            AssertIds(common::TouchId id);
    void                            AssertPenEvents(PenEventIdVector ids);
    void                            AssertPenEvents(PenEventId id);

    ///////////////////////////////
    //
    // END convenience methods
    //
    ////////////////////////////

    /////////////////////////////////////////////////////////////
    //
    // BEGIN: Methods in active use by the classifier
    //
    ////////////////////////////////////////////////////////

    bool                            AllCancelledFlag()
    {
        return _allCancelledFlag;
    }

    TouchIdVector                   ActiveIds();
    TouchIdVector                   ActiveNonEndedIds();

    // Temporal Id filters
    // Ids begun within specified (absolute) time interval
    TouchIdVector                   TouchIdsBeganInTimeInterval(double interval_start,
                                                                double interval_end);

    TouchIdVector                   TouchIdsEndedInTimeInterval(double interval_start,
                                                                double interval_end);

    // Ids begun within specified (absolute) time interval
    TouchIdSet                      TouchIdSetBeganInTimeInterval(double interval_start,
                                                               double interval_end);

    TouchIdSet                      TouchIdSetEndedInTimeInterval(double interval_start,
                                                               double interval_end);

    TouchIdVector                   ConcurrentTouches(common::TouchId probeId);

    common::TouchId                 TouchPrecedingTouch(common::TouchId probeId);
    
    PenEventId                      MostRecentPenDownEvent();
    PenEventId                      MostRecentPenUpEvent();
    PenEventId                      MostRecentPenEvent();
    void                            RemoveMostRecentPenEvent();
    
    common::TouchId                 MostRecentTouch();
    
    common::TouchId                 MostRecentEndedPen();

    TouchType                       MostRecentPenTipType();

    PenEventIdVector                PenBeganEventsInTimeInterval(double t0, double t1);
    PenEventIdVector                PenEndedEventsInTimeInterval(double t0, double t1);

    PenEventIdSet                   PenBeganEventSetInTimeInterval(double t0, double t1);
    PenEventIdSet                   PenEndedEventSetInTimeInterval(double t0, double t1);

    PenEventIdSet                   PenEventSetInTimeInterval(double t0, double t1);

    PenEventIdVector                PenEventsInTimeInterval(double t0, double t1, bool includeEndpoints);

    bool                            IsIdLogged(common::TouchId id);

    ////////////////////////////////////////////////////
    //
    // End actively-used methods
    //
    /////////////////////////////////////////////////

    /////////////////////////////////////////////////////////////////
    //
    // BEGIN: Methods used only for classifier debugging: Debug.*
    //
    ////////////////////////////////////////////////////////

    void                            InsertStroke(common::TouchId touchId, 
                                                 Eigen::VectorXd t, 
                                                 Eigen::VectorXf x,
                                                 Eigen::VectorXf y);
    void                            InsertStroke(common::TouchId touchId, 
                                                 Eigen::VectorXd t, 
                                                 Eigen::VectorXf x,
                                                 Eigen::VectorXf y,
                                                 int startIndex, 
                                                 int endIndex);

    void                            DeleteTouchId(common::TouchId id);

    std::deque<common::TouchId>     EndedTouches()
    {
        return _endedTouches;
    }

    //////////////////////////////////////////////////////////
    //
    // End actively-used methods
    //
    /////////////////////////////////////////////////

    // PETER -- I believe the classifier is not using the methods below here at the moment.
    // I am leaving them here because they do something potentially useful though.

    // Processing: determine Ids satisfying some state condition
    TouchIdVector                   IdsInPhase(common::TouchPhase phase);
    TouchIdVector                   LiveTouches();
    TouchIdVector                   LiveTouchesOfType(TouchType type);
    TouchIdVector                   LiveTouchesInPhase(common::TouchPhase phase);
    TouchIdVector                   LiveTouchesOfTypeInPhase(TouchType type,
                                                             common::TouchPhase phase);
    TouchIdVector                   TouchesOfTypeInPhase(TouchType type, common::TouchPhase phase);
    
    // Lists of Id's, and testing for existence of Id
    int                             NumberOfTouches();
    TouchIdVector                   LoggedIds();


    bool                            IsEnded(common::TouchId touchId);

    int                             LoggedPenEventCount();

    // Find which touches from the given set are active at a given time
    TouchIdVector                   TouchIdsActiveAtTime(TouchIdVector ids, double time);

    common::TouchId                 LastEndedTouch(TouchIdVector ids);


};

common::TouchId InvalidTouchId();

}
}
