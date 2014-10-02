//
//  Playback.h
//  FiftyThreeSdk
//
//  Copyright (c) 2014 FiftyThree, Inc. All rights reserved.
//

#pragma once

#include <tuple>

#include "Core/Any.h"
#include "Core/Enum.h"
#include "Core/Memory.h"
#include "Core/Touch/Touch.h"
#include "FiftyThreeSdk/Classification/CommonDeclarations.h"

namespace fiftythree
{
namespace sdk
{
DEFINE_ENUM(PlaybackEntryType,
            TouchesChanged,
            PenEvent);

struct PlaybackEntry
{
    ALIAS_PTR_TYPES(PlaybackEntry);

    PlaybackEntryType               _type;
    std::set<core::Touch::Ptr>   _touches;
    PenEvent                        _penEvent;

    PlaybackEntry(PlaybackEntryType type) : _type(type) {}

    PlaybackEntry(const std::set<core::Touch::Ptr> & touches) : _type(PlaybackEntryType::TouchesChanged)
    {
        for (const core::Touch::Ptr & touch :  touches)
        {
            core::Touch::Ptr copyOfTouch = core::Touch::New(touch->Id(), touch->Phase(), touch->CurrentSample());

            std::string k; fiftythree::core::any v;

            for (const auto & pair : touch->DynamicProperties())
            {
                std::tie(k,v) = pair;
                copyOfTouch->DynamicProperties()[k] = v;
            }

            _touches.insert(copyOfTouch);
        }

    }

    PlaybackEntry(PenEvent const & penEvent) : _penEvent(penEvent), _type(PlaybackEntryType::PenEvent) {}

    double MostRecentTimestamp() const
    {
        if (_type == PlaybackEntryType::PenEvent)
        {
            return _penEvent._timestamp;
        }
        else
        {
            double tMax = 0.0;

            for (const core::Touch::cPtr & touch :  _touches)
            {
                if (touch->CurrentSample().TimestampSeconds() > tMax)
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
