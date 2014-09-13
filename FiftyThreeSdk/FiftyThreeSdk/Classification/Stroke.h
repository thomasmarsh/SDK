//
//  Stroke.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "Core/Enum.h"
#include "Core/Memory.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/DataStream.hpp"
#include "FiftyThreeSdk/Classification/Eigen.h"
#include "FiftyThreeSdk/Classification/Screen.h"

namespace fiftythree
{
namespace sdk
{
struct StrokeStatistics
{

    typedef fiftythree::core::shared_ptr<StrokeStatistics> Ptr;
    typedef fiftythree::core::shared_ptr<const StrokeStatistics> cPtr;

    // 1.0 is a constant which was obtained from training data.
    // the optimal value will depend on screen size and pixel/point coordinate system.
    // for iPad data 1.0f seems about right.  change this if needed in the future.
    float _smoothLengthConstant = 1.0f;

    // shrinkage for denoising spatial second differences.  lots of little curvatures occur
    // due to iOS rounding to pixel coordinates.  real curvatures from palms are much larger
    float _d2Shrinkage = 2.0f;

    // expected sample delta-t
    float _expectedSamplingRate = 1.0f / 60.0f;

    // shrinkage denoising for sample rate errors.  small fluctuations are not uncommon.
    float _samplingRateErrorShrinkage = .1f / 60.0f;

    static Ptr New()
    {
        return fiftythree::core::make_shared<StrokeStatistics>();
    }

    StrokeStatistics() :
    _arcLength(0.0f),
    _strokeTime(0.0f),
    _totalD2InSpace(Eigen::Vector2f::Zero()),
    _totalAbsoluteD2InSpace(0.0f),
    _totalSquaredD2InSpace(0.0f),
    _dtVariance(0.0f),
    _dtMean(0.0f),
    _dtSumSquaredVariation(0.0f),
    _arclengthParameter(Eigen::VectorXf::Zero(1)),
    _smoothLength(0.0f),
    _sampleTimingSquaredError(0.0f),
    _sampleTimingMeanSquaredError(0.0f),
    _firstDeltaT(0.0f),
    _totalD2AtScale(44, 0.0f),
    _normalD2(0.0f),
    _tangentialD2(0.0f),
    _totalD2(0.0f),
    _normalD3(0.0f),
    _normalD4(0.0f),
    _tangentialD3(0.0f),
    _tangentialD4(0.0f),
    _maxDeltaT(0.0f),
    _maxTravel(0.0f),
    _minStepSize(std::numeric_limits<float>::max())
    {
    }

    // D2InSpace means we just take second differences of the sample points
    // without taking arrival times into account.
    Eigen::Vector2f _totalD2InSpace;
    float _totalAbsoluteD2InSpace;
    float _totalSquaredD2InSpace;

    float _arcLength;
    float _strokeTime;
    float _dtVariance;
    float _dtMean;
    float _dtSumSquaredVariation;

    Eigen::VectorXf _arclengthParameter;

    float _normalD2;
    float _tangentialD2;
    float _totalD2;

    float _normalD3;
    float _tangentialD3;

    float _normalD4;
    float _tangentialD4;

    // integral of speed divided by curvature.  like length, but prefers straight lines
    // and not wiggly curves.
    float _smoothLength;

    std::vector<float> _totalD2AtScale;

    // deviation of sample timings from the expected sampling rate.  palms have irregular timing.
    // this does not include the very first dt.  that's considered special, since people sometimes
    // rest the pen and pause.  if you want that, look at _firstDeltaT as well.
    float _sampleTimingSquaredError;
    float _sampleTimingMeanSquaredError;

    // length of time between the first and second samples to arrive.
    float _firstDeltaT;

    // largest delta T after the first
    float _maxDeltaT;

    // a poor-man's diameter.  maximum distance traveled from the initial point
    float _maxTravel;

    // shortest distance between 2 adjacent points
    float _minStepSize;

    EIGEN_MAKE_ALIGNED_OPERATOR_NEW
};

class Stroke
{

public:

    typedef fiftythree::core::shared_ptr<Stroke> Ptr;

    DEFINE_ENUM(SamplingType,
                UniformInTime,
                UniformInSpace);

    // Samples that occur less than this delta amount of time before the preceding sample are discarded.
    static const float kMinSampleTimestampDelta;

protected:

    DataStream2f _XYDataStream;

