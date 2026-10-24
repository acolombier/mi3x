#include "qml/qmlcoreservices.h"

#include "broadcast/broadcastmanager.h"
#include "coreservices.h"
#include "library/library.h"
#include "mixer/playermanager.h"
#include "moc_qmlcoreservices.cpp"
#include "notification.h"
#include "notificationmanager.h"

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
    NotificationManager::notifySticky(
            tr("Couldn't load track."),
            reason,
            {},
            NotificationManager::FallbackDialog::Warning);
    Q_UNUSED(pTrack);
}

void QmlCoreServices::slotBroadcastError(
        const QString& title, const QString& text) {
    // TODO(#51): transient vs permanent handling (sticky + Retry/
    // Edit-connection CTAs) once opening the broadcast preferences from
    // the notification space is defined.
    NotificationManager::notifySticky(title,
            text,
            {},
            NotificationManager::FallbackDialog::Warning);
}

void QmlCoreServices::slotAutoDJError(
        AutoDJProcessor::AutoDJError error) {
    // TODO(#51): strings are duplicated from DlgAutoDJ::autoDJError
    // (translation context differs); centralize once the widget view is
    // irrelevant for the QML UI.
    switch (error) {
    case AutoDJProcessor::ADJ_NOT_TWO_DECKS:
        NotificationManager::notifySticky(kAutoDJErrorTitle,
                tr("Auto DJ requires two decks assigned to opposite sides "
                   "of the crossfader."),
                {},
                NotificationManager::FallbackDialog::Warning);
        break;
    case AutoDJProcessor::ADJ_BOTH_DECKS_PLAYING:
        NotificationManager::notifySticky(kAutoDJErrorTitle,
                tr("One deck must be stopped to enable Auto DJ mode."),
                {},
                NotificationManager::FallbackDialog::Warning);
        break;
    case AutoDJProcessor::ADJ_UNUSED_DECK_PLAYING:
        NotificationManager::notifySticky(kAutoDJErrorTitle,
                tr("Decks not used for Auto DJ must be stopped to enable "
                   "Auto DJ mode."),
                {},
                NotificationManager::FallbackDialog::Warning);
        break;
    case AutoDJProcessor::ADJ_OK:
    default:
        break;
    }
}

void QmlCoreServices::connectUserNotifications() {
    DEBUG_ASSERT(m_pInternal);

    connect(m_pInternal->getNotificationManager().get(),
            &NotificationManager::notificationAdded,
            this,
            &QmlCoreServices::notificationsChanged);
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
