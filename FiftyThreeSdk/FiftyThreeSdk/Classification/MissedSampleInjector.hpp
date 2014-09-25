//
//  MissedSampleInjector.hpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <boost/make_shared.hpp>

#include "FiftyThreeSdk/Classification/DataStream.hpp"

namespace fiftythree
{
namespace sdk
{

template <class DataType>
class MissedSampleInjector
{

public:

    typedef DataStream<DataType> DataStreamType;

    typename DataStreamType::Ptr _realAndInjectedSamples;

    typedef boost::shared_ptr< MissedSampleInjector<DataType> > Ptr;

    float _minimumInjectedSampleSpacing;
    bool  _useSmoothedSamples;

    static MissedSampleInjector<DataType>::Ptr New() { return Ptr(new MissedSampleInjector<DataType>); }

    MissedSampleInjector() :
    _realAndInjectedSamples(typename DataStreamType::Ptr(new DataStreamType)),
    _minimumInjectedSampleSpacing(25.0f)
    {

    }

    DataStreamType const &RealAndInjectedSamples()
    {
        return *_realAndInjectedSamples;
    }

    void SetSamplingRate(float samplesPerSecond)
    {
        _realAndInjectedSamples->_sampleRate = samplesPerSecond;
    }

    void Reset()
    {
        _realAndInjectedSamples = typename DataStreamType::Ptr(new DataStreamType);
    }

    size_t AddPoint(DataType const & point, double timestamp)
    {
        assert(_realAndInjectedSamples);

        int missingCount = 0;

        if (! _realAndInjectedSamples->IsEmpty())
        {

            int sizeOnEntry = _realAndInjectedSamples->Size();

            float samplingInterval = 1.0f / _realAndInjectedSamples->_sampleRate;

            float dt = timestamp - _realAndInjectedSamples->LastAbsoluteTimestamp();

            missingCount = std::max(0, int(roundf(dt / samplingInterval)) - 1);

            float ds = (_realAndInjectedSamples->LastPoint() - point).norm();

            missingCount = std::min(missingCount, int(ds * 2.0f));

            // ds > minspacing just ensures we won't detect a lot of missing samples when they stop
            if (missingCount > 0 && ds > _minimumInjectedSampleSpacing)
            {

                // the missing samples will be recovered by evaluating segment
                // at times = 0, 1, 2, ..., (missingCount - 1)
                CubicPolynomial<DataType> segment;

                typename DataStreamType::Ptr samples = _realAndInjectedSamples;
                if (_useSmoothedSamples)
                {
                    // this case here is not used at the moment, but i suppose it could be useful for something
                    // so i'm leaving it in.
                    //samples = _target->SmoothedSamplePoints();
                }

                switch (samples->Size())
                {
                    case 1:
                    default:
                    {
                        DataType fromPoint  = samples->LastPoint();
                        segment             = CubicPolynomial<DataType>::LineWithValuesAtTimes(fromPoint, point, -1.0f, float(missingCount));
                        break;
                    }

                        /*
                    case 2:
                    default:
                    {

                        DataType p = samples->ReverseData(1);
                        DataType q = samples->LastPoint();

                        segment = CubicPolynomial<DataType>::QuadraticWithValuesAtTimes(p, q, point, -2.0f, -1.0f, float(missingCount));

                        break;
                    }
                        */

                        // there is no "case 3:" because it was too sensitive to noise.  if you move slowly,
                        // then suddenly go fast, and detect a few dropped samples, the slow samples produce
                        // a wildly erratic polynomial and the interpolated samples shoot all over the place.
                        // this still happens with quadratics to a lesser extent and i need to be a little smarter there.
                }

                float t = 0.0f;

                double dtInject              = dt / float(missingCount + 1);
                double injectTimestamp       = _realAndInjectedSamples->LastAbsoluteTimestamp() + dtInject;

                for (int j=0; j<missingCount; j++, t++, injectTimestamp += dtInject)
                {
                    DataType injectee = segment.ValueAt(t);

                    std::cerr << "\n inject = (" << injectee.x() << ", " << injectee.y() << "), t = " << injectTimestamp;

                    _realAndInjectedSamples->AddPoint(injectee, injectTimestamp);
                    //_target->AddPoint(injectee, injectTimestamp);
                }
            }

        }

        //DebugAssert(_real)

        std::cerr << "\n addpt = (" << point.x() << ", " << point.y() << "), t = " << timestamp;

        _realAndInjectedSamples->AddPoint(point, timestamp);
        //_target->AddPoint(point, timestamp);

        return 1 + missingCount;

    }

};

typedef MissedSampleInjector<Vector1f>         MissedSampleInjector1f;
typedef MissedSampleInjector<Eigen::Vector2f>  MissedSampleInjector2f;
typedef MissedSampleInjector<Vector7f>         MissedSampleInjector7f;

}
}
