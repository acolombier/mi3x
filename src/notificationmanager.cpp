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

NotificationManager* NotificationManager::s_pInstance = nullptr;
NotificationManager::NotificationManager()
        : m_inhibitNotifications(false),
          m_notificationsAddedWhileInhibited(false),
          m_notificationsClosedWhileInhibited(false) {
    m_timer.setInterval(1000);
    connect(&m_timer, &QTimer::timeout, this, &NotificationManager::slotUpdateNotifications);
    // Allow static helpers to reach the instance without pulling in
    // CoreServices (avoids a dependency cycle).
    registerInstance(this);
};

NotificationManager::~NotificationManager() = default;

void NotificationManager::notify(NotificationPointer pNotification) {
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

    if (m_inhibitNotifications) {
        m_notificationsAddedWhileInhibited = true;
    } else {
        emit notificationAdded();
    }
}

void NotificationManager::closeNotification(NotificationPointer pNotification) {
    m_notifications.removeAll(pNotification);
    if (m_inhibitNotifications) {
        m_notificationsClosedWhileInhibited = true;
    } else {
        emit notificationClosed();
    }
}

// TODO(#51): scaffolding dispatch for replacing blocking modal dialogs with
// notifications in the QML UI. The user will harden this (dedup, i18n of
// common CTAs, fallback dialogs when no GUI thread is available) once the
// remaining call sites are migrated.
NotificationPointer NotificationManager::notifySticky(
        const QString& title,
        const QString& text,
        const QVector<QPair<QString, std::function<void()>>>& buttons,
        FallbackDialog fallback) {
    if (CmdlineArgs::Instance().isQml() && s_pInstance) {
        auto pNotification = std::make_shared<Notification>(title, NotificationFlag::Sticky);
        pNotification->setDetails(text);
        for (const auto& [label, func] : buttons) {
            pNotification->addButton(label, nullptr, func);
        }
        s_pInstance->notify(pNotification);
        return pNotification;
    }

    // Legacy fallback: blocking message box, matching the pre-refactor UX.
    const QMessageBox::Icon icon = fallback == FallbackDialog::Information
            ? QMessageBox::Information
            : fallback == FallbackDialog::Warning ? QMessageBox::Warning
                                                  : QMessageBox::Critical;
    const QString textWithButtons =
            buttons.isEmpty()
            ? text
            : text + QStringLiteral("\n\n"); // TODO(#51): map CTA buttons to message box buttons
    QMessageBox message(icon, title, textWithButtons, QMessageBox::Ok, nullptr);
    message.exec();
    return nullptr;
}

NotificationPointer NotificationManager::notifyInfo(const QString& text, bool fallbackInfo) {
    Q_UNUSED(fallbackInfo);
    if (s_pInstance && CmdlineArgs::Instance().isQml()) {
        auto pNotification = std::make_shared<Notification>(text);
        s_pInstance->notify(pNotification);
        return pNotification;
    }
    qDebug() << "Notification (legacy UI):" << text;
    return nullptr;
}

void NotificationManager::slotUpdateNotifications() {
    bool changed = false;
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
            changed = true;
            it = m_notifications.erase(it);
        } else {
            timedNotificationLeft = true;
            it++;
        }
    }
    lock.unlock();

    if (!timedNotificationLeft) {
        m_timer.stop();
    }

    if (changed) {
        if (m_inhibitNotifications) {
            m_notificationsClosedWhileInhibited = true;
        } else {
            emit notificationClosed();
        }
    }
}

} // namespace mixxx
