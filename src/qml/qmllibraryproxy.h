#pragma once
#include <qqmlintegration.h>

#include <QObject>
#include <QQmlEngine>
#include <QString>
<<<<<<< HEAD
=======
#include <QUrl>
                >>>>>>> origin / feat / qml
#include <Qt>
#include <memory>

#include "library/dao/directorydao.h"
#include "library/scanner/libraryscanner.h"
                < < < < < < < HEAD
#include "library/trackcollectionmanager.h"
        == == ==
        =
>>>>>>> origin/feat/qml
#include "qml/qmllibrarysource.h"
#include "qml/qmllibrarytracklistmodel.h"
#include "util/parented_ptr.h"

                class Library;
class LibraryScanner;
class KeyboardEventFilter;

namespace mixxx {
class LibraryExporter;
namespace qml {

class QmlLibrarySource : public QObject {
    Q_OBJECT
<<<<<<< HEAD
    Q_PROPERTY(QString path MEMBER m_path CONSTANT)
    Q_PROPERTY(uint totalSecond MEMBER m_totalSecond CONSTANT)
    Q_PROPERTY(uint trackCount MEMBER m_trackCount CONSTANT)
    QML_NAMED_ELEMENT(LibrarySource)
    QML_UNCREATABLE("Only accessible via Mixxx.Library.sources")
  public:
    QmlLibrarySource(const DirectoryDAO::RootDirectoryInfo& record)
            : m_path(record.path),
=======
    Q_PROPERTY(QUrl url MEMBER m_url CONSTANT)
    Q_PROPERTY(uint totalSecond MEMBER m_totalSecond CONSTANT)
    Q_PROPERTY(uint trackCount MEMBER m_trackCount CONSTANT)
    QML_NAMED_ELEMENT(LibrarySource)
  public:
    QmlLibrarySource(const DirectoryDAO::RootDirectoryInfo& record)
            : m_url(QUrl::fromLocalFile(record.path)),
>>>>>>> origin/feat/qml
              m_totalSecond(record.totalSecond),
              m_trackCount(record.trackCount) {
    }

  private:
<<<<<<< HEAD
    QString m_path;
=======
    QUrl m_url;
>>>>>>> origin/feat/qml
    uint m_totalSecond;
    uint m_trackCount;
};

class QmlLibraryScannerProxy : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool running READ isRunning NOTIFY stateChanged)
    Q_PROPERTY(bool cancelling READ isCancelling NOTIFY stateChanged)
    QML_NAMED_ELEMENT(LibraryScanner)
    QML_UNCREATABLE("Only accessible via Mixxx.Library.scanner")
  public:
<<<<<<< HEAD
    QmlLibraryScannerProxy(
            LibraryScanner* libraryScanner,
            TrackCollectionManager* trackCollectionManager,
            QObject* parent);
=======
    QmlLibraryScannerProxy(LibraryScanner* libraryScanner, QObject* parent);
>>>>>>> origin/feat/qml

    bool isRunning() const {
        return m_running;
    }

    bool isCancelling() const {
        return m_cancelling;
    }

    Q_INVOKABLE void start() {
        m_running = true;
        m_pLibraryScanner->scan();
        emit stateChanged();
    }

    Q_INVOKABLE void cancel() {
        m_cancelling = true;
        emit stateChanged();
        emit requestCancel();
    }

  signals:
    void progress(const QString& path);
    void started();
    void finished();

    void stateChanged();

    void requestStart();
    void requestCancel();

  private:
    LibraryScanner* m_pLibraryScanner;
    bool m_running;
    bool m_cancelling;
};

