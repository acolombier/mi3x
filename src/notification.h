#pragma once
#include <QDateTime>
#include <QDialogButtonBox>
#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <functional>
#include <memory>

namespace mixxx {

enum class NotificationFlag {
    None = 0,
    Sticky = 1,
    Default = None,
};
Q_DECLARE_FLAGS(NotificationFlags, NotificationFlag);
Q_DECLARE_OPERATORS_FOR_FLAGS(NotificationFlags);

struct NotificationButton {
    Q_GADGET
    Q_PROPERTY(QString label MEMBER label)
  public:
    QString label;
    QObject* receiver;
    std::function<void()> func;

    Q_INVOKABLE void invoke() {
        func();
    }
};

class Notification : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(Notification)

    Q_PROPERTY(NotificationFlags flags MEMBER m_flags NOTIFY flagsChanged);
    Q_PROPERTY(QString text MEMBER m_text NOTIFY textChanged);
    Q_PROPERTY(QString details MEMBER m_details NOTIFY detailsChanged);
    Q_PROPERTY(int timeoutSecs MEMBER m_timeoutSecs CONSTANT);
    Q_PROPERTY(QDateTime lastUpdated MEMBER m_lastUpdated CONSTANT);
    Q_PROPERTY(QVector<NotificationButton> buttons MEMBER m_buttons CONSTANT);

  public:
    explicit Notification(const QString& text, NotificationFlags flags = NotificationFlag::Default);
    ~Notification() {};

    NotificationFlags flags() const {
        return m_flags;
    }

    const QString& text() const {
        return m_text;
    }

    // Mutates a notification in place, e.g. progress counters or scan
    // summaries. Emits textChanged() so QML delegates re-render without
    // the list model churning (no relisting inside NotificationManager).
    void setText(const QString& text) {
        if (m_text == text) {
            return;
        }
        m_text = text;
        emit textChanged();
    }

    const QString& details() const {
        return m_details;
    }

    void setDetails(const QString& details) {
        if (m_details == details) {
            return;
        }
        m_details = details;
        emit detailsChanged();
    }

    void setTimeoutSecs(int timeout) {
        m_timeoutSecs = timeout;
    }

    int timeoutSecs() const {
        return m_timeoutSecs;
    }

    void setLastUpdated(const QDateTime& lastUpdated) {
        m_lastUpdated = lastUpdated;
    }

    QDateTime lastUpdated() const {
        return m_lastUpdated;
    }

    // Sticky notifications remain until explicitly closed; non-sticky ones
    // are auto-removed by NotificationManager after timeoutSecs().
    void setSticky(bool sticky) {
        const NotificationFlags newFlags =
                sticky ? NotificationFlag::Sticky : NotificationFlag::None;
        if (m_flags == newFlags) {
            return;
        }
        m_flags = newFlags;
        emit flagsChanged();
    }

    QVector<NotificationButton> buttons() {
        return m_buttons;
    }

    void addButton(const QString& buttonLabel,
            QObject* receiver,
            const std::function<void()>& func) {
        NotificationButton button;
        button.label = buttonLabel;
        button.receiver = receiver;
        button.func = func;
        m_buttons.append(button);
    }

    // Scaffolding builders for the ticket #51 modal->notification migration.
    // TODO(#51): complete/harden the factory methods (dedup, i18n of common
    // button CTAs) once the call sites are migrated.
    typedef std::shared_ptr<Notification> Pointer;

  signals:
    void closed();
    void textChanged();
    void detailsChanged();
    void flagsChanged();

  private:
    // Some members are mutable because notifications may be updated in
    // place (see setText/setDetails/setSticky): progress notifications are
    // first created sticky and later demoted to auto-timeout, avoiding
    // churn in the notification list.
    NotificationFlags m_flags;
    QString m_text;
    QString m_details;
    int m_timeoutSecs;
    QDateTime m_lastUpdated;
    QVector<NotificationButton> m_buttons;
};

typedef std::shared_ptr<Notification> NotificationPointer;

} // namespace mixxx

Q_DECLARE_METATYPE(mixxx::NotificationPointer)
