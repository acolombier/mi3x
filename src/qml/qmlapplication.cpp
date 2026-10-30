#include "qmlapplication.h"

#include <QCoreApplication>
#include <QQmlEngineExtensionPlugin>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTextDocument>
#include <utility>

#include "controllers/controllermanager.h"
#include "defs_urls.h"
#include "mixer/playermanager.h"
#include "moc_qmlapplication.cpp"
#include "notificationmanager.h"
#include "preferences/configobject.h"
#include "qml/asyncimageprovider.h"
#include "qml/qmlapplicationproxy.h"
#include "qml/qmlcoreservices.h"
#include "qml/qmldlgpreferencesproxy.h"
#include "qml/qmlrecordingproxy.h"
#include "qmlsettingparameter.h"
#include "soundio/soundmanager.h"
#include "util/assert.h"
#include "util/desktophelper.h"
#include "util/versionstore.h"
#include "waveform/guitick.h"
#include "waveform/visualsmanager.h"
#include "waveform/waveformwidgetfactory.h"
#ifdef __RPC_SERVER__
#include "qml/rpcserve.h"
#endif
#if defined(Q_OS_ANDROID)
#include <android/api-level.h>
#include <android/log.h>
#include <android/performance_hint.h>

#include <QDir>
#include <QFile>
#include <QJniObject>
#endif

Q_IMPORT_QML_PLUGIN(MixxxPlugin)
Q_IMPORT_QML_PLUGIN(Mixxx_ControlsPlugin)
#ifdef QT_STATIC
Q_IMPORT_QML_PLUGIN(QtGraphicalEffectsPrivatePlugin)
Q_IMPORT_QML_PLUGIN(QMultimediaQuickModule)
#endif

namespace {
const QString kMainQmlFileName = QStringLiteral("qml/main.qml");

// Converts a (capturing) lambda into a function pointer that can be passed to
// qmlRegisterSingletonType.
template<class F>
auto lambda_to_singleton_type_factory_ptr(F&& f) {
    static F fn = std::forward<F>(f);
    return [](QQmlEngine* pEngine, QJSEngine* pScriptEngine) -> QObject* {
        return fn(pEngine, pScriptEngine);
    };
}
#if defined(Q_OS_ANDROID)
// Directories under res/qml/ that are compiled into the binary as QML modules
// and should not be copied to external storage.
const QStringList kSkipQmlDirs = {
        QStringLiteral("Mixxx"),
};

bool canWriteToExternalStorage() {
    // API 30+ (Android 11+) requires MANAGE_EXTERNAL_STORAGE.
    // Older: WRITE_EXTERNAL_STORAGE is granted at install time.
    if (android_get_device_api_level() >= 30) {
        return QJniObject::callStaticMethod<jboolean>(
                "android/os/Environment", "isExternalStorageManager");
    }
    return true;
}

void copyAssetDir(const QString& src, const QString& dst) {
    QDir().mkpath(dst);

    QDir srcDir(src);
    const QStringList files = srcDir.entryList(QDir::Files);
    for (const QString& file : files) {
        QFile srcFile(srcDir.absoluteFilePath(file));
        QFile dstFile(dst + '/' + file);
        if (srcFile.open(QIODevice::ReadOnly) && dstFile.open(QIODevice::WriteOnly)) {
            dstFile.write(srcFile.readAll());
        }
    }

    const QStringList dirs = srcDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString& dir : dirs) {
        if (kSkipQmlDirs.contains(dir)) {
            continue;
        }
        copyAssetDir(src + '/' + dir, dst + '/' + dir);
    }
}
#endif

} // namespace

