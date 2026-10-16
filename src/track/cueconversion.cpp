#include "track/cueconversion.h"

#include <cmath>

#include "control/controlobject.h"
#include "preferences/colorpalettesettings.h"
#include "track/beats.h"
#include "track/cue.h"
#include "track/track.h"
#include "util/color/rgbcolor.h"
#include "util/math.h"

namespace mixxx {

namespace cueconversion {

namespace {

const ConfigKey kHotcueDefaultColorIndexConfigKey("[Controls]", "HotcueDefaultColorIndex");
const ConfigKey kLoopDefaultColorIndexConfigKey("[Controls]", "LoopDefaultColorIndex");
const ConfigKey kJumpDefaultColorIndexConfigKey("[Controls]", "jump_default_color_index");

std::optional<int> getDefaultColorIndex(
        UserSettingsPointer pConfig, CueType type) {
    switch (type) {
    case CueType::Loop:
        return pConfig->getValue(kLoopDefaultColorIndexConfigKey, -1);
    case CueType::Jump:
        return pConfig->getValue(kJumpDefaultColorIndexConfigKey, -1);
    default:
        return pConfig->getValue(kHotcueDefaultColorIndexConfigKey, -1);
    }
}

} // namespace

void updateTypeAndColorIfDefault(
        UserSettingsPointer pConfig, Cue* pCue, CueType newType) {
    const auto colorPalette =
            ColorPaletteSettings(pConfig).getHotcueColorPalette();

    const auto oldColorIndexOpt = getDefaultColorIndex(pConfig, pCue->getType());
    const int oldColorIndex =
            oldColorIndexOpt ? *oldColorIndexOpt : -1;
    const RgbColor oldDefaultColor =
            (oldColorIndex < 0 || oldColorIndex >= colorPalette.size())
            ? colorPalette.defaultColor()
            : colorPalette.at(oldColorIndex);

    pCue->setType(newType);

    if (pCue->getColor() != oldDefaultColor) {
        return;
    }

    const auto newColorIndexOpt = getDefaultColorIndex(pConfig, pCue->getType());
    const int newColorIndex = newColorIndexOpt ? *newColorIndexOpt : -1;
    if (newColorIndex < 0 || newColorIndex >= colorPalette.size()) {
        pCue->setColor(colorPalette.defaultColor());
    } else {
        pCue->setColor(colorPalette.at(newColorIndex));
    }
}

audio::FramePos getCurrentPlayPositionWithQuantize(
        TrackPointer pTrack, const QString& playerGroup) {
    const audio::FramePos position =
            audio::FramePos::fromEngineSamplePos(
                    ControlObject::get(ConfigKey(playerGroup, "playposition")) *
                    ControlObject::get(ConfigKey(playerGroup, "track_samples")));
    const bool quantize = ControlObject::get(ConfigKey(playerGroup, "quantize")) > 0.0;
    const auto pBeats = pTrack->getBeats();
    if (quantize && pBeats) {
        audio::FramePos nextBeatPosition, prevBeatPosition;
        pBeats->findPrevNextBeats(position, &prevBeatPosition, &nextBeatPosition, false);
        return (nextBeatPosition - position > position - prevBeatPosition)
                ? prevBeatPosition
                : nextBeatPosition;
    }
    return position;
}

void convertCueType(
        TrackPointer pTrack,
        const CuePointer& pCue,
        const QString& playerGroup,
        UserSettingsPointer pConfig,
        CueType newType) {
    VERIFY_OR_DEBUG_ASSERT(pTrack && pCue) {
        return;
    }

    switch (newType) {
    case CueType::HotCue: {
        if (pCue->getType() != CueType::HotCue) {
            cueconversion::updateTypeAndColorIfDefault(pConfig, pCue.get(), CueType::HotCue);
        }
        break;
    }
    case CueType::Loop: {
        auto cueStartEnd = pCue->getStartAndEndPosition();
        // If we are changing the cue type from a jump, we need to permute the positions
        if (pCue->getType() == CueType::Jump) {
            const auto endPosition = cueStartEnd.endPosition;
            if (cueStartEnd.endPosition < cueStartEnd.startPosition) {
                // Only swap value if this is a forward jump
                cueStartEnd.endPosition = cueStartEnd.startPosition;
                cueStartEnd.startPosition = endPosition;
            }
            pCue->setStartAndEndPosition(cueStartEnd.startPosition, cueStartEnd.endPosition);
        }
        if (!cueStartEnd.endPosition.isValid() ||
                cueStartEnd.endPosition <= cueStartEnd.startPosition) {
            const double beatloopSize =
                    ControlObject::get(ConfigKey(playerGroup, "beatloop_size"));
            const auto pBeats = pTrack->getBeats();
            if (beatloopSize <= 0 || !pBeats) {
                return;
            }
            const auto position = pBeats->findNBeatsFromPosition(
                    cueStartEnd.startPosition, beatloopSize);
            if (position <= pCue->getPosition()) {
                return;
            }
            pCue->setEndPosition(position);
        }
        cueconversion::updateTypeAndColorIfDefault(pConfig, pCue.get(), CueType::Loop);
        break;
    }
    case CueType::Jump: {
        auto cueStartEnd = pCue->getStartAndEndPosition();
        // If we are changing the cue type from a loop, we need to permute the position
        // Also, if the type is already a jump, we swap to the to/from point
        if (pCue->getType() == CueType::Loop || pCue->getType() == CueType::Jump) {
            const auto endPosition = cueStartEnd.endPosition;
            cueStartEnd.endPosition = cueStartEnd.startPosition;
            cueStartEnd.startPosition = endPosition;
        }
        if (!cueStartEnd.endPosition.isValid()) {
            const auto newPosition = getCurrentPlayPositionWithQuantize(pTrack, playerGroup);
            if (std::abs(newPosition - cueStartEnd.startPosition) <=
                    cueconversion::kMinimumAudibleLoopSizeFrames) {
                return;
            }
            cueStartEnd.endPosition = newPosition;
        }
        pCue->setStartAndEndPosition(cueStartEnd.startPosition, cueStartEnd.endPosition);
        cueconversion::updateTypeAndColorIfDefault(pConfig, pCue.get(), CueType::Jump);
        break;
    }
    default:
        DEBUG_ASSERT(!"Invalid cue type");
        break;
    }
}

} // namespace cueconversion

} // namespace mixxx
