//
//  Performance.h
//  Classification
//
//  Created by matt on 10/18/13.
//  Copyright (c) 2013 Peter Sibley. All rights reserved.
//


#pragma once


#include "Common/Enum.h"
#include "Common/Touch/Touch.h"
#include "CommonDeclarations.h"
#include <boost/foreach.hpp>
#include "FiftyThreeSdk/Classification/Classifier.h"

namespace fiftythree
{
namespace sdk
{
    
    
    typedef std::pair<TouchType, std::map<TouchType, int> > TypeCountsPair;
 
    class PerformanceReport
    {
      
        std::map<TouchType, std::map<TouchType, int> > _counts;
        std::string                                    _csvReport;
        
        std::vector<TouchType>                         _trueClasses;
        
    public:
        
        PerformanceReport()
        {
            
        }
        
        // construct a performance report assuming the TRUE_CLASS column is correct
        PerformanceReport(std::string const & csvReport);
        
        // override the TRUE_CLASS column from the file with the spec'd data.  Used
        // when running RT's to allow labeled data to override the default.
        PerformanceReport(std::string const & csvReport, std::vector<TouchType> const &trueClasses);
        
        void init(std::string const & csvReport, std::vector<TouchType> const &trueClasses);
        
        std::vector<TouchType> const & TrueClasses()
        {
            return _trueClasses;
        }
        
        
        // not returning const ref because then you can't use bracket[] operator.
        std::map<TouchType, int> & CountsForTouchType(TouchType probeType)
        {
            return _counts[probeType];
        }
        
        std::string const & CSVReport()
        {
            return _csvReport;
        }
        
        int TrueCountForType(TouchType probeType);
        
        int InferredCountForType(TouchType probeType);
        
        int TotalTouchCount();
        
        float ScoreForType(TouchType probeType);
        
        float OverallScore();
        
        
    };
    
    
}
}




