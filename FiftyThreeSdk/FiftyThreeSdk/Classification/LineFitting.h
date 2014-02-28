//
//  LineFitting.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include<type_traits>

#include "Core/Asserts.h"
#include "FiftyThreeSdk/Classification/Eigen.h"
#include "FiftyThreeSdk/Classification/EigenLAB.h"
#include "FiftyThreeSdk/Classification/LinAlgHelpers.h"

namespace fiftythree
{
namespace sdk
{

template<typename T>
class Geometric2DLine
{

    static_assert(std::is_floating_point<T>::value, "Expecting a floating point type");

protected:
    // This is a unit-vector line direction
    // Has limited meaning in this context since the "positive" direction of the line is
    // undefined. Child classes make use of this
    Eigen::Matrix<T, 1, 2> _direction;

    // This is *NOT* the direction of the line. It is coefficients a, b in
    //      a x + b y = c
    Eigen::Matrix<T, 1, 2> _orientation;
    T _offset;

    // Equation of line is
    //   _orientation(0)*x + _orientation(1)*y + _offset = 0;
    //   a*x + b*y = c

    // Mapping between direction and orientation
    void SetOrientationFromDirection()
    {
        _orientation(0) = -_direction(1);
        _orientation(1) = _direction(0);
    }

    void SetDirectionFromOrientation()
    {
        _direction(0) = _orientation(1);
        _direction(1) = -_orientation(0);
    }

    // Updates _offset given an input (x,y) point.
    void SetOffsetFromNewPoint(const Eigen::Matrix<T, 1, 2> &point)
    {
        _offset = -_orientation.dot(point);
    }

public:

    Geometric2DLine(): _offset( (T) 0.0f)
    {
        _orientation.setZero(1,2);
        _direction.setZero(1,2);
    }

    Geometric2DLine(const T & a,const T & b,const T & c): _offset(c)
    {
        _orientation(0) = a;
        _orientation(1) = b;
        NormalizeVectorInPlace(_orientation);

        SetDirectionFromOrientation();
    }

    // Set with direction, offset pair
    Geometric2DLine(const Eigen::Matrix<T, 1, 2> & direction, const T & c):
        _offset(c),
        _direction(direction)
    {
        NormalizeVectorInPlace(_direction);
        SetOrientationFromDirection();
    }

    // Set with direction, point pair
    Geometric2DLine(const Eigen::Matrix<T, 1, 2> & direction, const Eigen::Matrix<T, 1, 2> & point):
        _direction(direction)
    {
        NormalizeVectorInPlace(_direction);
        SetOrientationFromDirection();

        SetOffsetFromNewPoint(point);
    }

    // Set with a vector (a,b,c)
    Geometric2DLine(const Eigen::Matrix<T, 3, 1> & coeffs): _offset(coeffs(2))
    {
        _orientation(0) = coeffs(0);
        _orientation(1) = coeffs(1);
        NormalizeVectorInPlace(_orientation);

        SetDirectionFromOrientation();
    }

    // Has no meaning without directed lines (child classes)
    void ReverseDirection()
    {
        _direction *= ( (T) -1.0f );
        _orientation *= ( (T) -1.0f ); // Doesn't really matter, but whatever
    }

    // Has no meaning without directed lines (child classes)
    void ReverseOrientation()
    {
        ReverseDirection();
    }

    // Note: this method has limited meaning here: the _offset defines a point
    // about which the line is rotated to match the new direction, but it's not
    // obvious what this does geometrically. Child classes use this to more sensible effect.
    void SetDirection(const Eigen::Matrix<T, 1, 2> &direction)
    {
        _direction = direction;
        NormalizeVectorInPlace(_direction);
        SetOrientationFromDirection();
    }

    Eigen::Matrix<T, 1, 2> Orientation()
    {
        return _orientation;
    }

    Eigen::Matrix<T, 1, 2> Direction()
    {
        return _direction;
    }

    T OffsetParameter()
    {
        return _offset;
    }

    bool IsLineVertical()
    {
        return IsFPZero(_direction(0));
    }

    bool IsLineHorizontal()
    {
        return IsFPZero(_direction(1));
    }

