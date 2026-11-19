#include "notification.h"

#include <qobject.h>

#include "moc_notification.cpp"
#include "util/assert.h"

namespace mixxx {

Notification::Notification(const QString& text, Flags flags, const QString& key)
        : m_flags(flags),
          m_text(text),
          m_key(key),
          m_timeoutSecs(0) {
}

void NotificationButton::invoke() {
    if (!func) {
        auto* pReceiver = qobject_cast<Notification*>(receiver);
        VERIFY_OR_DEBUG_ASSERT(pReceiver) {
            return;
        }
        emit pReceiver->clicked(*this);
        return;
    }
    if (!receiver) {
        qWarning() << "Notification action has no receiver! This is will "
                      "lead actions to default to the GUI thread which may "
                      "have unexpected performance impacts.";
        return func();
    }
    QMetaObject::invokeMethod(receiver, [this]() {
        func();
    });
}

} // namespace mixxx
