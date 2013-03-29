//
//  FTPenAndTouchLogger.h
//  FiftyThreeSdk
//
//  Created by Adam on 3/29/13.
//  Copyright (c) 2013 FiftyThree. All rights reserved.
//

#pragma once

#include <boost/smart_ptr.hpp>

namespace fiftythree
{
namespace sdk
{

class FTPenAndTouchLogger
{
public:
    typedef boost::shared_ptr<FTPenAndTouchLogger> Ptr;
    typedef const boost::shared_ptr<FTPenAndTouchLogger> cPtr;
    
protected:
    ~FTPenAndTouchLogger() {}
    
public:
    virtual void StartLogging() = 0;
    virtual void StopLogging() = 0;
    
    static Ptr New();
};

}
}