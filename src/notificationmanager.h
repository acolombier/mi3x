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
#include "util/singleton.h"

namespace mixxx {

class NotificationManager : public QObject, public Singleton<NotificationManager> {
    Q_OBJECT

  public:
    void notify(const NotificationPointer& pNotification);

    const QList<NotificationPointer>& activeNotifications() const {
        return m_notifications;
    }

    void closeNotification(const NotificationPointer& pNotification);

  signals:
    void notificationAdded(mixxx::NotificationPointer pNotification);
    void notificationClosed(mixxx::NotificationPointer pNotification);

  protected:
    NotificationManager();
    ~NotificationManager();

    friend class Singleton<NotificationManager>;

  private slots:
    void slotUpdateNotifications();

  private:
    QTimer m_timer;
    QList<NotificationPointer> m_notifications;
    QMutex m_mutex;
};

} // namespace mixxx
