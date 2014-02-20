//
//  CommonDeclarationsCurves.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <vector>

#include "Common/Eigen.h"

namespace fiftythree
{
namespace sdk
{

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
