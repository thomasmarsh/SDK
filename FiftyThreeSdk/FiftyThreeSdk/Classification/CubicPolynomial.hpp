//
//  CubicPolynomial.hpp
//  FiftyThreeSdk
//
//  Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <type_traits>

#include "Core/Asserts.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"

namespace fiftythree
{
namespace sdk
{
/*
 This is a template class -- we care about 2 cases: T = float and T = Eigen::VectorNf where
 probably N = 2.

 Any factory methods like LineFromTo(a,b) are designed to work on the interval [0,1], so if
 CubicPolynomial P = CubicPolynomial::LineFromTo(a,b)
 then you will have P(0) = a and P(1) = b.

 */

template <class T>
class CubicPolynomial
{

    static_assert((T::ColsAtCompileTime == 1 &&
                   T::IsVectorAtCompileTime),
                  "Ensures it's an Eigen fixed sized column vector.");

protected:
    float _globalIntervalLeft;
    float _globalIntervalRight;
    float _standardIntervalLeft = -1;
    float _standardIntervalRight = 1;
public:

    T _a, _b, _c, _d;

    // store the points at which the polynomial is defined, if they are known.
    float _t0, _t1, _t2, _t3;

    int _definingValueCount;

    CubicPolynomial(T a, T b, T c, T d) : _a(a), _b(b), _c(c), _d(d), _definingValueCount(-1) {}
    CubicPolynomial() {}

    T ValueAt(float t) const
    {
        return _a * (t * t * t)    +
        _b * (t * t) +
        _c * t +
        _d;
    }

    T FirstDerivativeAt(float t) const
    {
        return 3.0f * _a * t * t +
                2.0f * _b * t +
                1.0f * _c;
    }

    T SecondDerivativeAt(float t) const
    {

        return 6.0f * _a * t +
                2.0f * _b;
    }

    static CubicPolynomial<T> Constant(T p)
    {
        return LineFromTo(p, p);
    }

    static CubicPolynomial<T> LineFromTo(T p, T q)
    {
        T d = p;
        T c = q - d;

        T a = CubicPolynomial<T>::Zero();
        T b = CubicPolynomial<T>::Zero();

        return CubicPolynomial(a, b, c, d);
    }

    // given a new value, this creates a polynomial which agrees with *this
    // at t=0 (in value, first derivative, and second derivatives) and has value (value)
    // at t=1, so we get a C^2 extension of *this.
    // formulas just come from explicit computation.
    CubicPolynomial<T> ExtendCubicTo(T value) const
    {
        // clang-format off

        T b = .5f * this->SecondDerivativeAt(1);
        T c =       this->FirstDerivativeAt(1);
        T d =       this->ValueAt(1);
        T a =       value - (b + c + d);
        // clang-format on

        return CubicPolynomial(a,b,c,d);
    }

    static CubicPolynomial<T> CubicThroughPointsWithFirstDerivatives(T p0, T p1, T fp0, T fp1)
    {
        // clang-format off
        T c = fp0;
        T d = p0;
        T a = fp1 - 2.0f * p1 + c + 2.0f * d;
        T b = p1 - (a + c + d);

        return CubicPolynomial(a,b,c,d);
        // clang-format on
    }

    static CubicPolynomial<T> CubicThroughPointsWithDerivativesAtZero(T p1, T p2, T fp0, T fpp0)
    {
        // clang-format off
        T b = .5f * fpp0;
        T c = fp0;
        T d = p1;
        T a = p2 - (b + c + d);

        return CubicPolynomial(a,b,c,d);
        // clang-format on
    }

    CubicPolynomial<T> ExtendQuadraticTo(T value) const
    {

        T c =       this->FirstDerivativeAt(1.0f);
        T d =       this->ValueAt(1.0f);
        T b =       value - (c + d);

        return CubicPolynomial(CubicPolynomial<T>::Zero(),b,c,d);
    }

    // this works for Eigen vector types.
    static T Zero()
    {
        return T::Zero();
    }

    // this produces polynomial P with P(0) = p, P(1) = r, and control point q
    static CubicPolynomial<T> QuadraticWithControlPoints(T p, T q, T r)
    {

        T a = CubicPolynomial<T>::Zero();
        T b = p - 2.0f * q + r;
        T c = 2.0f * (q - p);
        T d = p;

        return CubicPolynomial<T>(a,b,c,d);

    }

    static CubicPolynomial<T> QuadraticWithValueAndDerivativesAtTime(T f, T fp, T fpp, float t)
    {

        T b = .5f * fpp;
        T c = fp - t * fpp;
        T d = f - .5f * fpp * t * t - (fp - t * fpp) * t;

        CubicPolynomial<T> P(T::Zero(), b, c, d);

        P._t0 = t;
        P._definingValueCount = 1;

        return P;
    }

    static CubicPolynomial<T> QuadraticWithValueAndDerivativesAtZero(T f0, T fp0, T fpp0)
    {

        T b = .5f * fpp0;
        T c = fp0;
        T d = f0;

        return CubicPolynomial<T>(T::Zero(), b, c, d);

    }

    // the polynomial was constructed using one of the "ValuesAtTimes" factory methods,
    // we will store the times of definition.  useful for extrapolation, for example.
    float LastDefiningTimestamp() const
    {

        switch (_definingValueCount)
        {
            case 1:
                return _t0;
                break;

            case 2:
                return _t1;
                break;

            case 3:
                return _t2;
                break;

            case 4:
                return _t3;
                break;

            default:
                return 0;
                break;
        }
    }

