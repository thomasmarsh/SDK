//
//  DumbStylus.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <boost/foreach.hpp>
#include <tuple>

#include "Core/Touch/Touch.h"
#include "FiftyThreeSdk/Classification/Cluster.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/EigenLAB.h"
#include "FiftyThreeSdk/Classification/Stroke.h"
#include "FiftyThreeSdk/Classification/TouchLogger.h"

namespace fiftythree {
namespace sdk {

class DumbStylusClassifier
{

    TouchLogger*    _touchLog;
    const CommonData*     _commonData;

    std::map<ClusterId, core::TouchClassification>        _clusterTypes;
    std::map<core::TouchId, core::TouchClassification>  _touchTypes;

    IdTypeMap  ReclassifyByHandedness();
    void       SetClusterType(Cluster::Ptr const & cluster, core::TouchClassification newType, IdTypeMap &changedTypes);

public:

    typedef fiftythree::core::shared_ptr<DumbStylusClassifier> Ptr;

    DumbStylusClassifier(TouchLogger*      logPtr,
                         const CommonData* dataPtr) :
    _touchLog(logPtr),
    _commonData(dataPtr)
    {
    }

    IdTypeMap ReclassifyCurrentEvent();

    core::TouchClassification CurrentType(core::TouchId touchId);
    core::TouchClassification ClusterType(ClusterId clusterId);

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
