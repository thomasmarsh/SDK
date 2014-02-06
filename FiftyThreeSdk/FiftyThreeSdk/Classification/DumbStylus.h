//
//  DumbStylus.h
//  Classification
//
//  Created by matt on 12/9/13.
//  Copyright (c) 2013 Peter Sibley. All rights reserved.
//

#pragma once

#include "Common/Touch/Touch.h"
#include "FiftyThreeSdk/Classification/Stroke.h"
#include "FiftyThreeSdk/Classification/EigenLAB.h"

#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/TouchLogger.h"
#include "FiftyThreeSdk/Classification/Cluster.h"

#include <boost/foreach.hpp>
#include <boost/tuple/tuple.hpp>

namespace fiftythree {
namespace classification {

class DumbStylusClassifier
{

    TouchLogger*    _touchLog;
    const CommonData*     _commonData;
    
    std::map<ClusterId, TouchType>        _clusterTypes;
    std::map<common::TouchId, TouchType>  _touchTypes;
    
    IdTypeMap  ReclassifyByHandedness();
    void       SetClusterType(Cluster::Ptr const & cluster, TouchType newType, IdTypeMap &changedTypes);
    
public:
    
    typedef fiftythree::common::shared_ptr<DumbStylusClassifier> Ptr;
    
    DumbStylusClassifier(TouchLogger*      logPtr,
                         const CommonData* dataPtr) :
    _touchLog(logPtr),
    _commonData(dataPtr)
    {
    }
    
    IdTypeMap ReclassifyCurrentEvent();
    
    TouchType CurrentType(common::TouchId touchId);
    TouchType ClusterType(ClusterId clusterId);
    
    void      ClearStaleData();
    
    void      ClearAllData()
    {
        _clusterTypes.clear();
        _touchTypes.clear();
    }
    
    bool      HandednessLocked();
    
};
}
}



















