#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include <QFile>
#include <QFileInfo>
#include <QSqlQuery>
#include <QTemporaryDir>

#include "library/scanner/symlinkduplicateresolver.h"
#include "library/trackset/crate/crate.h"
#include "test/librarytest.h"
#include "track/globaltrackcache.h"
#include "track/track.h"

using ::testing::UnorderedElementsAre;

class TrackDAOTest : public LibraryTest {
};

#ifndef __WINDOWS__

class SymlinkDuplicateResolverTest : public LibraryTest {
  protected:
    TrackId addTrackWithData(
            const QString& location,
            int rating = 0,
            const QString& lastPlayedAt = QString()) {
        const TrackPointer pTrack = getOrAddTrackByLocation(location);
        EXPECT_TRUE(pTrack);
        if (!pTrack) {
            return {};
        }
        const TrackId trackId = pTrack->getId();
        EXPECT_TRUE(trackId.isValid());

        QSqlQuery query(dbConnection());
        query.prepare(QStringLiteral(
                "UPDATE library SET rating=:rating, last_played_at=:lastPlayedAt "
                "WHERE id=:id"));
        query.bindValue(QStringLiteral(":rating"), rating);
        query.bindValue(QStringLiteral(":lastPlayedAt"),
                lastPlayedAt.isEmpty() ? QVariant() : QVariant(lastPlayedAt));
        query.bindValue(QStringLiteral(":id"), trackId.toVariant());
        EXPECT_TRUE(query.exec());
        return trackId;
    }

    void addCue(TrackId trackId) {
        QSqlQuery query(dbConnection());
        query.prepare(QStringLiteral(
                "INSERT INTO cues (track_id, type, position, length, hotcue, label) "
                "VALUES (:trackId, 0, 0, 0, 0, 'cue')"));
        query.bindValue(QStringLiteral(":trackId"), trackId.toVariant());
        EXPECT_TRUE(query.exec());
    }

    void addPlaylistEntry(TrackId trackId) {
        auto& playlistDao = internalCollection()->getPlaylistDAO();
        const int playlistId = playlistDao.createPlaylist(QStringLiteral("Test"));
        ASSERT_GE(playlistId, 0);
        EXPECT_TRUE(playlistDao.appendTrackToPlaylist(trackId, playlistId));
    }

    void addCrateEntry(TrackId trackId) {
        Crate crate;
        crate.setName(QStringLiteral("Test Crate"));
        CrateId crateId;
        ASSERT_TRUE(internalCollection()->insertCrate(crate, &crateId));
        ASSERT_TRUE(internalCollection()->addCrateTracks(
                crateId, QList<TrackId>{trackId}));
    }
};

namespace {

int countRows(const QSqlDatabase& database, const QString& statement, TrackId trackId) {
    QSqlQuery query(database);
    query.prepare(statement);
    query.bindValue(QStringLiteral(":trackId"), trackId.toVariant());
    EXPECT_TRUE(query.exec());
    EXPECT_TRUE(query.next());
    return query.value(0).toInt();
}

QString getTrackLocation(const QSqlDatabase& database, TrackId trackId) {
    QSqlQuery query(database);
    query.prepare(QStringLiteral(
            "SELECT track_locations.location FROM library "
            "INNER JOIN track_locations ON library.location=track_locations.id "
            "WHERE library.id=:id"));
    query.bindValue(QStringLiteral(":id"), trackId.toVariant());
    EXPECT_TRUE(query.exec());
    if (!query.next()) {
        return {};
    }
    return query.value(0).toString();
}

int getMixxxDeleted(const QSqlDatabase& database, TrackId trackId) {
    QSqlQuery query(database);
    query.prepare(QStringLiteral(
            "SELECT mixxx_deleted FROM library WHERE id=:id"));
    query.bindValue(QStringLiteral(":id"), trackId.toVariant());
    EXPECT_TRUE(query.exec());
    EXPECT_TRUE(query.next());
    return query.value(0).toInt();
}

} // namespace

