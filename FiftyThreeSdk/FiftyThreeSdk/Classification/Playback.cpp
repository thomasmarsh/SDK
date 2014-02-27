//
//  Playback.cpp
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#include <boost/algorithm/string.hpp>
#include <boost/foreach.hpp>
#include <boost/lexical_cast.hpp>

#include "Core/Touch/Touch.h"
#include "FiftyThreeSdk/Classification/Playback.h"

using namespace boost::algorithm;
using namespace fiftythree::core;
using boost::lexical_cast;
using fiftythree::core::make_shared;

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

}

using namespace fiftythree::common;

namespace fiftythree
{
namespace sdk
{

PlaybackSequence::PlaybackSequence(std::istream & str)
{
    std::vector<std::string> row;
    int previousIndex = -1;

    while (str)
    {
        row = CSVgetNextLineAndSplitIntoTokens(str);

        if (row.empty() || (row.size() == 1 && row[0] == ""))
        {
            break;
        }

        int    index       = lexical_cast<int>(row[0]);
        double timestamp   = lexical_cast<double>(row[1]);
        int    type        = lexical_cast<int>(row[2]);

        if(index != previousIndex)
        {
            if(type == PlaybackEntryType::PenEvent)
            {
                int penEventType =lexical_cast<int>(row[3]);
                PenEvent pe;

                pe._type      = static_cast<PenEventType::PenEventTypeEnum>(penEventType);
                pe._timestamp = timestamp;

                _playbackEntries.push_back(make_shared<PlaybackEntry>(pe));
            }
            else
            {
                // set up a new entry -- the touches will get added below
                _playbackEntries.push_back(make_shared<PlaybackEntry>(PlaybackEntryType::TouchesChanged));
            }
        }

        if(type == PlaybackEntryType::TouchesChanged)
        {
            TouchId touchId  = static_cast<TouchId>(lexical_cast<int>(row[3]));
            TouchPhase phase = static_cast<TouchPhase::TouchPhaseEnum>(lexical_cast<int>(row[4]));

            float      x     = lexical_cast<float>(row[5]);
            float      y     = lexical_cast<float>(row[6]);

            Eigen::Vector2f z(x,y);
            core::InputSample sample(z, z, timestamp);

            auto touch = core::Touch::New(touchId, phase, sample);

            if (row.size() >= 8)
            {
                float r = lexical_cast<float>(row[7]);
                sample.SetTouchRadius(r);
            }

            // optional...
            if (row.size() >= 9)
            {
                int v = lexical_cast<int>(row[8]);
                touch->DynamicProperties()["prviewControllerGestureTouches"] = boost::any(v);
            }

            _playbackEntries.back()->_touches.insert(touch);
        }
        previousIndex = index;
    }
}

void PlaybackSequence::Write(std::ostream & str)
{
    str.precision(20);

    int counter = 0;
    BOOST_FOREACH(const PlaybackEntry::Ptr & entry, _playbackEntries)
    {
        if(entry->_type == PlaybackEntryType::PenEvent)
        {
            str << counter << ", " << entry->_penEvent._timestamp <<  ", " << entry->_type << ", ";
            str << entry->_penEvent._type;
            str << std::endl;
        }
        else
        {
            BOOST_FOREACH(const core::Touch::cPtr & touch, entry->_touches)
            {
                core::InputSample snapshotSample = touch->CurrentSample();

                str << counter << ", " << snapshotSample.TimestampSeconds() <<  ", " << entry->_type << ", ";

                str << touch->Id() << ", ";
                str << touch->Phase() << ", ";
                str << snapshotSample.Location().x() << ", ";
                str << snapshotSample.Location().y() << ", ";

                if(snapshotSample.TouchRadius())
                {
                    str << *(snapshotSample.TouchRadius());
                }
                else
                {
                    str << "0.0";
                }

                // optional...
                boost::unordered_map<std::string, boost::any>::const_iterator it = touch->DynamicProperties().find("prviewControllerGestureTouches");
                if (it != touch->DynamicProperties().end())
                {
                    str << ", " << boost::lexical_cast<std::string>(boost::any_cast<int>(it->second));
                }

                str << std::endl;

            }
        }
        ++counter;
    }
}
}
}
