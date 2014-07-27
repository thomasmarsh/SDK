//
//  FiniteDifferences.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <type_traits>

#include "Core/Eigen.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/EigenLAB.h"

namespace fiftythree
{
namespace sdk
{
typedef std::pair <int, std::vector <int>> LocationStencilPair;
typedef std::vector <LocationStencilPair> BoundaryStencil;
typedef std::map <int, std::vector<int>> BoundaryStencilMap;

template<typename T, typename I>
T Factorial(const I & num)
{
    static_assert(std::is_integral<I>::value, "Should be integral type");

    DebugAssert(num >= 0);
    T result = 1.0;

    for (int i=0; i < num; ++i)
    {
        result *= (T) (i+1);
    }

    return result;
}

// Derivative normalizations /////////////

// Computes (order-1) piecewise cross-validation error from the order'th
// derivative. E.g. for order=2 we get a piecewise-linear deviation.
template<typename DerivedA, typename DerivedB>
void NthDerivativeToCrossValidation(const Eigen::Map<DerivedA> &x,
                                Eigen::Map<DerivedB> &derivative,
                                const int &order)
{
    DebugAssert(x.cols() == 1);
    size_t N = x.rows();
    DerivedA scaling = DerivedA::Ones(N);

    if (N <= order)
    {
        // This is a spurious call -- we shouldn't do anything
        return;
    }

    switch (order)
    {
        case 0:
            // Do nothing -- Non-sensical
            break;

        case 1:
            // Do nothing -- I guess cross-validation error between zero function and pw constant?
            break;

        case 2:
            // Hierarchical surplus from linear interpolation
            derivative /= 2.0f;

            // Scaling with stencil +1
            scaling.segment(0,N-1) = scaling.segment(0, N-1).cwiseProduct(x.segment(0, N-1) - x.segment(1, N-1));
            scaling(N-1) *= x(N-1) - x(N-3);

            // Scaling with stencil -1
            scaling.segment(1,N-1) = scaling.segment(1, N-1).cwiseProduct(x.segment(1, N-1) - x.segment(0, N-1));
            scaling(0) *= x(0) - x(2);

            derivative.block(0,0,N,1) = derivative.block(0,0,N,1).cwiseProduct(scaling.template cast<float>());
            derivative.block(0,1,N,1) = derivative.block(0,1,N,1).cwiseProduct(scaling.template cast<float>());

            break;

        case 3:
            // Hierarchical surplus from quadratic interpolation
            derivative /= 6.0f;

            // Scaling with stencil +1
            scaling.segment(0,N-1) = scaling.segment(0, N-1).cwiseProduct(x.segment(0, N-1) - x.segment(1, N-1));
            scaling(N-1) *= x(N-1) - x(N-4);

            // Scaling with stencil -1
            scaling.segment(1,N-1) = scaling.segment(1, N-1).cwiseProduct(x.segment(1, N-1) - x.segment(0, N-1));
            scaling(0) *= x(0) - x(2);

            // Scaling with stencil -2
            scaling.segment(2,N-2) = scaling.segment(2, N-2).cwiseProduct(x.segment(2, N-2) - x.segment(0, N-2));
            scaling(0) *= x(0) - x(3);
            scaling(1) *= x(1) - x(3);

            derivative.block(0,0,N,1) = derivative.block(0,0,N,1).cwiseProduct(scaling.template cast<float>());
            derivative.block(0,1,N,1) = derivative.block(0,1,N,1).cwiseProduct(scaling.template cast<float>());

            break;

        default:
            // Not yet implemented
            DebugAssert(false);
    }

}

// Method for Eigen::MatrixBase's
template<typename DerivedA, typename DerivedB>
void NthDerivativeToCrossValidation(const Eigen::MatrixBase<DerivedA> &x,
                                    Eigen::MatrixBase<DerivedB> &derivative,
                                    const int &order)
{
    Eigen::Map<DerivedA> mapX((typename DerivedA::Scalar*) &x(0), x.rows(), x.cols());
    Eigen::Map<DerivedB> mapDerivative((typename DerivedB::Scalar*) &derivative(0), derivative.rows(), derivative.cols());

    NthDerivativeToCrossValidation<DerivedA, DerivedB>(mapX, mapDerivative, order);
}

template<typename DerivedA, typename DerivedB>
void NthDerivativeFromCrossValidation(const Eigen::Map<DerivedA> &x,
                                      Eigen::Map<DerivedB> &derivative,
                                      const int &order)
{
    DebugAssert(x.cols() == 1);
    size_t N = x.rows();
    DerivedA scaling = DerivedA::Ones(N);

    if (N <= order)
    {
        // This is a spurious call -- we shouldn't do anything
        return;
    }

    switch (order)
    {
        case 0:
            // Do nothing -- Non-sensical
            break;

        case 1:
            // Do nothing -- I guess cross-validation error between zero function and pw constant?
            break;

        case 2:

            // Scaling with stencil +1
            scaling.segment(0,N-1) = scaling.segment(0, N-1).cwiseProduct(x.segment(0, N-1) - x.segment(1, N-1));
            scaling(N-1) *= x(N-1) - x(N-3);

            // Scaling with stencil -1
            scaling.segment(1,N-1) = scaling.segment(1, N-1).cwiseProduct(x.segment(1, N-1) - x.segment(0, N-1));
            scaling(0) *= x(0) - x(2);

            derivative.block(0,0,N,1) = derivative.block(0,0,N,1).cwiseQuotient(scaling.template cast<float>());
            derivative.block(0,1,N,1) = derivative.block(0,1,N,1).cwiseQuotient(scaling.template cast<float>());

            // Hierarchical surplus to linear interpolation
            derivative *= 2.0f;

            break;

        case 3:

            // Scaling with stencil +1
            scaling.segment(0,N-1) = scaling.segment(0, N-1).cwiseProduct(x.segment(0, N-1) - x.segment(1, N-1));
            scaling(N-1) *= x(N-1) - x(N-4);

            // Scaling with stencil -1
            scaling.segment(1,N-1) = scaling.segment(1, N-1).cwiseProduct(x.segment(1, N-1) - x.segment(0, N-1));
            scaling(0) *= x(0) - x(2);

            // Scaling with stencil -2
            scaling.segment(2,N-2) = scaling.segment(2, N-2).cwiseProduct(x.segment(2, N-2) - x.segment(0, N-2));
            scaling(0) *= x(0) - x(3);
            scaling(1) *= x(1) - x(3);

            derivative.block(0,0,N,1) = derivative.block(0,0,N,1).cwiseQuotient(scaling.template cast<float>());
            derivative.block(0,1,N,1) = derivative.block(0,1,N,1).cwiseQuotient(scaling.template cast<float>());

            // Hierarchical surplus to quadratic interpolation
            derivative *= 6.0f;

            break;

        default:
            // Not yet implemented
            DebugAssert(false);
    }

}

// Method for Eigen::MatrixBase's
template<typename DerivedA, typename DerivedB>
void NthDerivativeFromCrossValidation(const Eigen::MatrixBase<DerivedA> &x,
                                      Eigen::MatrixBase<DerivedB> &derivative,
                                      const int &order)
{
    Eigen::Map<DerivedA> mapX((typename DerivedA::Scalar*) &x(0), x.rows(), x.cols());
    Eigen::Map<DerivedB> mapDerivative((typename DerivedB::Scalar*) &derivative(0), derivative.rows(), derivative.cols());

    NthDerivativeFromCrossValidation<DerivedA, DerivedB>(mapX, mapDerivative, order);
}

//
//                Begin utility methods for Finite Differences                 //
//

// Most of these methods are in-place computational tools for modularity of various
// common operations. None of them perform any kind of input checking.
//
// Divides each column of y by an abscissa quotient
template<typename DerivedA, typename DerivedB>
void ColumnWiseDividedDifferenceDivision(const Eigen::MatrixBase<DerivedA> &x,
                                         Eigen::MatrixBase<DerivedB> &y,
                                         const size_t &startIndex,
                                         const size_t &nRows,
                                         const size_t &xLeftOffset,
                                         const size_t &xRightOffset)
{
    for (size_t i = 0; i < y.cols(); ++i)
    {
        y.block(startIndex, i, nRows, 1) = y.block(startIndex, i, nRows, 1).cwiseQuotient( (x.segment(startIndex + xLeftOffset, nRows) - x.segment(startIndex + xRightOffset, nRows)).template cast<typename DerivedB::Scalar>());
    }
}

// Performs a single left-biased difference.
// Uses the given indices to determine which interior nodes need to be updated, and also
// divides by certain x-differences dependent on n.
template<typename DerivedA, typename DerivedB>
void LeftwardDividedDifference(const Eigen::MatrixBase<DerivedA> &x,
                               Eigen::MatrixBase<DerivedB> &output,
                               Eigen::MatrixBase<DerivedB> &tempStorage,
                               const size_t &n,
                               const size_t &xLeftOffset,
                               const size_t &xRightOffset,
                               const size_t &M,
                               const size_t &yCols)
{
    tempStorage.block(xLeftOffset, 0, M-n, yCols) = output.block(xLeftOffset, 0, M-n, yCols) - output.block(xLeftOffset-1, 0, M-n, yCols);

    output.block(xLeftOffset, 0, M-n, yCols) = tempStorage.block(xLeftOffset, 0, M-n, yCols);

    ColumnWiseDividedDifferenceDivision(x, output, xLeftOffset, M-n, xRightOffset, -xLeftOffset);
}

// Performs a single right-biased difference.
// Uses the given indices to determine which interior nodes need to be updated, and also
// divides by certain x-differences dependent on n.
template<typename DerivedA, typename DerivedB>
void RightwardDividedDifference(const Eigen::MatrixBase<DerivedA> &x,
                                Eigen::MatrixBase<DerivedB> &output,
                                Eigen::MatrixBase<DerivedB> &tempStorage,
                                const size_t &n,
                                const size_t &xLeftOffset,
                                const size_t &xRightOffset,
                                const size_t &M,
                                const size_t &yCols)
{
    tempStorage.block(xLeftOffset, 0, M-n, yCols) = output.block(xLeftOffset, 0, M-n, yCols) - output.block(xLeftOffset+1, 0, M-n, yCols);

    output.block(xLeftOffset, 0, M-n, yCols) = tempStorage.block(xLeftOffset, 0, M-n, yCols);

    ColumnWiseDividedDifferenceDivision(x, output, xLeftOffset, M-n, -xLeftOffset, xRightOffset);
}

// Copies central edge values to all boundary locations
template<typename Derived>
void PostDifferencingBoundaryCopying(Eigen::MatrixBase<Derived> &output,
                                     const size_t &xLeftOffset,
                                     const size_t &xRightOffset,
                                     const size_t &M,
                                     const size_t &yCols)
{
    size_t endIndex = M - 1 - xRightOffset;

    for (size_t i = 0; i < xLeftOffset; ++i)
    {
        output.block(i, 0, 1, yCols) = output.block(xLeftOffset, 0, 1, yCols);
    }
    for (size_t i = 0; i < xRightOffset; ++i)
    {
        output.block(M-1-i, 0, 1, yCols) = output.block(endIndex, 0, 1, yCols);
    }
}

// Performs factorial normalization
template<typename Derived>
void PostDifferencingDerivativeNormalization(Eigen::MatrixBase<Derived> &output,
                                             const size_t &currentN,
                                             const size_t &N)
{
    // Could save a little here with Pochhammer symbols
    output *= (Factorial<typename Derived::Scalar>(N)) /
              (Factorial<typename Derived::Scalar>(currentN));

}

//
//                End utility methods for Finite Differences                   //
//

// Takes a derivative of order currentN, and updates to a derivative of order N >= currentN.
// It edits y in-place for the output.
// NOTE: This function, given currentN, assumes some very special structure about x and y,
// and so it may not work the way one expects for general x and y.
// E.g. IncrementalDerivative(x, y, 0, 2) computes a second derivative of data y
// E.g. IncrementalDerivative(x, y, 1, 2) assumes y is a first derivative and
// overwrites it with the second derivative.
template<typename DerivedA, typename DerivedB>
void IncrementalDerivative(const Eigen::MatrixBase<DerivedA> &x,
                           Eigen::MatrixBase<DerivedB> &y,
                           const size_t &currentN,
                           const size_t &N)
{
    DebugAssert(N >= currentN);

    if (N == currentN)
    {
        return;
    }

    size_t M = x.rows();
    DebugAssert(M == y.rows());
    if (N - currentN >= M)
    {
        y.setZero();
        return;
    }

    size_t yCols = y.cols();

    DerivedB tempStorage = y;

    // Given currentN we can infer these parameters
    size_t xLeftOffset = (currentN+1)/2;
    size_t xRightOffset = xLeftOffset - (currentN % 2);

    for (size_t n = currentN+1; n <= N; ++n)
    {

        if ( (n % 2) == 1 ) // We add a stencil point on the left
        {

            xLeftOffset += 1;
            LeftwardDividedDifference(x, y, tempStorage, n, xLeftOffset, xRightOffset, M, yCols);

        }
        else // We add a stencil point on the right
        {

            xRightOffset += 1;
            RightwardDividedDifference(x, y, tempStorage, n, xLeftOffset, xRightOffset, M, yCols);

        }

    }

    PostDifferencingBoundaryCopying(y, xLeftOffset, xRightOffset, M, yCols);
    PostDifferencingDerivativeNormalization(y, currentN, N);
}

// Takes N'th order derivative of y wrt x, putting data in "output".
// This is the simplest method: does things with as little allocation as possible
// The stencil is automatically computed with size N+1, centered around a point, with a
// bias to the left in the case of N odd.
// This sacrifices a lot of flexibility for more general procedures but is quite fast.
// The powerhouse behind this is divided differences
template<typename DerivedA, typename DerivedB>
void Derivative(const Eigen::MatrixBase<DerivedA> &x,
                const Eigen::MatrixBase<DerivedB> &y,
                Eigen::MatrixBase<DerivedB> &output,
                const int &N)
{
    output = y;
    IncrementalDerivative(x, output, 0, N);
}

// Utilities /////////////////////////////

// Requires t.rows() == xy.rows()
template<typename DerivedA, typename DerivedB>
DerivedB JerkOrthogonalToVelocity(const Eigen::MatrixBase<DerivedA> &t,
                                  const Eigen::MatrixBase<DerivedB> &xy)
{
    //DerivedB velocity = NthDerivative(t, xy, 1);
    //DerivedB jerk = NthDerivative(t, xy, 3);

    DerivedB velocity = xy;
    IncrementalDerivative(t, velocity, 0, 1);

    DerivedB jerk = velocity;
    IncrementalDerivative(t, jerk, 1, 3);

    size_t N = xy.rows();

    DebugAssert(N==t.rows());

    Eigen::Matrix<typename DerivedB::Scalar, Eigen::Dynamic, 1> ProjectionFactors;
    ProjectionFactors.resize(N, 1);

    // Numerator is j.*v
    // Denominator is |v|.^2
    ProjectionFactors = ( velocity.array() * jerk.array() ).rowwise().sum().array() /
                        ( velocity.array().square()       ).rowwise().sum().array();

    // We're mostly concerned with xy.cols==2, so a for-loop should be fine on performance
    for (int i = 0; i < xy.cols(); ++i)
    {
        //output.block(0,i,N,1).array() -= (velocity.block(0,i,N,1).array() * ProjectionFactors.array());
        jerk.block(0,i,N,1).array() -= (velocity.block(0,i,N,1).array() * ProjectionFactors.array());
    }

    return jerk;
}

template<typename DerivedA, typename DerivedB>
DerivedB D4OrthogonalToVelocity(const Eigen::MatrixBase<DerivedA> &t,
                                const Eigen::MatrixBase<DerivedB> &xy)
{
    //DerivedB velocity = NthDerivative(t, xy, 1);
    //DerivedB d4 = NthDerivative(t, xy, 4);

    DerivedB velocity(xy);
    IncrementalDerivative(t, velocity, 0, 1);

    DerivedB d4(velocity);
    IncrementalDerivative(t, d4, 1, 4);

    //DerivedB output(d4);

    size_t N = xy.rows();

    DebugAssert(N==t.rows());

    Eigen::Matrix<typename DerivedB::Scalar, Eigen::Dynamic, 1> ProjectionFactors;
    ProjectionFactors.resize(N, 1);

    // prevent NaN
    velocity.array() += .00001f;

    // Numerator is j.*v
    // Denominator is |v|.^2
    ProjectionFactors = ( velocity.array() * d4.array() ).rowwise().sum().array() /
    ( velocity.array().square()       ).rowwise().sum().array();

    // We're mostly concerned with xy.cols==2, so a for-loop should be fine on performance
    for (int i = 0; i < xy.cols(); ++i)
    {
        //output.block(0,i,N,1).array() -= (velocity.block(0,i,N,1).array() * ProjectionFactors.array());
        d4.block(0,i,N,1).array() -= (velocity.block(0,i,N,1).array() * ProjectionFactors.array());
    }

    return d4;
}

template<typename DerivedA, typename DerivedB>
DerivedB D2OrthogonalToVelocity(const Eigen::MatrixBase<DerivedA> &t,
                                const Eigen::MatrixBase<DerivedB> &xy)
{

    //DerivedB velocity = NthDerivative(t, xy, 1);
    //DerivedB d2 = NthDerivative(t, xy, 2);

    DerivedB velocity(xy);
    IncrementalDerivative(t, velocity, 0, 1);

    DerivedB d2(velocity);
    IncrementalDerivative(t, d2, 1, 2);

    size_t N = xy.rows();

    DebugAssert(N==t.rows());

    Eigen::Matrix<typename DerivedB::Scalar, Eigen::Dynamic, 1> ProjectionFactors;
    ProjectionFactors.resize(N, 1);

    // Numerator is j.*v
    // Denominator is |v|.^2
    ProjectionFactors = ( velocity.array() * d2.array() ).rowwise().sum().array() /
    ( velocity.array().square()       ).rowwise().sum().array();

    // We're mostly concerned with xy.cols==2, so a for-loop should be fine on performance
    for (int i = 0; i < xy.cols(); ++i)
    {
        //output.block(0,i,N,1).array() -= (velocity.block(0,i,N,1).array() * ProjectionFactors.array());
        d2.block(0,i,N,1).array() -= (velocity.block(0,i,N,1).array() * ProjectionFactors.array());
    }

    return d2;
}

/*
Matt: "JerkOrthogonalToVelocity" is the function you wanted, and here's code to test:

// This is just from (x(t), y(t)) = (cos(t), 2*sin(t))
double traw[] =
{
                 0,
 0.349065850398866,
 0.698131700797732,
   1.0471975511966,
  1.39626340159546,
  1.74532925199433,
   2.0943951023932,
  2.44346095279206,
  2.79252680319093,
  3.14159265358979
};

double xraw[] =
{
                 1,
 0.939692620785908,
 0.766044443118978,
               0.5,
  0.17364817766693,
 -0.17364817766693,
              -0.5,
-0.766044443118978,
-0.939692620785908,
                -1
};

double yraw[] =
{
                 0,
 0.684040286651337,
  1.28557521937308,
  1.73205080756888,
  1.96961550602442,
  1.96961550602442,
  1.73205080756888,
  1.28557521937308,
  0.684040286651338,
  2.44929359829471e-16
};

// Create a stroke from the raw data
curves::Stroke::Ptr stroke = curves::Stroke::New();
for (int i = 0; i < 10; ++i)
{
    Eigen::Vector2f tempXY;
    tempXY(0) = (float) xraw[i];
    tempXY(1) = (float) yraw[i];

    stroke->AddPoint(tempXY, traw[i]);
}

// From a stroke, extract data in Eigen form
Eigen::MatrixX2f xy = stroke->XYMatrixMap();
Eigen::VectorXf t = stroke->RelativeTimestampMap();

// You could make t double's as well; the function is templated for mixed scalar types
MatrixX2f answer = JerkOrthogonalToVelocity(t, xy);
std::cout << "Answer:\n" << answer << std::endl;

// Output of the above:
// Answer:
//      0.339404     0.029923
//      0.339404     0.029923
//  -1.78814e-07            0
//    7.7486e-07  5.96046e-07
//  -9.53674e-07 -1.37091e-06
//             0  6.64361e-06
//   2.20537e-06 -3.03984e-06
//   4.47035e-06 -2.74181e-06
//  -5.93066e-06  1.54972e-06
//      0.339399   -0.0299226

// Matlab's answer:
//         0.339403393304619        0.0299229877918057
//          0.33940339330462        0.0299229877918057
//      7.43849426498855e-15      1.99840144432528e-15
//     -7.99360577730113e-15     -4.88498130835069e-15
//      3.33066907387547e-15       4.9960036108132e-15
//                         0                         0
//     -2.66453525910038e-15      3.66373598126302e-15
//      2.99760216648792e-15     -1.55431223447522e-15
//     -2.22044604925031e-15      6.66133814775094e-16
//         0.339403393304608       -0.0299229877918046

 */
}
}
