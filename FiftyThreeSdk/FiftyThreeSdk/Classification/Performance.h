//
//  Performance.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <map>
#include <vector>

#include "Core/Enum.h"
#include "Core/Touch/Touch.h"
#include "FiftyThreeSdk/Classification/Classifier.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"

namespace fiftythree
{
namespace sdk
{
typedef std::pair<core::TouchClassification, std::map<core::TouchClassification, int>> TypeCountsPair;

class PerformanceReport
{
    std::map<core::TouchClassification, std::map<core::TouchClassification, int>> _counts;
    std::string _csvReport;

    std::vector<core::TouchClassification> _trueClasses;

public:
    PerformanceReport() = default;

    // construct a performance report assuming the TRUE_CLASS column is correct
    PerformanceReport(std::string const &csvReport);

    // override the TRUE_CLASS column from the file with the spec'd data.  Used
    // when running RT's to allow labeled data to override the default.
    PerformanceReport(std::string const &csvReport, std::vector<core::TouchClassification> const &trueClasses);

    void init(std::string const &csvReport, std::vector<core::TouchClassification> const &trueClasses);

    std::vector<core::TouchClassification> const &TrueClasses()
    {
        return _trueClasses;
    }

    // not returning const ref because then you can't use bracket[] operator.
    std::map<core::TouchClassification, int> &CountsForTouchType(core::TouchClassification probeType)
    {
        return _counts[probeType];
    }

    std::string const &CSVReport()
    {
        return _csvReport;
    }

    int TrueCountForType(core::TouchClassification probeType);

    int InferredCountForType(core::TouchClassification probeType);

    int TotalTouchCount();

    float ScoreForType(core::TouchClassification probeType);

    float OverallScore();
};
}
}