    // speed is a funny thing.  you can't actually compute it from _XY and _timestamp
    // because timestamps include time when someone is stopped and so any trailing average of speed
    // has all kinds of artifacting (artificial slowness) when they stop or samples are dropped.
    // further complicating matters are the unreliable timestamps coming from UITouch -- these cause
    // goofiness even when we're not dropping any samples.  instead we use sample-to-sample spacing,
    // which implicitly assumes equal time increments and ignores any time when they are not moving.
    std::vector<Eigen::Vector2f>  _velocity;
    std::vector<Vector1f>         _pressure;

    std::vector<Vector1f>         _touchRadius;

    // due to Eigen alignment issues, we have to dynamically allocate this guy
    // to make sure he gets aligned or your code may crash depending on compiler
    // settings passed to Eigen.
    StrokeStatistics::Ptr         _statistics;

    // for some cases like early detection you get better performance by ignoring data after
    // the first N points
    StrokeStatistics::Ptr         _earlyStatistics;

    int ClampedIndex(int index) const;

public:

    bool _computeStatistics;

    StrokeStatistics::cPtr Statistics() const
    {
        return _statistics;
    }

    StrokeStatistics::cPtr EarlyStatistics() const
    {
        return _earlyStatistics;
    }

    float NormalizedSmoothLength()
    {
        if (_computeStatistics && Size() >= 5)
        {
            return _statistics->_smoothLength;
        }
        else
        {
            return 0.0f;
        }
    }

    DataStream2f & XYDataStream()
    {
        return _XYDataStream;
    }

    void AppendXYAtRelativeTime(std::vector<Eigen::Vector2f> const & xy, std::vector<float> const & time);

    bool               _offscreenExitFlag;
    bool               _offscreenArrivalFlag;

    //double             _t0;

    core::TouchClassification _touchType;

    SamplingType _samplingType;
    float        _XYSamplesPerSecond;

    static Stroke::Ptr New() { return Stroke::Ptr(new Stroke()); }

    Stroke() :
    _offscreenExitFlag(false),
    _offscreenArrivalFlag(false),
    _samplingType(SamplingType::UniformInSpace),
    _XYSamplesPerSecond(60),
    _computeStatistics(true)
    {
        if (_computeStatistics)
        {
            _statistics = StrokeStatistics::New();
        }

    }

    void ToNormalizedCoordinates(Screen const & screen);
    void ToScreenCoordinates(Screen const & screen);

    double           FirstAbsoluteTimestamp()  const { return _XYDataStream.FirstAbsoluteTimestamp(); }
    StdVectorFloat & RelativeTimestamp() { return _XYDataStream.RelativeTimestamp(); }
    std::vector< Eigen::Vector2f > & XY() { return _XYDataStream.Data(); }

    Eigen::Map<Eigen::VectorXf> XYMap(Interval const & I);
    Eigen::Map<Eigen::MatrixX2f, 0, Eigen::Stride<1,2>> XYMatrixMap();
    Eigen::Map<Eigen::MatrixX2f, 0, Eigen::Stride<1,2>> XYMatrixMap(int endIndex);

    Eigen::Map<Eigen::VectorXf> ArclengthParameterMap(int endIndex);
    Eigen::Map<Eigen::VectorXf> ArclengthParameterMap();

    Eigen::Map<Eigen::VectorXf> RelativeTimestampMap();
    Eigen::Map<Eigen::VectorXf> RelativeTimestampMap(int endIndex);

    Stride2Map XMap(Interval const & I) const;
    Stride2Map YMap(Interval const & I) const;

    Stride2Map XMap() const
    {
        return XMap(MaximalInterval());
    }

    Stride2Map YMap() const
    {
        return YMap(MaximalInterval());
    }

    Stride2Map VelocityXMap(Interval const & I);
    Stride2Map VelocityYMap(Interval const & I);

    float* XYPointer() const
    {
        return (float*) &(_XYDataStream.Data()[0]);
    }

    float* RelativeTPointer() const
    {
        return (float*) &(_XYDataStream.RelativeTimestamp()[0]);
    }

    float* ArclengthParameterPointer() const
    {
        return (float*) &(_statistics->_arclengthParameter(0));
    }

    void AddVelocity(Eigen::Vector2f velocity) { _velocity.push_back(velocity); }

    void AddPoint(Eigen::Vector2f const & XY, double timestamp);
    void AddPoint(Eigen::Vector2f const & XY, Vector1f pressure, double timestamp);
    void AddPoint(Eigen::Vector2f const & XY, Vector7f const & pressure, double timestamp);

