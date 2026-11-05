#pragma once

#include <qqmlcomponent.h>

#include <QJSEngine>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QString>

#include "coreservices.h"
#include "notification.h"
#include "track/track_decl.h"

class LibraryScanResultSummary;

namespace mixxx {
class CoreServices;
namespace qml {

class QmlColorPalette : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(ColorPalette)
  public:
    explicit QmlColorPalette(QObject* parent = nullptr)
            : QObject(parent) {
    }
    ~QmlColorPalette() override = default;
};

class QmlSkin : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(Skin)
    Q_PROPERTY(QString name MEMBER m_name NOTIFY nameChanged)
    Q_PROPERTY(QString version MEMBER m_version NOTIFY versionChanged)
    Q_PROPERTY(QString description MEMBER m_description NOTIFY descriptionChanged)
    Q_PROPERTY(QQmlListProperty<mixxx::qml::QmlColorPalette> colorPalettes READ
                    colorPalettes NOTIFY colorPalettesChanged)
    Q_PROPERTY(uint defaultHeight MEMBER m_defaultHeight NOTIFY defaultHeightChanged)
    Q_PROPERTY(uint defaultWidth MEMBER m_defaultWidth NOTIFY defaultWidthChanged)
    Q_PROPERTY(uint minimumWidth MEMBER m_minimumWidth NOTIFY minimumWidthChanged)
    Q_PROPERTY(uint minimumHeight MEMBER m_minimumHeight NOTIFY minimumHeightChanged)
    Q_PROPERTY(QQmlComponent* main MEMBER m_main NOTIFY mainChanged)
    Q_PROPERTY(QQmlComponent* loader MEMBER m_loader NOTIFY loaderChanged)
  public:
    explicit QmlSkin(QObject* parent = nullptr);
    ~QmlSkin() override;

    QQmlListProperty<mixxx::qml::QmlColorPalette> colorPalettes() {
        return {this, &m_colorPalettes};
    }
  signals:
    void mainChanged();
    void loaderChanged();
    void nameChanged();
    void versionChanged();
    void descriptionChanged();
    void colorPalettesChanged();
    void defaultHeightChanged();
    void defaultWidthChanged();
    void minimumWidthChanged();
    void minimumHeightChanged();

  private:
    QQmlComponent* m_main;
    QQmlComponent* m_loader;
    QString m_name;
    QString m_version;
    QString m_description;
    QList<mixxx::qml::QmlColorPalette*> m_colorPalettes;
    uint m_defaultHeight;
    uint m_defaultWidth;
    uint m_minimumWidth;
    uint m_minimumHeight;
};

class QmlCoreServices : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    // Workaround for https://qt-project.atlassian.net/browse/QTBUG-87815
    // This is necessary to make touchscreen/Android usable
    Q_PROPERTY(bool hasPopup READ hasPopup NOTIFY hasPopupChanged)
    Q_PROPERTY(QQmlListProperty<mixxx::Notification> notifications READ
                    notifications NOTIFY notificationsChanged)
    Q_PROPERTY(QList<mixxx::qml::QmlSkin*> skins READ getSkins NOTIFY skinsChanged)
    // Q_PROPERTY(QmlSkin* selectedSkin READ getSelectedSkin NOTIFY selectedSkinChanged)
    QML_NAMED_ELEMENT(Core)
    QML_SINGLETON
  public:
    static QmlCoreServices* create(QQmlEngine* pQmlEngine, QJSEngine* pJsEngine);
    static void registerCoreServices(CoreServices* pCoreServices) {
        s_pCoreServices = QPointer(pCoreServices);
    }

    QQmlListProperty<mixxx::Notification> notifications();
    QList<mixxx::qml::QmlSkin*> getSkins() const {
        return m_pSkins.values();
    }

    bool ready() const {
        return m_ready;
    }

    void setReady();
    QmlSkin* getSelectedSkin();

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

    void skinsChanged();

  protected:
    QmlCoreServices(QQmlEngine* pQmlEngine);
    ~QmlCoreServices() override = default;

  private slots:
    void slotTrackLoadFailed(TrackPointer pTrack, const QString& reason);
    void slotLibraryScanSummary(const LibraryScanResultSummary&);
    void slotBroadcastError(const QString& title, const QString& text);
    void slotInitialization();
    void slotNotificationAdded(mixxx::NotificationPointer);
    void slotNotificationClosed(mixxx::NotificationPointer);
    void slotSkinLoaded(const QUrl& fileInfo, QQmlComponent::Status status);

  private:
    // Unlike other proxy, shared ownership is not possible with the
    // CoreServices, so we use QPointer has safety guard.
    static inline QPointer<CoreServices> s_pCoreServices;

    bool m_ready{false};
    // Workaround for https://qt-project.atlassian.net/browse/QTBUG-87815
    // This is necessary to make touchscreen/Android usable
    QSet<QObject*> m_popups;

    QMap<QUrl, QQmlComponent*> m_skinManifests;
    QMap<QUrl, QmlSkin*> m_pSkins;

    static void append_notification(QQmlListProperty<mixxx::Notification>* list,
            mixxx::Notification* slice);
    static qsizetype count_notification(QQmlListProperty<mixxx::Notification>* p);
    static mixxx::Notification* at_notification(
            QQmlListProperty<mixxx::Notification>* p, qsizetype idx);
    static void clear_notification(QQmlListProperty<mixxx::Notification>* p);
};

} // namespace qml
} // namespace mixxx
