#include "qml/qmlcoreservices.h"

#include <qnamespace.h>
#include <qobject.h>
#include <qqmlengine.h>

#include <utility>

#include "coreservices.h"
#include "moc_qmlcoreservices.cpp"

namespace mixxx {
namespace qml {

QmlCoreServices::QmlCoreServices(QQmlEngine* pQmlEngine)
        : QObject(pQmlEngine) {
    connect(s_pCoreServices.get(),
            &mixxx::CoreServices::initialized,
            this,
            &QmlCoreServices::slotInitialization);
    if (s_pCoreServices->isInitialized()) {
        slotInitialization();
    }
}

void QmlCoreServices::setReady() {
    if (m_ready) {
        return;
    }
    m_ready = true;
    emit readyChanged();
}

// static
QmlCoreServices* QmlCoreServices::create(QQmlEngine* pQmlEngine, QJSEngine*) {
    return new QmlCoreServices(pQmlEngine);
}

void QmlCoreServices::addOpenedPopup(QObject* popup) {
    bool wasEmpty = m_popups.isEmpty();
    m_popups.insert(popup);
    if (wasEmpty) {
        emit hasPopupChanged();
    }
}
void QmlCoreServices::removeOpenedPopup(QObject* popup) {
    bool wasNotEmpty = !m_popups.isEmpty();
    m_popups.remove(popup);
    if (wasNotEmpty) {
        emit hasPopupChanged();
    }
}

void QmlCoreServices::clearOpenedPopup() {
    if (m_popups.isEmpty()) {
        return;
    }
    m_popups.clear();
    emit hasPopupChanged();
}

void QmlCoreServices::slotInitialization() {
    if (s_pCoreServices->isInitialized()) {
        setReady();
    }
}
} // namespace qml
} // namespace mixxx
