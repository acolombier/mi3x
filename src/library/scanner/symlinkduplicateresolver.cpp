#include "library/scanner/symlinkduplicateresolver.h"

#include <QFileInfo>
#include <QSqlQuery>
#include <QStringList>
#include <QVariant>
#include <cmath>
#include <utility>

#include "library/coverart.h"
#include "library/dao/trackschema.h"
#include "library/queryutil.h"
#include "track/globaltrackcache.h"
#include "util/logger.h"

namespace {

const mixxx::Logger kLogger("SymlinkDuplicateResolver");

constexpr double kMaxDurationDifferenceSeconds = 1.0;

bool hasDurationMismatch(double lhsDuration, double rhsDuration) {
    if (lhsDuration <= 0.0 || rhsDuration <= 0.0) {
        return false;
    }
    return std::abs(lhsDuration - rhsDuration) >= kMaxDurationDifferenceSeconds;
}

} // namespace

SymlinkDuplicateResolver::SymlinkDuplicateResolver(
        const QSqlDatabase& database)
        : m_database(database) {
}

SymlinkDuplicateResolver::TrackData SymlinkDuplicateResolver::findTrackByLocation(
        const QString& location) const {
    TrackData track;
    if (location.isEmpty()) {
        return track;
    }

    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
            "SELECT library.id, track_locations.id, track_locations.location, "
            "library.mixxx_deleted, library.duration "
            "FROM library "
            "INNER JOIN track_locations ON library.location=track_locations.id "
            "WHERE track_locations.location=:location "
            "LIMIT 1"));
    query.bindValue(QStringLiteral(":location"), location);
    if (!query.exec()) {
        LOG_FAILED_QUERY(query) << "Failed to find track by location" << location;
        return track;
    }
    if (query.next()) {
        track.id = TrackId(query.value(0));
        track.locationId = DbId(query.value(1));
        track.location = query.value(2).toString();
        track.hidden = query.value(3).toInt() != 0;
        track.duration = query.value(4).toDouble();
    }
    return track;
}

SymlinkDuplicateResolver::TrackData SymlinkDuplicateResolver::findTargetTrack(
        const QString& canonicalTargetLocation,
        const QSet<TrackId>& excludedTrackIds) const {
    TrackData target = findTrackByLocation(canonicalTargetLocation);
    if (target.id.isValid() && !target.hidden &&
            !excludedTrackIds.contains(target.id)) {
        return target;
    }

    const QString targetFileName = QFileInfo(canonicalTargetLocation).fileName();
    if (targetFileName.isEmpty()) {
        return {};
    }

    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
            "SELECT library.id, track_locations.id, track_locations.location, "
            "library.mixxx_deleted, library.duration "
            "FROM library "
            "INNER JOIN track_locations ON library.location=track_locations.id "
            "WHERE track_locations.filename=:filename"));
    query.bindValue(QStringLiteral(":filename"), targetFileName);
    if (!query.exec()) {
        LOG_FAILED_QUERY(query) << "Failed to find target track candidates";
        return {};
    }

    while (query.next()) {
        const auto trackId = TrackId(query.value(0));
        if (excludedTrackIds.contains(trackId) || query.value(3).toInt() != 0) {
            continue;
        }
        const QString location = query.value(2).toString();
        if (QFileInfo(location).canonicalFilePath() != canonicalTargetLocation) {
            continue;
        }
        TrackData candidate;
        candidate.id = trackId;
        candidate.locationId = DbId(query.value(1));
        candidate.location = location;
        candidate.hidden = query.value(3).toInt() != 0;
        candidate.duration = query.value(4).toDouble();
        return candidate;
    }
    return {};
}

