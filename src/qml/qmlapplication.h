#pragma once

#include <QApplication>
#include <QQmlApplicationEngine>
#include <QTimer>

#include "coreservices.h"
#include "qmlautoreload.h"

class GuiTick;
class VisualsManager;
#if defined(Q_OS_ANDROID)
class QQuickWindow;
class APerformanceHintSession;
#endif

namespace mixxx {
namespace qml {
#ifdef __RPC_SERVER__
class RpcServe;
#endif

class QmlApplication : public QObject {
    Q_OBJECT
  public:
    QmlApplication(
            QApplication* app,
            const CmdlineArgs& args);
    ~QmlApplication() override;

    bool isReady() const {
        return m_loadSucceeded;
    }

    QQmlApplicationEngine* qmlEngine() const {
        return m_pAppEngine.get();
    }

    const QString& mainFilePath() const {
        return m_mainFilePath;
    }

  public slots:
    bool loadQml(const QString& path);

#if defined(Q_OS_ANDROID)
  private slots:
    void slotFrameSwapped();
    void slotWindowChanged(QQuickWindow* window);
#endif
  signals:
    void settingSaved();

  private:
    std::unique_ptr<CoreServices> m_pCoreServices;
    std::unique_ptr<::VisualsManager> m_visualsManager;
    std::unique_ptr<GuiTick> m_pGuiTick;
    QTimer m_guiTickTimer;

    QString m_mainFilePath;

    std::unique_ptr<QQmlApplicationEngine> m_pAppEngine;
    bool m_ownsWaveformWidgetFactory{false};
    bool m_loadSucceeded;
    QmlAutoReload m_autoReload;
    // reference to the setting popup. Owned by the QML scene
    QObject* m_pSettingsPopup;

#ifdef __RPC_SERVER__
    // Automation server (--serve); created on demand at the end of the
    // constructor, destroyed before the QML engine in the destructor.
    std::unique_ptr<RpcServe> m_pRpcServe;
#endif

#if defined(Q_OS_ANDROID)
    // The following are necessary to implement the performance manager
    // (https://developer.android.com/ndk/reference/group/a-performance-hint)
    // This helps the system automatically adjust performance and prevent frame
    // drops
    PerformanceTimer m_frameTimer;
    APerformanceHintSession* m_perfSession;
#endif
};

} // namespace qml
} // namespace mixxx
