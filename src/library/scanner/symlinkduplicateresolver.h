#pragma once

#include <QDateTime>
#include <QHash>
#include <QList>
#include <QSet>
#include <QSqlDatabase>
#include <QString>

#include "library/relocatedtrack.h"
#include "track/trackid.h"
#include "util/db/dbid.h"

class SymlinkDuplicateResolver final {
  public:
    struct Result {
        bool success = true;
        QSet<TrackId> hiddenTrackIds;
        QList<RelocatedTrack> relocatedTracks;
        QList<TrackId> removedTrackIds;
        int numHidden = 0;
        int numRelocated = 0;
    };

    explicit SymlinkDuplicateResolver(const QSqlDatabase& database);

    Result resolve(
            const QHash<QString, QString>& symlinkLocations,
            volatile const bool* pCancel = nullptr) const;

  private:
    struct TrackData {
        TrackId id;
        DbId locationId;
        QString location;
        bool hidden = false;
        double duration = 0.0;
    };

    struct UserDataInfo {
        bool hasUserData = false;
        QDateTime lastPlayedAt;
        QDateTime dateAdded;
    };

    TrackData findTrackByLocation(const QString& location) const;
    TrackData findTargetTrack(
            const QString& canonicalTargetLocation,
            const QSet<TrackId>& excludedTrackIds) const;

    UserDataInfo readUserDataInfo(TrackId trackId) const;

    bool hideTracks(const QList<TrackId>& trackIds) const;
    bool relocateTrackToTarget(
            const TrackData& winner,
            const TrackData& target) const;
    bool createHiddenTombstone(
            const TrackData& sourceTrack,
            const DbId& locationId) const;
    bool deleteTrack(TrackId trackId) const;

    const QSqlDatabase m_database;
};