SymlinkDuplicateResolver::UserDataInfo SymlinkDuplicateResolver::readUserDataInfo(
        TrackId trackId) const {
    UserDataInfo info;
    if (!trackId.isValid()) {
        return info;
    }

    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
            "SELECT datetime_added, last_played_at, rating, comment, color, "
            "timesplayed, played, bpm, bpm_lock, key, key_id, "
            "tuning_frequency_hz, beats_version, length(beats), length(keys), "
            "coverart_source "
            "FROM library WHERE id=:id"));
    query.bindValue(QStringLiteral(":id"), trackId.toVariant());
    if (!query.exec() || !query.next()) {
        LOG_FAILED_QUERY(query) << "Failed to read user data for track" << trackId;
        return info;
    }

    const auto parseTimestamp = [](const QVariant& value) {
        const QString timestamp = value.toString();
        auto dateTime = QDateTime::fromString(timestamp, Qt::ISODate);
        if (!dateTime.isValid()) {
            dateTime = QDateTime::fromString(
                    timestamp, QStringLiteral("yyyy-MM-dd HH:mm:ss"));
        }
        if (!dateTime.isValid()) {
            dateTime = value.toDateTime();
        }
        return dateTime;
    };

    info.dateAdded = parseTimestamp(query.value(0));
    info.lastPlayedAt = parseTimestamp(query.value(1));

    const int rating = query.value(2).toInt();
    const QString comment = query.value(3).toString();
    const QVariant color = query.value(4);
    const int timesPlayed = query.value(5).toInt();
    const int played = query.value(6).toInt();
    const double bpm = query.value(7).toDouble();
    const int bpmLock = query.value(8).toInt();
    const QString key = query.value(9).toString();
    const int keyId = query.value(10).toInt();
    const double tuningFrequency = query.value(11).toDouble();
    const QString beatsVersion = query.value(12).toString();
    const int beatsLength = query.value(13).toInt();
    const int keysLength = query.value(14).toInt();
    const int coverArtSource = query.value(15).toInt();

    info.hasUserData =
            rating > 0 ||
            !comment.trimmed().isEmpty() ||
            !color.isNull() ||
            timesPlayed > 0 ||
            played != 0 ||
            info.lastPlayedAt.isValid() ||
            bpm > 0.0 ||
            bpmLock != 0 ||
            !key.isEmpty() ||
            keyId != 0 ||
            tuningFrequency > 0.0 ||
            !beatsVersion.isEmpty() ||
            beatsLength > 0 ||
            keysLength > 0 ||
            coverArtSource == CoverInfo::USER_SELECTED;

    if (info.hasUserData) {
        return info;
    }

    const std::pair<QString, QString> dependentTables[] = {
            {QStringLiteral("cues"), QStringLiteral("track_id")},
            {QStringLiteral("PlaylistTracks"), QStringLiteral("track_id")},
            {QStringLiteral("crate_tracks"), QStringLiteral("track_id")},
    };
    for (const auto& [table, column] : dependentTables) {
        QSqlQuery dependentQuery(m_database);
        dependentQuery.prepare(QStringLiteral(
                "SELECT 1 FROM %1 WHERE %2=:id LIMIT 1")
                        .arg(table, column));
        dependentQuery.bindValue(QStringLiteral(":id"), trackId.toVariant());
        if (!dependentQuery.exec()) {
            LOG_FAILED_QUERY(dependentQuery)
                    << "Failed to check user data in" << table
                    << "for track" << trackId;
            continue;
        }
        if (dependentQuery.next()) {
            info.hasUserData = true;
            break;
        }
    }

    return info;
}

bool SymlinkDuplicateResolver::hideTracks(const QList<TrackId>& trackIds) const {
    if (trackIds.isEmpty()) {
        return true;
    }

    QStringList idList;
    idList.reserve(trackIds.size());
    for (const auto& trackId : trackIds) {
        idList.append(trackId.toString());
    }

    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
            "UPDATE library SET mixxx_deleted=1 WHERE id IN (%1)")
                    .arg(idList.join(',')));
    if (!query.exec()) {
        LOG_FAILED_QUERY(query) << "Failed to hide tracks";
        return false;
    }
    return true;
}

bool SymlinkDuplicateResolver::createHiddenTombstone(
        const TrackData& sourceTrack,
        const DbId& locationId) const {
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
            "INSERT INTO library "
            "(location, mixxx_deleted, artist, title, album, album_artist, "
            "filetype, duration) "
            "SELECT :locationId, 1, artist, title, album, album_artist, "
            "filetype, duration "
            "FROM library WHERE id=:sourceId"));
    query.bindValue(QStringLiteral(":locationId"), locationId.toVariant());
    query.bindValue(QStringLiteral(":sourceId"), sourceTrack.id.toVariant());
    if (!query.exec()) {
        LOG_FAILED_QUERY(query)
                << "Failed to create hidden tombstone for"
                << sourceTrack.location;
        return false;
    }
    return true;
}

