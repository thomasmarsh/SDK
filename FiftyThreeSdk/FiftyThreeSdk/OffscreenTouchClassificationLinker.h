//
//  OffscreenTouchClassificationLinker.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <vector>

#include "Core/Event.hpp"
#include "Core/Memory.h"
#include "Core/NoCopy.h"
#include "Core/Touch/Touch.h"

namespace fiftythree
{
namespace sdk
{
class OffscreenTouchClassificationLinker
{
public:
    ALIAS_PTR_TYPES(OffscreenTouchClassificationLinker);

protected:
    ~OffscreenTouchClassificationLinker() {}
    OffscreenTouchClassificationLinker() = default;

public:
    virtual Event<std::vector<core::Touch::cPtr>> &TouchesReclassified() = 0;

    virtual void UpdateTouchContinuationLinkage() = 0;

    static Ptr New();

    FT_NO_COPY(OffscreenTouchClassificationLinker)
};
}
}
