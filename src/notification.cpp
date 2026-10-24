#include "notification.h"

#include "moc_notification.cpp"

namespace mixxx {

Notification::Notification(const QString& text, NotificationFlags flags)
        : m_flags(flags),
          m_text(text),
          m_timeoutSecs(0) {
}
} // namespace mixxx