bool SymlinkDuplicateResolver::deleteTrack(TrackId trackId) const {
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("DELETE FROM library WHERE id=:id"));
    query.bindValue(QStringLiteral(":id"), trackId.toVariant());
    if (!query.exec()) {
        LOG_FAILED_QUERY(query) << "Failed to delete duplicate track" << trackId;
        return false;
    }
    return true;
}

bool SymlinkDuplicateResolver::relocateTrackToTarget(
        const TrackData& winner,
        const TrackData& target) const {
    QSqlQuery targetQuery(m_database);
    targetQuery.prepare(QStringLiteral(
            "SELECT filetype, duration, bitrate, samplerate, channels, "
            "header_parsed, source_synchronized_ms "
            "FROM library WHERE id=:id"));
    targetQuery.bindValue(QStringLiteral(":id"), target.id.toVariant());
    if (!targetQuery.exec() || !targetQuery.next()) {
        LOG_FAILED_QUERY(targetQuery)
                << "Failed to read file properties of target track" << target.id;
        return false;
    }

    const QVariant filetype = targetQuery.value(0);
    const QVariant duration = targetQuery.value(1);
    const QVariant bitrate = targetQuery.value(2);
    const QVariant samplerate = targetQuery.value(3);
    const QVariant channels = targetQuery.value(4);
    const QVariant headerParsed = targetQuery.value(5);
    const QVariant sourceSynchronizedMs = targetQuery.value(6);

    if (!createHiddenTombstone(winner, winner.locationId)) {
        return false;
    }
    if (!deleteTrack(target.id)) {
        return false;
    }

    QSqlQuery updateQuery(m_database);
    updateQuery.prepare(QStringLiteral(
            "UPDATE library SET "
            "location=:location, filetype=:filetype, duration=:duration, "
            "bitrate=:bitrate, samplerate=:samplerate, channels=:channels, "
            "header_parsed=:header_parsed, "
            "source_synchronized_ms=:source_synchronized_ms "
            "WHERE id=:id"));
    updateQuery.bindValue(QStringLiteral(":location"), target.locationId.toVariant());
    updateQuery.bindValue(QStringLiteral(":filetype"), filetype);
    updateQuery.bindValue(QStringLiteral(":duration"), duration);
    updateQuery.bindValue(QStringLiteral(":bitrate"), bitrate);
    updateQuery.bindValue(QStringLiteral(":samplerate"), samplerate);
    updateQuery.bindValue(QStringLiteral(":channels"), channels);
    updateQuery.bindValue(QStringLiteral(":header_parsed"), headerParsed);
    updateQuery.bindValue(
            QStringLiteral(":source_synchronized_ms"), sourceSynchronizedMs);
    updateQuery.bindValue(QStringLiteral(":id"), winner.id.toVariant());
    if (!updateQuery.exec()) {
        LOG_FAILED_QUERY(updateQuery)
                << "Failed to relocate track" << winner.id
                << "to" << target.location;
        return false;
    }
    return true;
}

