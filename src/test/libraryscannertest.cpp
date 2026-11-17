#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QTimer>

#include "library/dao/directorydao.h"
#include "library/scanner/libraryscanner.h"
#include "test/librarytest.h"
#include "track/track.h"

class LibraryScannerTest : public LibraryTest {
  protected:
    LibraryScannerTest()
            : m_libraryScanner(dbConnectionPooler(), config()) {
    }
    LibraryScanner m_libraryScanner;
};

TEST_F(LibraryScannerTest, ScannerRoundtrip) {
    // Normal flow:
    EXPECT_EQ(m_libraryScanner.m_state, LibraryScanner::IDLE);
    m_libraryScanner.changeScannerState(LibraryScanner::STARTING);
    EXPECT_EQ(m_libraryScanner.m_state, LibraryScanner::STARTING);
    m_libraryScanner.changeScannerState(LibraryScanner::SCANNING);
    EXPECT_EQ(m_libraryScanner.m_state, LibraryScanner::SCANNING);
    m_libraryScanner.changeScannerState(LibraryScanner::FINISHED);
    EXPECT_EQ(m_libraryScanner.m_state, LibraryScanner::IDLE);

    // No Tracks:
    EXPECT_EQ(m_libraryScanner.m_state, LibraryScanner::IDLE);
    m_libraryScanner.changeScannerState(LibraryScanner::STARTING);
    EXPECT_EQ(m_libraryScanner.m_state, LibraryScanner::STARTING);
    m_libraryScanner.changeScannerState(LibraryScanner::IDLE);
    EXPECT_EQ(m_libraryScanner.m_state, LibraryScanner::IDLE);

    // Cancel during scanning:
    EXPECT_EQ(m_libraryScanner.m_state, LibraryScanner::IDLE);
    m_libraryScanner.changeScannerState(LibraryScanner::STARTING);
    EXPECT_EQ(m_libraryScanner.m_state, LibraryScanner::STARTING);
    m_libraryScanner.changeScannerState(LibraryScanner::SCANNING);
    EXPECT_EQ(m_libraryScanner.m_state, LibraryScanner::SCANNING);
    m_libraryScanner.changeScannerState(LibraryScanner::CANCELING);
    EXPECT_EQ(m_libraryScanner.m_state, LibraryScanner::CANCELING);
    m_libraryScanner.changeScannerState(LibraryScanner::FINISHED);
    EXPECT_EQ(m_libraryScanner.m_state, LibraryScanner::IDLE);
    m_libraryScanner.changeScannerState(LibraryScanner::IDLE);
    EXPECT_EQ(m_libraryScanner.m_state, LibraryScanner::IDLE);

    // restart during canceling :
    EXPECT_EQ(m_libraryScanner.m_state, LibraryScanner::IDLE);
    m_libraryScanner.changeScannerState(LibraryScanner::CANCELING);
    EXPECT_EQ(m_libraryScanner.m_state, LibraryScanner::CANCELING);
    m_libraryScanner.changeScannerState(LibraryScanner::STARTING);
    EXPECT_EQ(m_libraryScanner.m_state, LibraryScanner::CANCELING);
    m_libraryScanner.changeScannerState(LibraryScanner::IDLE);
    EXPECT_EQ(m_libraryScanner.m_state, LibraryScanner::IDLE);
}

#ifndef __WINDOWS__
TEST_F(LibraryScannerTest, symlinkDuplicateReconciledDuringScan) {
    const QTemporaryDir tempDir;
    ASSERT_TRUE(tempDir.isValid());

    const QString targetPath = tempDir.filePath(QStringLiteral("track.mp3"));
    const QString aliasPath = tempDir.filePath(QStringLiteral("alias.mp3"));
    mixxxtest::copyFile(getTestFile(QStringLiteral("-jpg.mp3")), targetPath);
    ASSERT_TRUE(QFile::link(targetPath, aliasPath));

    TrackId aliasId;
    {
        const TrackPointer pTrack = getOrAddTrackByLocation(aliasPath);
        ASSERT_TRUE(pTrack);
        aliasId = pTrack->getId();
        ASSERT_TRUE(aliasId.isValid());
    }

    QSqlQuery query(dbConnection());
    query.prepare(QStringLiteral(
            "UPDATE library SET rating=5, last_played_at='2025-01-02 03:04:05' "
            "WHERE id=:id"));
    query.bindValue(QStringLiteral(":id"), aliasId.toVariant());
    ASSERT_TRUE(query.exec());

    ASSERT_EQ(DirectoryDAO::AddResult::Ok,
            internalCollection()->getDirectoryDAO().addDirectory(
                    mixxx::FileInfo(tempDir.path())));

    m_libraryScanner.start();
    QEventLoop loop;
    QObject::connect(&m_libraryScanner,
            &LibraryScanner::scanFinished,
            &loop,
            &QEventLoop::quit);
    QTimer::singleShot(20000, &loop, &QEventLoop::quit);
    m_libraryScanner.scan();
    loop.exec();

    QSqlQuery resultQuery(dbConnection());
    resultQuery.prepare(QStringLiteral(
            "SELECT library.id, library.mixxx_deleted, track_locations.location "
            "FROM library "
            "INNER JOIN track_locations ON library.location=track_locations.id "
            "WHERE track_locations.location IN (:target, :alias)"));
    resultQuery.bindValue(QStringLiteral(":target"), targetPath);
    resultQuery.bindValue(QStringLiteral(":alias"), aliasPath);
    ASSERT_TRUE(resultQuery.exec());

    bool foundTarget = false;
    bool foundAlias = false;
    while (resultQuery.next()) {
        const TrackId trackId(resultQuery.value(0));
        const int mixxxDeleted = resultQuery.value(1).toInt();
        const QString location = resultQuery.value(2).toString();
        if (location == targetPath) {
            foundTarget = true;
            EXPECT_EQ(aliasId, trackId);
            EXPECT_EQ(0, mixxxDeleted);
        } else if (location == aliasPath) {
            foundAlias = true;
            EXPECT_EQ(1, mixxxDeleted);
            EXPECT_NE(aliasId, trackId);
        }
    }
    EXPECT_TRUE(foundTarget);
    EXPECT_TRUE(foundAlias);
}
#endif // __WINDOWS__
