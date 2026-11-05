#include "qmlapplication.h"

#include <QCoreApplication>
#include <QQmlContext>
#include <QQmlEngineExtensionPlugin>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTextDocument>
#include <optional>
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
        const CmdlineArgs& args)
        : m_pCoreServices(std::make_unique<mixxx::CoreServices>(args, app)),
          m_visualsManager(std::make_unique<VisualsManager>()),
          m_pGuiTick(std::make_unique<GuiTick>()),
          m_mainFilePath(m_pCoreServices->getSettings()->getResourcePath() + kMainQmlFileName),
          m_pAppEngine(nullptr),
          m_loadSucceeded(false),
          m_pSettingsPopup(nullptr),
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

    QmlCoreServices::registerCoreServices(m_pCoreServices.get());

    m_loadSucceeded = loadQml(m_mainFilePath);
    if (!m_loadSucceeded && !CmdlineArgs::Instance().getDeveloper()) {
        return;
    }

    m_pCoreServices->initialize();
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
        m_pRpcServe = std::make_unique<RpcServe>(this, m_pCoreServices.get());
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
    std::optional<std::pair<QString, QString>> titleAndText;
    mixxx::Notification::Flags notificationFlags;
    bool showContinue = false, showHelp = false;
    // Predicate to indicate whether the issue is resolved and the notification can be closed
    std::function<bool(SoundDeviceStatus)> showRetry = nullptr, showReconfig = nullptr;
    if (result == SoundDeviceStatus::ErrorDeviceCount ||
            result == SoundDeviceStatus::ErrorExcessiveOutputChannel) {
        titleAndText = SoundManager::soundDeviceBusyMessageBuilder(
                m_pCoreServices->getSoundManager()->getErrorDeviceName());
        notificationFlags = mixxx::Notification::Flag::Sticky |
                mixxx::Notification::Flag::Wrap |
                mixxx::Notification::Flag::Error;
        showRetry = [](SoundDeviceStatus result) {
            return !(result == SoundDeviceStatus::ErrorDeviceCount ||
                    result == SoundDeviceStatus::ErrorExcessiveOutputChannel);
        };
        showHelp = true;
        showReconfig = showRetry;
    } else if (result != SoundDeviceStatus::Ok) {
        titleAndText = SoundManager::soundDeviceErrorMessageBuilder(
                m_pCoreServices->getSoundManager()->getLastErrorMessage(
                        result));
        notificationFlags = mixxx::Notification::Flag::Sticky |
                mixxx::Notification::Flag::Wrap |
                mixxx::Notification::Flag::Error;
        showRetry = [](SoundDeviceStatus result) {
            return result == SoundDeviceStatus::Ok;
        };
    } else if (m_pCoreServices->getSoundManager()
                       ->getConfig()
                       .getOutputs()
                       .isEmpty() &&
            !m_pCoreServices->getSoundManager()->pipewireSkipConfig()) {
        titleAndText = SoundManager::soundDeviceNoOutputMessageBuilder();
        notificationFlags = mixxx::Notification::Flag::Sticky |
                mixxx::Notification::Flag::Wrap |
                mixxx::Notification::Flag::Warn;
        showContinue = true;
        showReconfig = [this](SoundDeviceStatus result) {
            return result == SoundDeviceStatus::Ok &&
                    !m_pCoreServices->getSoundManager()
                             ->getConfig()
                             .getOutputs()
                             .isEmpty() &&
                    !m_pCoreServices->getSoundManager()->pipewireSkipConfig();
        };
    }
    if (titleAndText) {
        auto pNotification =
                std::make_shared<mixxx::Notification>(titleAndText->first, notificationFlags);
        pNotification->setDetails(titleAndText->second);

        if (showContinue) {
            pNotification->addButton(tr("Continue"), this, [this, pNotification]() {
                NotificationManager::instance()->closeNotification(pNotification);
            });
        }
        if (showRetry) {
            pNotification->addButton(tr("Retry"),
                    this,
                    [this, pNotification, showRetry = std::move(showRetry)]() {
                        // FIXME alsa will freeze for 5 second. Plus the setting
                        // was already applied so this lead to double op
                        m_pCoreServices->getSoundManager()
                                ->clearAndQueryDevices();
                        if (showRetry(m_pCoreServices->getSoundManager()
                                            ->setupDevices())) {
                            NotificationManager::instance()
                                    ->closeNotification(pNotification);
                        }
                    });
        }
        if (showHelp) {
            pNotification->addButton(tr("Help"), this, [this, pNotification]() {
                mixxx::DesktopHelper::openUrl(QUrl(MIXXX_WIKI_TROUBLESHOOTING_SOUND_URL));
            });
        }
        if (showReconfig) {
            pNotification->addButton(tr("Reconfigure"),
                    this,
                    [this,
                            pNotification,
                            showReconfig = std::move(showReconfig)]() {
                        VERIFY_OR_DEBUG_ASSERT(m_pSettingsPopup) {
                            return;
                        }
                        QMetaObject::invokeMethod(
                                m_pSettingsPopup, "open", Qt::QueuedConnection);
                        QMetaObject::invokeMethod(m_pSettingsPopup,
                                "focusSection",
                                Qt::QueuedConnection,
                                Q_ARG(QVariant,
                                        QVariant::fromValue(
                                                QStringList({"soundHardware",
                                                        "routerGroup"}))));
                        connect(
                                this,
                                &QmlApplication::settingSaved,
                                this,
                                [this, pNotification, showReconfig]() {
                                    // FIXME alsa will freeze for 5 second. Plus
                                    // the setting was already applied so this
                                    // lead to double op
                                    m_pCoreServices->getSoundManager()
                                            ->clearAndQueryDevices();
                                    if (showReconfig(m_pCoreServices
                                                        ->getSoundManager()
                                                        ->setupDevices())) {
                                        NotificationManager::instance()
                                                ->closeNotification(
                                                        pNotification);
                                        // The user has either reconfigured
                                        // devices or accepted no outputs, so
                                        // it's now safe to write the new config
                                        // to disk.
                                        m_pCoreServices->getSoundManager()
                                                ->getConfig()
                                                .writeToDisk();
                                    }
                                },
                                Qt::SingleShotConnection);
                    });
        }
        pNotification->addButton(tr("Exit"), this, [this, pNotification]() {
            QCoreApplication::exit(0);
        });
        NotificationManager::instance()->notify(pNotification);
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
    disconnect(&m_guiTickTimer);
    m_guiTickTimer.stop();
    m_pGuiTick.reset();
    m_pCoreServices.reset();
}

