//
//  DataStream.hpp
//  FiftyThreeSdk
//
//  Copyright (c) 2015 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "Core/Enum.h"
#include "Core/Memory.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"
#include "FiftyThreeSdk/Classification/CubicPolynomial.hpp"
#include "FiftyThreeSdk/Classification/EigenLAB.h"

namespace fiftythree
{
namespace sdk
{
// this is probably more for making the code self-documenting than anything else...
DEFINE_ENUM(SamplingType,
            UniformInTime,
            UniformInSpace);

template <class DataType>
class DataStream
{
public:
    typedef std::vector<DataType> ContainerType;

    typedef DataStream<DataType> Stream;
    ALIAS_PTR_TYPES(DataStream<DataType>);

protected:
    ContainerType _data;
    std::vector<float> _relativeTimestamp;

    // make a special case for the most recent.  every so often the float conversion
    // causes issues.
    double _mostRecentTimestamp;

    int ClampedIndex(int index) const
    {
        return std::max(0, std::min(index, (int)_data.size() - 1));
    }

public:
    SamplingType _samplingType;
    float _sampleRate;
    double _t0;

    // set t0 < 0 as a "this was not set" flag.
    DataStream<DataType>()
    : _sampleRate(60.0f)
    , _t0(-.001)
    , _mostRecentTimestamp(-.001)
    {
    }

    static DataStream<DataType>::Ptr New() { return Stream::Ptr(new Stream()); }

    void SetFirstAbsoluteTimestamp(double newValue) { _t0 = newValue; }
    double FirstAbsoluteTimestamp() const { return _t0; }

    StdVectorFloat &RelativeTimestamp() { return _relativeTimestamp; }
    StdVectorFloat const &RelativeTimestamp() const { return _relativeTimestamp; }

    std::vector<DataType> &Data() { return _data; }
    std::vector<DataType> const &Data() const { return _data; }

    std::vector<DataType> ValuesAtTimes(std::vector<float> const &t)
    {
        return Interp<std::vector<DataType>>(&(_relativeTimestamp[0]), _data, &(t[0]), _relativeTimestamp.size(), t.size());
    }

    void AddPoint(DataType value, double timestamp)
    {
        if (_data.empty()) {
            _t0 = timestamp;
        }

        _mostRecentTimestamp = timestamp;

        _data.push_back(value);
        _relativeTimestamp.push_back(timestamp - _t0);
    }

    CubicPolynomial<DataType> ReverseExtrapolatingSegment(int order = 3) const
    {
        DebugAssert(Size() >= 2);

        DebugAssert(order >= 1 && order <= 3);

        int pointCount = std::min(int(Size()), order + 1);

        switch (pointCount) {
            case 0:
                return CubicPolynomial<DataType>();
                break;

            case 1: {
                return CubicPolynomial<DataType>::Constant(Data(0));
                break;
            }

            case 2: {
                DataType p0 = Data(1);
                double absoluteT0 = AbsoluteTimestamp(1);
                float t0 = 0;

                DataType p1 = Data(0);
                float t1 = absoluteT0 - AbsoluteTimestamp(0);

                return CubicPolynomial<DataType>::LineWithValuesAtTimes(p0, p1, t0, t1);
                break;
            }

            case 3:
            default: {
                DataType p0 = Data(2);
                double absoluteT0 = AbsoluteTimestamp(2);
                float t0 = 0;

                DataType p1 = Data(1);
                float t1 = absoluteT0 - AbsoluteTimestamp(1);

                DataType p2 = Data(0);
                float t2 = absoluteT0 - AbsoluteTimestamp(0);

                return CubicPolynomial<DataType>::QuadraticWithValuesAtTimes(p0, p1, p2, t0, t1, t2);
                break;
            }
        }
    }

    CubicPolynomial<DataType> ExtrapolatingSegment(int order = 3) const
    {
        DebugAssert(Size() >= 2);

        DebugAssert(order >= 1 && order <= 3);

        int pointCount = std::min(int(Size()), order + 1);

        switch (pointCount) {
            case 0: {
                return CubicPolynomial<DataType>();
                break;
            }
            case 1: {
                return CubicPolynomial<DataType>::Constant(Data(0));
                break;
            }
            case 2: {
                DataType p0 = ReverseData(1);
                double absoluteT0 = ReverseAbsoluteTimestamp(1);
                float t0 = 0;

                DataType p1 = ReverseData(0);
                float t1 = ReverseAbsoluteTimestamp(0) - absoluteT0;

                return CubicPolynomial<DataType>::LineWithValuesAtTimes(p0, p1, t0, t1);

                break;
            }
            case 3:
            default: {
                DataType p0 = ReverseData(2);
                double absoluteT0 = ReverseAbsoluteTimestamp(2);
                float t0 = 0;

                DataType p1 = ReverseData(1);
                float t1 = ReverseAbsoluteTimestamp(1) - absoluteT0;

                DataType p2 = ReverseData(0);
                float t2 = ReverseAbsoluteTimestamp(0) - absoluteT0;

                return CubicPolynomial<DataType>::QuadraticWithValuesAtTimes(p0, p1, p2, t0, t1, t2);
                break;
            }
        }
    }

