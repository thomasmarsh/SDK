//
//  Playback.h
//  Classification
//
//  Copyright (c) 2013 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <boost/foreach.hpp>
#include <boost/smart_ptr.hpp>
#include "Common/Enum.h"
#include "Common/Touch/Touch.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"

namespace fiftythree
{
namespace classification
{

DEFINE_ENUM(PlaybackEntryType,
            TouchesChanged,
            PenEvent
            );

struct PlaybackEntry
{
    typedef fiftythree::common::shared_ptr<PlaybackEntry> Ptr;

    PlaybackEntryType               _type;
    std::set<common::Touch::Ptr>   _touches;
    PenEvent                        _penEvent;

    PlaybackEntry(PlaybackEntryType type) : _type(type) {}

    PlaybackEntry(const std::set<common::Touch::Ptr> & touches) : _type(PlaybackEntryType::TouchesChanged)
    {

        BOOST_FOREACH(const common::Touch::Ptr & touch, touches)
        {
            common::Touch::Ptr copyOfTouch = common::Touch::New(touch->Id(), touch->Phase(), touch->CurrentSample());

            std::string k; boost::any v;

            BOOST_FOREACH(tie(k,v), touch->DynamicProperties())
            {
                copyOfTouch->DynamicProperties()[k] = v;
            }

            _touches.insert(copyOfTouch);
        }

    }

    PlaybackEntry(PenEvent const & penEvent) : _penEvent(penEvent), _type(PlaybackEntryType::PenEvent) {}

    double MostRecentTimestamp() const
    {
        if(_type == PlaybackEntryType::PenEvent)
        {
            return _penEvent._timestamp;
        }
        else
        {
            double tMax = 0.0;

            BOOST_FOREACH(const common::Touch::cPtr & touch, _touches)
            {
                if(touch->CurrentSample().TimestampSeconds() > tMax)
                {
                    tMax = touch->CurrentSample().TimestampSeconds();
                }
            }

            return tMax;
        }
    }
};

class PlaybackSequence
{
    std::vector<PlaybackEntry::Ptr> _playbackEntries;

public:

    inline  PlaybackSequence() {}
    inline ~PlaybackSequence() {}

    PlaybackSequence(std::istream & str);

    void Write(std::ostream & str);

    inline void AddEntry(PlaybackEntry::Ptr const & playbackEntry)
    {
        _playbackEntries.push_back(playbackEntry);
    }

    inline  std::vector<PlaybackEntry::Ptr> const & Entries()
    {
        return _playbackEntries;
    }

    inline  void Clear()
    {
        _playbackEntries.clear();
    }

    inline  void swap(PlaybackSequence & other)
    {
        _playbackEntries.swap(other._playbackEntries);
    }
};
inline void swap(PlaybackSequence & lhs, PlaybackSequence & rhs)
{
    lhs.swap(rhs);
}
}
}