    // Evaluates y = -1/b*(c + a*x);
    // NOTE: if line is vertical then this function is not sensible.
    // Test first with IsLineVertical()
    // In this case, the function simply returns 0 for all values of y.
    Eigen::Matrix<T, Eigen::Dynamic, 1> EvaluateAtX(const Eigen::Matrix<T, Eigen::Dynamic, 1> & x)
    {
        size_t N = x.rows();

        Eigen::Matrix<T, Eigen::Dynamic, 1> output;
        output.setZero(N, 1);

        if ( IsLineVertical() )
        {
            return output;
        }

        output = ( (T) -1.0f/_orientation(1) ) * ( _offset + _orientation(0)*x.array() );

        return output;

    }

    T EvaluateAtX(const T &x)
    {
        Eigen::Matrix<T, 1, 1> X;
        X(0) = x;
        return EvaluateAtX(X)(0);
    }

    // Evaluates x = -1/a*(c + b*y);
    // NOTE: if line is horizontal then this function is not sensible.
    // Test first with IsLineHorizontal()
    // In this case, the function simply returns 0 for all values of x.
    Eigen::Matrix<T, Eigen::Dynamic, 1> EvaluateAtY(const Eigen::Matrix<T, Eigen::Dynamic, 1> & y)
    {
        size_t N = y.rows();

        Eigen::Matrix<T, Eigen::Dynamic, 1> output;
        output.setZero(N, 1);

        if ( IsLineHorizontal() )
        {
            return output;
        }

        output = ( (T) -1.0f/_orientation(0) ) * ( _offset + _orientation(1)*y.array() );

        return output;
    }

    T EvaluateAtY(const T &y)
    {
        Eigen::Matrix<T, 1, 1> Y;
        Y(0) = y;
        return EvaluateAtY(Y)(0);
    }
};

// Parameter type and data type should match.
template<typename T>
class LinearlyParameterized2DLine: public Geometric2DLine<T>
{

    static_assert(std::is_floating_point<T>::value, "Expecting a floating point type");

private:
    typedef Geometric2DLine<T> parent;

protected:

    T _speed; // non-negative
    Eigen::Matrix<T, 1, 2> _anchorPoint; // location at parameter = 0

    // With parameter t, and 2D point (x,y), the equation of the line is
    //   (x,y) = _anchorPoint + t*_speed*_direction

public:

    LinearlyParameterized2DLine(): _speed((T) 0.0f)
    {
        _anchorPoint.setZero(1,2);

    }

    LinearlyParameterized2DLine(const T & speed,
                                const Eigen::Matrix<T, 1, 2> & direction,
                                const Eigen::Matrix<T, 1, 2> & anchorPoint):
                                _anchorPoint(anchorPoint),
                                _speed(speed),
                                parent(direction, anchorPoint)
    {
        if (_speed < 0)
        {
            _speed = -_speed;
            parent::ReverseDirection();
        }
    }

    // In case user uses other dimension permutation
    LinearlyParameterized2DLine(const T & speed,
                                const Eigen::Matrix<T, 2, 1> & direction,
                                const Eigen::Matrix<T, 2, 1> & anchorPoint):
                                _speed(speed),
                                parent(direction.transpose(), anchorPoint.transpose())
    {
        if (speed < 0)
        {
            _speed = -_speed;
            parent::ReverseDirection();
        }
    }

    T Speed()
    {
        return _speed;
    }

    Eigen::Matrix<T, 1, 2> AnchorPoint()
    {
        return _anchorPoint;
    }

    void SetSpeed(const T &speed)
    {
        _speed = speed;
        if (_speed < 0)
        {
            _speed = -_speed;
            parent::ReverseDirection();
        }
    }

    void SetAnchorPoint(const Eigen::Matrix<T, 1, 2> & anchorPoint)
    {
        _anchorPoint = anchorPoint;
        parent::SetOffsetFromNewPoint(anchorPoint);
    }

