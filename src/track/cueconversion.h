#pragma once

#include <QString>
#include <optional>

#include "audio/frame.h"
#include "preferences/usersettings.h"
#include "track/cueinfo.h"
#include "track/track_decl.h"

class Cue;
class CuePointer;

namespace mixxx {

namespace cueconversion {

constexpr audio::FrameDiff_t kMinimumAudibleLoopSizeFrames = 150;

/// Convert the type of an existing hotcue between hotcue, saved loop and
/// saved jump, keeping the stored positions where sensible. Based on the
/// current beatloop size, play position and quantize setting of the player
/// group. Mirrors the behavior of WCueMenuPopup and should be kept in
/// sync with it.
void convertCueType(
        TrackPointer pTrack,
        const CuePointer& pCue,
        const QString& playerGroup,
        UserSettingsPointer pConfig,
        CueType newType);

/// Updates the cue type and, if the cue currently has the "default" color of
/// its (old) type, also updates the color to the default color of the new
/// type. Port of WCueMenuPopup::updateTypeAndColorIfDefault.
void updateTypeAndColorIfDefault(
        UserSettingsPointer pConfig,
        Cue* pCue,
        CueType newType);

} // namespace cueconversion

} // namespace mixxx
