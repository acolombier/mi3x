
#include "qmllibrarytracklistcolumn.h"

#include <map>

#include "library/trackmodel.h"
#include "moc_qmllibrarytracklistcolumn.cpp"
#include "qml/qmllibrarytracklistcolumn.h"

namespace {
static const std::map<ColumnCache::Column, TrackModel::SortColumnId>
        kSortColumnMapping = {
                {ColumnCache::COLUMN_LIBRARYTABLE_INVALID,
                        TrackModel::SortColumnId::Invalid},
                {ColumnCache::COLUMN_LIBRARYTABLE_ID,
                        TrackModel::SortColumnId::CurrentIndex},
                {ColumnCache::COLUMN_LIBRARYTABLE_ARTIST,
                        TrackModel::SortColumnId::Artist},
                {ColumnCache::COLUMN_LIBRARYTABLE_TITLE,
                        TrackModel::SortColumnId::Title},
                {ColumnCache::COLUMN_LIBRARYTABLE_ALBUM,
                        TrackModel::SortColumnId::Album},
                {ColumnCache::COLUMN_LIBRARYTABLE_ALBUMARTIST,
                        TrackModel::SortColumnId::AlbumArtist},
                {ColumnCache::COLUMN_LIBRARYTABLE_YEAR,
                        TrackModel::SortColumnId::Year},
                {ColumnCache::COLUMN_LIBRARYTABLE_GENRE,
                        TrackModel::SortColumnId::Genre},
                {ColumnCache::COLUMN_LIBRARYTABLE_COMPOSER,
                        TrackModel::SortColumnId::Composer},
                {ColumnCache::COLUMN_LIBRARYTABLE_GROUPING,
                        TrackModel::SortColumnId::Grouping},
                {ColumnCache::COLUMN_LIBRARYTABLE_TRACKNUMBER,
                        TrackModel::SortColumnId::TrackNumber},
                {ColumnCache::COLUMN_LIBRARYTABLE_FILETYPE,
                        TrackModel::SortColumnId::FileType},
                {ColumnCache::COLUMN_TRACKLOCATIONSTABLE_LOCATION,
                        TrackModel::SortColumnId::NativeLocation},
                {ColumnCache::COLUMN_LIBRARYTABLE_COMMENT,
                        TrackModel::SortColumnId::Comment},
                {ColumnCache::COLUMN_LIBRARYTABLE_DURATION,
                        TrackModel::SortColumnId::Duration},
                {ColumnCache::COLUMN_LIBRARYTABLE_BITRATE,
                        TrackModel::SortColumnId::BitRate},
                {ColumnCache::COLUMN_LIBRARYTABLE_BPM,
                        TrackModel::SortColumnId::Bpm},
                {ColumnCache::COLUMN_LIBRARYTABLE_REPLAYGAIN,
                        TrackModel::SortColumnId::ReplayGain},
                {ColumnCache::COLUMN_LIBRARYTABLE_DATETIMEADDED,
                        TrackModel::SortColumnId::DateTimeAdded},
                {ColumnCache::COLUMN_LIBRARYTABLE_TIMESPLAYED,
                        TrackModel::SortColumnId::TimesPlayed},
                {ColumnCache::COLUMN_LIBRARYTABLE_RATING,
                        TrackModel::SortColumnId::Rating},
                {ColumnCache::COLUMN_LIBRARYTABLE_KEY,
                        TrackModel::SortColumnId::Key},
                {ColumnCache::COLUMN_LIBRARYTABLE_PREVIEW,
                        TrackModel::SortColumnId::Preview},
                {ColumnCache::COLUMN_LIBRARYTABLE_COVERART,
                        TrackModel::SortColumnId::CoverArt},
                {ColumnCache::COLUMN_PLAYLISTTRACKSTABLE_POSITION,
                        TrackModel::SortColumnId::Position},
                {ColumnCache::COLUMN_PLAYLISTTRACKSTABLE_PLAYLISTID,
                        TrackModel::SortColumnId::PlaylistId},
                // Not sure about those 2
                {ColumnCache::COLUMN_TRACKLOCATIONSTABLE_LOCATION,
                        TrackModel::SortColumnId::Location},
                {ColumnCache::COLUMN_TRACKLOCATIONSTABLE_LOCATION,
                        TrackModel::SortColumnId::Filename},
                // MISSING!
                // {ColumnCache::COLUMN_FILE_MODIFIED_TIME,
                // TrackModel::SortColumnId::FileModifiedTime},
                // {ColumnCache::COLUMN_FILE_CREATION_TIME,
                // TrackModel::SortColumnId::FileCreationTime},
                {ColumnCache::COLUMN_LIBRARYTABLE_SAMPLERATE,
                        TrackModel::SortColumnId::SampleRate},
                {ColumnCache::COLUMN_LIBRARYTABLE_COLOR,
                        TrackModel::SortColumnId::Color},
                {ColumnCache::COLUMN_LIBRARYTABLE_LAST_PLAYED_AT,
                        TrackModel::SortColumnId::LastPlayedAt},
                {ColumnCache::COLUMN_PLAYLISTTRACKSTABLE_DATETIMEADDED,
                        TrackModel::SortColumnId::PlaylistDateTimeAdded},
                {ColumnCache::COLUMN_LIBRARYTABLE_TUNING_FREQUENCY,
                        TrackModel::SortColumnId::TuningFrequency},
};
} // namespace

namespace mixxx {
namespace qml {

QmlLibraryTrackListColumn::QmlLibraryTrackListColumn(QObject* parent,
        const QString& label,
        int fillSpan,
        int columnIdx,
        double preferredWidth,
        double autoHideWidth,
        Role role,
        ColumnType columnType,
        Display display)
        : QObject(parent),
          m_label(label),
          m_role(role),
          m_columnType(columnType),
          m_fillSpan(fillSpan),
          m_columnIdx(columnIdx),
          m_display(display),
          m_preferredWidth(preferredWidth),
          m_autoHideWidth(autoHideWidth) {
}

int QmlLibraryTrackListColumn::getSortColumn() const {
    auto columnIdx = static_cast<ColumnCache::Column>(m_columnIdx);
    if (!kSortColumnMapping.contains(columnIdx)) {
        return -1;
    }
    return static_cast<int>(kSortColumnMapping.at(columnIdx));
}

} // namespace qml
} // namespace mixxx