class QmlLibraryProxy : public QObject {
    Q_OBJECT
    Q_PROPERTY(mixxx::qml::QmlLibraryTrackListModel* model MEMBER m_pModelProperty CONSTANT)
    Q_PROPERTY(QQmlListProperty<mixxx::qml::QmlLibrarySource> sources READ sources CONSTANT)
    Q_PROPERTY(mixxx::qml::QmlLibraryScannerProxy* scanner MEMBER m_pScanner CONSTANT)
<<<<<<< HEAD
    Q_PROPERTY(bool libraryScanActive READ libraryScanActive NOTIFY libraryScanActiveChanged)
    Q_PROPERTY(bool enginePrimeExportAvailable READ enginePrimeExportAvailable CONSTANT)
    Q_PROPERTY(QString waveformCacheDiskUsage READ waveformCacheDiskUsage NOTIFY
                    waveformCacheDiskUsageChanged)
=======
>>>>>>> origin/feat/qml
    QML_NAMED_ELEMENT(Library)
    QML_SINGLETON

  public:
<<<<<<< HEAD
    enum class AddResult {
        Ok,
=======
    enum class Result {
        Ok,
        NotFound,
>>>>>>> origin/feat/qml
        AlreadyWatching,
        InvalidOrMissingDirectory,
        UnreadableDirectory,
        SqlError,
<<<<<<< HEAD
    };
    Q_ENUM(AddResult);
    enum class RemoveResult {
        Ok,
        NotFound,
        SqlError,
    };
    Q_ENUM(RemoveResult);
    enum class RelocateResult {
        Ok,
        InvalidOrMissingDirectory,
        UnreadableDirectory,
        SqlError,
    };
    Q_ENUM(RelocateResult);
=======
        Unknown
    };
    Q_ENUM(Result);
>>>>>>> origin/feat/qml
    enum class SourceRemovalType {
        KeepTracks,
        HideTracks,
        PurgeTracks
    };
    Q_ENUM(SourceRemovalType);
<<<<<<< HEAD
    enum class JumpDirection {
        Impossible,
        Forward,
        Backward,
    };
    Q_ENUM(JumpDirection);

    explicit QmlLibraryProxy(QObject* parent = nullptr);
=======

    explicit QmlLibraryProxy(std::shared_ptr<Library> pLibrary, QObject* parent = nullptr);
>>>>>>> origin/feat/qml
    ~QmlLibraryProxy() override;

    static QmlLibraryProxy* create(QQmlEngine* pQmlEngine, QJSEngine* pJsEngine);
    static void registerLibrary(std::shared_ptr<Library> pLibrary) {
        s_pLibrary = std::move(pLibrary);
    }

    static Library* get() {
        return s_pLibrary.get();
    }

<<<<<<< HEAD
    QString waveformCacheDiskUsage() const {
        return m_waveformCacheDiskUsage;
    }
    Q_INVOKABLE void refreshWaveformCacheDiskUsage();
    Q_INVOKABLE bool clearCachedWaveforms();

