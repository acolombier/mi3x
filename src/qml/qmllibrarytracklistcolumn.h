#pragma once

#include <QAbstractItemModel>
#include <QObject>
#include <QQmlEngine>
#include <QQmlListProperty>
#include <QQmlParserStatus>
#include <QQuickItem>
#include <QVariant>

#include "library/columncache.h"
#include "qml/qml_owned_ptr.h"

namespace mixxx {
namespace qml {

class QmlLibraryTrackListColumn : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString label MEMBER m_label NOTIFY labelChanged)
    Q_PROPERTY(int fillSpan MEMBER m_fillSpan FINAL)
    Q_PROPERTY(int columnIdx MEMBER m_columnIdx NOTIFY columnIdxChanged)
    Q_PROPERTY(int sortColumn READ getSortColumn NOTIFY columnIdxChanged)
    Q_PROPERTY(double preferredWidth MEMBER m_preferredWidth FINAL)
    Q_PROPERTY(double autoHideWidth MEMBER m_autoHideWidth NOTIFY autoHideWidthChanged)
    Q_PROPERTY(Display display MEMBER m_display NOTIFY displayChanged)
    Q_PROPERTY(Role role MEMBER m_role FINAL)
    Q_PROPERTY(ColumnType columnType MEMBER m_columnType FINAL)
    QML_NAMED_ELEMENT(TrackListColumn)
  public:
    enum class SQLColumns {
        Album = ColumnCache::COLUMN_LIBRARYTABLE_ALBUM,
        Artist = ColumnCache::COLUMN_LIBRARYTABLE_ARTIST,
        Title = ColumnCache::COLUMN_LIBRARYTABLE_TITLE,
        Year = ColumnCache::COLUMN_LIBRARYTABLE_YEAR,
        Bpm = ColumnCache::COLUMN_LIBRARYTABLE_BPM,
        Key = ColumnCache::COLUMN_LIBRARYTABLE_KEY,
        FileType = ColumnCache::COLUMN_LIBRARYTABLE_FILETYPE,
        Bitrate = ColumnCache::COLUMN_LIBRARYTABLE_BITRATE,
        Invalid = ColumnCache::COLUMN_LIBRARYTABLE_INVALID,
        Id = ColumnCache::COLUMN_LIBRARYTABLE_ID,
        AlbumArtist = ColumnCache::COLUMN_LIBRARYTABLE_ALBUMARTIST,
        Genre = ColumnCache::COLUMN_LIBRARYTABLE_GENRE,
        Composer = ColumnCache::COLUMN_LIBRARYTABLE_COMPOSER,
        Grouping = ColumnCache::COLUMN_LIBRARYTABLE_GROUPING,
        TrackNumber = ColumnCache::COLUMN_LIBRARYTABLE_TRACKNUMBER,
        Comment = ColumnCache::COLUMN_LIBRARYTABLE_COMMENT,
        Duration = ColumnCache::COLUMN_LIBRARYTABLE_DURATION,
        ReplayGain = ColumnCache::COLUMN_LIBRARYTABLE_REPLAYGAIN,
        CuePoint = ColumnCache::COLUMN_LIBRARYTABLE_CUEPOINT,
        Url = ColumnCache::COLUMN_LIBRARYTABLE_URL,
        SampleRate = ColumnCache::COLUMN_LIBRARYTABLE_SAMPLERATE,
        Wavesummaryhex = ColumnCache::COLUMN_LIBRARYTABLE_WAVESUMMARYHEX,
        Channels = ColumnCache::COLUMN_LIBRARYTABLE_CHANNELS,
        MixxxDeleted = ColumnCache::COLUMN_LIBRARYTABLE_MIXXXDELETED,
        DateTimeAdded = ColumnCache::COLUMN_LIBRARYTABLE_DATETIMEADDED,
        HeaderParsed = ColumnCache::COLUMN_LIBRARYTABLE_HEADERPARSED,
        TimesPlayed = ColumnCache::COLUMN_LIBRARYTABLE_TIMESPLAYED,
        Played = ColumnCache::COLUMN_LIBRARYTABLE_PLAYED,
        Rating = ColumnCache::COLUMN_LIBRARYTABLE_RATING,
        KeyId = ColumnCache::COLUMN_LIBRARYTABLE_KEY_ID,
        TuningFrequency = ColumnCache::COLUMN_LIBRARYTABLE_TUNING_FREQUENCY,
        BpmLock = ColumnCache::COLUMN_LIBRARYTABLE_BPM_LOCK,
        BeatsVersion = ColumnCache::COLUMN_LIBRARYTABLE_BEATS_VERSION,
        Preview = ColumnCache::COLUMN_LIBRARYTABLE_PREVIEW,
        Color = ColumnCache::COLUMN_LIBRARYTABLE_COLOR,
        Coverart = ColumnCache::COLUMN_LIBRARYTABLE_COVERART,
        CoverartSource = ColumnCache::COLUMN_LIBRARYTABLE_COVERART_SOURCE,
        CoverartType = ColumnCache::COLUMN_LIBRARYTABLE_COVERART_TYPE,
        CoverartLocation = ColumnCache::COLUMN_LIBRARYTABLE_COVERART_LOCATION,
        CoverartColor = ColumnCache::COLUMN_LIBRARYTABLE_COVERART_COLOR,
        CoverartDigest = ColumnCache::COLUMN_LIBRARYTABLE_COVERART_DIGEST,
        CoverartHash = ColumnCache::COLUMN_LIBRARYTABLE_COVERART_HASH,
        LastPlayedAt = ColumnCache::COLUMN_LIBRARYTABLE_LAST_PLAYED_AT,
        TrackLocation = ColumnCache::COLUMN_TRACKLOCATIONSTABLE_LOCATION,
        TrackDirectory = ColumnCache::COLUMN_TRACKLOCATIONSTABLE_DIRECTORY,
        TrackFSDeleted = ColumnCache::COLUMN_TRACKLOCATIONSTABLE_FSDELETED,
        PlaylistTrackId = ColumnCache::COLUMN_PLAYLISTTRACKSTABLE_TRACKID,
        PlaylistPosition = ColumnCache::COLUMN_PLAYLISTTRACKSTABLE_POSITION,
        PlaylistPlaylistId = ColumnCache::COLUMN_PLAYLISTTRACKSTABLE_PLAYLISTID,
        PlaylistDatetimeAdded = ColumnCache::COLUMN_PLAYLISTTRACKSTABLE_DATETIMEADDED,
        RekordboxAnalyzePath = ColumnCache::COLUMN_REKORDBOX_ANALYZE_PATH,
        NumColumns = ColumnCache::NUM_COLUMNS,
    };
    Q_ENUM(SQLColumns)
    enum class Display {
        Auto,
        Show,
        Hide
    };
    Q_ENUM(Display)
    enum class Role {
        Location,
        Artist,
        Title,
        Cover,
    };
    Q_ENUM(Role)
    enum class ColumnType {
        Default,
        Overview,
        AlbumArt,
    };
    Q_ENUM(ColumnType)
    explicit QmlLibraryTrackListColumn(QObject* parent = nullptr)
            : QObject(parent) {
    }
    explicit QmlLibraryTrackListColumn(QObject* parent,
            const QString& label,
            int fillSpan,
            int columnIdx,
            double preferredWidth,
            double autoHideWidth,
            Role role,
            ColumnType columnType = ColumnType::Default,
            Display display = Display::Auto);
    const QString& label() const {
        return m_label;
    }
    Role role() const {
        return m_role;
    }
    ColumnType columnType() const {
        return m_columnType;
    }
    Display display() const {
        return m_display;
    }
    int fillSpan() const {
        return m_fillSpan;
    }
    int columnIdx() const {
        return m_columnIdx;
    }
    double preferredWidth() const {
        return m_preferredWidth;
    }
    double autoHideWidth() const {
        return m_autoHideWidth;
    }

    int getSortColumn() const;

  private:
    QString m_label;
    Role m_role{};
    ColumnType m_columnType{ColumnType::Default};
    int m_fillSpan{0};
    int m_columnIdx{-1};
    Display m_display{Display::Auto};
    double m_preferredWidth{-1};
    double m_autoHideWidth{-1};

  signals:
    void displayChanged();
    void labelChanged();
    void autoHideWidthChanged();
    void columnIdxChanged();
};
} // namespace qml
} // namespace mixxx
