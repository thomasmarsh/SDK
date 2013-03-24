//
//  FTPenTouchManager.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#import "FTPenTouchManager.h"
#import "FTPenGestureRecognizer.h"
#import "FTPenManager.h"
#import "FTPen.h"
#include "TouchClassifierManager.h"
#include "LatencyTouchClassifier.h"

#include <boost/foreach.hpp>
#include <vector>

#include "Common/PenManager.h"
#include "Common/InputSample.h"
#include "PenEvent.h"

using namespace fiftythree::sdk;
using namespace fiftythree::common;

@interface FTPenTouchManager ()
{
    std::vector<TouchClassifierManager::Ptr> _managers;
}

@property (nonatomic) FTPenManager* penManager;

@end

@implementation FTPenTouchManager

- (id)initWithPenManager:(FTPenManager *)penManager
{
    if (self = [super init])
    {
        _penManager = penManager;
    }
    return self;
}

- (void)registerView:(UIView *)view
{
    TouchClassifierManager::Ptr classifierManager = TouchClassifierManager::New();
    classifierManager->AddClassifier(LatencyTouchClassifier::New());
    _managers.push_back(classifierManager);
    
    [view addGestureRecognizer:[[FTPenGestureRecognizer alloc] initWithTouchClassifierManager:classifierManager penManager:self.penManager]];
}

- (void)deregisterView:(UIView *)view
{
    for (UIGestureRecognizer *rec in view.gestureRecognizers)
    {
        if ([rec isKindOfClass:[FTPenGestureRecognizer class]])
        {
            TouchClassifierManager::Ptr manager = ((FTPenGestureRecognizer *)rec).classifierManager;
            [view removeGestureRecognizer:rec];
            
            _managers.erase(std::remove(_managers.begin(), _managers.end(), manager), _managers.end());
            break;
        }
    }
}

- (void)pen:(FTPen *)pen didPressTip:(FTPenTip)tip
{
    BOOST_FOREACH(const TouchClassifierManager::Ptr & manager, _managers)
    {
        InputSample sample(0, 0, [NSProcessInfo processInfo].systemUptime);
        PenEvent::Ptr penEvent = PenEvent::New(sample, PenEventType::PenDown, PenTip((PenTip::PenTipEnum)tip));
        manager->ProcessPenEvent(*penEvent);
    }
}

- (void)pen:(FTPen *)pen didReleaseTip:(FTPenTip)tip
{
    BOOST_FOREACH(const TouchClassifierManager::Ptr & manager, _managers)
    {
        InputSample sample(0, 0, [NSProcessInfo processInfo].systemUptime);
        PenEvent::Ptr penEvent = PenEvent::New(sample, PenEventType::PenUp, PenTip((PenTip::PenTipEnum)tip));
        manager->ProcessPenEvent(*penEvent);
    }    
}

@end
