#include "errordialoghandler.h"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QScopedPointer>
#include <QScreen>
#include <QThread>
#include <QtDebug>

#include "moc_errordialoghandler.cpp"
#include "notification.h"
#include "notificationmanager.h"
#include "util/assert.h"
#include "util/cmdlineargs.h"
#include "util/compatibility/qmutex.h"
#include "util/thread_check.h"
#include "util/versionstore.h"
#include "util/widgethelper.h"

namespace {
// Gross estimated dimensions for the size of the error dialog,
// with Show Details expanded.
constexpr int kEstimatedShowDetailedDialogWidth = 1000; // px
constexpr int kEstimatedShowDetailedDialogHeight = 500; // px
constexpr int kEstimatedDialogPadding = 50;             // px
// used to push the dialog away from screen borders to not cover taskbars
constexpr int kMinimumDialogMargin = 40; // px
} // namespace

ErrorDialogProperties::ErrorDialogProperties()
        : m_title(VersionStore::applicationName()),
          m_detailsUseMonospaceFont(false),
          m_modal(true),
          m_shouldQuit(false),
          m_type(DLG_NONE),
          m_icon(QMessageBox::NoIcon),
          m_defaultButton(QMessageBox::NoButton),
          m_escapeButton(QMessageBox::NoButton) {
}

void ErrorDialogProperties::setTitle(const QString& title) {
    m_title.append(" - ").append(title);
}

void ErrorDialogProperties::setText(const QString& text) {
    // If no key is set, use this window text since it is likely to be unique
    if (m_key.isEmpty()) {
        m_key = text;
    }
    m_text = text;
}

void ErrorDialogProperties::setType(DialogType typeToSet) {
    m_type = typeToSet;
    switch (m_type) {
        case DLG_FATAL:     // Fatal uses critical icon
        case DLG_CRITICAL:  m_icon = QMessageBox::Critical; break;
        case DLG_WARNING:   m_icon = QMessageBox::Warning; break;
        case DLG_INFO:      m_icon = QMessageBox::Information; break;
        case DLG_QUESTION:  m_icon = QMessageBox::Question; break;
        case DLG_NONE:
        default:
            // default is NoIcon
            break;
    }
}

void ErrorDialogProperties::addButton(QMessageBox::StandardButton button) {
    m_buttons.append(button);
}

// ----------------------------------------------------
// ---------- ErrorDialogHandler begins here ----------

ErrorDialogHandler* ErrorDialogHandler::s_pInstance = nullptr;
bool ErrorDialogHandler::s_bEnabled = true;

// static
void ErrorDialogHandler::setEnabled(bool enabled) {
    s_bEnabled = enabled;
}

ErrorDialogHandler::ErrorDialogHandler() {
    m_errorCondition = false;
    connect(this, &ErrorDialogHandler::showErrorDialog, this, &ErrorDialogHandler::errorDialog);
}

ErrorDialogHandler::~ErrorDialogHandler() {
    s_pInstance = nullptr;
}

ErrorDialogProperties* ErrorDialogHandler::newDialogProperties() {
    return new ErrorDialogProperties();
}

bool ErrorDialogHandler::requestErrorDialog(
        DialogType type, const QString& message, bool shouldQuit) {
    if (!s_bEnabled) {
        return false;
    }
    ErrorDialogProperties* props = newDialogProperties();
    props->setType(type);
    props->setText(message);
    if (shouldQuit) {
        props->setShouldQuit(shouldQuit);
    }
    switch (type) {
        case DLG_FATAL:     props->setTitle(tr("Fatal error")); break;
        case DLG_CRITICAL:  props->setTitle(tr("Critical error")); break;
        case DLG_WARNING:   props->setTitle(tr("Warning")); break;
        case DLG_INFO:      props->setTitle(tr("Information")); break;
        case DLG_QUESTION:  props->setTitle(tr("Question")); break;
        case DLG_NONE:
        default:
            // Default title & (lack of) icon is fine
            break;
    }
    return requestErrorDialog(props);
}

