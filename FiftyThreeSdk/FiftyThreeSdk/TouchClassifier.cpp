//
//  TouchClassifier.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include "FiftyThreeSdk/TouchClassifier.h"

namespace fiftythree
{
namespace sdk
{
TouchClassifier::Ptr ActiveClassifier::_Instance = TouchClassifier::Ptr();

void ActiveClassifier::Activate(const TouchClassifier::Ptr & classifier)
{
    _Instance = classifier;
}

TouchClassifier::Ptr ActiveClassifier::Instance()
{
    return _Instance;
}
}
}
