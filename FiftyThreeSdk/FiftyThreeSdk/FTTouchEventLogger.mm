//
//  FTTouchEventLogger.mm
//  FiftyThreeSdk
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#include "FTTouchEventLogger.h"

#include <boost/foreach.hpp>
#include <sstream>
#import <Foundation/Foundation.h>

const std::string TOUCH_PREFIX = "touch=";
const std::string PEN_PREFIX = "pen=";

using namespace fiftythree::common;
using namespace fiftythree::sdk;
using std::string;
using std::stringstream;

class FTTouchEventLoggerImpl : public FTTouchEventLoggerObjc
{
private:
    std::vector<Touch::cPtr> _PastTouches;
    NSMutableData* data;

public:
    FTTouchEventLoggerImpl()
    {
        data = [NSMutableData data];
    }

    void TouchesBegan(const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            _PastTouches.push_back(touch);

            stringstream ss;
            ss << TOUCH_PREFIX << touch->ToString() << std::endl;

            std::cout << ss.str();

            [data appendBytes:ss.str().c_str() length:ss.tellp()];
        }
    }

    void TouchesMoved(const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            stringstream ss;
            ss << TOUCH_PREFIX << touch->ToString() << std::endl;

            std::cout << ss.str();

            [data appendBytes:ss.str().c_str() length:ss.tellp()];
        }
    }

    void TouchesEnded(const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            stringstream ss;
            ss << TOUCH_PREFIX << touch->ToString() << std::endl;

            std::cout << ss.str();

            [data appendBytes:ss.str().c_str() length:ss.tellp()];
        }
    }

    void TouchesCancelled(const TouchesSet & touches)
    {
        BOOST_FOREACH(const Touch::cPtr & touch, touches)
        {
            stringstream ss;
            ss << TOUCH_PREFIX << touch->ToString() << std::endl;

            std::cout << ss.str();

            [data appendBytes:ss.str().c_str() length:ss.tellp()];
        }
    }

    virtual void HandlePenEvent(const PenEvent & event)
    {
        stringstream ss;
        ss << PEN_PREFIX << event.ToString() << std::endl;

        std::cout << ss.str();

        [data appendBytes:ss.str().c_str() length:ss.tellp()];
    }

    virtual void Clear()
    {
        _PastTouches.clear();
        data = [NSMutableData data];
    }

    virtual NSMutableData* GetData()
    {
        return [NSMutableData dataWithData:data];
    }

    Touch::cPtr NearestStrokeForTouch(Touch::cPtr touch)
    {
        Touch::cPtr nearestStroke;
        float nearestDistance = std::numeric_limits<float>::max();

        BOOST_FOREACH(const Touch::cPtr & candidate, _PastTouches)
        {
            Eigen::Vector2f touchLocation = touch->CurrentSample().Location();

            BOOST_FOREACH(const InputSample & sample, *candidate->History())
            {
                float distance = Distance<float, Eigen::Vector2f>(touchLocation, sample.Location());

                if (distance < nearestDistance && distance < 20.f)
                {
                    nearestDistance = distance;
                    nearestStroke = candidate;
                }
            }
        }

        return nearestStroke;
    }

    FT_NO_COPY(FTTouchEventLoggerImpl);
};

FTTouchEventLogger::Ptr FTTouchEventLogger::New()
{
    return boost::make_shared<FTTouchEventLoggerImpl>();
}
