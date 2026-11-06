#pragma once

#include <QJSEngine>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QString>

#include "coreservices.h"
#include "track/track_decl.h"

class LibraryScanResultSummary;

namespace mixxx {
namespace qml {

class QmlCoreServices : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    // Workaround for https://qt-project.atlassian.net/browse/QTBUG-87815
    // This is necessary to make touchscreen/Android usable
    Q_PROPERTY(bool hasPopup READ hasPopup NOTIFY hasPopupChanged)
    QML_NAMED_ELEMENT(Core)
    QML_SINGLETON
  public:
    static QmlCoreServices* create(QQmlEngine* pQmlEngine, QJSEngine* pJsEngine);
    static void registerCoreServices(CoreServices* pCoreServices) {
        s_pCoreServices = QPointer(pCoreServices);
    }

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

  protected:
    QmlCoreServices(QQmlEngine* pQmlEngine);
    ~QmlCoreServices() override = default;
  private slots:
    void slotTrackLoadFailed(TrackPointer pTrack, const QString& reason);
    void slotLibraryScanSummary(const LibraryScanResultSummary&);
    void slotInitialization();

  private:
    // Unlike other proxy, shared ownership is not possible with the
    // CoreServices, so we use QPointer has safety guard.
    static inline QPointer<CoreServices> s_pCoreServices;

    bool m_ready{false};
    // Workaround for https://qt-project.atlassian.net/browse/QTBUG-87815
    // This is necessary to make touchscreen/Android usable
    QSet<QObject*> m_popups;
};

} // namespace qml
} // namespace mixxx
