#include "qml/qmlcoreservices.h"

<<<<<<< HEAD
#include <QCoreApplication>
#include <QEventLoop>
#include <QtGlobal>

        == == ==
        =
>>>>>>> origin/feat/qml
#include "moc_qmlcoreservices.cpp"

                namespace mixxx {
namespace qml {

<<<<<<< HEAD
=======
// QmlCoreServices::QmlCoreServices(QObject* parent, int): QObject(parent){

// }

>>>>>>> origin/feat/qml
void QmlCoreServices::setReady() {
    if (m_ready) {
        return;
    }
    m_ready = true;
    emit readyChanged();
}

<<<<<<< HEAD
void QmlCoreServices::setInitializationProgress(int progress, const QString& service) {
    const int clampedProgress = qBound(0, progress, 100);
    if (m_initializationProgress != clampedProgress) {
        m_initializationProgress = clampedProgress;
        emit initializationProgressChanged();
    }
    if (m_initializationService != service) {
        m_initializationService = service;
        emit initializationServiceChanged();
    }

    QCoreApplication::processEvents(QEventLoop::ExcludeUserInputEvents);
}

// static
QmlCoreServices* QmlCoreServices::create(QQmlEngine*, QJSEngine*) {
    return instance();
}

=======
// static
QmlCoreServices* QmlCoreServices::create(QQmlEngine* pQmlEngine, QJSEngine*) {
    return instance();
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
>>>>>>> origin/feat/qml
} // namespace qml
} // namespace mixxx