TEST_F(SymlinkDuplicateResolverTest, symlinkDuplicateAliasWinsAndKeepsUserData) {
    const QTemporaryDir tempDir;
    ASSERT_TRUE(tempDir.isValid());

    const QString targetPath = tempDir.filePath(QStringLiteral("track.mp3"));
    const QString aliasPath = tempDir.filePath(QStringLiteral("alias.mp3"));
    mixxxtest::copyFile(getTestFile(QStringLiteral("-jpg.mp3")), targetPath);
    ASSERT_TRUE(QFile::link(targetPath, aliasPath));

    const TrackId aliasId = addTrackWithData(
            aliasPath, 5, QStringLiteral("2025-01-02 03:04:05"));
    ASSERT_TRUE(aliasId.isValid());
    const TrackId targetId = addTrackWithData(targetPath);
    ASSERT_TRUE(targetId.isValid());
    ASSERT_NE(aliasId, targetId);

    addCue(aliasId);
    addPlaylistEntry(aliasId);
    addCrateEntry(aliasId);

    const SymlinkDuplicateResolver resolver(dbConnection());
    const auto result = resolver.resolve(
            QHash<QString, QString>{{aliasPath,
                    QFileInfo(targetPath).canonicalFilePath()}});

    ASSERT_TRUE(result.success);
    EXPECT_EQ(1, result.numRelocated);
    EXPECT_EQ(1, result.relocatedTracks.size());
    EXPECT_TRUE(result.hiddenTrackIds.isEmpty());

    EXPECT_EQ(targetPath, getTrackLocation(dbConnection(), aliasId));
    EXPECT_TRUE(getTrackLocation(dbConnection(), targetId).isEmpty());
    EXPECT_EQ(0, getMixxxDeleted(dbConnection(), aliasId));

    EXPECT_EQ(1,
            countRows(dbConnection(),
                    QStringLiteral("SELECT COUNT(*) FROM cues WHERE "
                                   "track_id=:trackId"),
                    aliasId));
    EXPECT_EQ(1,
            countRows(dbConnection(),
                    QStringLiteral("SELECT COUNT(*) FROM PlaylistTracks WHERE "
                                   "track_id=:trackId"),
                    aliasId));
    EXPECT_EQ(1,
            countRows(dbConnection(),
                    QStringLiteral("SELECT COUNT(*) FROM crate_tracks WHERE "
                                   "track_id=:trackId"),
                    aliasId));
    EXPECT_EQ(5,
            countRows(dbConnection(),
                    QStringLiteral(
                            "SELECT rating FROM library WHERE id=:trackId"),
                    aliasId));

    QSqlQuery tombstoneQuery(dbConnection());
    tombstoneQuery.prepare(QStringLiteral(
            "SELECT library.id, library.mixxx_deleted FROM library "
            "INNER JOIN track_locations ON library.location=track_locations.id "
            "WHERE track_locations.location=:location"));
    tombstoneQuery.bindValue(QStringLiteral(":location"), aliasPath);
    ASSERT_TRUE(tombstoneQuery.exec());
    ASSERT_TRUE(tombstoneQuery.next());
    EXPECT_EQ(1, tombstoneQuery.value(1).toInt());
    EXPECT_NE(aliasId, TrackId(tombstoneQuery.value(0)));

    const auto secondResult = resolver.resolve(
            QHash<QString, QString>{{aliasPath,
                    QFileInfo(targetPath).canonicalFilePath()}});
    ASSERT_TRUE(secondResult.success);
    EXPECT_EQ(0, secondResult.numRelocated);
    EXPECT_TRUE(secondResult.hiddenTrackIds.isEmpty());
    EXPECT_EQ(targetPath, getTrackLocation(dbConnection(), aliasId));
}