SymlinkDuplicateResolver::Result SymlinkDuplicateResolver::resolve(
        const QHash<QString, QString>& symlinkLocations,
        volatile const bool* pCancel) const {
    Result result;
    if (symlinkLocations.isEmpty()) {
        return result;
    }

    QHash<QString, QStringList> aliasesByTarget;
    for (auto it = symlinkLocations.constBegin();
            it != symlinkLocations.constEnd();
            ++it) {
        if (pCancel && *pCancel) {
            return result;
        }
        const QString& symlinkLocation = it.key();
        const QString& canonicalTargetLocation = it.value();
        if (canonicalTargetLocation.isEmpty() ||
                canonicalTargetLocation == symlinkLocation) {
            continue;
        }
        aliasesByTarget[canonicalTargetLocation].append(symlinkLocation);
    }

    const QSet<TrackId> cachedTrackIds =
            GlobalTrackCacheLocker().getCachedTrackIds();

    for (auto groupIt = aliasesByTarget.constBegin();
            groupIt != aliasesByTarget.constEnd();
            ++groupIt) {
        if (pCancel && *pCancel) {
            return result;
        }

        const QString& canonicalTargetLocation = groupIt.key();
        const QStringList& aliasLocations = groupIt.value();

        QSet<TrackId> aliasTrackIds;
        QList<TrackData> aliases;
        for (const QString& aliasLocation : aliasLocations) {
            const TrackData alias = findTrackByLocation(aliasLocation);
            if (!alias.id.isValid() || aliasTrackIds.contains(alias.id)) {
                continue;
            }
            aliasTrackIds.insert(alias.id);
            aliases.append(alias);
        }
        const TrackData target = findTargetTrack(canonicalTargetLocation, aliasTrackIds);
        if (!target.id.isValid() || target.hidden) {
            continue;
        }

        QList<TrackData> visibleAliases;
        for (const auto& alias : std::as_const(aliases)) {
            if (!alias.hidden) {
                visibleAliases.append(alias);
            }
        }
        if (visibleAliases.isEmpty()) {
            continue;
        }

        bool durationMismatch = false;
        for (const auto& alias : std::as_const(visibleAliases)) {
            if (hasDurationMismatch(alias.duration, target.duration)) {
                durationMismatch = true;
                break;
            }
        }
        if (durationMismatch) {
            kLogger.info()
                    << "Skipping symlink duplicate with differing durations:"
                    << "alias =" << visibleAliases.constFirst().location
                    << "target =" << target.location;
            continue;
        }

        bool cachedAlias = false;
        for (const auto& alias : std::as_const(aliases)) {
            if (cachedTrackIds.contains(alias.id)) {
                cachedAlias = true;
                break;
            }
        }
        if (cachedAlias) {
            kLogger.info()
                    << "Deferring symlink duplicate reconciliation while"
                    << "an alias track is cached:"
                    << target.location;
            continue;
        }

        const UserDataInfo targetDataInfo = readUserDataInfo(target.id);
        bool targetWins = targetDataInfo.hasUserData;

        TrackData winner = target;
        if (!targetWins) {
            bool winnerFound = false;
            UserDataInfo winnerDataInfo;
            for (const auto& alias : std::as_const(visibleAliases)) {
                const UserDataInfo aliasDataInfo = readUserDataInfo(alias.id);
                if (!aliasDataInfo.hasUserData) {
                    continue;
                }
                if (!winnerFound ||
                        aliasDataInfo.lastPlayedAt > winnerDataInfo.lastPlayedAt ||
                        (aliasDataInfo.lastPlayedAt == winnerDataInfo.lastPlayedAt &&
                                aliasDataInfo.dateAdded > winnerDataInfo.dateAdded) ||
                        (aliasDataInfo.lastPlayedAt == winnerDataInfo.lastPlayedAt &&
                                aliasDataInfo.dateAdded == winnerDataInfo.dateAdded &&
                                alias.location < winner.location)) {
                    winner = alias;
                    winnerDataInfo = aliasDataInfo;
                    winnerFound = true;
                }
            }
            if (!winnerFound) {
                targetWins = true;
            }
        }

        if (targetWins) {
            QList<TrackId> aliasIdsToHide;
            for (const auto& alias : std::as_const(visibleAliases)) {
                aliasIdsToHide.append(alias.id);
            }
            if (!hideTracks(aliasIdsToHide)) {
                result.success = false;
                return result;
            }
            for (const auto& trackId : std::as_const(aliasIdsToHide)) {
                result.hiddenTrackIds.insert(trackId);
            }
            result.numHidden += aliasIdsToHide.size();
            continue;
        }

        if (cachedTrackIds.contains(target.id)) {
            GlobalTrackCacheLocker().purgeTrackId(target.id);
        }

        if (!relocateTrackToTarget(winner, target)) {
            result.success = false;
            return result;
        }

        result.relocatedTracks.append(RelocatedTrack(
                TrackRef::fromFilePath(winner.location, winner.id),
                TrackRef::fromFilePath(target.location, target.id)));
        result.removedTrackIds.append(target.id);
        result.numRelocated++;

        QList<TrackId> otherAliasIdsToHide;
        for (const auto& alias : std::as_const(visibleAliases)) {
            if (alias.id != winner.id) {
                otherAliasIdsToHide.append(alias.id);
            }
        }
        if (!hideTracks(otherAliasIdsToHide)) {
            result.success = false;
            return result;
        }
        for (const auto& trackId : std::as_const(otherAliasIdsToHide)) {
            result.hiddenTrackIds.insert(trackId);
        }
        result.numHidden += otherAliasIdsToHide.size();
    }

    return result;
}
