#include "qml/qmlcoreservices.h"

#include <qnamespace.h>
#include <qobject.h>
#include <qqmlengine.h>

#include <utility>

#include "library/library.h"
#include "library/library_prefs.h"
#include "mixer/playermanager.h"
#include "moc_qmlcoreservices.cpp"
#include "notification.h"
#include "notificationmanager.h"
#include "track/track.h"
#include "util/assert.h"

namespace mixxx {
namespace qml {

QmlCoreServices::QmlCoreServices(QQmlEngine* pQmlEngine)
        : QObject(pQmlEngine) {
    connect(s_pCoreServices.get(),
            &mixxx::CoreServices::libraryScanSummary,
            this,
            &QmlCoreServices::slotLibraryScanSummary);
    connect(s_pCoreServices.get(),
            &mixxx::CoreServices::initialized,
            this,
            &QmlCoreServices::slotInitialization);
    if (s_pCoreServices->isInitialized()) {
        slotInitialization();
    }
}

void QmlCoreServices::setReady() {
    if (m_ready) {
        return;
    }
    m_ready = true;
    emit readyChanged();
}

// static
QmlCoreServices* QmlCoreServices::create(QQmlEngine* pQmlEngine, QJSEngine*) {
    return new QmlCoreServices(pQmlEngine);
}

void QmlCoreServices::addOpenedPopup(QObject* popup) {
    bool wasEmpty = m_popups.isEmpty();
    m_popups.insert(popup);
    if (wasEmpty) {
        emit hasPopupChanged();
    }
}
void QmlCoreServices::removeOpenedPopup(QObject* popup) {
    bool wasNotEmpty = !m_popups.isEmpty();
    m_popups.remove(popup);
    if (wasNotEmpty) {
        emit hasPopupChanged();
    }
}

void QmlCoreServices::clearOpenedPopup() {
    if (m_popups.isEmpty()) {
        return;
    }
    m_popups.clear();
    emit hasPopupChanged();
}

void QmlCoreServices::slotTrackLoadFailed(
        TrackPointer pTrack, const QString& reason) {
    // Repeated failures for the same
    // track are suppressed until a different track is loaded using notification keys.
    const auto& akey = pTrack->getId().toString();
    const auto pNotifications = NotificationManager::instance()->activeNotifications();
    for (const auto& pNotification : std::as_const(pNotifications)) {
        if (pNotification->key() == akey) {
            pNotification->setDetails(reason);
            return;
        }
    }
    auto pNotification = std::make_shared<Notification>(
            tr("Couldn't load track."), mixxx::Notification::Flag::Error, akey);
    pNotification->setDetails(reason);
    NotificationManager::instance()->notify(pNotification);
}

void QmlCoreServices::slotLibraryScanSummary(const LibraryScanResultSummary& result) {
    if (!s_pCoreServices->getSettings()->getValue<bool>(
                ::mixxx::library::prefs::kShowScanSummaryConfigKey, true)) {
        return;
    }

    // Don't show the report dialog when the scan is run during startup and no
    // noteworthy changes have been detected.
    if (result.autoscan &&
            result.numNewTracks == 0 &&
            result.numNewMissingTracks == 0 &&
            result.numRediscoveredTracks == 0) {
        return;
    }
    auto pNotification = std::make_shared<Notification>(tr("Library scan finished"));
    if (result.noDirectoriesConfigured) {
        pNotification->setDetails(tr("No music directories configured for scanning.") +
                QStringLiteral("<br>") +
                tr("Add directories in the library preferences."));
        NotificationManager::instance()->notify(pNotification);
        return;
    }

    QString summary =
            tr("Scan took %1").arg(result.durationString) + QStringLiteral("<br><br>");
    if (result.numNewTracks == 0 &&
            result.numMovedTracks == 0 &&
            result.numNewMissingTracks == 0 &&
            result.numRediscoveredTracks == 0) {
        summary += tr("No changes detected.") +
                QStringLiteral("<br><b>") +
                tr("%n track(s) in total", nullptr, result.tracksTotal) +
                QStringLiteral("</b>");
    } else {
        if (result.numNewTracks != 0) {
            summary += tr("%n new track(s) found", nullptr, result.numNewTracks) +
                    QStringLiteral("<br>");
        }
        if (result.numMovedTracks != 0) {
            summary += tr("%n moved track(s) detected", nullptr, result.numMovedTracks) +
                    QStringLiteral("<br>");
        }
        if (result.numNewMissingTracks != 0) {
            summary += tr("%n track(s) missing (%1 total)",
                    nullptr,
                    result.numNewMissingTracks)
                               .arg(result.numMissingTracks);
        }
        if (result.numRediscoveredTracks != 0) {
            summary += QStringLiteral("<br>") +
                    tr("%n track(s) rediscovered",
                            nullptr,
                            result.numRediscoveredTracks);
        }
        summary += QStringLiteral("<br><br><b>") +
                tr("%n track(s) in total", nullptr, result.tracksTotal) +
                QStringLiteral("</b>");
    }

    pNotification->setDetails(summary);
    NotificationManager::instance()->notify(pNotification);
}

void QmlCoreServices::slotInitialization() {
    // Application event to notification builder slots
    connect(s_pCoreServices->getPlayerManager().get(),
            &PlayerManager::trackLoadFailed,
            this,
            &QmlCoreServices::slotTrackLoadFailed,
            Qt::UniqueConnection);
    if (s_pCoreServices->isInitialized()) {
        setReady();
    }
}
} // namespace qml
} // namespace mixxx
