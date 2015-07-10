//
//  TouchClassifier.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include "Core/Touch/Touch.h"
#include "Core/Touch/TouchTracker.h"
#include "FiftyThreeSdk/Classification//Classifier.h"
#include "FiftyThreeSdk/TouchClassifier.h"

using Classifier = fiftythree::sdk::Classifier;
using namespace fiftythree::core;
using namespace fiftythree::sdk;
using std::vector;

namespace fiftythree
{
namespace sdk
{
TouchClassifier::Ptr ActiveClassifier::_Instance = TouchClassifier::Ptr();

void ActiveClassifier::Activate(const TouchClassifier::Ptr &classifier)
{
    _Instance = classifier;
}

TouchClassifier::Ptr ActiveClassifier::Instance()
{
    return _Instance;
}
}
}