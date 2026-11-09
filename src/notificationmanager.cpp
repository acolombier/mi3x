#include "notificationmanager.h"

#include <QDebug>
#include <QMessageBox>
#include <QMetaObject>
#include <QMutexLocker>
#include <QPointer>
#include <QThread>

#include "moc_notificationmanager.cpp"
#include "util/assert.h"
#include "util/cmdlineargs.h"
#include "util/thread_affinity.h"

namespace {

constexpr int kAutoTimeoutSecs = 10;
}

namespace mixxx {

NotificationManager::NotificationManager()
        : m_timer() {
    m_timer.setInterval(1000);
    connect(&m_timer, &QTimer::timeout, this, &NotificationManager::slotUpdateNotifications);
};

NotificationManager::~NotificationManager() = default;

void NotificationManager::notify(const NotificationPointer& pNotification) {
    VERIFY_OR_DEBUG_ASSERT(pNotification) {
        return;
    }

    if (QThread::currentThread() != thread()) {
        QMetaObject::invokeMethod(
                this,
                [this, pNotification]() {
                    notify(pNotification);
                },
                Qt::QueuedConnection);
        return;
    }

    qDebug() << "New notification:" << pNotification->text();

    if (!pNotification->lastUpdated().isValid()) {
        pNotification->setLastUpdated(QDateTime::currentDateTimeUtc());
    }

    if (!pNotification->flags().testFlag(Notification::Flag::Sticky)) {
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

void NotificationManager::clear() {
    QList<NotificationPointer> notificationsToClose;
    {
        QMutexLocker lock(&m_mutex);
        auto it = m_notifications.begin();
        while (it != m_notifications.end()) {
            if ((*it)->flags().testFlag(Notification::Flag::Sticky)) {
                ++it;
                continue;
            }
            notificationsToClose.append(*it);
            it = m_notifications.erase(it);
        }
    }

    for (const auto& pNotification : std::as_const(notificationsToClose)) {
        emit notificationClosed(pNotification);
    }

    // Ensure slotUpdateNotifications is run on this object's thread
    QMetaObject::invokeMethod(this,
            &NotificationManager::slotUpdateNotifications,
            Qt::AutoConnection);
}

void NotificationManager::closeNotification(const NotificationPointer& pNotification) {
    QMutexLocker lock(&m_mutex);
    m_notifications.removeAll(pNotification);
    lock.unlock();

    // Ensure slotUpdateNotifications is run on this object's thread
    QMetaObject::invokeMethod(this,
            &NotificationManager::slotUpdateNotifications,
            Qt::AutoConnection);
    emit notificationClosed(pNotification);
}

void NotificationManager::slotUpdateNotifications() {
    DEBUG_ASSERT_THIS_QOBJECT_THREAD_AFFINITY();
    bool timedNotificationLeft = false;
    QList<NotificationPointer> notificationsToClose;

    QMutexLocker lock(&m_mutex);
    auto it = m_notifications.begin();
    while (it != m_notifications.end()) {
        const NotificationPointer pNotification = *it;
        if (pNotification->flags().testFlag(Notification::Flag::Sticky)) {
            it++;
            continue;
        }

        DEBUG_ASSERT(pNotification->lastUpdated().isValid());
        if (pNotification->lastUpdated().addSecs(
                    pNotification->timeoutSecs()) <=
                QDateTime::currentDateTimeUtc()) {
            qDebug() << "Notification timed out:" << pNotification->text();
            notificationsToClose.append(pNotification);
            it = m_notifications.erase(it);
        } else {
            timedNotificationLeft = true;
            it++;
        }
    }
    lock.unlock();

    for (const auto& pNotification : std::as_const(notificationsToClose)) {
        emit notificationClosed(pNotification);
    }

    if (!timedNotificationLeft) {
        m_timer.stop();
    }
}

} // namespace mixxx
