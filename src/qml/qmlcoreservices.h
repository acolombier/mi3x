#pragma once

#include <QJSEngine>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QString>

#include "library/autodj/autodjprocessor.h"
#include "notification.h"
#include "qmlapplication.h"
#include "track/track_decl.h"
#include "util/singleton.h"

class PlayerManager;
class LibraryScanResultSummary;

namespace mixxx {
class CoreServices;
namespace qml {

class QmlCoreServices : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    // Workaround for https://qt-project.atlassian.net/browse/QTBUG-87815
    // This is necessary to make touchscreen/Android usable
    Q_PROPERTY(bool hasPopup READ hasPopup NOTIFY hasPopupChanged)
    Q_PROPERTY(QQmlListProperty<mixxx::Notification> notifications READ
                    notifications NOTIFY notificationsChanged)
    QML_NAMED_ELEMENT(Core)
    QML_SINGLETON
  public:
    static QmlCoreServices* create(QQmlEngine* pQmlEngine, QJSEngine* pJsEngine);
    static void registerCoreServices(CoreServices* pCoreServices) {
        s_pCoreServices = QPointer(pCoreServices);
    }

    QQmlListProperty<mixxx::Notification> notifications();

    bool ready() const {
        return m_ready;
    }

    void setReady();

    // Workaround for https://qt-project.atlassian.net/browse/QTBUG-87815
    // This is necessary to make touchscreen/Android usable
    bool hasPopup() const {
        return !m_popups.empty();
    }
    Q_INVOKABLE void addOpenedPopup(QObject* popup);
    Q_INVOKABLE void removeOpenedPopup(QObject* popup);
    Q_INVOKABLE void clearOpenedPopup();

  signals:
    void readyChanged();
    // Workaround for https://qt-project.atlassian.net/browse/QTBUG-87815
    // This is necessary to make touchscreen/Android usable
    void hasPopupChanged();

    void notificationsChanged();
    void notificationAdded(mixxx::Notification*);
    void notificationClosed(mixxx::Notification*);

  protected:
    QmlCoreServices(QQmlEngine* pQmlEngine);
    ~QmlCoreServices() override = default;

    friend class Singleton<QmlCoreServices>;

  private slots:
    void slotTrackLoadFailed(TrackPointer pTrack, const QString& reason);
    void slotLibraryScanSummary(const LibraryScanResultSummary&);
    void slotBroadcastError(const QString& title, const QString& text);
    void slotInitialization();
    void slotNotificationAdded(mixxx::NotificationPointer);
    void slotNotificationClosed(mixxx::NotificationPointer);

  private:
    // Unlike other proxy, shared ownership is not possible with the
    // CoreServices, so we use QPointer has safety guard.
    static inline QPointer<CoreServices> s_pCoreServices;

    bool m_ready{false};
    // Workaround for https://qt-project.atlassian.net/browse/QTBUG-87815
    // This is necessary to make touchscreen/Android usable
    QSet<QObject*> m_popups;

    static void append_notification(QQmlListProperty<mixxx::Notification>* list,
            mixxx::Notification* slice);
    static qsizetype count_notification(QQmlListProperty<mixxx::Notification>* p);
    static mixxx::Notification* at_notification(
            QQmlListProperty<mixxx::Notification>* p, qsizetype idx);
    static void clear_notification(QQmlListProperty<mixxx::Notification>* p);
};

} // namespace qml
} // namespace mixxx