bool QmlApplication::loadQml(const QString& path) {
    // QQmlApplicationEngine::load creates a new window but also leaves the old one,
    // so it is necessary to destroy the old QQmlApplicationEngine and create a new one.
    m_pAppEngine = std::make_unique<QQmlApplicationEngine>();
    m_pSettingsPopup = nullptr;

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

    const auto& rootObjects = m_pAppEngine->rootObjects();
    for (auto* item : std::as_const(rootObjects)) {
        auto* pWindow = qobject_cast<QQuickWindow*>(item);
        if (!pWindow) {
            continue;
        }
        m_pSettingsPopup = m_pAppEngine->contextForObject(item)->objectForName("settingsPopup");
#if defined(Q_OS_ANDROID)
        slotWindowChanged(pWindow);
#endif
        break;
    }
    DEBUG_ASSERT(m_pSettingsPopup);

    if (m_pSettingsPopup) {
        const QMetaObject* meta = m_pSettingsPopup->metaObject();
        int signalIndex = meta->indexOfSignal(
                "saved(QVariant)");
        DEBUG_ASSERT(signalIndex >= 0);
        if (signalIndex >= 0) {
            QMetaMethod signalMethod = meta->method(signalIndex);
            connect(m_pSettingsPopup,
                    signalMethod,
                    this,
                    QMetaMethod::fromSignal(&QmlApplication::settingSaved));
        }
    }

#ifdef __RPC_SERVER__
    if (m_pRpcServe) {
        m_pRpcServe->onQmlLoaded();
    }
#endif
    return true;
}

} // namespace qml
} // namespace mixxx
