//
//  LinAlgHelpers.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <cmath>

#include "Core/Asserts.h"
#include "FiftyThreeSdk/Classification/Eigen.h"
#include "FiftyThreeSdk/Classification/EigenLAB.h"

namespace fiftythree
{
namespace sdk
{
// Solves A x = b, just does it without all the Eigen syntax overhead
// Effectively, this method evaluates pinv(A)*b.
template <typename DerivedA, typename DerivedB>
Eigen::Matrix<typename DerivedA::Scalar, Eigen::Dynamic, 1> LinearLeastSquaresSolve(const Eigen::MatrixBase<DerivedA> &A,
                                                                                    const Eigen::MatrixBase<DerivedB> &b,
                                                                                    typename DerivedB::Scalar &residual)
{
    DebugAssert(b.cols() == 1);
    DebugAssert(A.rows() == b.rows());

    // Below is Eigen's recommended solution method
    // Since Eigen doesn't seem to have native support for a thin QR, this'll probably
    // be better than computing and storing the full QR to simulataneously get residuals and
    // coefficients.
    // Full QR ---> (A.rows() - A.cols()) unnecessary vectors
    // TODO: Internet says JacobiSVD is slow an buggy. Is QR faster?
    //DerivedB output;
    //output.resize(A.cols());
    //
    //DerivedB output = A.jacobiSvd(ComputeThinU | ComputeThinV).solve(b);

    auto QR = A.colPivHouseholderQr();

    // I'd be happy to use something like
    //DerivedB output = QR.solve(b);
    // But Eigen's documentation says some scary stuff:
    //   "This method just tries to find as good a solution as possible. "
    //   "If there exists more than one solution, this method will arbitrarily choose one."
    // Yikes. No idea what that means.
    //
    // So instead we'll do things the painful way:
    //DerivedA Q = ( (DerivedA) QR.householderQ() ).block(0, 0, A.rows(), QR.rank());

    auto R = ((DerivedA)QR.matrixQR().template triangularView<Eigen::Upper>()).block(0, 0, QR.rank(), QR.rank());

    // *sigh*, attempt to pre-empt more template snafu's
    auto bCopy = b.template cast<typename DerivedA::Scalar>();
    //bCopy.applyOnTheLeft(QR.householderQ().setLength(QR.rank()).adjoint());
    bCopy.applyOnTheLeft(QR.householderQ().adjoint());

    Eigen::Matrix<typename DerivedA::Scalar, Eigen::Dynamic, 1> output;
    output.setZero(A.cols(), 1);

    output.segment(0, QR.rank()) = (R.lu().solve(bCopy.segment(0, QR.rank())));

    output = QR.colsPermutation() * output;

    residual = 0; // implicit cast
    if (QR.rank() < bCopy.rows()) {
        residual = std::sqrt(
            SquaredNorm(
                bCopy.segment(QR.rank(), bCopy.rows() - QR.rank())));
    }

    return output;
}

// Throw away residual
template <typename DerivedA, typename DerivedB>
DerivedB LinearLeastSquaresSolve(const Eigen::MatrixBase<DerivedA> &A,
                                 const Eigen::MatrixBase<DerivedB> &b)
{
    typename DerivedB::Scalar residual;
    return LinearLeastSquaresSolve(A, b, residual);
}

// Solves diag(sqrt(w))*A*x = diag(sqrt(w))*b, just does it without all the Eigen syntax overhead
template <typename DerivedA, typename DerivedB>
DerivedB LinearLeastSquaresSolve(const Eigen::MatrixBase<DerivedA> &A,
                                 const Eigen::MatrixBase<DerivedB> &b,
                                 const Eigen::MatrixBase<DerivedB> &w)
{
    DebugAssert(w.rows() == A.rows());

    DerivedA tempA = w.cwiseSqrt().asDiagonal() * A;
    DerivedB tempB = w.cwiseSqrt().array() * b.array();

    // Hopefully the compiler optimizes this
    DerivedB output = LinearLeastSquaresSolve<DerivedA, DerivedB>(tempA, tempB);
    return output;
}
}
}
