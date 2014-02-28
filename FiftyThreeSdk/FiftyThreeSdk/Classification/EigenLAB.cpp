//
//  EigenLAB.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include <boost/foreach.hpp>
#include <iostream>
#include <map>

#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/CubicPolynomial.hpp"
#include "FiftyThreeSdk/Classification/EigenLAB.h"

using namespace Eigen;

using std::vector;

namespace fiftythree
{
namespace sdk
{
double tic(bool reset)
{
    static double __sec;
    if (reset)
    {
        __sec = get_time();
    }
    return __sec;
}

double toc()
{
    return (get_time() - tic(0));
}

Eigen::Map<Eigen::VectorXf> Map(vector<Vector2f> const & Z)
{
    return Eigen::Map<Eigen::VectorXf>((float*) &(Z[0]), Z.size() * 2);
}

Eigen::Map<Eigen::VectorXf> Map(vector<float> const & R)
{
    return Eigen::Map<Eigen::VectorXf>((float*) &R[0], R.size());
}

Eigen::Map<Eigen::VectorXi> Map(vector<int> const & R)
{
    return Eigen::Map<Eigen::VectorXi>((int*) &R[0], R.size());
}

Eigen::Map<Eigen::VectorXf> Map(Eigen::MatrixXf const & A)
{
    return Eigen::Map<Eigen::VectorXf>((float*) A.data(), A.rows()*A.cols());
}

Stride2Map XMap(vector<Vector2f> const & Z)
{
    return Stride2Map((float*) &Z[0], Z.size());
}

Stride2Map YMap(vector<Vector2f> const & Z)
{
    float  *data = (float*) &Z[0];
    return Stride2Map(data+1, Z.size());
}

float ShrinkTowardsZero(float x, float shrinkageAmount)
{
    return sgn(x) * std::max(0.0f, fabsf(x) - shrinkageAmount);
}

int sgn(float x)
{
    return (0.0f < x) - (x < 0.0f);
}

float Cross2f(Eigen::Vector2f const &v, Eigen::Vector2f const &w)
{
    return v.x() * w.y() - v.y() * w.x();
}

vector<Vector2f > Tail(vector< Vector2f> const & Z, size_t n)
{
    vector<Vector2f> W;
    if (Z.size() < n)
    {
        return W;
    }

    W = vector<Vector2f>(Z.end()-n, Z.end());

    return W;

}

void Append(vector<Vector2f > & to, vector< Vector2f> const & from)
{
    to.insert(to.end(), from.begin(), from.end());
}

vector<float> Diff(vector<float> const &X)
{

    vector<float> X_out(std::max(0, (int)X.size()-1));

    if (X.empty())
    {
        return X_out;
    }

    Eigen::Map<VectorXf>  mapIn   = Map(X);
    Eigen::Map<VectorXf>  mapOut  = Map(X_out);

    mapOut = Diff(mapIn);

    return X_out;

}

Eigen::VectorXf Diff(Eigen::VectorXf const & X)
{
    size_t N = X.size()-1;
    return X.segment(1,N) - X.segment(0,N);
}

// Note: this actually uses the statistician's normalization 1 / (N-1)
// which may not be what you want if you're using variance to compute geometric things
// like centroid size
float  Variance(vector<float> const & X)
{
    size_t N = X.size();

    if (N <= 1)
    {
        return 0;
    }

    Eigen::Map<Eigen::VectorXf> XM = Map(X);  //(&(X[0]), X.size());

    return Variance(XM);
}

float Variance(Eigen::VectorXf const & X)
{
    float mu = X.array().mean();
    int N = (int) X.size();

    return (1.0f / (N - 1.0f)) * ((Eigen::VectorXf) (X.array() - mu)).squaredNorm();
}

int HistogramBinIndex(float value, vector<float> const & edges)
{
    int index = 0;
    for ( ; index < edges.size(); index++)
    {
        if (value < edges[index])
        {
            break;
        }
    }
    return index;
}

Eigen::MatrixXf Covariance(vector<Eigen::Vector2f> const & D)
{
    Eigen::MatrixXf result;
    const float N = D.size();
    if (D.size() <= 1)
    {
        result = Eigen::MatrixXf(1,1);
        result(0,0) = 0.0f;
        return result;
    }
    Vector2f mean = CenterOfMass(D);

    vector<Eigen::Vector2f> meanVec(D.size(), mean);

    Eigen::VectorXf DMinusMu =  Map(D) - Map(meanVec);

    result = (1.0f/N-1.0f) * (DMinusMu * DMinusMu.transpose()).array();

    return result;
}

void PCA2f(Eigen::MatrixX2f const & D,
            Eigen::Vector2f & scale,
            Eigen::Vector2f & principalDirection,
            Eigen::Vector2f & mean)
{
    // D is a Nx2 matrix where each row is a sample.
    if (D.rows() > 0)
    {
        if (D.rows() == 1)
        {
            scale = Vector2f::UnitX();
            mean = D.row(0);
            return;
        }
        // Compute the 1x2 mean of the data vector then repmat it.
        mean =  D.colwise().mean();
        // Mean center the data.
        Eigen::MatrixX2f DMinusMu = D.rowwise() - mean.transpose();

        // By default this won't bother saving U. We're only
        // really interested in measuring 2-d "eccentricity" so we
        // just grab the singluar values and square them.
        // (numerics folks say using the SVD is more stable than eigs(cov(D)) )
        auto svd = DMinusMu.jacobiSvd(ComputeFullV);

        scale.x() = svd.singularValues()(0);
        scale.y() = svd.singularValues()(1);

        scale.array().square();
        principalDirection = svd.matrixV().col(0);
     }
}

Eigen::Vector2f CenterOfMass(vector<Eigen::Vector2f> const &points)
{

    Eigen::Vector2f center;

    if ( points.size() < 1 )
    {
        return center;
    }

    for (const Eigen::Vector2f & point :  points)
    {
        center += point;
    }

    center = center/( (float) points.size() );

    return center;
}

float RadialMoment(vector<Eigen::Vector2f> points)
{
    Eigen::Vector2f center = CenterOfMass(points);
    float moment = 0.0f;
    if (points.size() < 1)
    {
        return moment;
    }

    for (const Eigen::Vector2f & point :  points)
    {
        moment += std::sqrt((point - center).squaredNorm());
    }

    return moment;
}

float RadialMomentOfInertia(vector<Eigen::Vector2f> points)
{
    Eigen::Vector2f center = CenterOfMass(points);
    float moment = 0.0f;
    if ( points.size() < 1)
    {
        return moment;
    }

    for (const Eigen::Vector2f & point :  points)
    {
        moment += (point - center).squaredNorm();
    }

    return std::sqrt(moment);
}

VectorXf Linspace(float from, float to, size_t size)
{

    VectorXf out(size);

    if (size == 1)
    {
        // this decision is compatible with the arc-length resampling code, which
        // relies on this in the one-point case
        out[0] = from;
    }
    else
    {

        float  dt      = 1.0f / float(size-1);
        float  lambda  = 0.0f;
        size_t index   = 0;
        for (size_t j=size; j--; lambda += dt, index++)
        {
            float value = lambda * to + (1.0f - lambda) * from;
            out[index]  = value;
        }
    }

    return out;

}

// this is just a simple first-order finite difference approximation
// which is guaranteed to underestimate the true arc length.
// however, it is more than sufficient for our current usage.
float ArcLength(CubicPolynomial<XYType> const & P)
{

    float s = 0;
    XYType prev = P.ValueAt(0);
    float lambda = .1;
    for (int j=1; j<10; j++, lambda += .1)
    {
        XYType curr = P.ValueAt(lambda);
        s += (curr - prev).norm();

        prev = curr;

    }
    return s;
}

// making a special case since this often needs to be optimized.
// nothing calling it requires optimization at the moment.
Eigen::VectorXf CumSum0NormDiff(vector<Eigen::Vector2f> const &Z)
{
    int N_out = (int) Z.size() - 1;
    VectorXf ds(N_out);

    if (N_out <= 0)
    {
        return ds;
    }

    Stride2Map mapX = XMap(Z);
    Stride2Map mapY = YMap(Z);

    VectorXf normDiff = ((mapX.segment(1, N_out) - mapX.segment(0, N_out)).array().square() +
                         (mapY.segment(1, N_out) - mapY.segment(0, N_out)).array().square()).sqrt();

    ds = CumSum0(normDiff);

    return ds;
}

vector<float> NormDiff(vector<Vector2f> const &Z)
{
    int N_out = (int) Z.size() - 1;
    vector<float> ds(N_out);

    if (N_out <= 0)
    {
        return ds;
    }

    Stride2Map mapX = XMap(Z);
    Stride2Map mapY = YMap(Z);

    VectorXfMap  mapOut  = Map(ds);

    mapOut = ((mapX.segment(1, N_out) - mapX.segment(0, N_out)).array().square() +
              (mapY.segment(1, N_out) - mapY.segment(0, N_out)).array().square()).sqrt();

    return ds;
}

vector<Vector2f > Diff(vector< Vector2f> const & Z)
{
    vector<Vector2f> Z_out(Z.size()-1);

    if (Z.empty())
    {
        return Z_out;
    }

    size_t N = 2 * (Z.size() - 1);

    VectorXfMap  mapIn   = Map(Z);
    VectorXfMap  mapOut  = Map(Z_out);

    mapOut = mapIn.segment(2, N) - mapIn.segment(0, N);

    return Z_out;
}

vector<Vector2f > DividedDiff(vector< float > const &t, vector< Vector2f> const &Z)
{
    DebugAssert(t.size() == Z.size());

    VectorXfMap  tMap    = Map(t);
    MatrixXf     tCopy = tMap.replicate<1, 2>().transpose();
    VectorXfMap  tCopyMap = Map(tCopy);

    vector<Vector2f> Z_out(Z.size()-1);

    if (Z.empty())
    {
        return Z_out;
    }

    size_t N = 2 * (Z.size() - 1);

    VectorXfMap  mapIn   = Map(Z);
    VectorXfMap  mapOut  = Map(Z_out);

    mapOut = (mapIn.segment(2, N) - mapIn.segment(0, N));
    mapOut = mapOut.cwiseQuotient(tCopyMap.segment(2,N) - tCopyMap.segment(0,N));

    return Z_out;
}

vector<Vector2f>  NewtonCoefficient(vector<float > const &t, vector< Vector2f> const &Z, int D)
{

    DebugAssert(t.size() == Z.size());
    DebugAssert(D > -1);

    if (D==0)
    {
        vector<Vector2f> Z_out(Z);
        return Z_out;
    }
    else if (D > Z.size()-1)
    {
        vector<Vector2f> Z_out(-1);
        return Z_out;
    }

    vector<Vector2f> Z_out(Z.size());
    vector<Vector2f> Z_in(Z);

    if (Z.empty())
    {
        return Z_out;
    }

    VectorXfMap tMap = Map(t);
    MatrixXf tCopy = tMap.replicate<1, 2>().transpose();
    VectorXfMap  tCopyMap = Map(tCopy);

    for (int d=1; d <= D; ++d)
    {
        size_t N = 2 * (Z.size() - d);

        Z_out.pop_back();
        VectorXfMap  mapIn = Map(Z_in);
        VectorXfMap  mapOut  = Map(Z_out);

        mapOut = (mapIn.segment(2,N) - mapIn.segment(0,N));
        mapOut = mapOut.cwiseQuotient(tCopyMap.segment(2*d,N) - tCopyMap.segment(0,N));

        Z_in = Z_out;
    }

    return Z_out;

}

Eigen::VectorXf  CumSum(Eigen::VectorXf const & Z)
{
    Eigen::VectorXf sum(Z.size());

    sum(0) = Z(0);
    for (int j=1; j<sum.size(); j++)
    {
        sum(j) = sum(j-1) + Z(j);
    }

    return sum;
}

Eigen::VectorXf  CumSum0(Eigen::VectorXf const & Z)
{
    Eigen::VectorXf sum(Z.size()+1);

    sum[0] = 0;
    for (int j=1; j<sum.size(); j++)
    {
        sum[j] = sum[j-1] + Z[j-1];
    }

    return sum;
}

Eigen::Vector2f ComplexMultiply(Eigen::Vector2f const & z, Eigen::Vector2f const & w)
{
    float a = z.x();
    float b = z.y();
    float c = w.x();
    float d = w.y();

    return Vector2f(a * c - b * d, a * d + b * c);
}

// this gives the sum of all squared X and Y values (it's the 2-norm of the vector Z
// when you think of Z complex, i.e. Z = X + iY)
// in real-life one usually says "norm squared" but we're going with Eigen's terminology
float SquaredNorm(vector<Eigen::Vector2f> const & Z)
{
    if (Z.empty())
    {
        return 0;
    }

    VectorXfMap mapZ = Map(Z);

    return mapZ.squaredNorm();
}

Eigen::VectorXf ComponentWiseNorm(vector<Vector2f> const & Z)
{
    VectorXf W(Z.size());

    if (Z.empty())
    {
        return W;
    }

    Stride2Map mapInX = XMap(Z);
    Stride2Map mapInY = YMap(Z);

    W = (mapInX.array().square() + mapInY.array().square()).sqrt();

    return W;
}

// In matlab: (sqrt(sum(M.^2, 2)))
Eigen::VectorXf RowWiseComponentNorm(const Eigen::MatrixXf & M)
{
    return M.rowwise().squaredNorm().cwiseSqrt();
}
}
}
