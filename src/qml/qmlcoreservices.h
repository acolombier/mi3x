#pragma once

#include <QJSEngine>
#include <QObject>
#include <QQmlEngine>
#include <QString>
<<<<<<< HEAD
#include <utility>

#include "util/singleton.h"

        == == ==
        =

#include "util/singleton.h"

                class RecordingManager;

>>>>>>> origin/feat/qml
namespace mixxx {
namespace qml {

class QmlCoreServices : public QObject, public Singleton<QmlCoreServices> {
    Q_OBJECT
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
<<<<<<< HEAD
    Q_PROPERTY(int initializationProgress READ initializationProgress NOTIFY
                    initializationProgressChanged)
    Q_PROPERTY(QString initializationService READ initializationService NOTIFY
                    initializationServiceChanged)
    Q_PROPERTY(QString colorScheme READ colorScheme CONSTANT)
    QML_NAMED_ELEMENT(Core)
    QML_SINGLETON
  public:
    explicit QmlCoreServices(QString colorScheme, QObject* parent)
            : QObject(parent),
              m_colorScheme(std::move(colorScheme)) {
=======
    // Workaround for https://qt-project.atlassian.net/browse/QTBUG-87815
    // This is necessary to make touchscreen/Android usable
    Q_PROPERTY(bool hasPopup READ hasPopup NOTIFY hasPopupChanged)
    QML_NAMED_ELEMENT(Core)
    QML_SINGLETON
  public:
    explicit QmlCoreServices(QObject* parent)
            : QObject(parent) {
>>>>>>> origin/feat/qml
    }
    ~QmlCoreServices() override = default;

    static QmlCoreServices* create(QQmlEngine* pQmlEngine, QJSEngine* pJsEngine);

    bool ready() const {
        return m_ready;
    }

<<<<<<< HEAD
    int initializationProgress() const {
        return m_initializationProgress;
    }

    QString initializationService() const {
        return m_initializationService;
    }

    QString colorScheme() const {
        return m_colorScheme;
    }

    void setReady();
    void setInitializationProgress(int progress, const QString& service);

  signals:
    void readyChanged();
    void initializationProgressChanged();
    void initializationServiceChanged();

  private:
    bool m_ready{false};
    int m_initializationProgress{0};
    QString m_initializationService;
    const QString m_colorScheme;
=======
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

  private:
    bool m_ready{false};
    // Workaround for https://qt-project.atlassian.net/browse/QTBUG-87815
    // This is necessary to make touchscreen/Android usable
    QSet<QObject*> m_popups;
>>>>>>> origin/feat/qml
};

} // namespace qml
} // namespace mixxx