TEST_F(SymlinkDuplicateResolverTest, symlinkDuplicateTargetWinsWithoutImportingAliasData) {
    const QTemporaryDir tempDir;
    ASSERT_TRUE(tempDir.isValid());

    const QString targetPath = tempDir.filePath(QStringLiteral("track.mp3"));
    const QString aliasPath = tempDir.filePath(QStringLiteral("alias.mp3"));
    mixxxtest::copyFile(getTestFile(QStringLiteral("-jpg.mp3")), targetPath);
    ASSERT_TRUE(QFile::link(targetPath, aliasPath));

    const TrackId aliasId = addTrackWithData(
            aliasPath, 5, QStringLiteral("2025-03-02 03:04:05"));
    ASSERT_TRUE(aliasId.isValid());
    const TrackId targetId = addTrackWithData(
            targetPath, 4, QStringLiteral("2025-02-02 03:04:05"));
    ASSERT_TRUE(targetId.isValid());
    ASSERT_NE(aliasId, targetId);

    addCue(aliasId);
    addPlaylistEntry(aliasId);
    addCrateEntry(aliasId);
    addCue(targetId);

    const SymlinkDuplicateResolver resolver(dbConnection());
    const auto result = resolver.resolve(
            QHash<QString, QString>{{aliasPath,
                    QFileInfo(targetPath).canonicalFilePath()}});

    ASSERT_TRUE(result.success);
    EXPECT_EQ(0, result.numRelocated);
    EXPECT_TRUE(result.relocatedTracks.isEmpty());
    EXPECT_THAT(result.hiddenTrackIds, UnorderedElementsAre(aliasId));

    EXPECT_EQ(1, getMixxxDeleted(dbConnection(), aliasId));
    EXPECT_EQ(0, getMixxxDeleted(dbConnection(), targetId));
    EXPECT_EQ(targetPath, getTrackLocation(dbConnection(), targetId));
    EXPECT_EQ(aliasPath, getTrackLocation(dbConnection(), aliasId));

    EXPECT_EQ(4,
            countRows(dbConnection(),
                    QStringLiteral(
                            "SELECT rating FROM library WHERE id=:trackId"),
                    targetId));
    EXPECT_EQ(1,
            countRows(dbConnection(),
                    QStringLiteral("SELECT COUNT(*) FROM cues WHERE "
                                   "track_id=:trackId"),
                    targetId));
    EXPECT_EQ(1,
            countRows(dbConnection(),
                    QStringLiteral("SELECT COUNT(*) FROM cues WHERE "
                                   "track_id=:trackId"),
                    aliasId));
    EXPECT_EQ(1,
            countRows(dbConnection(),
                    QStringLiteral("SELECT COUNT(*) FROM PlaylistTracks WHERE "
                                   "track_id=:trackId"),
                    aliasId));
    EXPECT_EQ(1,
            countRows(dbConnection(),
                    QStringLiteral("SELECT COUNT(*) FROM crate_tracks WHERE "
                                   "track_id=:trackId"),
                    aliasId));
}

TEST_F(SymlinkDuplicateResolverTest, symlinkDuplicateWithoutUserDataKeepsTargetVisible) {
    const QTemporaryDir tempDir;
    ASSERT_TRUE(tempDir.isValid());

    const QString targetPath = tempDir.filePath(QStringLiteral("track.mp3"));
    const QString aliasPath = tempDir.filePath(QStringLiteral("alias.mp3"));
    mixxxtest::copyFile(getTestFile(QStringLiteral("-jpg.mp3")), targetPath);
    ASSERT_TRUE(QFile::link(targetPath, aliasPath));

    const TrackId aliasId = addTrackWithData(aliasPath);
    ASSERT_TRUE(aliasId.isValid());
    const TrackId targetId = addTrackWithData(targetPath);
    ASSERT_TRUE(targetId.isValid());
    ASSERT_NE(aliasId, targetId);

    QSqlQuery clearQuery(dbConnection());
    clearQuery.prepare(QStringLiteral(
            "UPDATE library SET rating=0, comment='', color=NULL, timesplayed=0, "
            "played=0, bpm=0, bpm_lock=0, key='', key_id=0, "
            "tuning_frequency_hz=0, beats=NULL, beats_version='', "
            "beats_sub_version='', keys=NULL, keys_version='', "
            "keys_sub_version='', coverart_source=0, last_played_at=NULL "
            "WHERE id=:id"));
    for (const TrackId trackId : {aliasId, targetId}) {
        clearQuery.bindValue(QStringLiteral(":id"), trackId.toVariant());
        ASSERT_TRUE(clearQuery.exec());
    }

    const SymlinkDuplicateResolver resolver(dbConnection());
    const auto result = resolver.resolve(
            QHash<QString, QString>{{aliasPath,
                    QFileInfo(targetPath).canonicalFilePath()}});

    ASSERT_TRUE(result.success);
    EXPECT_EQ(0, result.numRelocated);
    EXPECT_THAT(result.hiddenTrackIds, UnorderedElementsAre(aliasId));

    EXPECT_EQ(1, getMixxxDeleted(dbConnection(), aliasId));
    EXPECT_EQ(0, getMixxxDeleted(dbConnection(), targetId));
    EXPECT_EQ(targetPath, getTrackLocation(dbConnection(), targetId));
}

