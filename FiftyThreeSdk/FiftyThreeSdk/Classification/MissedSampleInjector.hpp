//
//  MissedSampleInjector.hpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include "Core/Memory.h"
#include "FiftyThreeSdk/Classification/DataStream.hpp"

namespace fiftythree
{
namespace sdk
{
template <class DataType>
class MissedSampleInjector
{
public:
    using DataStreamType = DataStream<DataType>;
    using DataStreamTypePtr = typename DataStreamType::Ptr;
    using Ptr = core::shared_ptr<MissedSampleInjector<DataType>>;

    DataStreamTypePtr _realAndInjectedSamples;
    DataStreamTypePtr _realSamples;

    float _minimumInjectedSampleSpacing;
    bool _useSmoothedSamples;

    static MissedSampleInjector<DataType>::Ptr New() { return core::make_shared<MissedSampleInjector<DataType>>(); }

    MissedSampleInjector()
    : _realAndInjectedSamples(core::make_shared<DataStreamType>())
    , _realSamples(core::make_shared<DataStreamType>())
    , _minimumInjectedSampleSpacing(25.0f)
    {
    }

    DataStreamType const &RealAndInjectedSamples()
    {
        return *_realAndInjectedSamples;
    }

    DataStreamType const &RealSamples()
    {
        return *_realSamples;
    }

    void SetSamplingRate(float samplesPerSecond)
    {
        _realAndInjectedSamples->_sampleRate = samplesPerSecond;
        _realSamples->_sampleRate = samplesPerSecond;
    }

    void Reset()
    {
        _realAndInjectedSamples = typename DataStreamType::Ptr(new DataStreamType);
        _realSamples = typename DataStreamType::Ptr(new DataStreamType);
    }

    size_t AddPoint(DataType const &point, double timestamp)
    {
        assert(_realAndInjectedSamples);

        int missingCount = 0;
        auto sizeOnEntry = _realAndInjectedSamples->Size();

        // check if size >= 2 since the second point on iOS is unpredictable and we don't want to stuff a line
        // segment in there
        if (_realAndInjectedSamples->Size() > 1) {
            auto samplingInterval = 1.0f / _realSamples->_sampleRate;

            auto dt = timestamp - _realSamples->LastAbsoluteTimestamp();

            missingCount = std::max(0, int(roundf(dt / samplingInterval)) - 1);

            auto ds = (_realSamples->LastPoint() - point).norm();

            if (ds < _minimumInjectedSampleSpacing) {
                missingCount = 0;
            } else {
                missingCount = std::min(missingCount, int(ds));
            }

            // ds > minspacing just ensures we won't detect a lot of missing samples when they stop
            if (missingCount > 0) {
                // the missing samples will be recovered by evaluating segment
                // at times = 0, 1, 2, ..., (missingCount - 1)
                CubicPolynomial<DataType> segment;
                const auto &samples = _realSamples;

                auto fromTimestamp = samples->LastAbsoluteTimestamp();
                constexpr float relativeFromTimestamp = 0.0f;
                float relativeToTimestamp = timestamp - fromTimestamp;
                double TnormalizedFactor = 1.0 / (timestamp - fromTimestamp);

                switch (samples->Size()) {
                    case 1: {
                        const auto &fromPoint = samples->LastPoint();
                        segment = CubicPolynomial<DataType>::LineWithValuesAtTimes(fromPoint,
                                                                                   point,
                                                                                   TnormalizedFactor * relativeFromTimestamp,
                                                                                   TnormalizedFactor * relativeToTimestamp);
                        break;
                    }
                    case 2:
                    default: {
                        const auto &p = samples->ReverseData(1);
                        const auto &q = samples->LastPoint();
                        auto olderFromTimestamp = samples->ReverseAbsoluteTimestamp(1);
                        float olderRelativeFromTimestamp = olderFromTimestamp - fromTimestamp;

                        segment = CubicPolynomial<DataType>::QuadraticWithValuesAtTimes(p,
                                                                                        q,
                                                                                        point,
                                                                                        TnormalizedFactor * olderRelativeFromTimestamp,
                                                                                        TnormalizedFactor * relativeFromTimestamp,
                                                                                        TnormalizedFactor * relativeToTimestamp);

                        break;
                    }

                        // there is no "case 3:" because it was too sensitive to noise.  if you move slowly,
                        // then suddenly go fast, and detect a few dropped samples, the slow samples produce
                        // a wildly erratic polynomial and the interpolated samples shoot all over the place.
                        // this still happens with quadratics to a lesser extent and i need to be a little smarter there.
                }

                auto dtInject = dt / float(missingCount + 1);
                double relativeInjectTimestamp = dtInject;

                for (int j = 0; j < missingCount; ++j, relativeInjectTimestamp += dtInject) {
                    const auto &injectee = segment.ValueAt(TnormalizedFactor * relativeInjectTimestamp);
                    DebugAssert(std::isfinite(injectee[0]) && std::isfinite(injectee[1]));
                    auto absoluteInjectTimestamp = samples->LastAbsoluteTimestamp() + relativeInjectTimestamp;
                    _realAndInjectedSamples->AddPoint(injectee, absoluteInjectTimestamp);
                }
            }
        }

        _realSamples->AddPoint(point, timestamp);
        _realAndInjectedSamples->AddPoint(point, timestamp);

        DebugAssert(_realAndInjectedSamples->Size() - sizeOnEntry == 1 + missingCount);

        return 1 + missingCount;
    }
};

using MissedSampleInjector1f = MissedSampleInjector<Vector1f>;
using MissedSampleInjector2f = MissedSampleInjector<Eigen::Vector2f>;
}
}