    QQmlListProperty<QmlLibrarySource> sources() {
=======
    QQmlListProperty<mixxx::qml::QmlLibrarySource> sources() {
>>>>>>> origin/feat/qml
        return {this,
                nullptr,
                nullptr,
                &QmlLibraryProxy::sources_count,
                &QmlLibraryProxy::sources_at,
                &QmlLibraryProxy::sources_clear};
    }

<<<<<<< HEAD
    Q_INVOKABLE mixxx::qml::QmlLibraryProxy::AddResult addSource(const QUrl& newPath);
    Q_INVOKABLE mixxx::qml::QmlLibraryProxy::RemoveResult removeSource(
            const QUrl& oldPath,
            mixxx::qml::QmlLibraryProxy::SourceRemovalType type);
    Q_INVOKABLE mixxx::qml::QmlLibraryProxy::RelocateResult relinkSource(
            const QUrl& oldPath, const QUrl& newPath);

=======
    Q_INVOKABLE mixxx::qml::QmlLibraryProxy::Result addSource(const QUrl& newPath);
    Q_INVOKABLE mixxx::qml::QmlLibraryProxy::Result removeSource(
            const QUrl& oldPath,
            mixxx::qml::QmlLibraryProxy::SourceRemovalType type);
    Q_INVOKABLE mixxx::qml::QmlLibraryProxy::Result relinkSource(
            const QUrl& oldPath, const QUrl& newPath);

    /// Converts a file URL to a local path for display purposes. The only
    /// sanctioned url <-> path conversion in QML; all library operations
    /// receive and store QUrls.
    Q_INVOKABLE static QString urlToLocalPath(const QUrl& url) {
        return url.toLocalFile();
    }

>>>>>>> origin/feat/qml
    static void registerKeyboardEventFilter(std::shared_ptr<KeyboardEventFilter> pKeyboard) {
        s_pKeyboard = std::move(pKeyboard);
    }

    static KeyboardEventFilter* getKeyboard() {
        return s_pKeyboard.get();
    }

    QmlLibraryTrackListModel* model() const;
    bool libraryScanActive() const {
        return m_pTrackCollectionManager &&
                m_pTrackCollectionManager->isLibraryScanActive();
    }
    bool enginePrimeExportAvailable() const;

    Q_INVOKABLE void analyze(const mixxx::qml::QmlTrackProxy* track) const;
<<<<<<< HEAD
    Q_INVOKABLE void createCrate();
    Q_INVOKABLE void createPlaylist();
    Q_INVOKABLE void exportLibrary();
    Q_INVOKABLE void rescanLibrary();
    Q_INVOKABLE void searchInCurrentView();
    Q_INVOKABLE void searchInTracksLibrary();
    Q_INVOKABLE void showAutoDJ();
=======
>>>>>>> origin/feat/qml
    Q_INVOKABLE QString deckHotcueLabel(
            mixxx::qml::QmlTrackProxy* track,
            int hotcueNumber) const;
    Q_INVOKABLE bool setDeckHotcueLabel(
            mixxx::qml::QmlTrackProxy* track,
            int hotcueNumber,
            const QString& label);
    Q_INVOKABLE bool setDeckHotcueType(
            mixxx::qml::QmlTrackProxy* track,
            const QString& group,
            int hotcueNumber,
            const QString& action);
<<<<<<< HEAD
    Q_INVOKABLE mixxx::qml::QmlLibraryProxy::JumpDirection deckHotcueJumpDirection(
            mixxx::qml::QmlTrackProxy* track,
            const QString& group,
            int hotcueNumber) const;
    Q_INVOKABLE void cleanupDeckHotcuePopup(
            mixxx::qml::QmlTrackProxy* track,
            int hotcueNumber);

  signals:
    void libraryScanActiveChanged();
    void waveformCacheDiskUsageChanged();
    void libraryScanSummaryAvailable(
            const QString& title,
            const QString& text,
            const QString& informativeText);
=======
    Q_INVOKABLE void cleanupDeckHotcuePopup(
            mixxx::qml::QmlTrackProxy* track,
            int hotcueNumber);
>>>>>>> origin/feat/qml

  private:
    void deliverPendingLibraryScanSummary();
    static inline std::shared_ptr<Library> s_pLibrary;

<<<<<<< HEAD
    QString m_waveformCacheDiskUsage;
=======
    std::shared_ptr<Library> m_pLibrary;
>>>>>>> origin/feat/qml

    /// This needs to be a plain pointer because it's used as a `Q_PROPERTY` member variable.
    QmlLibraryTrackListModel* m_pModelProperty;
    QmlLibraryScannerProxy* m_pScanner;
<<<<<<< HEAD
    TrackCollectionManager* m_pTrackCollectionManager;
=======
>>>>>>> origin/feat/qml

    static qsizetype sources_count(QQmlListProperty<QmlLibrarySource>* property);
    static QmlLibrarySource* sources_at(
            QQmlListProperty<QmlLibrarySource>* property, qsizetype index);
    static void sources_clear(QQmlListProperty<QmlLibrarySource>* property);
    static inline std::shared_ptr<KeyboardEventFilter> s_pKeyboard;
#ifdef __ENGINEPRIME__
    std::unique_ptr<mixxx::LibraryExporter> m_pLibraryExporter;
#endif
};

} // namespace qml
} // namespace mixxx