    // "p" for parameter instead of t (here, T = type is confusing)
    // Returns a matrix of size p.rows() x 2
    Eigen::Matrix<T, Eigen::Dynamic, 2> Evaluate(const Eigen::Matrix<T, Eigen::Dynamic, 1> & p)
    {

        Eigen::Matrix<T, Eigen::Dynamic, 2> output;
        output.resize(p.rows(), 2);

    //   (x,y) = _anchorPoint + t*_speed*_direction
        output = _speed*(p*parent::Direction());
        output.col(0).array() += _anchorPoint(0);
        output.col(1).array() += _anchorPoint(1);

        return output;
    }

    // Returns a matrix of size 1 x 2
    Eigen::Matrix<T, 1, 2> Evaluate(const T & p)
    {
        Eigen::Matrix<T, 1, 1> P;
        P(0) = p;
        return Evaluate(P).block(0,0,1,2);
    }

};

// Parameter type and data type should match.
template<typename T>
class QuadraticallyParameterized2DLine: public Geometric2DLine<T>
{

    static_assert(std::is_floating_point<T>::value, "Expecting a floating point type");

private:
    typedef Geometric2DLine<T> parent;

protected:

    T _acceleration; // non-negative
    T _velocity0; // Signed velocity at parameter = 0
    Eigen::Matrix<T, 1, 2> _anchorPoint; // location at parameter = 0

    // With parameter t, and 2D point (x,y), the equation of the line is
    //   (x,y) = _anchorPoint + ( t * _velocity0 + t^2 * _acceleration ) * _direction

public:

    QuadraticallyParameterized2DLine(): _velocity0((T) 0.0f),
                                        _acceleration((T) 0.0f)
    {
        _anchorPoint.setZero(1,2);
    }

    QuadraticallyParameterized2DLine(const T & acceleration,
                                     const T & velocity0,
                                     const Eigen::Matrix<T, 1, 2> & direction,
                                     const Eigen::Matrix<T, 1, 2> & anchorPoint):
                                     _anchorPoint(anchorPoint),
                                     _velocity0(velocity0),
                                     _acceleration(acceleration),
                                     parent(direction, anchorPoint)
    {
        if (_acceleration < 0)
        {
            _acceleration = -_acceleration;
            _velocity0 = -_velocity0;
            parent::ReverseDirection();
        }
    }

    // In case user uses other dimension permutation
    QuadraticallyParameterized2DLine(const T & acceleration,
                                     const T & velocity0,
                                     const Eigen::Matrix<T, 2, 1> & direction,
                                     const Eigen::Matrix<T, 2, 1> & anchorPoint):
                                     _velocity0(velocity0),
                                     _acceleration(acceleration),
                                     parent(direction.transpose(), anchorPoint.transpose())
    {
        if (_acceleration < 0)
        {
            _acceleration = -_acceleration;
            _velocity0 = -_velocity0;
            parent::ReverseDirection();
        }
    }

    T Velocity0()
    {
        return _velocity0;
    }

    T Acceleration()
    {
        return _acceleration;
    }

    Eigen::Matrix<T, 1, 2> AnchorPoint()
    {
        return _anchorPoint;
    }

    void SetAcceleration(const T & acceleration)
    {
        _acceleration = acceleration;
        if (_acceleration < 0)
        {
            _acceleration = -_acceleration;
            parent::ReverseDirection();
        }
    }

    void SetAnchorPoint(const Eigen::Matrix<T, 1, 2> & anchorPoint)
    {
        _anchorPoint = anchorPoint;
        parent::SetOffsetFromNewPoint(anchorPoint);
    }

    // "p" for parameter instead of t (here, T = type is confusing)
    // Returns a matrix of size p.rows() x 2
    Eigen::Matrix<T, Eigen::Dynamic, 2> Evaluate(const Eigen::Matrix<T, Eigen::Dynamic, 1> & p)
    {

        Eigen::Matrix<T, Eigen::Dynamic, 2> output;
        output.resize(p.rows(), 2);

    //   (x,y) = _anchorPoint + ( t * _velocity0 + t^2 * _acceleration ) * _direction
        output = (_velocity0*p + _acceleration*p.array().square())*parent::Direction();
        output.col(0).array() += _anchorPoint(0);
        output.col(1).array() += _anchorPoint(1);

        return output;
    }

