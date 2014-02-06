//
//  Performance.cpp
//  Classification
//
//  Created by matt on 10/18/13.
//  Copyright (c) 2013 Peter Sibley. All rights reserved.
//

#include "FiftyThreeSdk/Classification/Performance.h"
#include <boost/tuple/tuple.hpp>
#include <string>
#include <boost/algorithm/string.hpp>

using namespace boost::algorithm;
using namespace boost::tuples;

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
namespace classification {
    
// CLUSTER_ID, TOUCH_ID, PEN_DOWN_DT, PEN_UP_DT, SWITCH_ON_DURATION, TOUCH_DURATION,
// HANDEDNESS_PRIOR, ISOLATED_PRIOR, ORTHOGONAL_JERK, CURVATURE_SCORE, LENGTH_PRIOR,
// CLUSTER_PRIOR, TOUCH_PRIOR, PEN_SCORE, INFERRED_CLASS, TRUE_CLASS

PerformanceReport::PerformanceReport(std::string const & csvReport)  : _csvReport(csvReport)
{
    std::vector<TouchType> emptyVector;

    init(csvReport, emptyVector);
}

    
PerformanceReport::PerformanceReport(std::string const & csvReport, std::vector<TouchType> const &trueClasses)  : _csvReport(csvReport)
{
    init(csvReport, trueClasses);
}
   
    
void PerformanceReport::init(std::string const & csvReport, std::vector<TouchType> const &trueClasses)
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
        
        TouchType trueClass      = static_cast<TouchType::TouchTypeEnum>(std::atoi(row[indexTrue].c_str()));
        if(trueClasses.size() > 0)
        {
            trueClass = trueClasses[index];
        }
        
        _trueClasses.push_back(trueClass);
        
        TouchType inferredClass  = static_cast<TouchType::TouchTypeEnum>(std::atoi(row[indexInferred].c_str()));
        
        _counts[trueClass][inferredClass]++;
        
        index++;
    }
}
    
    
int PerformanceReport::InferredCountForType(TouchType probeType)
{
    std::map<TouchType, int>  & probeCounts = CountsForTouchType(probeType);
    
    return probeCounts[probeType];
}
    
float PerformanceReport::ScoreForType(TouchType probeType)
{
    float inferredCount = InferredCountForType(probeType);
    float trueCount     = TrueCountForType(probeType);
    
    return inferredCount / trueCount;
}

int PerformanceReport::TotalTouchCount()
{
    int count = 0;
    TouchType type;
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
    
    TouchType type;
    BOOST_FOREACH(tie(type, ignore), _counts)
    {
        float score      = ScoreForType(type);
        float trueCount  = TrueCountForType(type);
    
        totalScore      += score * (trueCount / totalCount);
        
    }
    
    return totalScore;
    
}
    
    
int PerformanceReport::TrueCountForType(TouchType probeType)
{
    float total = 0.0f;
    
    typedef std::pair<TouchType, int> TypeIntPair;
    
    BOOST_FOREACH(TypeIntPair pair, _counts[probeType])
    {
        total += pair.second;
    }
    return total;
}


    
    
}
}



























