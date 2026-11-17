#include <gtest/gtest.h>

#include <QDialog>
#include <QEvent>
#include <QFile>
#include <QFileDialog>
#include <QString>
#include <QTemporaryDir>
#include <QTimer>
#include <algorithm>
#include <string>

#include "preferences/configobject.h"
#include "qml/qmlapplication.h"
#include "test/mixxxtest.h"
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

class SettingsPathGuard final {
  public:
    explicit SettingsPathGuard(CmdlineArgs& args)
            : m_args(args),
              m_previousArgs(args) {
    }

    ~SettingsPathGuard() {
        m_args = m_previousArgs;
    }

  private:
    CmdlineArgs& m_args;
    const CmdlineArgs m_previousArgs;
};

class QmlStartupSmokeTest : public MixxxTest,
                            public testing::WithParamInterface<const char*> {
  protected:
    static CmdlineArgs makeCmdlineArgs(const QString& settingsPath) {
        CmdlineArgs args;
        args.setSettingsPath(settingsPath);
        return args;
    }

    static void writeProfile(const QString& settingsPath, const char* skinName) {
        auto settings = UserSettingsPointer(new UserSettings(settingsPath + "mixxx.cfg"));
        settings->setValue(ConfigKey("[Config]", "Version"), VersionStore::FUTURE_UNSTABLE);
        settings->setValue(
                ConfigKey("[Config]", "ResizableSkin"),
                QString::fromLatin1(skinName));
        settings->save();

        QFile soundConfig(settingsPath + "soundconfig.xml");
        ASSERT_TRUE(soundConfig.open(QIODevice::WriteOnly | QIODevice::Truncate));
        ASSERT_GT(soundConfig.write("<SoundManagerConfig api=\"None\"/>\n"), 0);
    }
};

TEST_P(QmlStartupSmokeTest, Starts) {
    const char* skinName = GetParam();
    QTemporaryDir profile;
    ASSERT_TRUE(profile.isValid());
    const QString settingsPath = profile.path() + QLatin1Char('/');
    writeProfile(settingsPath, skinName);

    SettingsPathGuard settingsPathGuard(CmdlineArgs::Instance());
    CmdlineArgs::Instance().setSettingsPath(settingsPath);
    const auto args = makeCmdlineArgs(settingsPath);

    RejectFileDialogs rejectFileDialogs;
    application()->installEventFilter(&rejectFileDialogs);
    bool startupReady = false;
    {
        mixxx::qml::QmlApplication qmlApplication(application(), args);
        startupReady = qmlApplication.isReady();
    }
    application()->removeEventFilter(&rejectFileDialogs);

    EXPECT_TRUE(startupReady)
            << "Mixxx failed to start the QML skin '" << skinName << "'"
            << "\nSettings path: " << qPrintable(settingsPath);
}

INSTANTIATE_TEST_SUITE_P(
        QmlSkins,
        QmlStartupSmokeTest,
        testing::Values("Midnight Dark", "LateNight"),
        [](const testing::TestParamInfo<const char*>& info) {
            std::string name = info.param;
            std::replace(name.begin(), name.end(), ' ', '_');
            return name;
        });

} // namespace
