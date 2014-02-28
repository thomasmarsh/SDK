//
//  FiniteDifferences.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include <algorithm>
#include <map>

#include "FiftyThreeSdk/Classification/Eigen.h"
#include "FiftyThreeSdk/Classification/EigenLAB.h"
#include "FiftyThreeSdk/Classification/FiniteDifferences.h"

using std::make_pair;
using std::map;
using std::vector;

namespace fiftythree
{
namespace sdk
{
// local divided difference stencil
vector<int> DividedDifferenceStencil(const int &order)
{
    // If order = 3, this returns the following vector:
    // [ -2 1 -1 0]
    // If order = 4, this returns the following vector:
    // [ 2 -2 1 -1 0]
    // If order = 5, this returns the following vector:
    // [ -3 2 -1 1 -1 0]
    // This weird order is done for two reasons:
    // - we want the central point to be the last added so that by default the last
    //   finite difference computed is a measure of cross-validation error
    // - with this order, then by computing backward differences we effectively get an
    //   estimate (a) for cross-validation at the central location by adding one
    //   point at a time and (b) for successive derivative evaluations at the
    //   central location by adding one point at a time.

    static map< int, vector<int>> StoredResults;

    // Hard-coding of stencils because we only care about derivatives less than
    // 4. More general code is below.
    if (StoredResults.empty())
    {
        vector<int> stencil;

        int tempOrder = 0;
        // [0]
        stencil.push_back(0);
        StoredResults.insert( std::make_pair(tempOrder, stencil) );

        tempOrder = 1;
        // [-1 0]
        stencil.push_back(0);
        stencil[0] = -1;
        StoredResults.insert( std::make_pair(tempOrder, stencil) );

        tempOrder = 2;
        // [1 -1 0]
        stencil.push_back(0);
        stencil[0] = 1;
        stencil[1] = -1;
        StoredResults.insert( std::make_pair(tempOrder, stencil) );

        tempOrder = 3;
        // [-2 1 -1 0]
        stencil.push_back(0);
        stencil[0] = -2;
        stencil[1] = 1;
        stencil[2] = -1;
        StoredResults.insert( std::make_pair(tempOrder, stencil) );
    }

    DebugAssert(order >= 0);
    vector< int > stencil(order+1);

    if (StoredResults.count(order) > 0)
    {
        stencil = StoredResults[order];
    }
    else
    {
        // The general code which generates the special cases above.

        for (int i=0; i < order; ++i)
        {
            stencil[i] = (int) std::floor((i+2)/2.0f);

            if ((i % 2) == 0)
            {
                stencil[i] *= -1;
            }
        }

        std::reverse(stencil.begin(), stencil.end()-1);

        stencil[order] = 0;

        StoredResults.insert(make_pair(order, stencil));
    }
    return stencil;
}
}
}
