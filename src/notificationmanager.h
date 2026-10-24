#pragma once
#include <QDateTime>
#include <QList>
#include <QMultiMap>
#include <QMutex>
#include <QObject>
#include <QString>
#include <QTimer>
#include <memory>

#include "notification.h"

namespace mixxx {

class NotificationManager : public QObject {
    Q_OBJECT

  public:
    NotificationManager();
    ~NotificationManager();

    // TODO(#51): scaffolding for replacing blocking message boxes with
    // notifications in the QML UI. Register the instance created by
    // CoreServices so static helpers can reach it from anywhere.
    static void registerInstance(NotificationManager* pManager) {
        s_pInstance = pManager;
    }

    static NotificationManager* instance() {
        return s_pInstance;
    }

    // Show a sticky (non-auto-dismissing) notification with optional CTA
    // buttons in the QML UI. Falls back to QWidget message boxes when the
    // legacy UI is active so that call sites do not have to branch.
    enum class FallbackDialog {
        Information,
        Warning,
        Critical,
    };
    static NotificationPointer notifySticky(
            const QString& title,
            const QString& text,
            const QVector<QPair<QString, std::function<void()>>>& buttons,
            FallbackDialog fallback = FallbackDialog::Warning);
    static NotificationPointer notifyInfo(const QString& text, bool fallbackInfo = false);

    void notify(NotificationPointer pNotification);

    const QList<NotificationPointer>& activeNotifications() const {
        return m_notifications;
    }

    void setInhibitNotifications(bool value) {
        if (m_inhibitNotifications == value) {
            return;
        }
        m_inhibitNotifications = value;
        if (m_inhibitNotifications) {
            m_notificationsAddedWhileInhibited = false;
            m_notificationsClosedWhileInhibited = false;
        } else {
            if (m_notificationsClosedWhileInhibited) {
                emit notificationClosed();
            }
            if (m_notificationsAddedWhileInhibited) {
                emit notificationAdded();
            }
        }
    }

    void closeNotification(NotificationPointer pNotification);

  signals:
    void notificationAdded();
    void notificationClosed();

  private slots:
    void slotUpdateNotifications();

  private:
    QTimer m_timer;
    QList<NotificationPointer> m_notifications;
    QMutex m_mutex;

    bool m_inhibitNotifications;
    bool m_notificationsAddedWhileInhibited;
    bool m_notificationsClosedWhileInhibited;

    static NotificationManager* s_pInstance;
};

} // namespace mixxx
