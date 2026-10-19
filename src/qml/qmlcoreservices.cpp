#include "qml/qmlcoreservices.h"

#include "coreservices.h"
#include "moc_qmlcoreservices.cpp"
#include "notification.h"
#include "notificationmanager.h"

namespace mixxx {
namespace qml {

// QmlCoreServices::QmlCoreServices(QObject* parent, int): QObject(parent){

// }
QmlCoreServices::QmlCoreServices(std::shared_ptr<::mixxx::CoreServices> pCoreServices)
        : QObject(),
          m_pInternal(std::move(pCoreServices)) {
    connect(m_pInternal->getNotificationManager().get(),
            &NotificationManager::notificationAdded,
            this,
            &QmlCoreServices::notificationsChanged);
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
} // namespace qml
} // namespace mixxx