    void AppendWithRelativeTimestamps(std::vector<DataType> const &inData, std::vector<float> const &inTimes)
    {
        _data.insert(_data.end(), inData.begin(), inData.end());
        _relativeTimestamp.insert(_relativeTimestamp.end(), inData.begin(), inData.end());
    }

    // this returns bogus values for the timestamps -- the first appended point
    // will have the same timestamp as the last point on the current stroke.
    // this only makes sense geometrically but sometimes that's all you care about.
    void Append(Stream const &other)
    {
        Append(other, 0);
    }

    // this one rejiggers the timestamps so the first appended point looks like
    // it arrived at initialDt seconds after the final point currently in this->_data.  typically initialDt
    // is the sampling rate (i.e. unless they stop moving entirely).
    void Append(Stream const &other, float initialDt)
    {
        size_t index = 0;
        float lastRelativeTime = LastRelativeTimestamp();
        for (size_t j = other.Size(); j--; index++) {
            float newRelativeTime = (lastRelativeTime + initialDt) + (other.RelativeTimestamp(index) - other.RelativeTimestamp(0));
            AddPoint(other.Data(index), double(newRelativeTime) + _t0);
        }
    }

    void Clear()
    {
        _data.clear();
        _relativeTimestamp.clear();
    }

    DataType LastData() const
    {
        return Data(LastValidIndex());
    }

    // "slow" accessors which do range-checking.
    // they return zeros when the _data is empty.
    DataType Data(int idx) const
    {
        if (_data.empty()) {
            return DataType::Zero();
        } else {
            return _data[ClampedIndex(idx)];
        }
    }

    float ReverseRelativeTimestamp(int idx) const
    {
        return RelativeTimestamp(LastValidIndex() - idx);
    }

    double ReverseAbsoluteTimestamp(int idx) const
    {
        return AbsoluteTimestamp(LastValidIndex() - idx);
    }

    DataType ReverseData(int idx) const
    {
        if (IsEmpty()) {
            return DataType::Zero();
        }

        int safeIndex = std::max(0, LastValidIndex() - idx);

        return _data[safeIndex];
    }

    DataType LastPoint() const
    {
        if (Size() == 0) {
            //return DataType(0);
            return DataType::Zero();
        } else {
            return _data[Size() - 1];
        }
    }

    Stream Tail(int count) const
    {
        if (IsEmpty() || count < 1) {
            return Stream();
        }

        count = std::min(count, (int)Size());

        return SubStream(Interval(Size() - count, count));
    }

    Stream SubStream(Interval subInterval) const
    {
        Stream subStream;

        if (LastValidIndex() == -1) {
            return subStream;
        }

        Interval validSubInterval = subInterval.Intersection(MaximalInterval());

        int a = validSubInterval._index;
        int b = validSubInterval._index + validSubInterval._count;

        subStream.Data() = ContainerType(&_data[a], &_data[b]);
        subStream._relativeTimestamp = std::vector<float>(&_relativeTimestamp[a], &_relativeTimestamp[b]);

        // reclock everything so times start at zero and _t0 has the absolute
        // timestamp of the first point
        subStream._t0 = _t0 + double(RelativeTimestamp(a));
        for (int j = 0; j < subStream._relativeTimestamp.size(); j++) {
            subStream._relativeTimestamp[j] -= RelativeTimestamp(a);
        }

        DebugAssert(subStream.Size() == subInterval._count);

        return subStream;
    }

    Stream StreamByPrependingPoint(DataType point, double timestamp, double t0) const
    {
        Stream outStream;

        if (LastValidIndex() == -1) {
            return outStream;
        }

        outStream._t0 = t0;

        outStream.AddPoint(point, timestamp);

        outStream._data.insert(outStream._data.end(), this->_data.begin(), this->_data.end());
        outStream._relativeTimestamp.insert(outStream._relativeTimestamp.end(),
                                            this->_relativeTimestamp.begin(),
                                            this->_relativeTimestamp.end());

        // all the data has been copied.  we now need to offset the timestamps
        // so they are relative to the new first point in outStream.
        float dt = this->AbsoluteTimestamp(0) - t0;
        for (int j = 0; j < this->Size(); j++) {
            outStream._relativeTimestamp[j + 1] += dt;
        }

        return outStream;
    }

    // returns -1 if size is zero
    int LastValidIndex() const { return (int)_data.size() - 1; }

    Interval MaximalInterval() const { return Interval(0, Size()); }

    double AbsoluteTimestamp(int idx) const
    {
        if (idx == LastValidIndex()) {
            return _mostRecentTimestamp;
        } else {
            return _t0 + double(RelativeTimestamp(idx));
        }
    }

    double LastAbsoluteTimestamp() const
    {
        int idx = LastValidIndex();
        return AbsoluteTimestamp(idx);
    }

    float RelativeTimestamp(int idx) const
    {
        if (Size() == 0) {
            return 0;
        } else {
            return _relativeTimestamp[ClampedIndex(idx)];
        }
    }

    float LastRelativeTimestamp() const
    {
        if (Size() == 0) {
            return 0;
        } else {
            return RelativeTimestamp((int)Size() - 1);
        }
    }

    size_t Size() const { return _data.size(); }
    bool IsEmpty() const { return _data.empty(); }
};
}
}