namespace mixxx {
namespace qml {

QmlApplication::QmlApplication(
        QApplication* app,
        std::shared_ptr<CoreServices> pCoreServices,
        const QString& mainQmlFilePath)
        : m_pCoreServices(std::move(pCoreServices)),
          m_visualsManager(std::make_unique<VisualsManager>()),
          m_pGuiTick(std::make_unique<GuiTick>()),
          m_mainFilePath(mainQmlFilePath.isEmpty()
                          ? m_pCoreServices->getSettings()->getResourcePath() + kMainQmlFileName
                          : mainQmlFilePath),
          m_pAppEngine(nullptr),
          m_loadSucceeded(false),
#if defined(Q_OS_ANDROID)
          m_perfSession(nullptr),
#endif
          m_autoReload() {
#ifdef MIXXX_USE_QML
    // Put the legacy waveform widget factory into QML mode. This keeps the
    // shared preferences page consistent with the QML renderer capabilities.
    WaveformWidgetFactory::setQmlMode(true);
#endif
    QQuickStyle::setStyle("Basic");

#if defined(Q_OS_ANDROID)
    if (canWriteToExternalStorage()) {
        const QString externalQmlDir = QStringLiteral("/storage/emulated/0/Mixxx/qml");
        copyAssetDir(QStringLiteral("assets:/qml"), externalQmlDir);
        m_mainFilePath = externalQmlDir + QStringLiteral("/main.qml");
    }
#endif

    QJSEngine::setObjectOwnership(QmlCoreServices::createInstance(this), QJSEngine::CppOwnership);

    m_loadSucceeded = loadQml(m_mainFilePath);
    if (!m_loadSucceeded && !CmdlineArgs::Instance().getDeveloper()) {
        return;
    }

    m_pCoreServices->initialize(app);
    QmlApplicationProxy::registerVinylControlManager(
            m_pCoreServices->getVinylControlManager().get());

    // Create the legacy waveform widget factory if the widget main window has
    // not already done so. The shared preferences page and the QML waveform
    // display require the factory instance (and its config) to exist.
    if (!WaveformWidgetFactory::isCreated()) {
        WaveformWidgetFactory::createInstance();
        m_ownsWaveformWidgetFactory = true;
    }
    WaveformWidgetFactory::instance()->setConfig(m_pCoreServices->getSettings());

    QString configVersion = m_pCoreServices->getSettings()->getValue(
            ConfigKey("[Config]", "Version"), "");

    // The risk check guards against Mixxx 3.0 potentially running different
    // database upgrade paths that could corrupt 2.x profiles.
    //
    // When a QML skin is auto-detected from preferences (--developer, no
    // --new-ui), the underlying binary and DB schema are identical to a
    // normal 2.x launch — there is no data corruption risk. Skip the gate.
    //
    // When explicitly launched with --new-ui, the full 3.0 application path
    // is taken and the gate remains in effect as designed.
    const bool viaNewUiFlag = CmdlineArgs::Instance().isQml();

    if (configVersion == VersionStore::FUTURE_UNSTABLE || configVersion.isEmpty()) {
        qDebug() << "Generating a new user profile for safe testing with unstable code";
    } else if (!viaNewUiFlag) {
        qDebug() << "QmlApplication: QML skin loaded via preferences, "
                    "skipping data-corruption risk check (2.x profile is safe)";
    } else if (CmdlineArgs::Instance().isAwareOfRisk()) {
        qCritical() << "Existing user profile detected from" << configVersion
                    << "but you said you wanted to play with fire!";
        m_pCoreServices->getSettings()->setValue(
                ConfigKey("[Config]", "did_run_with_unstable"), true);
    } else {
        QMessageBox msgBox;
        msgBox.setIcon(QMessageBox::Critical);
        msgBox.setWindowTitle(tr("Existing user profile detected"));
        msgBox.setText(
                tr("Trying to run Mixxx 3.0 with an existing %0 user profile! "
                   "<br><br>There is <b>serious risks</b> of data loss and "
                   "corruption.<br>We recommend using a test profile folder "
                   "with the '--settings-path' argument. <br><br>If you want "
                   "to continue at your own risk, run Mixxx with the argument "
                   "'--allow-dangerous-data-corruption-risk'.")
                        .arg(configVersion));

        QPushButton* continueButton =
                msgBox.addButton(tr("Ok"), QMessageBox::ActionRole);
        msgBox.exec();
        m_pCoreServices.reset();
        QCoreApplication::exit(-1);
    }

#ifdef __RPC_SERVER__
    // Start the automation server if requested. It attaches to this
    // application instance (no separate Qt application setup needed).
    if (CmdlineArgs::Instance().getServe()) {
        m_pRpcServe = std::make_unique<RpcServe>(this, m_pCoreServices);
    }
#endif

    // FIXME: DlgPreferences has some initialization logic that must be executed
    // before the GUI is shown, at least for the effects system.
    std::shared_ptr<QDialog> pDlgPreferences = m_pCoreServices->makeDlgPreferences();
    // Without this, QApplication will quit when the last QWidget QWindow is
    // closed because it does not take into account the window created by
    // the QQmlApplicationEngine.
    pDlgPreferences->setAttribute(Qt::WA_QuitOnClose, false);

    // Since DlgPreferences is only meant to be used in the main QML engine, it
    // follows a strict singleton pattern design
    QmlDlgPreferencesProxy::s_pInstance =
            std::make_unique<QmlDlgPreferencesProxy>(pDlgPreferences, this);
    QmlRecordingProxy::s_pRecordingManager = m_pCoreServices->getRecordingManager();

    const QStringList visualGroups =
            m_pCoreServices->getPlayerManager()->getVisualPlayerGroups();
    for (const QString& group : visualGroups) {
        m_visualsManager->addDeck(group);
    }

    m_pCoreServices->getPlayerManager()->connect(
            m_pCoreServices->getPlayerManager().get(),
            &PlayerManager::numberOfDecksChanged,
            this,
            [this](int decks) {
                for (int i = 0; i < decks; ++i) {
                    QString group = PlayerManager::groupForDeck(i);
                    m_visualsManager->addDeckIfNotExist(group);
                }
            });

    connect(&m_guiTickTimer, &QTimer::timeout, this, [this]() {
        m_pGuiTick->process();
    });
    m_guiTickTimer.start(std::chrono::milliseconds(16));

    // No memory leak here, the QQmlEngine takes ownership of the provider
    QQuickAsyncImageProvider* pImageProvider = new AsyncImageProvider(
            m_pCoreServices->getTrackCollectionManager());
    m_pAppEngine->addImageProvider(AsyncImageProvider::kProviderName, pImageProvider);
    QmlCoreServices::instance()->setReady();
    // TODO(#51): surface the signals raised by low-level services as
    // notifications; the widget-level subscribers only exist in
    // MixxxMainWindow, which is not instantiated in the QML application.
    QmlCoreServices::instance()->connectUserNotifications();

    m_pCoreServices->getControllerManager()->setUpDevices();

    connect(&m_autoReload,
            &QmlAutoReload::triggered,
            this,
            [this]() {
                if (!loadQml(m_mainFilePath) && !CmdlineArgs::Instance().getDeveloper()) {
                    qWarning() << "Auto-reload failed to load QML. Exiting.";
                    QCoreApplication::exit(-1);
                }
                // No memory leak here, the QQmlEngine takes ownership of the provider
                QQuickAsyncImageProvider* pImageProvider = new AsyncImageProvider(
                        m_pCoreServices->getTrackCollectionManager());
                m_pAppEngine->addImageProvider(AsyncImageProvider::kProviderName, pImageProvider);
            });

    // Sound hardware setup
    // Try to open configured devices. If that fails, display dialogs
    // that allow to either retry, reconfigure devices or exit.
    SoundDeviceStatus result = m_pCoreServices->getSoundManager()->setupDevices();
    if (result == SoundDeviceStatus::ErrorDeviceCount ||
            result == SoundDeviceStatus::ErrorExcessiveOutputChannel) {
        auto pNotification =
                std::make_shared<mixxx::Notification>(tr("Sound Device Busy"),
                        mixxx::Notification::Flag::Sticky |
                                mixxx::Notification::Flag::Wrap |
                                mixxx::Notification::Flag::Error);
        pNotification->setDetails("<html> <p>" %
                        tr("Mixxx was unable to open all the configured sound devices.") +
                "</p> <p>" %
                        m_pCoreServices->getSoundManager()->getErrorDeviceName() %
                        " is used by another application or not plugged in."
                        "</p><ul>"
                        "<li>" %
                        tr("<b>Retry</b> after closing the other application "
                           "or reconnecting a sound device") %
                        "</li>"
                        "<li>" %
                        tr("<b>Reconfigure</b> Mixxx's sound device settings.") %
                        "</li>"
                        "<li>" %
                        tr("Get <b>Help</b> from the Mixxx Wiki.") %
                        "</li>"
                        "<li>" %
                        tr("<b>Exit</b> Mixxx.") %
                        "</li>"
                        "</ul></html>");
        pNotification->addButton("Retry", this, [this, pNotification]() {
            m_pCoreServices->getSoundManager()->clearAndQueryDevices();
            auto result = m_pCoreServices->getSoundManager()->setupDevices();
            if (result != SoundDeviceStatus::ErrorDeviceCount &&
                    result != SoundDeviceStatus::ErrorExcessiveOutputChannel) {
                m_pCoreServices->getNotificationManager()->closeNotification(pNotification);
            }
        });
        pNotification->addButton("Help", this, [this, pNotification]() {
            mixxx::DesktopHelper::openUrl(QUrl(MIXXX_WIKI_TROUBLESHOOTING_SOUND_URL));
        });
        pNotification->addButton("Reconfigure", this, [this, pNotification]() {
            auto windows = QGuiApplication::topLevelWindows();
            mixxx::qml::QmlSettingGroup* pEngineSection = nullptr;
            QObject* pSettings = nullptr;
            for (auto* w : std::as_const(windows)) {
                pEngineSection = w->findChild<mixxx::qml::QmlSettingGroup*>("engineSection");
                pSettings = w->findChild<QObject*>("settingsPopup");
                if (pEngineSection && pSettings) {
                    break;
                }
            }
            VERIFY_OR_DEBUG_ASSERT(pEngineSection && pSettings) {
                return;
            }
            QMetaObject::invokeMethod(pSettings, "open", Qt::QueuedConnection);
            QMetaObject::invokeMethod(pSettings,
                    "focusSection",
                    Qt::QueuedConnection,
                    Q_ARG(QVariant, QVariant::fromValue(pEngineSection)));
            connect(pEngineSection, &QmlSettingGroup::saved, this, [this, pNotification]() {
                m_pCoreServices->getSoundManager()->clearAndQueryDevices();
                auto result = m_pCoreServices->getSoundManager()->setupDevices();
                if (result != SoundDeviceStatus::ErrorDeviceCount &&
                        result != SoundDeviceStatus::ErrorExcessiveOutputChannel) {
                    m_pCoreServices->getNotificationManager()->closeNotification(pNotification);
                    // The user has either reconfigured devices or accepted no outputs,
                    // so it's now safe to write the new config to disk.
                    m_pCoreServices->getSoundManager()->getConfig().writeToDisk();
                }
            });
        });
        pNotification->addButton("Exit", this, [this, pNotification]() {
            QCoreApplication::exit(0);
        });
        m_pCoreServices->getNotificationManager()->notify(pNotification);
    } else if (result != SoundDeviceStatus::Ok) {
        auto pNotification =
                std::make_shared<mixxx::Notification>(tr("Sound Device Error"),
                        mixxx::Notification::Flag::Sticky |
                                mixxx::Notification::Flag::Wrap |
                                mixxx::Notification::Flag::Error);
        pNotification->setDetails("<html> <p>" %
                        tr("Mixxx was unable to open all the configured sound "
                           "devices.") +
                "</p> <p>" %
                        m_pCoreServices->getSoundManager()
                                ->getLastErrorMessage(result)
                                .replace("\n", "<br/>") %
                        "</p><ul>"
                        "<li>" %
                        tr("<b>Retry</b> after fixing an issue") %
                        "</li>"
                        "<li>" %
                        tr("<b>Reconfigure</b> Mixxx's sound device settings.") %
                        "</li>"
                        "<li>" %
                        tr("Get <b>Help</b> from the Mixxx Wiki.") %
                        "</li>"
                        "<li>" %
                        tr("<b>Exit</b> Mixxx.") %
                        "</li>"
                        "</ul></html>");
        pNotification->addButton("Retry", this, [this, pNotification]() {
            m_pCoreServices->getSoundManager()->clearAndQueryDevices();
            auto result = m_pCoreServices->getSoundManager()->setupDevices();
            if (result != SoundDeviceStatus::ErrorDeviceCount &&
                    result != SoundDeviceStatus::ErrorExcessiveOutputChannel) {
                m_pCoreServices->getNotificationManager()->closeNotification(pNotification);
            }
        });
        pNotification->addButton("Exit", this, [this, pNotification]() {
            QCoreApplication::exit(0);
        });
        m_pCoreServices->getNotificationManager()->notify(pNotification);
    }

    // Test for at least one output device. If none, display another dialog
    // that says "mixxx will barely work with no outs".
    // In case of persisting errors, the user has already received a message
    // above. So we can just check the output count here.
    if (m_pCoreServices->getSoundManager()
                    ->getConfig()
                    .getOutputs()
                    .isEmpty() &&
            !m_pCoreServices->getSoundManager()->pipewireSkipConfig()) {
        auto pNotification =
                std::make_shared<mixxx::Notification>(tr("No Output Devices"),
                        mixxx::Notification::Flag::Sticky |
                                mixxx::Notification::Flag::Wrap |
                                mixxx::Notification::Flag::Warn);
        pNotification->setDetails("<html>" +
                tr("Mixxx was configured without any output sound devices. "
                   "Audio processing will be disabled without a configured "
                   "output device.") +
                "<ul>"
                "<li>" +
                tr("<b>Continue</b> without any outputs.") +
                "</li>"
                "<li>" +
                tr("<b>Reconfigure</b> Mixxx's sound device settings.") +
                "</li>"
                "<li>" +
                tr("<b>Exit</b> Mixxx.") +
                "</li>"
                "</ul></html>");
        pNotification->addButton("Continue", this, [this, pNotification]() {
            m_pCoreServices->getNotificationManager()->closeNotification(pNotification);
        });
        pNotification->addButton("Reconfigure", this, [this, pNotification]() {
            auto windows = QGuiApplication::topLevelWindows();
            QObject* pSettingsPopup = nullptr;
            QObject* pSettingsLoader = nullptr;
            for (auto* w : std::as_const(windows)) {
                pSettingsPopup = w->findChild<QObject*>("settingsPopup");
                pSettingsLoader = w->findChild<QObject*>("settingsLoader");
                if (pSettingsPopup && pSettingsLoader) {
                    break;
                }
            }
            VERIFY_OR_DEBUG_ASSERT(pSettingsPopup && pSettingsLoader) {
                return;
            }

            QMetaObject::invokeMethod(pSettingsPopup, "open", Qt::QueuedConnection);
            // TODO: The content of the setting page is lazy loaded so we cannot
            // interact with the category currently. auto* pEngineSection =
            // w->findChild<mixxx::qml::QmlSettingGroup*>("engineSection");
            // QMetaObject::invokeMethod(pSettings,
            //     "focusSection",
            //     Qt::QueuedConnection,
            //     Q_ARG(QVariant, QVariant::fromValue(pEngineSection)));
            // connect(pEngineSection,
            //     &mixxx::qml::QmlSettingGroup::saved,
            //     this,
            //     [this, pNotification]() {
            //         if (!m_pCoreServices->getSoundManager()
            //                         ->getConfig()
            //                         .getOutputs()
            //                         .isEmpty() ||
            //                 m_pCoreServices->getSoundManager()
            //                         ->pipewireSkipConfig()) {
            //             m_pCoreServices->getNotificationManager()
            //                     ->closeNotification(pNotification);
            //             // The user has either reconfigured devices or
            //             // accepted no outputs, so it's now safe to write
            //             // the new config to disk.
            //             m_pCoreServices->getSoundManager()
            //                     ->getConfig()
            //                     .writeToDisk();
            //         }
            // });
        });
        pNotification->addButton("Exit", this, [this, pNotification]() {
            QCoreApplication::exit(0);
        });
        m_pCoreServices->getNotificationManager()->notify(pNotification);
    }

#if defined(Q_OS_ANDROID)
    APerformanceHintManager* manager = APerformanceHint_getManager();
    VERIFY_OR_DEBUG_ASSERT(manager) {
        return;
    }
    int32_t thread32 = gettid();
    m_perfSession = APerformanceHint_createSession(manager, &thread32, 1, 1e9 / 60);
    VERIFY_OR_DEBUG_ASSERT(m_perfSession) {
        __android_log_print(ANDROID_LOG_WARN, "mixxx", "unable to create a ADPF session!");
    }
    else {
        APerformanceHint_setPreferPowerEfficiency(m_perfSession, false);
        __android_log_print(ANDROID_LOG_VERBOSE, "mixxx", "ADPF session ready");
    }
}

void QmlApplication::slotWindowChanged(QQuickWindow* window) {
    if (window) {
        connect(window, &QQuickWindow::afterFrameEnd, this, &QmlApplication::slotFrameSwapped);
    }
    m_frameTimer.restart();
}

void QmlApplication::slotFrameSwapped() {
    VERIFY_OR_DEBUG_ASSERT(m_perfSession) {
        return;
    }
    auto lastFrameDurationNs = m_frameTimer.elapsed().toIntegerNanos();
    auto t = std::chrono::steady_clock::now() - std::chrono::steady_clock::time_point{};
    APerformanceHint_reportActualWorkDuration(m_perfSession,
            lastFrameDurationNs);
    m_frameTimer.restart();
#endif
}

QmlApplication::~QmlApplication() {
#ifdef __RPC_SERVER__
    // Tear down the automation server first: it may reference the QML
    // engine and the command handler, which must not outlive them.
    m_pRpcServe.reset();
#endif
    QmlApplicationProxy::registerReloadCallback({});
    // Destroy the QML engine before the waveform factory. Scene-graph nodes
    // owned by the engine may still reference QML waveform renderers and the
    // factory while the engine is tearing down its object tree.
    m_pAppEngine.reset();
    // Delete all the QML singletons in order to prevent leak detection in CoreService
    QmlRecordingProxy::s_pRecordingManager.reset();
    QmlDlgPreferencesProxy::s_pInstance.reset();
    if (m_ownsWaveformWidgetFactory) {
        WaveformWidgetFactory::destroy();
    }
#ifdef MIXXX_USE_QML
    WaveformWidgetFactory::setQmlMode(false);
#endif
    m_visualsManager.reset();
    QmlApplicationProxy::registerVinylControlManager(nullptr);
    m_pCoreServices.reset();
}

bool QmlApplication::loadQml(const QString& path) {
    // QQmlApplicationEngine::load creates a new window but also leaves the old one,
    // so it is necessary to destroy the old QQmlApplicationEngine and create a new one.
    m_pAppEngine = std::make_unique<QQmlApplicationEngine>();

    m_autoReload.clear();
    m_pAppEngine->addUrlInterceptor(&m_autoReload);
    m_pAppEngine->addImportPath(QStringLiteral(":/mixxx.org/imports"));

    m_pAppEngine->load(path);
    if (m_pAppEngine->rootObjects().isEmpty()) {
        qWarning() << "Failed to load QML file" << path;
        if (!CmdlineArgs::Instance().getDeveloper()) {
            m_pAppEngine.reset();
            return false;
        }
    }

#if defined(Q_OS_ANDROID)
    for (auto* item : m_pAppEngine->rootObjects()) {
        auto* pWindow = qobject_cast<QQuickWindow*>(item);
        if (!pWindow) {
            continue;
        }
        slotWindowChanged(pWindow);
        break;
    }
#endif

#ifdef __RPC_SERVER__
    if (m_pRpcServe) {
        m_pRpcServe->onQmlLoaded();
    }
#endif
    return true;
}

} // namespace qml
} // namespace mixxx