bool ErrorDialogHandler::requestErrorDialog(ErrorDialogProperties* props) {
    if (!s_bEnabled) {
        delete props;
        return false;
    }

    // Make sure the minimum items are set
    QString text = props->getText();
    VERIFY_OR_DEBUG_ASSERT(!text.isEmpty()) {
        delete props;
        return false;
    }

    // Skip if a dialog with the same key is already displayed
    auto locker = lockMutex(&m_mutex);
    bool keyExists = m_dialogKeys.contains(props->getKey());
    locker.unlock();
    if (keyExists) {
        delete props;
        return false;
    }

    emit showErrorDialog(props);
    return true;
}

void ErrorDialogHandler::errorDialog(ErrorDialogProperties* pProps) {
    QScopedPointer<ErrorDialogProperties> props(pProps);
    if (!props) {
        return;
    }

    if (!inMainThread()) {
        qWarning() << "WARNING: errorDialog not called in the main thread. Not showing error dialog.";
        return;
    }

    // TODO(#51): In the QML UI, error dialogs are surfaced as notifications
    // instead of widget popups. The legacy widget code path below is kept
    // unchanged for the classic UI. The human contributor will complete
    // this mapping (severity styling, "Ignore" suppression UX, retry CTA)
    // as hardened follow-up work.
    if (CmdlineArgs::Instance().isQml()) {
        auto locker = lockMutex(&m_mutex);
        // To avoid duplicate dialogs on the same error
        m_dialogKeys.append(props->m_key);
        locker.unlock();

        auto pNotification = std::make_shared<mixxx::Notification>(
                props->m_title, mixxx::NotificationFlag::Sticky);
        // m_text is the primary message, m_infoText the supporting one.
        pNotification->setText(props->m_infoText.isEmpty()
                        ? props->m_text
                        : props->m_infoText);
        if (!props->m_details.isEmpty()) {
            pNotification->setDetails(props->m_details);
        }

        // Map standard buttons to notification CTAs. Clicking re-emits the
        // same stdButtonClicked signal subscribers are connected to, and
        // releases the deduplication key (except for Ignore, which keeps
        // suppressing further dialogs about this error).
        for (const QMessageBox::StandardButton button : std::as_const(props->m_buttons)) {
            if (button == QMessageBox::Ignore) {
                pNotification->addButton(
                        tr("Ignore"), nullptr, []() {
                            // TODO(#51): wire the Ignore suppression path so
                            // further dialogs about this key stay suppressed.
                        });
                continue;
            }
            QString buttonLabel;
            switch (button) {
            case QMessageBox::Close:
                buttonLabel = tr("Close");
                break;
            case QMessageBox::Retry:
                buttonLabel = tr("Retry");
                break;
            case QMessageBox::Ok:
            default:
                buttonLabel = tr("OK");
                break;
            }
            const QMessageBox::StandardButton clickedButton = button;
            const QString key = props->m_key;
            pNotification->addButton(buttonLabel, nullptr, [this, key, clickedButton]() {
                emit stdButtonClicked(key, clickedButton);
                auto locker2 = lockMutex(&m_mutex);
                if (m_dialogKeys.contains(key)) {
                    m_dialogKeys.removeOne(key);
                }
            });
        }
        mixxx::NotificationManager::instance()->notify(pNotification);
        return;
    }

    QMessageBox* pMsgBox = new QMessageBox();
    pMsgBox->setIcon(props->m_icon);
    pMsgBox->setWindowTitle(props->m_title);
    pMsgBox->setText(props->m_text);
    if (!props->m_infoText.isEmpty()) {
        pMsgBox->setInformativeText(props->m_infoText);
    }
    if (!props->m_details.isEmpty()) {
        pMsgBox->setDetailedText(props->m_details);
        if (props->m_detailsUseMonospaceFont) {
            // There is no event to respond on the Show Details button of QMessagBox.
            // Therefore we must consider the expanded size for positioning the dialog initially.
            auto* pScreen =
                    mixxx::widgethelper::getScreen(*pMsgBox);
            if (!pScreen) {
                // Fallback to obtain the primary screen when mixxx::widgethelper::getScreen can't
                // determine the screen. This happens always with Qt <5.14
                pScreen = qGuiApp->primaryScreen();
            }
            DEBUG_ASSERT(pScreen);
            int dialogWidth = kEstimatedShowDetailedDialogWidth;
            int dialogHeight = kEstimatedShowDetailedDialogHeight;

            // Limit dialog size to screen size, for the case of devices with very small display - like Raspberry Pi.
            if (dialogWidth > pScreen->geometry().width() - 2 * kMinimumDialogMargin) {
                dialogWidth = pScreen->geometry().width() - 2 * kMinimumDialogMargin;
            }
            if (dialogHeight > pScreen->geometry().height() - 2 * kMinimumDialogMargin) {
                dialogHeight = pScreen->geometry().height() - 2 * kMinimumDialogMargin;
            }
            pMsgBox->setGeometry(QStyle::alignedRect(
                    Qt::LeftToRight,
                    Qt::AlignCenter,
                    QSize(dialogWidth, dialogHeight),
                    pScreen->geometry()));
            pMsgBox->setStyleSheet(
                    QString("QTextEdit { min-width: %1px ; max-height: %2px; "
                            "font-family: monospace;}")
                            .arg(dialogWidth - kEstimatedDialogPadding)
                            .arg(dialogHeight));
        }
    }

    while (!props->m_buttons.isEmpty()) {
        pMsgBox->addButton(props->m_buttons.takeFirst());
    }
    pMsgBox->setDefaultButton(props->m_defaultButton);
    pMsgBox->setEscapeButton(props->m_escapeButton);
    pMsgBox->setModal(props->m_modal);

    // This deletes the msgBox automatically, avoiding a memory leak
    pMsgBox->setAttribute(Qt::WA_DeleteOnClose, true);
    // Without this, QApplication would close Mixxx when closing this
    // dialog and using the QML GUI because QApplication only takes
    // into account QWidget windows.
    pMsgBox->setAttribute(Qt::WA_QuitOnClose, false);

    auto locker = lockMutex(&m_mutex);
    // To avoid duplicate dialogs on the same error
    m_dialogKeys.append(props->m_key);

    // Signal mapper calls our slot with the key parameter so it knows which to
    // remove from the list
    QString key = props->m_key;
    connect(pMsgBox,
            &QMessageBox::finished,
            this,
            [this, key, pMsgBox] { boxClosed(key, pMsgBox); });

    locker.unlock();

    if (props->m_modal) {
        // Blocks so the user has a chance to read it before application exit
        pMsgBox->exec();
    } else {
        pMsgBox->show();
    }

    // If critical/fatal, gracefully exit application if possible
    if (props->m_shouldQuit) {
        m_errorCondition = true;
        if (QCoreApplication::instance()) {
            QCoreApplication::instance()->exit(-1);
        } else {
            qDebug() << "QCoreApplication::instance() is NULL! Abruptly quitting...";
            if (props->m_type==DLG_FATAL) {
                abort();
            } else {
                exit(-1);
            }
        }
    }
}

void ErrorDialogHandler::boxClosed(const QString& key, QMessageBox* msgBox) {
    auto locker = lockMutex(&m_mutex);
    locker.unlock();

    QMessageBox::StandardButton whichStdButton = msgBox->standardButton(msgBox->clickedButton());
    emit stdButtonClicked(key, whichStdButton);

    // If the user clicks "Ignore," we leave the key in the list so the same
    // error is not displayed again for the duration of the session
    if (whichStdButton == QMessageBox::Ignore) {
        qWarning() << "Suppressing this" << msgBox->windowTitle()
                   << "error box for the duration of the application.";
        return;
    }

    const auto locker2 = lockMutex(&m_mutex);
    if (m_dialogKeys.contains(key)) {
        if (!m_dialogKeys.removeOne(key)) {
            qWarning() << "Error dialog key removal from list failed!";
        }
    } else {
        qWarning() << "Error dialog key is missing from key list!";
    }
}

bool ErrorDialogHandler::checkError() {
    return m_errorCondition;
}