    void AddTouchRadius(Vector1f const &radius)
    {
        _touchRadius.push_back(radius);
    }

    void AddTouchRadius(float radius)
    {
        Vector1f radius1f = Vector1f::Constant(radius);
        _touchRadius.push_back(radius1f);
    }

    // sort of goofy, but the curves stuff uses Vector1f and the rest of the world often wants float
    // Vector1f allows shoehorning floats into a templated setup, but inconvenient if you just want float.
    std::vector<float> TouchRadiusFloat()
    {
        std::vector<float> out((float*) &(_touchRadius[0]), ((float*) &(_touchRadius[_touchRadius.size()])));

        return out;
    }

    Eigen::Map< Eigen::VectorXf > TouchRadiusXf()
    {
        return Eigen::Map< Eigen::VectorXf >((float*) &(_touchRadius[0]), _touchRadius.size());
    }

    std::vector<Vector1f> & TouchRadius()
    {
        return _touchRadius;
    }

    float ArcLength() const;
    float ArcLength(int endIndex) const;
    float StrokeTime();
    float StrokeTime(int endIndex);
    void  UpdateSummaryStatistics();

    void AppendStroke(Stroke const & other, float initialDt);
    void AppendStroke(Stroke const & other);

    // "slow" accessors which do range-checking.
    // they return zeros when the _XY vector is empty.
    float            X(int idx) const;
    float            Y(int idx) const;
    Eigen::Vector2f XY(int idx) const;

    Vector1f  Pressure(int idx) const;

    std::vector<Vector1f>&  Pressure()    { return _pressure; }

    Eigen::Vector2f ReverseXY(int idx) const;

    Eigen::Vector2f FirstPoint() const;
    Eigen::Vector2f LastPoint() const;
    Stroke SubStroke(Interval subInterval) const;

    // returns -1 if size is zero
    int LastValidIndex() const { return (int)_XYDataStream.Size() - 1; }
    // returns -1 if effective size is 1
    int SecondValidIndex() const;
    // returns -1 if effective size is 1
    int PenultimateValidIndex() const;

    void DenoiseFirstPoint(float lambda);
    
    Interval MaximalInterval() const { return Interval(0, Size()); }

    float SegmentLength(Interval const &I);

    float Length()
    {
        return SegmentLength(MaximalInterval());
    }

    Eigen::Vector2f SmoothTrailingVelocity(int radius);
    Eigen::Vector2f VelocityForPointAtIndex(int index);
    float SpeedForPointAtIndex(int idx);
    std::vector<Eigen::Vector2f>& Velocity() { return _velocity; }

    // rather than use a separate stream for acceleration data, this gives a simple finite difference
    // of _velocity.  the results will be essentially indistinguishable from simple exponential smoothing.
    // smoothRadius controls how far back we look to compute the difference.
    // it would be trivial to add another stream, but results would be essentially identical.
    Eigen::Vector2f AccelerationForPointAtIndex(int idx, int smoothRadius = 1);

    double LastAbsoluteTimestamp() const
    {
        if (IsEmpty())
        {
            return 0.0;
        }

        return AbsoluteTimestamp(LastValidIndex());
    }

    float TimestampRelativeToTime(int idx, double referenceTime);

    double AbsoluteTimestamp(int idx) const
    {
        //return _t0 + double(RelativeTimestamp(idx));
        return _XYDataStream.AbsoluteTimestamp(idx);
    }

    std::vector<double> TimeStamps()
    {

        int start = 0;
        // TODO: WTF
        if (_XYDataStream.AbsoluteTimestamp(0) < 000.0f)
        {
            start = 1;
        }

        std::vector<double> times(_XYDataStream.Size()-start);
        for (int i=0; i < _XYDataStream.Size()-start; ++i)
        {
            times[i] = _XYDataStream.AbsoluteTimestamp(ClampedIndex(i+start));
        }

        return times;
    }

    int IndexClosestToTime(double time);

    bool IsEmpty() const { return _XYDataStream.IsEmpty(); }

    float RelativeTimestamp(int idx) const;
    float LastRelativeTimestamp() const;
    float Lifetime() const
    {
        if (IsEmpty())
        {
            return 0.0f;
        }
        else
        {
            return LastRelativeTimestamp();
        }
    }

    size_t Size() const { return _XYDataStream.Size(); }

    Eigen::Vector2f  WeightedCenterOfMass();
};
}
}