TEST_F(SymlinkDuplicateResolverTest, symlinkDuplicateWithDifferentDurationIsSkipped) {
    const QTemporaryDir tempDir;
    ASSERT_TRUE(tempDir.isValid());

    const QString targetPath = tempDir.filePath(QStringLiteral("track.mp3"));
    const QString aliasPath = tempDir.filePath(QStringLiteral("alias.mp3"));
    mixxxtest::copyFile(getTestFile(QStringLiteral("-jpg.mp3")), targetPath);
    ASSERT_TRUE(QFile::link(targetPath, aliasPath));

    const TrackId aliasId = addTrackWithData(aliasPath, 5);
    ASSERT_TRUE(aliasId.isValid());
    const TrackId targetId = addTrackWithData(targetPath);
    ASSERT_TRUE(targetId.isValid());
    ASSERT_NE(aliasId, targetId);

    QSqlQuery query(dbConnection());
    query.prepare(QStringLiteral(
            "UPDATE library SET duration=:duration WHERE id=:id"));
    query.bindValue(QStringLiteral(":duration"), 100.0);
    query.bindValue(QStringLiteral(":id"), aliasId.toVariant());
    ASSERT_TRUE(query.exec());
    query.bindValue(QStringLiteral(":duration"), 200.0);
    query.bindValue(QStringLiteral(":id"), targetId.toVariant());
    ASSERT_TRUE(query.exec());

    const SymlinkDuplicateResolver resolver(dbConnection());
    const auto result = resolver.resolve(
            QHash<QString, QString>{{aliasPath,
                    QFileInfo(targetPath).canonicalFilePath()}});

    ASSERT_TRUE(result.success);
    EXPECT_EQ(0, result.numRelocated);
    EXPECT_TRUE(result.hiddenTrackIds.isEmpty());
    EXPECT_EQ(0, getMixxxDeleted(dbConnection(), aliasId));
    EXPECT_EQ(0, getMixxxDeleted(dbConnection(), targetId));
}

TEST_F(SymlinkDuplicateResolverTest, symlinkDuplicateMultipleAliasesUsesMostRecentData) {
    const QTemporaryDir tempDir;
    ASSERT_TRUE(tempDir.isValid());

    const QString targetPath = tempDir.filePath(QStringLiteral("track.mp3"));
    const QString alias1Path = tempDir.filePath(QStringLiteral("alias1.mp3"));
    const QString alias2Path = tempDir.filePath(QStringLiteral("alias2.mp3"));
    mixxxtest::copyFile(getTestFile(QStringLiteral("-jpg.mp3")), targetPath);
    ASSERT_TRUE(QFile::link(targetPath, alias1Path));
    ASSERT_TRUE(QFile::link(targetPath, alias2Path));

    const TrackId alias1Id = addTrackWithData(
            alias1Path, 3, QStringLiteral("2025-01-02 03:04:05"));
    ASSERT_TRUE(alias1Id.isValid());
    const TrackId alias2Id = addTrackWithData(
            alias2Path, 4, QStringLiteral("2025-02-02 03:04:05"));
    ASSERT_TRUE(alias2Id.isValid());
    const TrackId targetId = addTrackWithData(targetPath);
    ASSERT_TRUE(targetId.isValid());
    ASSERT_NE(alias1Id, alias2Id);
    ASSERT_NE(alias1Id, targetId);
    ASSERT_NE(alias2Id, targetId);

    const SymlinkDuplicateResolver resolver(dbConnection());
    const auto result = resolver.resolve(
            QHash<QString, QString>{
                    {alias1Path, QFileInfo(targetPath).canonicalFilePath()},
                    {alias2Path, QFileInfo(targetPath).canonicalFilePath()}});

    ASSERT_TRUE(result.success);
    EXPECT_EQ(1, result.numRelocated);
    EXPECT_THAT(result.hiddenTrackIds, UnorderedElementsAre(alias1Id));

    EXPECT_EQ(targetPath, getTrackLocation(dbConnection(), alias2Id));
    EXPECT_TRUE(getTrackLocation(dbConnection(), targetId).isEmpty());
    EXPECT_EQ(alias1Path, getTrackLocation(dbConnection(), alias1Id));
    EXPECT_EQ(1, getMixxxDeleted(dbConnection(), alias1Id));
    EXPECT_EQ(0, getMixxxDeleted(dbConnection(), alias2Id));
}

