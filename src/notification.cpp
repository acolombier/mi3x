#include "notification.h"

#include "moc_notification.cpp"

namespace mixxx {

Notification::Notification(const QString& text, Flags flags)
        : m_flags(flags),
          m_text(text),
          m_timeoutSecs(0) {
}

void NotificationButton::invoke() {
    if (!receiver) {
        qWarning() << "Notification action has no receiver! This is will "
                      "lead actions to default to the GUI thread which may "
                      "have unexpected performance impacts.";
        func();
    }
    QMetaObject::invokeMethod(receiver, [this]() {
        func();
    });
}

} // namespace mixxx
