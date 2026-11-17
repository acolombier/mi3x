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
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Album
            columnType: Mixxx.TrackListColumn.ColumnType.AlbumArt
            preferredWidth: 100
        },
        Mixxx.TrackListColumn {
            autoHideWidth: 850
            columnIdx: Mixxx.TrackListColumn.SQLColumns.Title
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
        }
    ]

    Mixxx.LibraryAllTrackSource {
        columns: root.defaultColumns
        label: qsTr("All...")
    }
    Mixxx.LibraryPlaylistSource {
        id: playlistSource

        capabilities: Mixxx.LibraryAbstractSource.Capability.Create | Mixxx.LibraryAbstractSource.Capability.AddTrack
        columns: root.defaultColumns
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
        icon: "../images/library_explorer.png"
        itemName: qsTr("explorer")
        label: qsTr("Explorer")

        columns: [
            Mixxx.TrackListColumn {
                autoHideWidth: 850
                columnType: Mixxx.TrackListColumn.ColumnType.Overview
                fillSpan: 3
                label: qsTr("Preview")
                preferredWidth: 200
            },
            Mixxx.TrackListColumn {
                fillSpan: 4
                label: qsTr("Filename")
            },
            Mixxx.TrackListColumn {
                fillSpan: 2
                label: qsTr("Artist")
                role: Mixxx.TrackListColumn.Role.Artist
            },
            Mixxx.TrackListColumn {
                fillSpan: 2
                label: qsTr("Title")
                role: Mixxx.TrackListColumn.Role.Title
            },
            Mixxx.TrackListColumn {
                fillSpan: 1
                label: qsTr("Album")
            },
            Mixxx.TrackListColumn {
                display: Mixxx.TrackListColumn.Display.Hide
                label: qsTr("Track #")
                preferredWidth: 60
            },
            Mixxx.TrackListColumn {
                autoHideWidth: 750
                label: qsTr("Year")
                preferredWidth: 80
            },
            Mixxx.TrackListColumn {
                autoHideWidth: 750
                label: qsTr("Genre")
                preferredWidth: 80
            },
            Mixxx.TrackListColumn {
                display: Mixxx.TrackListColumn.Display.Hide
                label: qsTr("Composer")
            },
            Mixxx.TrackListColumn {
                display: Mixxx.TrackListColumn.Display.Hide
                label: qsTr("Comment")
            },
            Mixxx.TrackListColumn {
                label: qsTr("Duration")
            },
            Mixxx.TrackListColumn {
                label: qsTr("BPM")
                preferredWidth: 60
            },
            Mixxx.TrackListColumn {
                label: qsTr("Key")
                preferredWidth: 70
            },
            Mixxx.TrackListColumn {
                autoHideWidth: 900
                label: qsTr("File Type")
                preferredWidth: 70
            },
            Mixxx.TrackListColumn {
                autoHideWidth: 1200
                label: qsTr("Bitrate")
                preferredWidth: 70
            },
            Mixxx.TrackListColumn {
                display: Mixxx.TrackListColumn.Display.Hide
                label: qsTr("Location")
                role: Mixxx.TrackListColumn.Role.Location
            },
            Mixxx.TrackListColumn {
                display: Mixxx.TrackListColumn.Display.Hide
                label: qsTr("Album Artist")
            },
            Mixxx.TrackListColumn {
                display: Mixxx.TrackListColumn.Display.Hide
                label: qsTr("Grouping")
            },
            Mixxx.TrackListColumn {
                display: Mixxx.TrackListColumn.Display.Hide
                label: qsTr("File Modified")
            },
            Mixxx.TrackListColumn {
                display: Mixxx.TrackListColumn.Display.Hide
                label: qsTr("File Created")
            },
            Mixxx.TrackListColumn {
                display: Mixxx.TrackListColumn.Display.Hide
                label: qsTr("ReplayGain")
            }
        ]
    }
}