#endif // __WINDOWS__

TEST_F(TrackDAOTest, detectMovedTracks) {
    TrackDAO& trackDAO = internalCollection()->getTrackDAO();

    QString filename = QStringLiteral("file.mp3");

    mixxx::FileInfo oldFile(QDir(QDir::tempPath() + QStringLiteral("/old/dir1")), filename);
    mixxx::FileInfo newFile(QDir(QDir::tempPath() + QStringLiteral("/new/dir1")), filename);
    mixxx::FileInfo otherFile(QDir(QDir::tempPath() + QStringLiteral("/new")), filename);

    TrackPointer pOldTrack = Track::newTemporary(mixxx::FileAccess(oldFile));
    TrackPointer pNewTrack = Track::newTemporary(mixxx::FileAccess(newFile));
    TrackPointer pOtherTrack = Track::newTemporary(mixxx::FileAccess(otherFile));

    // Arbitrary duration
    pOldTrack->setDuration(135);
    pNewTrack->setDuration(135.7);
    pOtherTrack->setDuration(135.7);

    TrackId oldId = internalCollection()->addTrack(pOldTrack, false);
    TrackId newId = internalCollection()->addTrack(pNewTrack, false);
    internalCollection()->addTrack(pOtherTrack, false);

    // Mark as missing
    QSqlQuery query(dbConnection());
    query.prepare("UPDATE track_locations SET fs_deleted=1 WHERE location=:location");
    query.bindValue(":location", oldFile.location());
    query.exec();

    QList<RelocatedTrack> relocatedTracks;
    QStringList addedTracks(newFile.location());
    bool cancel = false;
    trackDAO.detectMovedTracks(&relocatedTracks, addedTracks, &cancel);

    QSet<TrackId> updatedTrackIds;
    QSet<TrackId> removedTrackIds;
    for (const auto& relocatedTrack : std::as_const(relocatedTracks)) {
        updatedTrackIds.insert(relocatedTrack.updatedTrackRef().getId());
        removedTrackIds.insert(relocatedTrack.deletedTrackId());
    }

    EXPECT_THAT(updatedTrackIds, UnorderedElementsAre(oldId));
    EXPECT_THAT(removedTrackIds, UnorderedElementsAre(newId));

    QSet<QString> trackLocations = trackDAO.getAllTrackLocations();
    EXPECT_THAT(trackLocations, UnorderedElementsAre(newFile.location(), otherFile.location()));
}

// Regression test for the bug where a BPM-locked track without a beatgrid
// loses its lock when reloaded from the database.
// https://github.com/mixxxdj/mixxx/issues/15196
TEST_F(TrackDAOTest, bpmLockPreservedForTrackWithoutBeats) {
    const mixxx::FileInfo fileInfo(
            QDir(QDir::tempPath()), QStringLiteral("bpmlocked-no-beats.mp3"));
    TrackPointer pTrack = Track::newTemporary(mixxx::FileAccess(fileInfo));
    pTrack->setDuration(135);
    // Lock the BPM although the track has no beatgrid at all.
    pTrack->setBpmLocked(true);
    ASSERT_FALSE(pTrack->getBeats());
    ASSERT_TRUE(pTrack->isBpmLocked());

    const TrackId trackId = internalCollection()->addTrack(pTrack, false);
    ASSERT_TRUE(trackId.isValid());

    // Dropping the last reference evicts the track from the cache
    // synchronously (eviction runs as a direct call on this thread), so the
    // lookup below reloads it from the database instead of returning the
    // cached in-memory object whose lock flag was never lost.
    pTrack.reset();
    ASSERT_TRUE(GlobalTrackCacheLocker().isEmpty());

    const TrackPointer pReloaded = internalCollection()->getTrackById(trackId);
    ASSERT_TRUE(pReloaded);
    EXPECT_FALSE(pReloaded->getBeats());
    EXPECT_TRUE(pReloaded->isBpmLocked());
}

