//
//  Quadrature.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "Common/Eigen.h"
#include "FiftyThreeSdk/Classification//EigenLAB.h"

namespace fiftythree {
namespace sdk {

// Integrate via Trapezoid rule
template <typename T>
T TrapezoidRule(const Eigen::Matrix<T, Eigen::Dynamic, 1> &x,
                const Eigen::Matrix<T, Eigen::Dynamic, 1> &y) {

    int N = x.size();
    DebugAssert( N == y.size() );

    T factor = (T) (1.0/2.0);

    return factor * (
                        (x.segment(1, N-1) - x.segment(0, N-1)).cwiseProduct(
                            y.segment(1, N-1) + y.segment(0, N-1) )
                    ).sum();

}

// Overloading for std:vector
template <typename T>
T TrapezoidRule(const std::vector<T> &x,
                const std::vector<T> &y) {

    Eigen::Map< Eigen::Matrix<T, Eigen::Dynamic, 1> > xMap((T*) &x[0], x.size());

    Eigen::Map< Eigen::Matrix<T, Eigen::Dynamic, 1> > yMap((T*) &y[0], y.size());

    return TrapezoidRule<T>(xMap, yMap);
}

// Return weights for Trapezoid rule
template <typename T>
Eigen::Matrix<T, Eigen::Dynamic, 1> TrapezoidRuleWeights(const Eigen::Matrix<T, Eigen::Dynamic, 1> &x) {

    Eigen::Matrix<T, Eigen::Dynamic, 1> weights;
    int N = x.size();
    weights.setZero(N,1);

    Eigen::Matrix<T, Eigen::Dynamic, 1> dx;
    dx.setZero(N-1, 1);
    dx = x.segment(1, N-1) - x.segment(0, N-1);

    weights.segment(0, N-1) = dx;
    weights.segment(1, N-1) += dx;

    T factor = (T) (1.0/2.0);

    return factor*weights;

}

// Overloading for std:vector
template <typename T>
std::vector<T> TrapezoidRuleWeights(const std::vector<T> &x) {

    int N = x.size();
    Eigen::Map< Eigen::Matrix<T, Eigen::Dynamic, 1> > xMap((T*) &x[0], N);

    std::vector<T> output(N);

    Eigen::Map< Eigen::Matrix<T, Eigen::Dynamic, 1> > outputMap((T*) &output[0], N);

    outputMap = TrapezoidRuleWeights<T>(xMap);

    return output;
}

}
}
