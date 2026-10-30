#include <gtest/gtest.h>

#include <QDialog>
#include <QEvent>
#include <QFile>
#include <QFileDialog>
#include <QTemporaryDir>
#include <QTimer>
#include <memory>
#include <vector>

#include "control/controlobject.h"
#include "coreservices.h"
#include "qml/qmllibraryproxy.h"
#include "qml/qmltrackproxy.h"
#include "test/mixxxtest.h"
#include "track/beats.h"
#include "track/track.h"
#include "util/cmdlineargs.h"
#include "util/versionstore.h"

namespace {

class RejectFileDialogs final : public QObject {
  protected:
    bool eventFilter(QObject* watched, QEvent* event) override {
        if (event->type() == QEvent::Show) {
            if (auto* dialog = qobject_cast<QFileDialog*>(watched)) {
                QTimer::singleShot(0, dialog, &QDialog::reject);
            }
        }
        return false;
    }
};

void writeTestProfile(const QString& settingsPath) {
    auto settings = UserSettingsPointer(new UserSettings(settingsPath + "mixxx.cfg"));
    settings->setValue(ConfigKey("[Config]", "Version"), VersionStore::FUTURE_UNSTABLE);
    settings->save();

    QFile soundConfig(settingsPath + "soundconfig.xml");
    ASSERT_TRUE(soundConfig.open(QIODevice::WriteOnly | QIODevice::Truncate));
    ASSERT_GT(soundConfig.write("<SoundManagerConfig api=\"None\"/>\n"), 0);
}

class QmlLibraryProxyTest : public MixxxTest {
  protected:
    void SetUp() override {
        m_previousArgs = CmdlineArgs::Instance();
        ASSERT_TRUE(m_profile.isValid());

        const QString settingsPath = m_profile.path() + QLatin1Char('/');
        writeTestProfile(settingsPath);

        CmdlineArgs::Instance().setSettingsPath(settingsPath);
        CmdlineArgs args;
        args.setSettingsPath(settingsPath);

        m_rejectFileDialogs = std::make_unique<RejectFileDialogs>();
        application()->installEventFilter(m_rejectFileDialogs.get());
        m_coreServices = std::make_shared<mixxx::CoreServices>(args, application());
        m_coreServices->initialize(application());
        application()->removeEventFilter(m_rejectFileDialogs.get());

        m_proxy = std::make_unique<mixxx::qml::QmlLibraryProxy>(m_coreServices->getLibrary());
    }

    void TearDown() override {
        m_proxy.reset();
        m_coreServices.reset();
        if (m_rejectFileDialogs) {
            application()->removeEventFilter(m_rejectFileDialogs.get());
            m_rejectFileDialogs.reset();
        }
        CmdlineArgs::Instance() = m_previousArgs;
    }

    void setDeckControl(const QString& key, double value) {
        const ConfigKey configKey(QStringLiteral("[Channel1]"), key);
        if (!ControlObject::exists(configKey)) {
            m_testControls.emplace_back(std::make_unique<ControlObject>(configKey));
        }
        ControlObject::set(configKey, value);
    }

    std::unique_ptr<mixxx::qml::QmlLibraryProxy> m_proxy;

  private:
    QTemporaryDir m_profile;
    CmdlineArgs m_previousArgs;
    std::unique_ptr<RejectFileDialogs> m_rejectFileDialogs;
    std::shared_ptr<mixxx::CoreServices> m_coreServices;
    std::vector<std::unique_ptr<ControlObject>> m_testControls;
};

} // namespace