TEST_F(TrackDAOTest, markTrackLocationsAsVerifiedRecoversPresentFilesOnly) {
    // Regression cover for both directions of mixxxdj/mixxx#13533:
    //   1. A track erroneously flagged fs_deleted=1 must be revived when the
    //      file is still present in an unchanged-hash directory (the original
    //      bug).
    //   2. A track legitimately flagged fs_deleted=1 because the file was
    //      removed before the saved directory hash was last updated must NOT
    //      be revived on a subsequent unchanged-hash rescan.
    //
    // markTrackLocationsAsVerified is the cleanup-phase entry point that the
    // scanner uses for every verified location, including those collected
    // from unchanged-hash directories. It should clear fs_deleted /
    // needs_verification for exactly the locations passed in, and leave
    // unrelated rows untouched.
    TrackDAO& trackDAO = internalCollection()->getTrackDAO();

    QDir dir(QDir::tempPath() + QStringLiteral("/verified_dir"));
    mixxx::FileInfo presentFile(dir, QStringLiteral("present.mp3"));
    mixxx::FileInfo deletedFile(dir, QStringLiteral("deleted.mp3"));

    TrackPointer pPresent = Track::newTemporary(mixxx::FileAccess(presentFile));
    TrackPointer pDeleted = Track::newTemporary(mixxx::FileAccess(deletedFile));
    pPresent->setDuration(180);
    pDeleted->setDuration(180);

    TrackId presentId = internalCollection()->addTrack(pPresent, false);
    TrackId deletedId = internalCollection()->addTrack(pDeleted, false);
    ASSERT_TRUE(presentId.isValid());
    ASSERT_TRUE(deletedId.isValid());

    // Both rows simulate the post-`invalidateTrackLocationsInLibrary` state at
    // the start of a scan. The "deleted" row additionally carries the
    // fs_deleted=1 that the previous scan's verifyRemainingTracks set when
    // the file disappeared from disk between scans.
    QSqlQuery setQuery(dbConnection());
    setQuery.prepare(
            "UPDATE track_locations "
            "SET fs_deleted=:fs_deleted, needs_verification=1 "
            "WHERE location=:location");
    setQuery.bindValue(":fs_deleted", 1);
    setQuery.bindValue(":location", presentFile.location());
    ASSERT_TRUE(setQuery.exec());
    setQuery.bindValue(":fs_deleted", 1);
    setQuery.bindValue(":location", deletedFile.location());
    ASSERT_TRUE(setQuery.exec());

    // The recursive scanner only feeds locations whose file is currently
    // present in the directory into markTrackLocationsAsVerified. Simulate
    // that for a delete-then-rescan: only `presentFile` is in the list.
    trackDAO.markTrackLocationsAsVerified(QStringList{presentFile.location()});

    QSqlQuery readQuery(dbConnection());
    readQuery.prepare(
            "SELECT fs_deleted, needs_verification FROM track_locations "
            "WHERE location=:location");

    readQuery.bindValue(":location", presentFile.location());
    ASSERT_TRUE(readQuery.exec());
    ASSERT_TRUE(readQuery.next());
    EXPECT_EQ(0, readQuery.value(0).toInt())
            << "fs_deleted should be cleared for a still-present file";
    EXPECT_EQ(0, readQuery.value(1).toInt())
            << "needs_verification should be cleared for a still-present file";

    readQuery.bindValue(":location", deletedFile.location());
    ASSERT_TRUE(readQuery.exec());
    ASSERT_TRUE(readQuery.next());
    EXPECT_EQ(1, readQuery.value(0).toInt())
            << "fs_deleted must be preserved for a file no longer in the directory";
    EXPECT_EQ(1, readQuery.value(1).toInt())
            << "needs_verification must remain set so verifyRemainingTracks can confirm deletion";
}
