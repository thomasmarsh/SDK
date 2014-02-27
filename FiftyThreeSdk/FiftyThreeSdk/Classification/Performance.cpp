//
//  Performance.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include <boost/algorithm/string.hpp>
#include <string>
#include <tuple>

#include "FiftyThreeSdk/Classification/Performance.h"

using namespace boost::algorithm;
using fiftythree::core::TouchClassification;
using std::ignore;

namespace
{
std::vector<std::string> CSVgetNextLineAndSplitIntoTokens(std::istream & str)
{
    std::string line;
    std::getline(str,line);

    std::vector<std::string> parts;
    boost::algorithm::split(parts, line, boost::is_any_of(","));

    BOOST_FOREACH(std::string & part, parts)
    {
        trim(part);
    }
    return parts;
}

int IndexOfString(std::string probe, std::vector<std::string> headers)
{
    int index = 0;
    BOOST_FOREACH(std::string &str, headers)
    {
        if(str == probe)
        {
            return index;
        }
        index++;
    }

    return 0;
}

}

namespace fiftythree {
namespace sdk {

// CLUSTER_ID, TOUCH_ID, PEN_DOWN_DT, PEN_UP_DT, SWITCH_ON_DURATION, TOUCH_DURATION,
// HANDEDNESS_PRIOR, ISOLATED_PRIOR, ORTHOGONAL_JERK, CURVATURE_SCORE, LENGTH_PRIOR,
// CLUSTER_PRIOR, TOUCH_PRIOR, PEN_SCORE, INFERRED_CLASS, TRUE_CLASS

PerformanceReport::PerformanceReport(std::string const & csvReport)  : _csvReport(csvReport)
{
    std::vector<TouchClassification> emptyVector;

    init(csvReport, emptyVector);
}

PerformanceReport::PerformanceReport(std::string const & csvReport, std::vector<TouchClassification> const &trueClasses)  : _csvReport(csvReport)
{
    init(csvReport, trueClasses);
}

void PerformanceReport::init(std::string const & csvReport, std::vector<TouchClassification> const &trueClasses)
{
    std::istringstream istr(csvReport);

    std::vector<std::string> headers = CSVgetNextLineAndSplitIntoTokens(istr);

    int indexInferred = IndexOfString("INFERRED_CLASS", headers);
    int indexTrue     = IndexOfString("TRUE_CLASS", headers);

    int index = 0;
    while (istr)
    {
        std::vector<std::string> row = CSVgetNextLineAndSplitIntoTokens(istr);

        if (row.empty() || row.size() == 1)
        {
            break;
        }

        TouchClassification trueClass      = static_cast<TouchClassification::TouchClassificationEnum>(std::atoi(row[indexTrue].c_str()));
        if(trueClasses.size() > 0)
        {
            trueClass = trueClasses[index];
        }

        _trueClasses.push_back(trueClass);

        TouchClassification inferredClass  = static_cast<TouchClassification::TouchClassificationEnum>(std::atoi(row[indexInferred].c_str()));

        _counts[trueClass][inferredClass]++;

        index++;
    }
}

int PerformanceReport::InferredCountForType(TouchClassification probeType)
{
    std::map<TouchClassification, int>  & probeCounts = CountsForTouchType(probeType);

    return probeCounts[probeType];
}

float PerformanceReport::ScoreForType(TouchClassification probeType)
{
    float inferredCount = InferredCountForType(probeType);
    float trueCount     = TrueCountForType(probeType);

    return inferredCount / trueCount;
}

int PerformanceReport::TotalTouchCount()
{
    int count = 0;
    TouchClassification type;
    BOOST_FOREACH(tie(type, ignore), _counts)
    {
        count += TrueCountForType(type);
    }

    return count;
}

float PerformanceReport::OverallScore()
{
    float totalCount = TotalTouchCount();
    float totalScore = 0.0f;

    TouchClassification type;
    BOOST_FOREACH(tie(type, ignore), _counts)
    {
        float score      = ScoreForType(type);
        float trueCount  = TrueCountForType(type);

        totalScore      += score * (trueCount / totalCount);

    }

    return totalScore;

}

int PerformanceReport::TrueCountForType(TouchClassification probeType)
{
    float total = 0.0f;

    typedef std::pair<TouchClassification, int> TypeIntPair;

    BOOST_FOREACH(TypeIntPair pair, _counts[probeType])
    {
        total += pair.second;
    }
    return total;
}

}
}
