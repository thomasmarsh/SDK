//
//  Performance.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include <iostream>
#include <string>
#include <tuple>

#include "Core/StringUtils.h"
#include "FiftyThreeSdk/Classification/Performance.h"

using fiftythree::core::TouchClassification;
using std::ignore;
using std::string;
using std::vector;

namespace
{
vector<string> CSVgetNextLineAndSplitIntoTokens(std::istream &str)
{
    string line;
    std::getline(str, line);

    auto parts = fiftythree::core::Split(line, ',');

    for (auto &part : parts) {
        part = fiftythree::core::Trim(part);
    }
    return parts;
}

int IndexOfString(string probe, vector<string> headers)
{
    int index = 0;
    for (string &str : headers) {
        if (str == probe) {
            return index;
        }
        index++;
    }

    return 0;
}
}

namespace fiftythree
{
namespace sdk
{
// CLUSTER_ID, TOUCH_ID, PEN_DOWN_DT, PEN_UP_DT, SWITCH_ON_DURATION, TOUCH_DURATION,
// HANDEDNESS_PRIOR, ISOLATED_PRIOR, ORTHOGONAL_JERK, CURVATURE_SCORE, LENGTH_PRIOR,
// CLUSTER_PRIOR, TOUCH_PRIOR, PEN_SCORE, INFERRED_CLASS, TRUE_CLASS

PerformanceReport::PerformanceReport(string const &csvReport)
: _csvReport(csvReport)
{
    vector<TouchClassification> emptyVector;

    init(csvReport, emptyVector);
}

PerformanceReport::PerformanceReport(string const &csvReport, vector<TouchClassification> const &trueClasses)
: _csvReport(csvReport)
{
    init(csvReport, trueClasses);
}

void PerformanceReport::init(string const &csvReport, vector<TouchClassification> const &trueClasses)
{
    std::istringstream istr(csvReport);

    vector<string> headers = CSVgetNextLineAndSplitIntoTokens(istr);

    int indexInferred = IndexOfString("INFERRED_CLASS", headers);
    int indexTrue = IndexOfString("TRUE_CLASS", headers);

    int index = 0;
    while (istr) {
        vector<string> row = CSVgetNextLineAndSplitIntoTokens(istr);

        if (row.empty() || row.size() == 1) {
            break;
        }

        TouchClassification trueClass = static_cast<TouchClassification>(std::atoi(row[indexTrue].c_str()));
        if (trueClasses.size() > 0) {
            trueClass = trueClasses[index];
        }

        _trueClasses.push_back(trueClass);

        TouchClassification inferredClass = static_cast<TouchClassification>(std::atoi(row[indexInferred].c_str()));

        _counts[trueClass][inferredClass]++;

        index++;
    }
}

int PerformanceReport::InferredCountForType(TouchClassification probeType)
{
    std::map<TouchClassification, int> &probeCounts = CountsForTouchType(probeType);

    return probeCounts[probeType];
}

float PerformanceReport::ScoreForType(TouchClassification probeType)
{
    float inferredCount = InferredCountForType(probeType);
    float trueCount = TrueCountForType(probeType);

    return inferredCount / trueCount;
}

int PerformanceReport::TotalTouchCount()
{
    int count = 0;
    TouchClassification type;
    for (const auto &pair : _counts) {
        tie(type, ignore) = pair;
        count += TrueCountForType(type);
    }

    return count;
}

float PerformanceReport::OverallScore()
{
    float totalCount = TotalTouchCount();
    float totalScore = 0.0f;

    TouchClassification type;
    for (const auto &pair : _counts) {
        tie(type, ignore) = pair;
        float score = ScoreForType(type);
        float trueCount = TrueCountForType(type);

        totalScore += score * (trueCount / totalCount);
    }

    return totalScore;
}

int PerformanceReport::TrueCountForType(TouchClassification probeType)
{
    float total = 0.0f;

    typedef std::pair<TouchClassification, int> TypeIntPair;

    for (TypeIntPair pair : _counts[probeType]) {
        total += pair.second;
    }
    return total;
}
}
}
