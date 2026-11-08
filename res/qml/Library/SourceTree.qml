import QtQuick
import Mixxx 1.0 as Mixxx
import "../Theme"

Mixxx.LibrarySourceTree {
    id: root

    property alias crate: crateSource
    property alias playlist: playlistSource

    defaultColumns: [
        Mixxx.TrackListColumn {
            autoHideWidth: 750
            columnType: Mixxx.TrackListColumn.ColumnType.AlbumArt
            preferredWidth: 100
        },
        Mixxx.TrackListColumn {
            autoHideWidth: 850
            columnType: Mixxx.TrackListColumn.ColumnType.Overview
            fillSpan: 3
            label: qsTr("Preview")
            preferredWidth: 200
        },
        Mixxx.TrackListColumn {
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Title
            fillSpan: 3
            label: qsTr("Title")
        },
        Mixxx.TrackListColumn {
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Artist
            fillSpan: 2
            label: qsTr("Artist")
        },
        Mixxx.TrackListColumn {
            autoHideWidth: 690
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Album
            fillSpan: 1
            label: qsTr("Album")
        },
        Mixxx.TrackListColumn {
            autoHideWidth: 750
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Year
            label: qsTr("Year")
            preferredWidth: 80
        },
        Mixxx.TrackListColumn {
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Bpm
            label: qsTr("BPM")
            preferredWidth: 60
        },
        Mixxx.TrackListColumn {
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Key
            label: qsTr("Key")
            preferredWidth: 70
        },
        Mixxx.TrackListColumn {
            autoHideWidth: 900
            columnIdx: Mixxx.TrackListColumn.SQLColumns.FileType
            label: qsTr("File Type")
            preferredWidth: 70
        },
        Mixxx.TrackListColumn {
            autoHideWidth: 1200
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Bitrate
            label: qsTr("Bitrate")
            preferredWidth: 70
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.AlbumArtist // ColumnCache::COLUMN_LIBRARYTABLE_ALBUMARTIST,
            label: qsTr("Album Artist")
            preferredWidth: 200
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Genre // ColumnCache::COLUMN_LIBRARYTABLE_GENRE,
            label: qsTr("Genre")
            preferredWidth: 200
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Composer // ColumnCache::COLUMN_LIBRARYTABLE_COMPOSER,
            label: qsTr("Composer")
            preferredWidth: 200
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Grouping // ColumnCache::COLUMN_LIBRARYTABLE_GROUPING,
            label: qsTr("Grouping")
            preferredWidth: 200
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.TrackNumber // ColumnCache::COLUMN_LIBRARYTABLE_TRACKNUMBER,
            label: qsTr("Track #")
            preferredWidth: 50
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Comment // ColumnCache::COLUMN_LIBRARYTABLE_COMMENT,
            label: qsTr("Comment")
            preferredWidth: 300
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Duration // ColumnCache::COLUMN_LIBRARYTABLE_DURATION,
            label: qsTr("Duration")
            preferredWidth: 50
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.ReplayGain // ColumnCache::COLUMN_LIBRARYTABLE_REPLAYGAIN,
            label: qsTr("ReplayGain")
            preferredWidth: 100
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.CuePoint // ColumnCache::COLUMN_LIBRARYTABLE_CUEPOINT,
            label: qsTr("CuePoint")
            preferredWidth: 0
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Url // ColumnCache::COLUMN_LIBRARYTABLE_URL,
            label: qsTr("Url")
            preferredWidth: 0
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.SampleRate // ColumnCache::COLUMN_LIBRARYTABLE_SAMPLERATE,
            label: qsTr("Samplerate")
            preferredWidth: 50
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Wavesummaryhex // ColumnCache::COLUMN_LIBRARYTABLE_WAVESUMMARYHEX,
            label: qsTr("Overview")
            preferredWidth: 400
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Channels // ColumnCache::COLUMN_LIBRARYTABLE_CHANNELS,
            label: qsTr("Channels")
            preferredWidth: 25
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.MixxxDeleted // ColumnCache::COLUMN_LIBRARYTABLE_MIXXXDELETED,
            label: qsTr("MixxxDeleted")
            preferredWidth: 0
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.DateTimeAdded // ColumnCache::COLUMN_LIBRARYTABLE_DATETIMEADDED,
            label: qsTr("Date Added")
            preferredWidth: 150
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.HeaderParsed // ColumnCache::COLUMN_LIBRARYTABLE_HEADERPARSED,
            label: qsTr("HeaderParsed")
            preferredWidth: 0
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.TimesPlayed // ColumnCache::COLUMN_LIBRARYTABLE_TIMESPLAYED,
            label: qsTr("Played")
            preferredWidth: 100
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Played // ColumnCache::COLUMN_LIBRARYTABLE_PLAYED,
            label: qsTr("Played")
            preferredWidth: 0
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Rating // ColumnCache::COLUMN_LIBRARYTABLE_RATING,
            label: qsTr("Rating")
            preferredWidth: 100
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.KeyId // ColumnCache::COLUMN_LIBRARYTABLE_KEY_ID,
            label: qsTr("KeyId")
            preferredWidth: 0
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.TuningFrequency // ColumnCache::COLUMN_LIBRARYTABLE_TUNING_FREQUENCY,
            label: qsTr("A4 Pitch (Hz)")
            preferredWidth: 50
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.BpmLock // ColumnCache::COLUMN_LIBRARYTABLE_BPM_LOCK,
            label: qsTr("BpmLock")
            preferredWidth: 0
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.BeatsVersion // ColumnCache::COLUMN_LIBRARYTABLE_BEATS_VERSION,
            label: qsTr("BeatsVersion")
            preferredWidth: 0
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Preview // ColumnCache::COLUMN_LIBRARYTABLE_PREVIEW,
            label: qsTr("Preview")
            preferredWidth: 25
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Color // ColumnCache::COLUMN_LIBRARYTABLE_COLOR,
            label: qsTr("Color")
            preferredWidth: 25
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Coverart // ColumnCache::COLUMN_LIBRARYTABLE_COVERART,
            label: qsTr("Cover Art")
            preferredWidth: 25
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.CoverartSource // ColumnCache::COLUMN_LIBRARYTABLE_COVERART_SOURCE,
            label: qsTr("CoverartSource")
            preferredWidth: 0
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.CoverartType // ColumnCache::COLUMN_LIBRARYTABLE_COVERART_TYPE,
            label: qsTr("CoverartType")
            preferredWidth: 0
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.CoverartLocation // ColumnCache::COLUMN_LIBRARYTABLE_COVERART_LOCATION,
            label: qsTr("CoverartLocation")
            preferredWidth: 0
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.CoverartColor // ColumnCache::COLUMN_LIBRARYTABLE_COVERART_COLOR,
            label: qsTr("CoverartColor")
            preferredWidth: 0
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.CoverartDigest // ColumnCache::COLUMN_LIBRARYTABLE_COVERART_DIGEST,
            label: qsTr("CoverartDigest")
            preferredWidth: 0
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.CoverartHash // ColumnCache::COLUMN_LIBRARYTABLE_COVERART_HASH,
            label: qsTr("CoverartHash")
            preferredWidth: 0
        },
        Mixxx.TrackListColumn {
            autoHideWidth: Number.MAX_VALUE
            columnIdx: Mixxx.TrackListColumn.SQLColumns.LastPlayedAt // ColumnCache::COLUMN_LIBRARYTABLE_LAST_PLAYED_AT,
            label: qsTr("Last Played")
            preferredWidth: 150
        }
    ]

    Mixxx.LibraryAllTrackSource {
        columns: root.defaultColumns
        label: qsTr("All...")
    }
    Mixxx.LibraryPlaylistSource {
        id: playlistSource

        readonly property list<Mixxx.TrackListColumn> specificColumns: [
            Mixxx.TrackListColumn {
                autoHideWidth: Number.MAX_VALUE
                columnIdx: Mixxx.TrackListColumn.SQLColumns.PlaylistTrackId
                label: qsTr("TrackId")
                preferredWidth: 70
            },
            Mixxx.TrackListColumn {
                autoHideWidth: 0
                columnIdx: Mixxx.TrackListColumn.SQLColumns.PlaylistPosition
                label: qsTr("#")
                preferredWidth: 30
            },
            Mixxx.TrackListColumn {
                autoHideWidth: Number.MAX_VALUE
                columnIdx: Mixxx.TrackListColumn.SQLColumns.PlaylistPlaylistId
                label: qsTr("PlaylistId")
                preferredWidth: 70
            },
            Mixxx.TrackListColumn {
                autoHideWidth: Number.MAX_VALUE
                columnIdx: Mixxx.TrackListColumn.SQLColumns.PlaylistDatetimeAdded
                label: qsTr("Timestamp")
                preferredWidth: 80
            }
        ]

        capabilities: Mixxx.LibraryAbstractSource.Capability.Create | Mixxx.LibraryAbstractSource.Capability.AddTrack
        columns: [...specificColumns, ...root.defaultColumns]
        icon: "../images/library_playlist.png"
        itemName: qsTr("playlist")
        label: qsTr("Playlists")
    }
    Mixxx.LibraryCrateSource {
        id: crateSource

        capabilities: Mixxx.LibraryAbstractSource.Capability.Create | Mixxx.LibraryAbstractSource.Capability.AddTrack
        columns: root.defaultColumns
        icon: "../images/library_crates.png"
        itemName: qsTr("crate")
        label: qsTr("Crates")
    }
    Mixxx.LibraryExplorerSource {
        readonly property list<Mixxx.TrackListColumn> specificColumns: []

        columns: [...specificColumns, ...root.defaultColumns]
        icon: "../images/library_explorer.png"
        itemName: qsTr("explorer")
        label: qsTr("Explorer")
    }
}
