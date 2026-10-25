#include "notificationmanager.h"

#include <QDebug>
#include <QMessageBox>
#include <QMutexLocker>
#include <QPointer>

#include "moc_notificationmanager.cpp"
#include "util/assert.h"
#include "util/cmdlineargs.h"

namespace {

constexpr int kAutoTimeoutSecs = 10;
}

namespace mixxx {

NotificationManager::NotificationManager() {
    m_timer.setInterval(1000);
    connect(&m_timer, &QTimer::timeout, this, &NotificationManager::slotUpdateNotifications);
};

NotificationManager::~NotificationManager() = default;

void NotificationManager::notify(const NotificationPointer& pNotification) {
    VERIFY_OR_DEBUG_ASSERT(pNotification) {
        return;
    }
    qWarning() << "New notification:" << pNotification->text();

    if (!pNotification->lastUpdated().isValid()) {
        pNotification->setLastUpdated(QDateTime::currentDateTimeUtc());
    }

    if (!pNotification->flags().testFlag(NotificationFlag::Sticky)) {
        if (pNotification->timeoutSecs() == 0) {
            pNotification->setTimeoutSecs(kAutoTimeoutSecs);
        }

        if (!m_timer.isActive()) {
            m_timer.start();
        }
    }

    QMutexLocker lock(&m_mutex);
    m_notifications.prepend(pNotification);
    lock.unlock();

    emit notificationAdded(pNotification);
}

void NotificationManager::closeNotification(const NotificationPointer& pNotification) {
    m_notifications.removeAll(pNotification);
    emit notificationClosed(pNotification);
}

void NotificationManager::slotUpdateNotifications() {
    bool timedNotificationLeft = false;

    QMutexLocker lock(&m_mutex);
    auto it = m_notifications.begin();
    while (it != m_notifications.end()) {
        const NotificationPointer pNotification = *it;
        if (pNotification->flags().testFlag(NotificationFlag::Sticky)) {
            it++;
            continue;
        }

        DEBUG_ASSERT(pNotification->lastUpdated().isValid());
        if (pNotification->lastUpdated().addSecs(
                    pNotification->timeoutSecs()) <=
                QDateTime::currentDateTimeUtc()) {
            qDebug() << "Notification timed out:" << pNotification->text();
            it = m_notifications.erase(it);
            emit notificationClosed(*it);
        } else {
            timedNotificationLeft = true;
            it++;
        }
    }
    lock.unlock();

    if (!timedNotificationLeft) {
        m_timer.stop();
    }

}

} // namespace mixxx
