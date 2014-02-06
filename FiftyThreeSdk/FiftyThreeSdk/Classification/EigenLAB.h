//
//  EigenLAB.h
//  Curves
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

/*

 This contains a bunch of MATLABish functions ported over to Eigen.

 For the most part these functions return by value and rely on the compiler being
 smart enough to use NRVO to avoid making a copy.

 Some decisions should be made about where these helpers live.

 */

#include <ios>
#include <sys/time.h>
#include <Eigen/Geometry>
#include <limits>

#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/CubicPolynomial.hpp"

namespace fiftythree
{
namespace curves
{
    
template<typename T>
T round(T val)
{
  return floor(val + 0.5);
}

std::vector< Eigen::Vector2f >      Diff(std::vector< Eigen::Vector2f > const & Z);
std::vector<float>                  NormDiff(std::vector<Eigen::Vector2f> const &Z);

Eigen::VectorXf                     ComponentWiseNorm(std::vector< Eigen::Vector2f > const & Z);

// In matlab: (sqrt(sum(M.^2, 2)))
Eigen::VectorXf RowWiseComponentNorm(Eigen::MatrixXf M);

float                               SquaredNorm(std::vector< Eigen::Vector2f > const & Z);

// For some reason .squaredNorm() doesn't work for vector subsets of matrices
template<typename DerivedA>
typename DerivedA::Scalar SquaredNorm(const Eigen::MatrixBase<DerivedA> &A) { 

    DebugAssert( ( A.rows() == 1 ) || ( A.cols() == 1) );

    return A.array().square().sum();

}

// Floating-point zero test
// true if abs(input) <= nugget*machine_precision
template<typename T>
bool IsFPZero(T input, float nugget) {
    return ( std::abs(input) <= nugget * std::numeric_limits<T>::epsilon() );
}

template<typename T>
bool IsFPZero(T input) {
    return IsFPZero(input, 50.0f);
}

template<typename DerivedA>
void NormalizeVectorInPlace(Eigen::MatrixBase<DerivedA> &A) {
    DebugAssert( ( A.rows() == 1 ) || ( A.cols() == 1 ) );

    typename DerivedA::Scalar ANorm = std::sqrt(SquaredNorm(A));

    // If the vector is the zero vector, don't normalize
    if ( ! IsFPZero(ANorm) ) 
    {
        A /= std::sqrt(SquaredNorm(A));
    }
}


// Returns the covariance matrix, in Matlab parlance: (D-mean(D))*(D-mean(D)' 
Eigen::MatrixXf                     Covariance(std::vector<Eigen::Vector2f> const & D);

// Computes weighted mean of each column of XY
template<typename DerivedData, typename DerivedWeights>
Eigen::Matrix<typename DerivedData::Scalar, 1, Eigen::Dynamic> WeightedMean(const Eigen::MatrixBase<DerivedData> &XY, 
                                                               const Eigen::MatrixBase<DerivedWeights> &weights)
{
    DebugAssert(XY.rows() == weights.rows());

    typedef typename DerivedData::Scalar DataT;

    DataT weightSum = ((DataT) weights.sum());

    Eigen::Matrix<DataT, 1, Eigen::Dynamic> output = ( weights.transpose().template cast<DataT>() * XY )/weightSum;

    return output;
}
    
// Returns returns the principal component (In this 2D case, the second one is just perp the first.) of the
// data D.
//
// D is a Mx2 matrix with M data samples.
// scale are the weights of each principal component.
// principalDirection is the first component.
// mean is computed as part of the computation and might be useful to the caller.
void                                PCA2f(Eigen::MatrixX2f const & D,
                                          Eigen::Vector2f & scale,
                                          Eigen::Vector2f & principalDirection,
                                          Eigen::Vector2f & mean);

std::vector< Eigen::Vector2f >      Tail(std::vector< Eigen::Vector2f > const & Z, size_t n);
void                                Append(std::vector< Eigen::Vector2f > & to, std::vector< Eigen::Vector2f > const & from);
    
Eigen::Vector2f                     CenterOfMass(std::vector<Eigen::Vector2f> const &points);
float                               RadialMoment(std::vector<Eigen::Vector2f> points);
float                               RadialMomentOfInertia(std::vector<Eigen::Vector2f> points);

float                               Variance(std::vector<float> const & X);
float                               Variance(Eigen::VectorXf const & X);

std::vector<float>                  Diff(std::vector<float> const &X);
Eigen::VectorXf                     Diff(Eigen::VectorXf const &X);

Eigen::VectorXf                     CumSum0NormDiff(std::vector<Eigen::Vector2f> const &Z);
    
Eigen::VectorXf  CumSum(Eigen::VectorXf const & Z);
// like MATLAB cumsum (cumulative sum) but with a zero in the first entry for convenience when
// you're integrating somebody's derivative and you want the output to have the same length as input
Eigen::VectorXf  CumSum0(Eigen::VectorXf const & Z);

Eigen::VectorXf Linspace(float from, float to, size_t size);

// ContainerType would be std::vector< Vector2f >, std::vector<float>, etc
// DataType would be Vector2f, float, etc.
// interpolates Z = f(t) at times ti using linear interpolation
template <class ContainerType>
ContainerType Interp(float const *t, ContainerType const &Z, float const *ti, int inPointCount, int outPointCount)
{
    ContainerType out(outPointCount);

    if (inPointCount == 1)
    {
        for (int j=0; j<outPointCount; j++)
        {
            out[j] = Z[0];
        }

        return out;
    }

    // a is left endpoint of current interval
    unsigned int a = 0;
    unsigned int n = 0;
    for (unsigned int i=outPointCount; i--; )
    {
        // advance a until ti[n] lies in the interval ( t[a], t[a+1] ]
        while (ti[n] > t[a+1] && a < inPointCount-2)
        {
            a++;
        }

        // skip degenerate intervals unless we're at the very last point, in which case
        // the code below will just use the value at the appropriate endpoint
        if (t[a+1] == t[a] && i>0) {
            continue;
        }

        float dt_inv     = 1.0f / (t[a+1] - t[a]);
        if (t[a+1] == t[a])
        {
            dt_inv = 0;
        }

        typename ContainerType::value_type  dZ   = Z[a+1] - Z[a];

        if (ti[n] > t[inPointCount-1])
        {
            out[n] = Z[inPointCount-1];

        }
        else if (ti[n] < t[0])
        {
            out[n] = Z[0];
        }
        else
        {
            out[n] = Z[a] + (ti[n] - t[a])*dZ*dt_inv;
        }
        n++;
    }

    return out;
}

// assumes edges are in increasing order, otherwise results are wrong
int HistogramBinIndex(float value, std::vector<float> const & edges);
    
template <class ContainerType>
ContainerType Interp(Eigen::VectorXf const &t, ContainerType const &Z, Eigen::VectorXf const &ti)
{
    return Interp<ContainerType>((float*) t.data(), Z, (float*) ti.data(), t.size(), ti.size());
}

inline Eigen::Map<Eigen::VectorXf> Map(std::vector< Eigen::Vector2f > const & Z);

inline Eigen::Map<Eigen::VectorXf> Map(std::vector<float> const & R);
Eigen::Map<Eigen::VectorXi> Map(std::vector<int> const & R);

    
inline Eigen::Map<Eigen::VectorXf> Map(Eigen::MatrixXf const & A);
    
inline Stride2Map XMap(std::vector< Eigen::Vector2f > const & Z);

inline Stride2Map YMap(std::vector< Eigen::Vector2f > const & Z);

// Eigen only seems to support cross-product on Vector3f
float Cross2f(Eigen::Vector2f const &v, Eigen::Vector2f const &w);

float ShrinkTowardsZero(float x, float shrinkageAmount);

// move this to CubicPolynomial?
template < class DataType >
std::vector<DataType> EvaluateCubicAtTimes(CubicPolynomial<DataType> const & P, Eigen::VectorXf t)
{
    std::vector<DataType> values(t.size());

    for (int j=0; j < t.size(); j++)
    {
        values[j] = P.ValueAt(t[j]);
    }

    return values;
}

Eigen::Vector2f ComplexMultiply(Eigen::Vector2f const & z, Eigen::Vector2f const & w);

// this Perp() hack exists because in the case of Vector2f,
// IncrementalSmoother needs to extract the component of one vector
// which is orthogonal to another, to do acceleration shrinkage.
// In order to make IncrementalSmoother into a template class, we need to make Perp mean
// something in the case of Vector1f.  The DWIW thing is to return zero.
template <class VectorType>
VectorType Perp(VectorType const & decompose, VectorType const & relativeTo)
{

    int dimension = VectorType::RowsAtCompileTime;

    switch (dimension)
    {
        case 1:
        {
            return VectorType::Zero();
            break;
        }

        default:
        {
            // project decompose onto relativeTo
            VectorType projection = (decompose.dot(relativeTo) / (.0001f + relativeTo.squaredNorm())) * relativeTo;
            return decompose - projection;
            break;
        }

    }

}

float ArcLength(CubicPolynomial<XYType> const & P);

int   sgn(float x);

inline double get_time()
{
    timeval tv;
    // timezone tz;
    gettimeofday(&tv, NULL);
    double d_time = tv.tv_sec + tv.tv_usec/1000000.0;
    return d_time;
}

double tic(bool reset = 1);
double toc();

// Does orthogonalization assuming x and y have the same size
// Views each row as a Euclidean vector to take inner products. I.e.:
// [ x11   x12 ] ~ x,     [ y11   y12 ] ~ y,   <x1, y1> = x11*y11 + x12*y12
// [ x21   x22 ]          [ y21   y22 ]
// [   .    .  ]          [   .    .  ]
// [   .    .  ]          [   .    .  ]
// [   .    .  ]          [   .    .  ]
// [ xN1   xN2 ]          [ yN1   yN2 ]
template<typename DerivedA> 
DerivedA OrthogonalizeXAgainstY(const Eigen::MatrixBase<DerivedA> &x,
                                const Eigen::MatrixBase<DerivedA> &y) {

    DebugAssert(x.rows() == y.rows());
    DebugAssert(x.cols() == y.cols());
    int N = x.rows();

    DerivedA result(x);

    Eigen::Matrix<typename DerivedA::Scalar, Eigen::Dynamic, 1> ProjectionFactors;
    ProjectionFactors.resize(N, 1);
    
    // Numerator is x.*y
    // Denominator is |y|.^2
    ProjectionFactors = ( x.array() * y.array() ).rowwise().sum().array() / 
                        ( y.array().square()    ).rowwise().sum().array(); 

    for (int i = 0; i < x.cols(); ++i) {
        result.block(0,i,N,1).array() -= (y.block(0,i,N,1).array() * ProjectionFactors.array());
    }

    // And now we have to un-nan things when y has a zero row.
    float tol = 1e-8;
    Eigen::Matrix<bool,Eigen::Dynamic,1> flags = (y.array().square().rowwise().sum().array() > tol);
    for (int i = 0; i < x.cols(); ++i) {
        result.block(0,i,N,1) = flags.select(result.block(0,i,N,1), x.block(0,i,N,1));
    }

    return result;

}

// Views each row as an N-d vector, and returns the max Eucliean 2-norm over all rows
template<typename DerivedA>
typename DerivedA::Scalar RowwiseMaxNorm(const Eigen::MatrixBase<DerivedA> &x) {
    return std::sqrt(x.cwiseAbs2().rowwise().sum().maxCoeff());
}

// Returns ( x.rows() x (maxDegree + 1) ) sized Vandermonde matrix
template<typename T>
Eigen::Matrix<T, Eigen::Dynamic, Eigen::Dynamic> VandermondeMatrix(Eigen::Matrix<T, Eigen::Dynamic, 1> x, int maxDegree) {
    // Degree needs to be non-negative
    DebugAssert(maxDegree >= 0);

    int Nx = x.rows();

    Eigen::Matrix<T, Eigen::Dynamic, Eigen::Dynamic> output;
    output.resize(Nx, maxDegree + 1);

    for (int i = 0; i <= maxDegree; ++i) {
        output.block(0, i, Nx, 1) = x.array().pow(i);
    }

    return output;
}

}
}
