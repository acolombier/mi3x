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

    Q_PROPERTY(NotificationFlags flags MEMBER m_flags CONSTANT);
    Q_PROPERTY(QString text MEMBER m_text CONSTANT);
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

  signals:
    void closed();

  private:
    const NotificationFlags m_flags;
    const QString m_text;
    int m_timeoutSecs;
    QDateTime m_lastUpdated;
    QVector<NotificationButton> m_buttons;
};

typedef std::shared_ptr<Notification> NotificationPointer;

} // namespace mixxx