    // Returns a matrix of size 1 x 2
    Eigen::Matrix<T, 1, 2> Evaluate(const T & p)
    {
        Eigen::Matrix<T, 1, 1> P;
        P(0) = p;
        return Evaluate(P).block(0,0,1,2);
    }

};

template<typename DerivedA>
Geometric2DLine<typename DerivedA::Scalar> GeometricLeastSquaresLineFit(const Eigen::MatrixBase<DerivedA> & XY,
                                                                        typename DerivedA::Scalar & residualNorm)
{
    DebugAssert(XY.cols() == 2);

    typedef typename DerivedA::Scalar DataT;
    typedef Eigen::Matrix<DataT, Eigen::Dynamic, 1> DataVector;
    size_t N = XY.rows();

    Eigen::Matrix<DataT, 3, 1> coeffs;

    if (XY.rows() == 1)
    {
        // No good way to fit a line to one point...just return a horizontal line

        coeffs(0) = (DataT) 0;
        coeffs(1) = (DataT) 1;
        coeffs(2) = (DataT) -XY(0,1);

        residualNorm = 0;

        return Geometric2DLine<DataT>(coeffs);
    }

    Eigen::Matrix<DataT, 2, 2> A;
    DataT xMean = XY.block(0,0,N,1).array().mean();
    DataT yMean = XY.block(0,1,N,1).array().mean();
    DataVector X = XY.block(0,0,N,1).array() - xMean;
    DataVector Y = XY.block(0,1,N,1).array() - yMean;
    A(0,0) = SquaredNorm(X);
    A(1,1) = SquaredNorm(Y);
    A(0,1) = X.dot(Y);
    A(1,0) = A(0,1);

    Eigen::SelfAdjointEigenSolver<Eigen::Matrix<DataT, 2, 2> > eig(A);
    int minInd = 0;

    if (eig.eigenvalues()(0) > eig.eigenvalues()(1))
    {
        minInd = 1;
    }

    coeffs(0) = eig.eigenvectors()(0,minInd);
    coeffs(1) = eig.eigenvectors()(1,minInd);
    coeffs(2) = -coeffs(0)*xMean - coeffs(1)*yMean;

    X = (XY*coeffs.block(0,0,2,1)).array() + coeffs(2);
    residualNorm = X.norm();

    return Geometric2DLine<DataT>(coeffs);
}

// Throw away residual
template<typename DerivedA>
Geometric2DLine<typename DerivedA::Scalar> GeometricLeastSquaresLineFit(const Eigen::MatrixBase<DerivedA> & XY)
{
    typename DerivedA::Scalar residualNorm = 0;
    return GeometricLeastSquaresLineFit(XY, residualNorm);
}

template<typename DerivedA, typename DerivedB>
Geometric2DLine<typename DerivedA::Scalar> GeometricLeastSquaresLineFit(const Eigen::MatrixBase<DerivedA> & XY,
                                                                        const Eigen::MatrixBase<DerivedB> & sqrtWeights,
                                                                        const Eigen::Matrix<typename DerivedA::Scalar, 1, 2> XYMean,
                                                                        typename DerivedA::Scalar & residualNorm)
{

    DebugAssert( (XY.cols() == 2) && (sqrtWeights.rows() == XY.rows()) );

    typedef typename DerivedA::Scalar DataT;
    typedef Eigen::Matrix<DataT, Eigen::Dynamic, 1> DataVector;
    int N = XY.rows();

    Eigen::Matrix<DataT, 3, 1> coeffs;

    if (XY.rows() == 1)
    {
        // No good way to fit a line to one point...just return a horizontal line

        coeffs(0) = (DataT) 0;
        coeffs(1) = (DataT) 1;
        coeffs(2) = (DataT) -XY(0,1);

        residualNorm = 0;

        return Geometric2DLine<DataT>(coeffs);
    }

    DataVector X = ( XY.block(0,0,N,1).array() - XYMean(0) );
    X = X.cwiseProduct(sqrtWeights);
    DataVector Y = ( XY.block(0,1,N,1).array() - XYMean(1) );
    Y = Y.cwiseProduct(sqrtWeights);

    Eigen::Matrix<DataT, 2, 2> A;
    A(0,0) = SquaredNorm(X);
    A(1,1) = SquaredNorm(Y);
    A(0,1) = X.dot(Y);
    A(1,0) = A(0,1);

    Eigen::SelfAdjointEigenSolver<Eigen::Matrix<DataT, 2, 2> > eig(A);
    int minInd = 0;

    if (eig.eigenvalues()(0) > eig.eigenvalues()(1))
    {
        minInd = 1;
    }

    coeffs(0) = eig.eigenvectors()(0,minInd);
    coeffs(1) = eig.eigenvectors()(1,minInd);
    coeffs(2) = -coeffs(0)*XYMean(0) - coeffs(1)*XYMean(1);

    X = (XY*coeffs.block(0,0,2,1)).array() + coeffs(2);
    X = X.cwiseProduct(sqrtWeights);
    residualNorm = X.norm();

    return Geometric2DLine<DataT>(coeffs);
}

// Throw away residual
template<typename DerivedA, typename DerivedB>
Geometric2DLine<typename DerivedA::Scalar> GeometricLeastSquaresLineFit(const Eigen::MatrixBase<DerivedA> & XY,
                                                                        const Eigen::MatrixBase<DerivedB> & sqrtWeights,
                                                                        const Eigen::Matrix<typename DerivedA::Scalar, 1, 2> XYMean)
{
    typename DerivedA::Scalar residualNorm = 0;
    return GeometricLeastSquaresLineFit(XY, sqrtWeights, XYMean, residualNorm);
}

template<typename DerivedA, typename DerivedB>
Geometric2DLine<typename DerivedA::Scalar> GeometricLeastSquaresLineFit(const Eigen::MatrixBase<DerivedA> & XY,
                                                                        const Eigen::MatrixBase<DerivedB> & weights,
                                                                        typename DerivedA::Scalar & residualNorm)
{

    DebugAssert( (XY.cols() == 2) && (weights.rows() == XY.rows()) );

    typedef typename DerivedA::Scalar DataT;
    typedef Eigen::Matrix<DataT, Eigen::Dynamic, 1> DataVector;

    DataVector sqrtWeights = ( weights.array().sqrt() ).template cast<DataT>();

    Eigen::Matrix<DataT, 3, 1> coeffs;

    if (XY.rows() == 1)
    {
        // No good way to fit a line to one point...just return a horizontal line

        coeffs(0) = (DataT) 0;
        coeffs(1) = (DataT) 1;
        coeffs(2) = (DataT) -XY(0,1);

        residualNorm = 0;

        return Geometric2DLine<DataT>(coeffs);
    }

    Eigen::Matrix<DataT, 1, 2> XYMean = WeightedMean(XY, weights);

    Geometric2DLine<DataT> output = GeometricLeastSquaresLineFit(XY, sqrtWeights, XYMean, residualNorm);

    return output;
}

// Throw away residual
template<typename DerivedA, typename DerivedB>
Geometric2DLine<typename DerivedA::Scalar> GeometricLeastSquaresLineFit(const Eigen::MatrixBase<DerivedA> & XY,
                                                                        const Eigen::MatrixBase<DerivedB> & weights)
{
    typename DerivedA::Scalar residualNorm = 0;
    return GeometricLeastSquaresLineFit(XY, residualNorm);
}

// This function does a two-step least-squares procedure
// (1) Find the line that minimizes the least-squares distance to the given points XY
// (2) Use the parameters P to find the least-squares parameterization of the line from (1)
template<typename DerivedT, typename DerivedD>
LinearlyParameterized2DLine<typename DerivedD::Scalar> LeastSquaresLinearlyParameterizedLine(const Eigen::MatrixBase<DerivedT> & P,
                                                                                             const Eigen::MatrixBase<DerivedD> & XY,
                                                                                             typename DerivedD::Scalar &residual)
{

    DebugAssert( P.cols() == 1 );
    DebugAssert( XY.cols() == 2 );
    DebugAssert( P.rows() == XY.rows() );

    typedef typename DerivedD::Scalar DataT;
    typedef typename DerivedT::Scalar ParameterT;

    size_t N = XY.rows();

    // First find line:
    Geometric2DLine<DataT> line = GeometricLeastSquaresLineFit(XY);

    // Find initial anchor point (for numerical stability)

    // AnchorPoint must be the mean
    Eigen::Matrix<DataT, 1, 2> anchorPoint;
    anchorPoint(0) = XY.block(0, 0, N, 1).array().mean();
    anchorPoint(1) = XY.block(0, 1, N, 1).array().mean();

    // Now find least-squares parametrization of line
    Eigen::Matrix<DataT, Eigen::Dynamic, 1> tau = P.template cast<DataT>();
    //tau.array() -= t0;

    Eigen::Matrix<DataT, Eigen::Dynamic, 1> rhs;
    rhs.resize(2*N,1);
    rhs.segment(0,N) = XY.block(0, 0, N, 1).array() - anchorPoint(0);
    rhs.segment(N,N) = XY.block(0, 1, N, 1).array() - anchorPoint(1);

    // Least squares with data tau, rhs
    Eigen::Matrix<DataT, Eigen::Dynamic, 2> A;
    A.setOnes(2*N, 2);
    A.block(0,0,N,1) = tau;
    A.block(N,0,N,1) = tau;

    A.block(0, 0, N, 2) *= -line.Orientation()(1);
    A.block(N, 0, N, 2) *= line.Orientation()(0);

    Eigen::Matrix<DataT, 2, 1> coeffs = LinearLeastSquaresSolve(A, rhs, residual);

    anchorPoint(0) += -coeffs(1)*line.Orientation()(1);
    anchorPoint(1) += coeffs(1)*line.Orientation()(0);

    return LinearlyParameterized2DLine<DataT>(coeffs(0), line.Direction(), anchorPoint);
}

// Throws away residual
template<typename DerivedT, typename DerivedD>
LinearlyParameterized2DLine<typename DerivedD::Scalar> LeastSquaresLinearlyParameterizedLine(const Eigen::MatrixBase<DerivedT> & P,
                                                                                             const Eigen::MatrixBase<DerivedD> & XY)
{
    typename DerivedD::Scalar residual = 0;
    return LeastSquaresLinearlyParameterizedLine(P, XY, residual);
}

// Weighted version of above
template<typename DerivedT, typename DerivedD, typename DerivedW>
LinearlyParameterized2DLine<typename DerivedD::Scalar> LeastSquaresLinearlyParameterizedLine(const Eigen::MatrixBase<DerivedT> & P,
                                                                                             const Eigen::MatrixBase<DerivedD> & XY,
                                                                                             const Eigen::MatrixBase<DerivedW> & weights,
                                                                                             typename DerivedD::Scalar & residual)
{
    DebugAssert( P.cols() == 1 );
    DebugAssert( XY.cols() == 2 );
    DebugAssert( P.rows() == XY.rows() );
    DebugAssert( weights.rows() == P.rows() );

    typedef typename DerivedD::Scalar DataT;
    typedef typename DerivedT::Scalar ParameterT;
    typedef Eigen::Matrix<DataT, Eigen::Dynamic, 1> DataVector;

    int N = XY.rows();

    DataVector sqrtWeights = ( weights.array().sqrt() ).template cast<DataT>();

    Eigen::Matrix<DataT, 1, 2> XYMean = WeightedMean(XY, weights);

    // First find line:
    Geometric2DLine<DataT> line = GeometricLeastSquaresLineFit(XY, sqrtWeights, XYMean);

    // Find initial anchor point (for numerical stability)
    // AnchorPoint must be the mean

    // Now find least-squares parametrization of line
    Eigen::Matrix<DataT, Eigen::Dynamic, 1> tau = P.template cast<DataT>();

    // Least squares with data tau, rhs
    Eigen::Matrix<DataT, Eigen::Dynamic, 2> A;
    A.setOnes(2*N, 2);
    A.block(0,0,N,1) = tau;
    A.block(N,0,N,1) = tau;

    A.block(0, 0, N, 2) *= -line.Orientation()(1);
    A.block(N, 0, N, 2) *= line.Orientation()(0);

    // I think it's easier to form the matrix than call LinAlgHelper's weighted method
    A.block(0, 0, N, 2) = sqrtWeights.asDiagonal()*A.block(0, 0, N, 2);
    A.block(N, 0, N, 2) = sqrtWeights.asDiagonal()*A.block(N, 0, N, 2);

    DataVector rhs;
    rhs.resize(2*N,1);
    rhs.segment(0,N) = XY.block(0, 0, N, 1).array() - XYMean(0);
    rhs.segment(0,N) = rhs.segment(0,N).cwiseProduct(sqrtWeights);
    rhs.segment(N,N) = XY.block(0, 1, N, 1).array() - XYMean(1);
    rhs.segment(N,N) = rhs.segment(N,N).cwiseProduct(sqrtWeights);

    Eigen::Matrix<DataT, 2, 1> coeffs = LinearLeastSquaresSolve(A, rhs, residual);

    XYMean(0) += -coeffs(1)*line.Orientation()(1);
    XYMean(1) += coeffs(1)*line.Orientation()(0);

    return LinearlyParameterized2DLine<DataT>(coeffs(0), line.Direction(), XYMean);
}

// Throws away residual
template<typename DerivedT, typename DerivedD, typename DerivedW>
LinearlyParameterized2DLine<typename DerivedD::Scalar> LeastSquaresLinearlyParameterizedLine(const Eigen::MatrixBase<DerivedT> & P,
                                                                                             const Eigen::MatrixBase<DerivedD> & XY,
                                                                                             const Eigen::MatrixBase<DerivedW> weights)
{
    typename DerivedD::Scalar residual = 0;
    return LeastSquaresLinearlyParameterizedLine(P, XY, weights);
}

// This function does a two-step least-squares procedure
// (1) Find the line that minimizes the least-squares distance to the given points XY
// (2) Use the parameters P to find the least-squares parameterization of the line from (1)
template<typename DerivedT, typename DerivedD>
QuadraticallyParameterized2DLine<typename DerivedD::Scalar> LeastSquaresQuadraticallyParameterizedLine(const Eigen::MatrixBase<DerivedT> & P,
                                                                                                       const Eigen::MatrixBase<DerivedD> & XY,
                                                                                                       typename DerivedD::Scalar & residual)
{
    DebugAssert( ( P.cols() == 1 ) &&
                 ( XY.cols() == 2 ) &&
                 ( P.rows() == XY.rows() )
               );

    typedef typename DerivedD::Scalar DataT;
    typedef typename DerivedT::Scalar ParameterT;

    int N = XY.rows();

    // First find line:
    Geometric2DLine<DataT> line = GeometricLeastSquaresLineFit(XY);

    // Find initial anchor point (for numerical stability)

    // mean must lie on line...use as AnchorPoint
    Eigen::Matrix<DataT, 1, 2> anchorPoint;
    anchorPoint(0) = XY.block(0, 0, N, 1).array().mean();
    anchorPoint(1) = XY.block(0, 1, N, 1).array().mean();

    // Now find least-squares parametrization of line
    Eigen::Matrix<DataT, Eigen::Dynamic, 1> tau = P.template cast<DataT>();

    Eigen::Matrix<DataT, Eigen::Dynamic, 1> rhs;
    rhs.resize(2*N,1);
    rhs.segment(0,N) = XY.block(0, 0, N, 1).array() - anchorPoint(0);
    rhs.segment(N,N) = XY.block(0, 1, N, 1).array() - anchorPoint(1);

    // Least squares with data tau, rhs
    Eigen::Matrix<DataT, Eigen::Dynamic, 3> A;
    A.setOnes(2*N, 3);

    A.block(0,0,N,1) = tau.array().square();
    A.block(N,0,N,1) = A.block(0,0,N,1);

    A.block(0,1,N,1) = tau;
    A.block(N,1,N,1) = tau;

    A.block(0,0,N,3) *= line.Direction()(0);
    A.block(N,0,N,3) *= line.Direction()(1);

    Eigen::Matrix<DataT, 3, 1> coeffs = LinearLeastSquaresSolve(A, rhs, residual);

    anchorPoint += coeffs(2)*line.Direction();

    return QuadraticallyParameterized2DLine<DataT>(coeffs(0), coeffs(1), line.Direction(), anchorPoint);
}

// Throws away residual
template<typename DerivedT, typename DerivedD>
QuadraticallyParameterized2DLine<typename DerivedD::Scalar> LeastSquaresQuadraticallyParameterizedLine(const Eigen::MatrixBase<DerivedT> & P,
                                                                                                       const Eigen::MatrixBase<DerivedD> & XY)
{
    typename DerivedD::Scalar residual = 0;
    return LeastSquaresQuadraticallyParameterizedLine(P, XY, residual);
}

// Weighted version of above:
template<typename DerivedT, typename DerivedD, typename DerivedW>
QuadraticallyParameterized2DLine<typename DerivedD::Scalar> LeastSquaresQuadraticallyParameterizedLine(const Eigen::MatrixBase<DerivedT> & P,
                                                                                                       const Eigen::MatrixBase<DerivedD> & XY,
                                                                                                       const Eigen::MatrixBase<DerivedW> & weights,
                                                                                                       typename DerivedD::Scalar & residual)
{

    DebugAssert( ( P.cols() == 1 ) &&
                 ( XY.cols() == 2 ) &&
                 ( P.rows() == XY.rows() ) &&
                 ( weights.rows() == P.rows() )
               );

    typedef typename DerivedD::Scalar DataT;
    typedef typename DerivedT::Scalar ParameterT;
    typedef Eigen::Matrix<DataT, Eigen::Dynamic, 1> DataVector;

    int N = XY.rows();

    DataVector sqrtWeights = ( weights.array().sqrt() ).template cast<DataT>();
    Eigen::Matrix<DataT, 1, 2> XYMean = WeightedMean(XY, weights);

    // First find line:
    Geometric2DLine<DataT> line = GeometricLeastSquaresLineFit(XY, sqrtWeights, XYMean);

    // Find initial anchor point (for numerical stability)
    // XYMean must lie on line...use as AnchorPoint

    // Now find least-squares parametrization of line
    // TODO: don't need tau -- can template cast to a block of A
    DataVector tau = P.template cast<DataT>();

    // Least squares with data tau, rhs
    DataVector rhs;
    rhs.resize(2*N,1);
    rhs.segment(0,N) = XY.block(0, 0, N, 1).array() - XYMean(0);
    rhs.segment(0,N) = rhs.segment(0,N).cwiseProduct(sqrtWeights);
    rhs.segment(N,N) = XY.block(0, 1, N, 1).array() - XYMean(1);
    rhs.segment(N,N) = rhs.segment(N,N).cwiseProduct(sqrtWeights);

    Eigen::Matrix<DataT, Eigen::Dynamic, 3> A;
    A.setOnes(2*N, 3);

    A.block(0,0,N,1) = tau.array().square();
    A.block(N,0,N,1) = A.block(0,0,N,1);

    A.block(0,1,N,1) = tau;
    A.block(N,1,N,1) = tau;

    A.block(0,0,N,3) *= line.Direction()(0);
    A.block(N,0,N,3) *= line.Direction()(1);

    // I think it's easier to form the matrix than call LinAlgHelper's weighted method
    A.block(0, 0, N, 3) = sqrtWeights.asDiagonal()*A.block(0, 0, N, 3);
    A.block(N, 0, N, 3) = sqrtWeights.asDiagonal()*A.block(N, 0, N, 3);

    Eigen::Matrix<DataT, 3, 1> coeffs = LinearLeastSquaresSolve(A, rhs, residual);

    XYMean += coeffs(2)*line.Direction();

    return QuadraticallyParameterized2DLine<DataT>(coeffs(0), coeffs(1), line.Direction(), XYMean);
}

// Throws away residual
template<typename DerivedT, typename DerivedD, typename DerivedW>
QuadraticallyParameterized2DLine<typename DerivedD::Scalar> LeastSquaresQuadraticallyParameterizedLine(const Eigen::MatrixBase<DerivedT> & P,
                                                                                                       const Eigen::MatrixBase<DerivedD> & XY,
                                                                                                       const Eigen::MatrixBase<DerivedW> & weights)
{
    typename DerivedD::Scalar residual = 0;
    return LeastSquaresQuadraticallyParameterizedLine(P, XY, weights, residual);
}
}
}
