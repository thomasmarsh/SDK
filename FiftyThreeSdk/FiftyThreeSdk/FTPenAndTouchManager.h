//
//  FTPenAndTouchManager.h
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

class FTPenAndTouchManager
{
public:
    typedef boost::shared_ptr<FTPenAndTouchManager> Ptr;
    typedef const boost::shared_ptr<FTPenAndTouchManager> cPtr;
    
protected:
    ~FTPenAndTouchManager() {}
    
public:
    virtual void SetLogging(bool logging) = 0;
    virtual void RegisterForEvents() = 0;
    virtual void UnregisterForEvents() = 0;

    static Ptr New();
};

}
}