    static CubicPolynomial<T> LineWithValuesAtTimes(T p, T q, float t0, float t1)
    {
        Eigen::Matrix2f A;
        A << t0, 1,
        t1, 1;

        Eigen::Matrix2f AInv = A.inverse();

        T a = T::Zero();
        T b = T::Zero();

        // we write the matrix multiply out by hand since Eigen doesn't understand
        // what we want to do here.  what we really want is essentially
        //             AInv * [p_x, p_y; q_x, q_y],
        // i.e. AInv multiplying the vector componentwise

        T c = AInv(0,0) * p + AInv(0,1) * q;
        T d = AInv(1,0) * p + AInv(1,1) * q;

        CubicPolynomial<T> P = CubicPolynomial<T>(a, b, c, d);

        P._t0 = t0;
        P._t1 = t1;

        P._definingValueCount = 2;

        return P;

    }

    static CubicPolynomial<T> QuadraticWithValuesAtTimes(T p, T q, T r, float t0, float t1, float t2)
    {
        Eigen::Matrix3f A;
        A << t0*t0, t0, 1,
        t1*t1, t1, 1,
        t2*t2, t2, 1;

        Eigen::Matrix3f AInv = A.inverse();

        T a = T::Zero();
        // clang-format off

        // we write the matrix multiply out by hand since Eigen doesn't understand
        // what we want to do here.  what we really want is essentially
        //             AInv * [p_x, p_y; q_x, q_y; r_x, r_y],
        // i.e. AInv multiplying the vector componentwise

        T b = AInv(0,0) * p + AInv(0,1) * q + AInv(0,2) * r;
        T c = AInv(1,0) * p + AInv(1,1) * q + AInv(1,2) * r;
        T d = AInv(2,0) * p + AInv(2,1) * q + AInv(2,2) * r;
        // clang-format on
        CubicPolynomial<T> P = CubicPolynomial<T>(a, b, c, d);

        P._t0 = t0;
        P._t1 = t1;
        P._t2 = t2;

        P._definingValueCount = 3;

        return P;

    }

    static CubicPolynomial<T> CubicWithValuesAtTimes(T p, T q, T r, T s, float t0, float t1, float t2, float t3)
    {
        // clang-format off
        Eigen::Matrix4f A;
        A << t0*t0*t0, t0*t0, t0, 1,
        t1*t1*t1, t1*t1, t1, 1,
        t2*t2*t2, t2*t2, t2, 1,
        t3*t3*t3, t3*t3, t3, 1;
        // clang-format on
        Eigen::Matrix4f AInv = A.inverse();

        // we write the matrix multiply out by hand since Eigen doesn't understand
        // what we want to do here.  what we really want is essentially
        //             AInv * [p_x, p_y; q_x, q_y; r_x, r_y; s_x, s_y],
        // i.e. AInv multiplying the vector componentwise

        T a = AInv(0,0) * p + AInv(0,1) * q + AInv(0,2) * r + AInv(0, 3) * s;
        T b = AInv(1,0) * p + AInv(1,1) * q + AInv(1,2) * r + AInv(1, 3) * s;
        T c = AInv(2,0) * p + AInv(2,1) * q + AInv(2,2) * r + AInv(2, 3) * s;
        T d = AInv(3,0) * p + AInv(3,1) * q + AInv(3,2) * r + AInv(3, 3) * s;

        CubicPolynomial<T> P = CubicPolynomial<T>(a, b, c, d);

        P._t0 = t0;
        P._t1 = t1;
        P._t2 = t2;
        P._t3 = t3;

        // Uhhh..I think this is supposed to be 4? Possible breakage....
        //P._definingValueCount = 3;
        P._definingValueCount = 4;

        return P;

    }

    // a first-order finite difference approximation to arc length
    // it makes sense for parametric curves in R^n but happens to do what we want
    // for interpolation in the case of Vector1f as well
    float ArcLength(float t0, float t1, size_t meshSize)
    {
        DebugAssert(t1 > t0);
        DebugAssert(meshSize > 0);

        // step size
        float h = (t1 - t0) / float(meshSize);

        // we divide the interval [t0, t1] into meshSize intervals of width h
        // and evaluate the derivative at the midpoints
        float evaluationPoint = h * .5f;
        float totalLength = 0.0f;
        for (size_t index = meshSize; index--; evaluationPoint += h)
        {
            T derivative           = FirstDerivativeAt(evaluationPoint);
            float distanceTraveled = derivative.norm() * h;

            totalLength           += distanceTraveled;

        }

        return totalLength;

    }

    CubicPolynomial<T> ExtendLineTo(T value) const
    {
        return CubicPolynomial<T>::LineFromTo(this->ValueAt(1), value);
    }

protected:

    // Just an affine map to the standard interval
    std::vector<float> MapToStandardInterval(std::vector<float> t)
    {
        // If this is not defined with samples, abort
        if (_definingValueCount < 4)
        {
            return std::vector<float>();
        }

        std::vector<float> vals = t;

        vals -= _globalIntervalLeft;
        vals /= (_globalIntervalRight - _globalIntervalLeft);
        vals *= (_standardIntervalRight - _standardIntervalLeft);
        vals += _standardIntervalLeft;
    }
};

typedef CubicPolynomial<Eigen::Vector2f> CubicPolynomial2f;
typedef CubicPolynomial<Vector1f> CubicPolynomial1f;
}
}
