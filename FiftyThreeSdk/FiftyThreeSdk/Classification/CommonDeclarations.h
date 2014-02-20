//
//  CommonDeclarations.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <boost/assign.hpp>
#include <boost/strong_typedef.hpp>
#include <vector>

#include "Classifier.h"
#include "Common/Eigen.h"
#include "Common/Enum.h"
#include "Common/Touch/Touch.h"

namespace fiftythree
{
namespace sdk
{

typedef std::map<common::TouchId, float> IdFloatMap;
typedef std::map<common::TouchId, TouchType> IdTypeMap;
typedef std::pair<common::TouchId, TouchType> IdTypePair;

static const float Inf = std::numeric_limits<float>::infinity();
static const int intInf = std::numeric_limits<int>::max() -3 ; // -3 because of indexing issues

// Like TouchId, valid ids are non-negative
//typedef int PenEventId;
BOOST_STRONG_TYPEDEF(int, PenEventId);

class TouchClassificationProxy;

struct CommonData
{
    const std::map<common::TouchId, TouchType>* const types;
    const std::map<common::TouchId, bool>* const locked;

    TouchClassificationProxy* proxy;

    CommonData(std::map<common::TouchId, TouchType>* typesPointer,
               std::map<common::TouchId, bool>* lockedPointer,
               TouchClassificationProxy* proxyPointer):
    types(typesPointer),
    locked(lockedPointer),
    proxy(proxyPointer)
    {
    }
};

typedef std::vector<TouchType> TouchTypeVector;
typedef std::vector<TouchType>::iterator TouchTypeIterator;

// This is fairly arbitrary: we only update isolated stroke data when the number of samples reaches
// one of the threshold values below.
// The last threshold should always be Inf. Otherwise...*boom*
static const int isolatedBatchThresholds[] = {
  4, 8, 12, 16, 20, 28, 36, 44, 52, 60, 70, 80, 90, 100, 150, 200, 250, 300, 350, 400, 500, 600, intInf
};

template<typename DataType>
class DataStream;

typedef Eigen::Matrix<float,  1, 1> Vector1f;
typedef Eigen::Matrix<double, 1, 1> Vector1d;

typedef DataStream<Eigen::Vector2f>   DataStream2f;
typedef DataStream<Vector1f>          DataStream1f;
typedef Eigen::Matrix< float, 7, 1> Vector7f;

typedef DataStream<Vector7f>          DataStream7f;

typedef std::vector< float > StdVectorFloat;

typedef Eigen::Map<Eigen::VectorXf> VectorXfMap;
typedef Eigen::Map<Eigen::VectorXi> VectorXiMap;
typedef Eigen::Map<float> FloatMap;

typedef Eigen::Map<Eigen::VectorXf, 0, Eigen::InnerStride<2> > Stride2Map;

typedef Eigen::Vector2f XYType;

// identifies a stretch of _count points with first point at _index
struct Interval
{
    size_t _index;
    size_t _count;

    Interval(size_t index, size_t count) : _index(index), _count(count) {}
    Interval() : _index(0), _count(0) {}

    bool IsEmpty()   const
    {
        return _count == 0;
    }

    int  LastIndex() const
    {
        return _index + _count - 1;
    }

    static Interval Zero()
    {
        return Interval(0,0);
    }

    Interval Intersection(Interval const &other) const
    {

        int a = std::max(_index, other._index);
        int b = std::min(LastIndex(), other.LastIndex());
        return Interval(a, std::max(0, b-a+1));
    }

    bool operator==(Interval const &other)
    {
        return (other._index == _index) && (other._count == _count);
    }
};
}
}
