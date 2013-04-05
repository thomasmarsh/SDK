//
//  FTPenAndTouchManager.cpp
//  FiftyThreeSdk
//
//  Created by Adam on 3/29/13.
//  Copyright (c) 2013 FiftyThree. All rights reserved.
//

#include "FTPenAndTouchManager.h"

#include <boost/smart_ptr.hpp>
#include <boost/foreach.hpp>

#include "Common/NoCopy.h"
#include "Common/TouchManager.h"
#include "Common/PenManager.h"

#include "TouchClassifierManager.h"
#include "LatencyTouchClassifier.h"
#include "FTTouchEventLogger.h"

using namespace fiftythree::sdk;
using namespace fiftythree::common;

class FTPenAndTouchManagerImpl : public FTPenAndTouchManager, public boost::enable_shared_from_this<FTPenAndTouchManagerImpl>
{
private:
    TouchClassifierManager::Ptr _ClassifierManager;
    FTTouchEventLogger::Ptr _Logger;
    
public:
    FTPenAndTouchManagerImpl()
    {
        _ClassifierManager = TouchClassifierManager::New();
        _ClassifierManager->AddClassifier(LatencyTouchClassifier::New());
    }
    
    ~FTPenAndTouchManagerImpl()
    {
        UnregisterForEvents();
    }
    
    void RegisterForEvents()
    {
        TouchManager::Instance()->TouchesBegan().AddListener(shared_from_this(), &FTPenAndTouchManagerImpl::TouchesBegan);
        TouchManager::Instance()->TouchesMoved().AddListener(shared_from_this(), &FTPenAndTouchManagerImpl::TouchesMoved);
        TouchManager::Instance()->TouchesEnded().AddListener(shared_from_this(), &FTPenAndTouchManagerImpl::TouchesEnded);
        TouchManager::Instance()->TouchesCancelled().AddListener(shared_from_this(), &FTPenAndTouchManagerImpl::TouchesCancelled);
    }
    
    void UnregisterForEvents()
    {
        TouchManager::Instance()->TouchesBegan().RemoveListener(shared_from_this());
        TouchManager::Instance()->TouchesMoved().RemoveListener(shared_from_this());
        TouchManager::Instance()->TouchesEnded().RemoveListener(shared_from_this());
        TouchManager::Instance()->TouchesCancelled().RemoveListener(shared_from_this());
    }
    
    void SetLogging(bool logging)
    {
        if (logging)
        {
            _Logger = FTTouchEventLogger::New();
        }
    }
    
    void TouchesBegan(const TouchesSetEvent & sender, const TouchesSet & touches)
    {
        if (_Logger) _Logger->TouchesBegan(touches);
        
        _ClassifierManager->TouchesBegan(touches);
    }
    
    void TouchesMoved(const TouchesSetEvent & sender, const TouchesSet & touches)
    {
        if (_Logger) _Logger->TouchesMoved(touches);
        
        _ClassifierManager->TouchesMoved(touches);
    }
    
    void TouchesEnded(const TouchesSetEvent & sender, const TouchesSet & touches)
    {
        if (_Logger) _Logger->TouchesEnded(touches);
        
        _ClassifierManager->TouchesEnded(touches);
    }
    
    void TouchesCancelled(const TouchesSetEvent & sender, const TouchesSet & touches)
    {
        if (_Logger) _Logger->TouchesCancelled(touches);
        
        _ClassifierManager->TouchesCancelled(touches);
    }
    
    FT_NO_COPY(FTPenAndTouchManagerImpl);
};

FTPenAndTouchManager::Ptr FTPenAndTouchManager::New()
{
    return boost::make_shared<FTPenAndTouchManagerImpl>();
}