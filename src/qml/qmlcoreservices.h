#pragma once

#include <QJSEngine>
#include <QObject>
#include <QQmlEngine>
#include <QString>

#include "notification.h"
#include "util/singleton.h"

namespace mixxx {
class CoreServices;
namespace qml {

class QmlCoreServices : public QObject, public Singleton<QmlCoreServices> {
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
    explicit QmlCoreServices(std::shared_ptr<::mixxx::CoreServices> pCoreServices);
    ~QmlCoreServices() override = default;

    static QmlCoreServices* create(QQmlEngine* pQmlEngine, QJSEngine* pJsEngine);

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
    // void notificationAdded();
    // void notificationClosed();

    void notificationsChanged();

  private:
    bool m_ready{false};
    // Workaround for https://qt-project.atlassian.net/browse/QTBUG-87815
    // This is necessary to make touchscreen/Android usable
    QSet<QObject*> m_popups;
    std::shared_ptr<::mixxx::CoreServices> m_pInternal;

    static void append_notification(QQmlListProperty<mixxx::Notification>* list,
            mixxx::Notification* slice);
    static qsizetype count_notification(QQmlListProperty<mixxx::Notification>* p);
    static mixxx::Notification* at_notification(
            QQmlListProperty<mixxx::Notification>* p, qsizetype idx);
    static void clear_notification(QQmlListProperty<mixxx::Notification>* p);
};

} // namespace qml
} // namespace mixxx
