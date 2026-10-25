#include "qml/qmlcoreservices.h"

#include <qqmlengine.h>

#include "broadcast/broadcastmanager.h"
#include "coreservices.h"
#include "library/library.h"
#include "mixer/playermanager.h"
#include "moc_qmlcoreservices.cpp"
#include "notification.h"
#include "notificationmanager.h"
#include "track/track.h"
#include "util/assert.h"

namespace mixxx {
namespace qml {

namespace {
const QString kAutoDJErrorTitle = QStringLiteral("Auto DJ");
} // anonymous namespace

// QmlCoreServices::QmlCoreServices(QObject* parent, int): QObject(parent){

// }
QmlCoreServices::QmlCoreServices(std::shared_ptr<::mixxx::CoreServices> pCoreServices)
        : QObject(),
          m_pInternal(std::move(pCoreServices)) {
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
    return instance();
}

QQmlListProperty<mixxx::Notification> QmlCoreServices::notifications() {
    return {this,
            nullptr,
            &QmlCoreServices::append_notification,
            &QmlCoreServices::count_notification,
            &QmlCoreServices::at_notification,
            &QmlCoreServices::clear_notification};
}

void QmlCoreServices::append_notification(
        QQmlListProperty<mixxx::Notification>* list,
        mixxx::Notification* slice) {
    auto* pCoreServices = qobject_cast<QmlCoreServices*>(list->object);
    VERIFY_OR_DEBUG_ASSERT(pCoreServices) {
        return;
    };
    // FIXME what do we do with ownership? Should we take over from or copy?
    pCoreServices->m_pInternal->getNotificationManager()->notify(NotificationPointer(slice));
}

qsizetype QmlCoreServices::count_notification(QQmlListProperty<mixxx::Notification>* list) {
    auto* pCoreServices = qobject_cast<QmlCoreServices*>(list->object);
    VERIFY_OR_DEBUG_ASSERT(pCoreServices) {
        return -1;
    };
    return pCoreServices->m_pInternal->getNotificationManager()->activeNotifications().count();
}

mixxx::Notification* QmlCoreServices::at_notification(
        QQmlListProperty<mixxx::Notification>* list, qsizetype idx) {
    auto* pCoreServices = qobject_cast<QmlCoreServices*>(list->object);
    VERIFY_OR_DEBUG_ASSERT(pCoreServices) {
        return nullptr;
    };
    return pCoreServices->m_pInternal->getNotificationManager()
            ->activeNotifications()
            .at(idx)
            .get();
}

void QmlCoreServices::clear_notification(QQmlListProperty<mixxx::Notification>* list) {
    auto* pCoreServices = qobject_cast<QmlCoreServices*>(list->object);
    VERIFY_OR_DEBUG_ASSERT(pCoreServices) {
        return;
    };
    // TODO is this allowed?
    return;
    // return pCoreServices->m_pInternal->getNotificationManager()->activeNotifications().clear();
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
    // TODO(#51): replace with a dedicated slot member; attach a relocate/
    // reveal CTA once the notification space defines the flow. The dialog
    // strings are kept identical to the widget UI message
    // (MixxxMainWindow::slotTrackLoadFailed).
    Q_UNUSED(pTrack);
    auto pNotification = std::make_shared<Notification>(
            tr("Couldn't load track."));
    pNotification->setDetails(reason);
    m_pInternal->getNotificationManager()->notify(pNotification);
}

void QmlCoreServices::slotBroadcastError(
        const QString& title, const QString& text) {
    // TODO(#51): transient vs permanent handling (sticky + Retry/
    // Edit-connection CTAs) once opening the broadcast preferences from
    // the notification space is defined.
    auto pNotification = std::make_shared<Notification>(title, NotificationFlag::Sticky);
    pNotification->setDetails(text);
    m_pInternal->getNotificationManager()->notify(pNotification);
}

void QmlCoreServices::slotAutoDJError(
        AutoDJProcessor::AutoDJError error) {
    // TODO add buttons
    auto pNotification = std::make_shared<Notification>(
            kAutoDJErrorTitle, NotificationFlag::Sticky);

    switch (error) {
    case AutoDJProcessor::ADJ_NOT_TWO_DECKS:
        pNotification->setDetails(
                tr("Auto DJ requires two decks assigned to opposite sides of "
                   "the crossfader."));
        break;
    case AutoDJProcessor::ADJ_BOTH_DECKS_PLAYING:
        pNotification->setDetails(tr("One deck must be stopped to enable Auto DJ mode."));
        break;
    case AutoDJProcessor::ADJ_UNUSED_DECK_PLAYING:
        pNotification->setDetails(
                tr("Decks not used for Auto DJ must be stopped to enable Auto "
                   "DJ mode."));
        break;
    case AutoDJProcessor::ADJ_OK:
        return;
    default:
        break;
    }
    m_pInternal->getNotificationManager()->notify(pNotification);
}

void QmlCoreServices::connectUserNotifications() {
    DEBUG_ASSERT(m_pInternal);

    // List binding
    connect(m_pInternal->getNotificationManager(),
            &NotificationManager::notificationAdded,
            this,
            &QmlCoreServices::notificationsChanged);
    connect(m_pInternal->getNotificationManager(),
            &NotificationManager::notificationClosed,
            this,
            &QmlCoreServices::notificationsChanged);

    // Direct notification
    connect(m_pInternal->getNotificationManager(),
            &NotificationManager::notificationAdded,
            this,
            // &QmlCoreServices::notificationAdded
            [this](auto pNotification) {
                // FIXME risky
                emit notificationAdded(pNotification.get());
            });
    // );
    connect(m_pInternal->getNotificationManager(),
            &NotificationManager::notificationClosed,
            this,
            // &QmlCoreServices::notificationClosed
            [this](auto pNotification) {
                // FIXME need to find a way to exclude from smart pointer gc
                DEBUG_ASSERT(pNotification.use_count() == 1);
                // auto pUnique = std::make_unique<mixxx::Notification>(std::move(*pNotification));
                // auto pInner = pUnique.release();
                // QQmlEngine::setObjectOwnership(pInner, QQmlEngine::JavaScriptOwnership);
                emit notificationClosed(pNotification.get());
            });
    // );

    // Application event to notification builder slots
    connect(m_pInternal->getPlayerManager().get(),
            &PlayerManager::trackLoadFailed,
            this,
            &QmlCoreServices::slotTrackLoadFailed);
    connect(m_pInternal->getBroadcastManager().get(),
            &BroadcastManager::broadcastError,
            this,
            &QmlCoreServices::slotBroadcastError);
    if (auto pLibrary = m_pInternal->getLibrary()) {
        connect(pLibrary->getAutoDJProcessor(),
                &AutoDJProcessor::autoDJError,
                this,
                &QmlCoreServices::slotAutoDJError);
    }
}
} // namespace qml
} // namespace mixxx
