//
//  Stroke.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include "FiftyThreeSdk/Classification/EigenLAB.h"
#include "FiftyThreeSdk/Classification/FiniteDifferences.h"
#include "FiftyThreeSdk/Classification/Stroke.h"

using namespace Eigen;

namespace fiftythree
{
namespace sdk
{
constexpr float Stroke::kMinSampleTimestampDelta = 0.0001f;

float Stroke::ArcLength() const
{
    if (_computeStatistics) {
        return _statistics->_arcLength;
    } else {
        int N = (int)Size();

        if (N <= 1) {
            return 0.0f;
        }

        Stride2Map X = XMap();
        Stride2Map Y = YMap();

        VectorXf d1x = X.segment(1, N - 1) - X.segment(0, N - 1);
        VectorXf d1y = Y.segment(1, N - 1) - Y.segment(0, N - 1);

        VectorXf ds = (d1x.array().square() + d1y.array().square()).sqrt();

        float L = ds.sum();

        return L;
    }
}

float Stroke::ArcLength(int endIndex) const
{
    if (_computeStatistics) {
        return _statistics->_arclengthParameter(ClampedIndex(endIndex));
    } else {
        int N = ClampedIndex(endIndex) + 1;

        if (N <= 1) {
            return 0.0f;
        }

        Stride2Map X = XMap();
        Stride2Map Y = YMap();

        VectorXf d1x = X.segment(1, N - 1) - X.segment(0, N - 1);
        VectorXf d1y = Y.segment(1, N - 1) - Y.segment(0, N - 1);

        VectorXf ds = (d1x.array().square() + d1y.array().square()).sqrt();

        float L = ds.sum();

        return L;
    }
}

float Stroke::StrokeTime()
{
    if (_computeStatistics) {
        return _statistics->_strokeTime;
    } else {
        Eigen::VectorXf t = RelativeTimestampMap();
        return t(t.size() - 1) - t(0);
    }
}

float Stroke::StrokeTime(int lastIndex)
{
    return RelativeTimestamp(ClampedIndex(lastIndex));
}

void Stroke::UpdateSummaryStatistics()
{
    Vector2f xy = LastPoint();

    int N = (int)Size();

    if (Size() > 1) {
        // Update Arclength
        Vector2f previousPoint = _XYDataStream.ReverseData(1);
        float ds = (xy - previousPoint).norm();

        _statistics->_arcLength += ds;

        // Relatively expensive reallocation of stuff in Stroke
        _statistics->_arclengthParameter.conservativeResize(N);
        _statistics->_arclengthParameter(N - 1) = _statistics->_arclengthParameter(N - 2) + ds;

        float minStep = std::min(_statistics->_minStepSize, ds);
        _statistics->_minStepSize = minStep;

        // Update timestamp delta-T mean and variance
        float currentTimestamp = _XYDataStream.LastRelativeTimestamp();
        float previousTimestamp = _XYDataStream.ReverseRelativeTimestamp(1);

        float dt = currentTimestamp - previousTimestamp;
        float Ndt = Size() - 1;

        // Counts total live time for stroke
        _statistics->_strokeTime += dt;

        // See here for alternate formulas.
        // http://en.wikipedia.org/wiki/Algorithms_for_calculating_variance
        float muOld = _statistics->_dtMean;
        float muNew = muOld + (dt - muOld) / Ndt;
        _statistics->_dtMean = muNew;

        float M2Old = _statistics->_dtSumSquaredVariation;

        _statistics->_dtSumSquaredVariation = M2Old + (dt - muOld) * (dt - muNew);
        _statistics->_dtVariance = _statistics->_dtSumSquaredVariation / std::max(1.0f, Ndt - 1.0f);

        if (Size() > 2) {
            float dtErr = std::max(0.0f, std::abs(dt - _statistics->_expectedSamplingRate) - _statistics->_samplingRateErrorShrinkage);
            _statistics->_sampleTimingSquaredError += dtErr * dtErr;
            _statistics->_sampleTimingMeanSquaredError = _statistics->_sampleTimingSquaredError / float(Size() - 1);

            _statistics->_maxDeltaT = std::max(_statistics->_maxDeltaT, dt);

        } else // (size == 2)
        {
            _statistics->_firstDeltaT = dt;
        }

        float travel = (FirstPoint() - LastPoint()).norm();
        _statistics->_maxTravel = std::max(_statistics->_maxTravel, travel);

    } else {
        // should already be set by ctor
        _statistics->_arcLength = 0.0f;
        _statistics->_arclengthParameter = Eigen::VectorXf::Zero(1);
    }

    if (N > 2) {
        Vector2f p = _XYDataStream.ReverseData(2);
        Vector2f q = _XYDataStream.ReverseData(1);
        Vector2f r = _XYDataStream.ReverseData(0);

        Vector2f d1 = r - p;
        Vector2f d2 = p + r - (q * 2.0f);

        float d2norm = d2.norm();
        if (d2norm > 0.0f) {
            // shrinkage denoising to eliminate pixelation noise from accumulating.
            // this particularly helps with very slow motion, where there's lots of spurious
            // second differences.

            float speed = (r - p).norm();
            float lambda = std::max(0.0f, std::min(1.0f, (speed - 4.0f) / 12.0f));
            float shrinkage = (1.0f - lambda) * _statistics->_d2Shrinkage;

            d2 *= std::max(0.0f, d2norm - shrinkage) / d2norm;
        }

        _statistics->_totalD2InSpace += d2;
        _statistics->_totalAbsoluteD2InSpace += d2.norm();
        _statistics->_totalSquaredD2InSpace += d2.squaredNorm();

        float dot = d2.x() * d1.x() + d2.y() * d1.y();
        dot = std::abs(dot);

        // dividing by norm gives us the orthogonal component
        // dividing by normSquared gives us a scale-invariant quantity

        if (d1.squaredNorm() > 0.0f) {
            //_statistics->_normalD2                  += cross / d1.norm();
            _statistics->_tangentialD2 += dot / d1.norm();
            _statistics->_totalD2 += d2.norm();
        }

        for (int r = 1; r < 44; r++) {
            if (Size() > 2 * r) {
                Vector2f a = _XYDataStream.ReverseData(2 * r);
                Vector2f b = _XYDataStream.ReverseData(r);
                Vector2f c = _XYDataStream.ReverseData(0);

                Vector2f d2k = a + c - b * 2.0f;

                float speed = (c - a).norm();
                float lambda = std::max(0.0f, std::min(1.0f, (speed - 4.0f) / 12.0f));
                float shrinkage = (1.0f - lambda) * _statistics->_d2Shrinkage;
                float d2knorm = d2k.norm();

                d2k *= std::max(0.0f, d2knorm - shrinkage) / d2knorm;

                _statistics->_totalD2AtScale[r - 1] += d2k.norm();

            } else {
                break;
            }
        }
    }

    if (Size() > 4 && Size() <= 11) {
        Eigen::MatrixX2f xy = XYMatrixMap();
        Eigen::VectorXf t = RelativeTimestampMap();

        DebugAssert((t.tail(t.size() - 1) - t.head(t.size() - 1)).minCoeff() > .0001f);

        MatrixX2f velocity;
        Derivative(t, xy, velocity, 1);

        MatrixX2f answer2 = D2OrthogonalToVelocity(t, xy);
        MatrixX2f answer3 = JerkOrthogonalToVelocity(t, xy);
        MatrixX2f answer4 = D4OrthogonalToVelocity(t, xy);

        float L = _statistics->_arcLength;

        float L2 = L * L;
        float L3 = L2 * L;
        float L4 = L3 * L;

        _statistics->_normalD2 = answer2.norm() / (.0001f + L2);
        _statistics->_normalD3 = answer3.norm() / (.0001f + L3);
        _statistics->_normalD4 = answer4.norm() / (.0001f + L4);

        _statistics->_smoothLength = (velocity.rowwise().norm().array() / (.1f + answer4.rowwise().norm().array() / (.0001f + L4))).sum();
    }

    if (Size() >= 6) {
        Vector2f zm2 = _XYDataStream.ReverseData(4);
        Vector2f zm1 = _XYDataStream.ReverseData(3);
        Vector2f z0 = _XYDataStream.ReverseData(2);
        Vector2f zp1 = _XYDataStream.ReverseData(1);
        Vector2f zp2 = _XYDataStream.ReverseData(0);

        Vector2f d1 = zp1 - zm1;
        Vector2f d1_4 = .0833f * zm2 - .667f * zm1 + .667f * zp1 - .0833 * zp2;

        Vector2f d3 = zp2 - zp1 * 2.0f + zm1 * 2.0f - zm2;
        Vector2f d4 = zp2 - zp1 * 4.0f + z0 * 6.0f - zm1 * 4.0f + zm2;

        float dot3 = d3.x() * d1.x() + d3.y() * d1.y();

        float dot4 = d4.x() * d1_4.x() + d4.y() * d1_4.y();

        float speed = d1.norm();

        float lambda = std::max(0.0f, std::min(1.0f, (speed - 4.0f) / 12.0f));
        float shrinkage = (1.0f - lambda) * (4.0f * _statistics->_d2Shrinkage);

        _statistics->_tangentialD3 += std::max(std::abs(dot3) - shrinkage, 0.0f) / d1.norm();

        _statistics->_tangentialD4 += std::max(std::abs(dot4) - shrinkage, 0.0f) / (.00001f + d1.norm());
    }

    if (Size() <= 11) {
        if (!_earlyStatistics) {
            _earlyStatistics = StrokeStatistics::New();
        }
        *_earlyStatistics = *_statistics;
    }
}

void Stroke::AddPoint(Eigen::Vector2f const &xy, double timestamp)
{
    DebugAssert(IsEmpty() || timestamp >= LastAbsoluteTimestamp() + kMinSampleTimestampDelta);

    _XYDataStream.AddPoint(xy, timestamp);

    if (_computeStatistics) {
        UpdateSummaryStatistics();
    }
}

void Stroke::AddPoint(Eigen::Vector2f const &xy, Vector1f pressure, double timestamp)
{
    AddPoint(xy, timestamp);
    _pressure.push_back(pressure);
}

void Stroke::AppendXYAtRelativeTime(std::vector<Eigen::Vector2f> const &xy, std::vector<float> const &time)
{
    DebugAssert(xy.size() == time.size());

    //_XY.insert(_XY.end(), xy.begin(), xy.end());
    //_relativeTimestamp.insert(_relativeTimestamp.end(), time.begin(), time.end());

    _XYDataStream.Data().insert(_XYDataStream.Data().end(), xy.begin(), xy.end());
    _XYDataStream.RelativeTimestamp().insert(_XYDataStream.RelativeTimestamp().end(), time.begin(), time.end());
}

Eigen::Vector2f Stroke::SmoothTrailingVelocity(int radius)
{
    int b = LastValidIndex();
    int a = std::max(0, b - radius);

    return XY(b) - XY(a);
}

Eigen::Vector2f Stroke::AccelerationForPointAtIndex(int idx, int smoothRadius)
{
    if (idx >= _velocity.size() || idx < 0) {
        return Vector2f::Zero();
    }

    Vector2f vb = _velocity[idx];

    int firstIndex = idx - smoothRadius;
    Vector2f va;

    // rather than clamp firstIndex to 0, we assume they start from rest.  these two methods
    // give very different results for the first point on the stroke.
    // this method is actually correct if someone places the pen first, and then begins moving.
    // clamping firstIndex to zero is nearly identical, but always gives zero for idx == 0 and then gives
    // a nonzero value for the second sample.
    // this seems unlikely to be what you want.
    if (firstIndex < 0 || idx == 0) {
        va = Vector2f::Zero();
    } else {
        va = _velocity[idx - smoothRadius];
    }

    return vb - va;
}

Eigen::Vector2f Stroke::VelocityForPointAtIndex(int idx)
{
    if (idx >= _velocity.size() || idx < 0) {
        return Vector2f::Zero();
    }

    return _velocity[idx];
}

float Stroke::SpeedForPointAtIndex(int idx)
{
    return VelocityForPointAtIndex(idx).norm();
}

int Stroke::ClampedIndex(int index) const
{
    return std::max(0, std::min(index, (int)_XYDataStream.Size() - 1));
}

// these are the "slow and safe" accessors.
// if you want fast, get the _XY array itself
float Stroke::X(int idx) const
{
    return XY(idx)[0];
}

float Stroke::Y(int idx) const
{
    return XY(idx)[1];
}

float Stroke::TimestampRelativeToTime(int idx, double referenceTime)
{
    return AbsoluteTimestamp(idx) - referenceTime;
}

int Stroke::IndexClosestToTime(double time)
{
    int idx = 0;
    double currentDiff = std::abs(time - FirstAbsoluteTimestamp());

    // i == 1 is the correct starting place.  the i == 0 case is handled above,
    // and if the second point on the curve is further away in time, we'll immediately exit the loop.
    // this happens when time <= FirstAbsoluteTimestamp() + .5 * (sampling interval)
    for (int i = 1; i < Size(); ++i) {
        double newDiff = std::abs(time - AbsoluteTimestamp(i));

        if (newDiff < currentDiff) {
            idx = i;
            currentDiff = newDiff;
        } else { // We're getting farther away, so just return
            break;
        }
    }

    return idx;
}

float Stroke::RelativeTimestamp(int idx) const
{
    if (IsEmpty()) {
        return 0;
    } else {
        return _XYDataStream.RelativeTimestamp(ClampedIndex(idx));
    }
}

Eigen::Vector2f Stroke::XY(int idx) const
{
    if (IsEmpty()) {
        return Vector2f(0, 0);
    } else {
        return _XYDataStream.Data(ClampedIndex(idx));
    }
}

// "Normalized coordinates" live on a rectangle of width one with center at (0,0), i.e.
// x \in [-.5, .5]
// y \in .5 * [-height/width, height/width]
void Stroke::ToNormalizedCoordinates(Screen const &screen)
{
    Stride2Map x = XMap(MaximalInterval());
    Stride2Map y = YMap(MaximalInterval());

    x.array() -= (screen._widthInPoints * .5f);
    y.array() -= (screen._heightInPoints * .5f);

    x.array() /= screen._widthInPoints;
    y.array() /= screen._heightInPoints;

    Stride2Map vx = VelocityXMap(MaximalInterval());
    Stride2Map vy = VelocityYMap(MaximalInterval());

    vx.array() /= screen._widthInPoints;
    vy.array() /= screen._heightInPoints;
}

void Stroke::ToScreenCoordinates(Screen const &screen)
{
    Stride2Map x = XMap(MaximalInterval());
    Stride2Map y = YMap(MaximalInterval());

    x.array() *= screen._widthInPoints;
    y.array() *= screen._heightInPoints;

    x.array() += (screen._widthInPoints * .5f);
    y.array() += (screen._heightInPoints * .5f);

    Stride2Map vx = VelocityXMap(MaximalInterval());
    Stride2Map vy = VelocityYMap(MaximalInterval());

    vx.array() *= screen._widthInPoints;
    vy.array() *= screen._heightInPoints;
}

Eigen::Vector2f Stroke::ReverseXY(int idx) const
{
    return XY(LastValidIndex() - idx);
}

Vector1f Stroke::Pressure(int idx) const
{
    return _pressure[ClampedIndex(idx)];
}

// this one rejiggers the timestamps so the appended points look like
// they arrived at initialDt seconds after the first.  typically initialDt
// is the sampling rate (i.e. unless they stop moving).
void Stroke::AppendStroke(const Stroke &other, float initialDt)
{
    int index = 0;
    for (int j = (int)other.Size(); j--; index++) {
        float newRelativeTime = other.RelativeTimestamp(index) - other.RelativeTimestamp(0) + initialDt;

        AddPoint(other.XY(index), other.Pressure(index), double(newRelativeTime) + _XYDataStream.FirstAbsoluteTimestamp());
    }
}

// this returns bogus values for the timestamps -- the first appended point
// will have the same timestamp as the last point on the current stroke.
// this only makes sense geometrically but sometimes that's all you care about.
void Stroke::AppendStroke(Stroke const &other)
{
    return AppendStroke(other, 0);
}

float Stroke::LastRelativeTimestamp() const
{
    if (IsEmpty()) {
        return 0;
    } else {
        return _XYDataStream.RelativeTimestamp((int)Size() - 1);
    }
}

Eigen::Vector2f Stroke::FirstPoint() const
{
    if (IsEmpty()) {
        return Vector2f(0, 0);
    } else {
        return _XYDataStream.Data(0);
    }
}

Eigen::Vector2f Stroke::WeightedCenterOfMass()
{
    size_t N = Size();

    if (N == 0) {
        return Vector2f::Zero();
    } else if (N == 1) {
        return FirstPoint();
    }

    int N_out = (int)N - 1;

    std::vector<float> ds = NormDiff(_XYDataStream.Data());

    Stride2Map mapX = XMap();
    Stride2Map mapY = YMap();
    Eigen::Map<Eigen::VectorXf> mapDs = Eigen::Map<VectorXf>(&(ds[0]), N_out);

    // prevent NaN
    mapDs.array() += .0001f;

    // segment midpoints, weighted by segment length
    float muX = .5f * (mapX.segment(0, N_out) + mapX.segment(1, N_out)).dot(mapDs);
    float muY = .5f * (mapY.segment(0, N_out) + mapY.segment(1, N_out)).dot(mapDs);

    float wTotal = mapDs.sum();

    return Vector2f(muX, muY) / wTotal;
}

Eigen::Vector2f Stroke::LastPoint() const
{
    if (IsEmpty()) {
        return Vector2f(0, 0);
    } else {
        return _XYDataStream.Data((int)Size() - 1l);
    }
}

Stroke::Stroke(core::Touch const &touch, int maxPoints)
: _computeStatistics(false)
{
    int counter = 0;
    for (auto &sample : *(touch.History())) {
        if (maxPoints && counter >= maxPoints) {
            break;
        }

        AddPoint(sample.Location(), sample.TimestampSeconds());

        ++counter;
    }
}

void Stroke::DenoiseFirstPoint(float lambda, float maxTravel)
{
    CubicPolynomial2f P;

    switch (Size()) {
        case 2:
        case 1:
        case 0: {
            return;
            break;
        }

        case 3: {
            P = CubicPolynomial2f::LineWithValuesAtTimes(XY(1), XY(2), RelativeTimestamp(1), RelativeTimestamp(2));
            break;
        }

        case 4:
        default: {
            P = CubicPolynomial2f::QuadraticWithValuesAtTimes(XY(1), XY(2), XY(3), RelativeTimestamp(1), RelativeTimestamp(2), RelativeTimestamp(3));
            break;
        }
    }

    Vector2f target = (1.0f - lambda) * XY(0) + lambda * P.ValueAt(RelativeTimestamp(0));
    Vector2f correction = target - XY(0);
    float legalLength = std::min(correction.norm(), maxTravel);
    correction *= legalLength / correction.norm();

    _XYDataStream.Data()[0] = XY(0) + correction;
}

Eigen::Map<Eigen::VectorXf> Stroke::XYMap(Interval const &I)
{
    float *data = XYPointer();

    return Eigen::Map<VectorXf>(data + 2 * I._index, 2 * I._count);
}

Eigen::Map<Eigen::MatrixX2f, 0, Eigen::Stride<1, 2>> Stroke::XYMatrixMap()
{
    return XYMatrixMap((int)Size() - 1l);
}

Eigen::Map<Eigen::MatrixX2f, 0, Eigen::Stride<1, 2>> Stroke::XYMatrixMap(int endIndex)
{
    float *data = XYPointer();
    endIndex = ClampedIndex(endIndex);

    return Eigen::Map<Eigen::MatrixX2f, 0, Eigen::Stride<1, 2>>(data, endIndex + 1, 2);
}

Eigen::Map<Eigen::VectorXf> Stroke::RelativeTimestampMap()
{
    return RelativeTimestampMap((int)Size() - 1l);
}

Eigen::Map<Eigen::VectorXf> Stroke::RelativeTimestampMap(int endIndex)
{
    float *timestamp = RelativeTPointer();
    endIndex = ClampedIndex(endIndex);

    return Eigen::Map<Eigen::VectorXf>(timestamp, endIndex + 1);
}

Eigen::Map<Eigen::VectorXf> Stroke::ArclengthParameterMap(int endIndex)
{
    float *arclength;
    size_t samples;

    if (_computeStatistics) {
        arclength = ArclengthParameterPointer();
        samples = _statistics->_arclengthParameter.rows();

    } else {
        // We have to compute the arclength parameterization on-the-fly .... todo
        assert(false);
    }

    samples = std::min((int)samples, endIndex + 1);
    return Eigen::Map<Eigen::VectorXf>(arclength, samples);
}

Eigen::Map<Eigen::VectorXf> Stroke::ArclengthParameterMap()
{
    return ArclengthParameterMap((int)_statistics->_arclengthParameter.rows());
}

Stride2Map Stroke::VelocityXMap(Interval const &I)
{
    float *data = (float *)&(_velocity[0]);
    return Stride2Map(data + 2 * I._index, I._count);
}

Stride2Map Stroke::VelocityYMap(Interval const &I)
{
    float *data = (float *)&(_velocity[0]);
    return Stride2Map(data + 2 * I._index + 1, I._count);
}

Stride2Map Stroke::XMap(Interval const &I) const
{
    //float * data = (float*) &(_XY[0]);
    float *data = XYPointer();
    return Stride2Map(data + 2 * I._index, I._count);
}

Stride2Map Stroke::YMap(Interval const &I) const
{
    float *data = XYPointer();
    return Stride2Map(data + 2 * I._index + 1, I._count);
}

// extracting a substroke and calling ArcLength is not fast enough for real-time
// computation of speeds.  the safe accessors are not fast enough either.
// using vectorized Eigen might be faster, but this is more than adequate.
float Stroke::SegmentLength(fiftythree::sdk::Interval const &I)
{
    if (Size() < 2) {
        return 0;
    }

    Interval J = MaximalInterval().Intersection(I);

    DebugAssert(J == I);

    float L = 0.0f;
    float *data = (float *)&(_XYDataStream.Data()[J._index]);
    for (int j = 0; j < I._count - 1; j++) {
        float dx = data[2] - data[0];
        float dy = data[3] - data[1];

        L += std::sqrt(dx * dx + dy * dy);

        data += 2;
    }

    return L;
}

Stroke Stroke::SubStroke(Interval subInterval) const
{
    // no statistics on substrokes -- first, it doesn't make sense unless we replay all the samples,
    // and second, creating the shared ptr can be a performance hit in loops.
    Stroke subStroke(false);

    if (LastValidIndex() == -1) {
        return subStroke;
    }

    Interval validSubInterval = subInterval.Intersection(MaximalInterval());

    int a = (int)validSubInterval._index;
    int b = (int)validSubInterval._index + (int)validSubInterval._count;

    subStroke._XYDataStream.Data() = std::vector<Vector2f>(&(_XYDataStream.Data()[a]), &(_XYDataStream.Data()[b]));
    subStroke._XYDataStream.RelativeTimestamp() = std::vector<float>(&(_XYDataStream.RelativeTimestamp()[a]),
                                                                     &(_XYDataStream.RelativeTimestamp()[b]));

    subStroke._XYDataStream.SetFirstAbsoluteTimestamp(FirstAbsoluteTimestamp());

    DebugAssert(subStroke.Size() == subInterval._count);

    return subStroke;
}

int Stroke::SecondValidIndex() const
{
    int idx = -1;
    for (int i = 0; i < _XYDataStream.Size(); ++i) {
        if (i == 0) {
            continue;
        }
        if ((AbsoluteTimestamp(i) - AbsoluteTimestamp(0)) > 0) {
            idx = i;
            break;
        }
    }
    return idx;
}

int Stroke::PenultimateValidIndex() const
{
    int idx = -1;
    int lastIdx = LastValidIndex();
    for (int i = lastIdx; i >= 0; --i) {
        if (i == lastIdx) {
            continue;
        }
        if ((AbsoluteTimestamp(lastIdx) - AbsoluteTimestamp(i) > 0)) {
            idx = i;
            break;
        }
    }

    return idx;
}
}
}
