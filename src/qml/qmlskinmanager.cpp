#include "qml/qmlskinmanager.h"

#include <qalgorithms.h>
#include <qdiriterator.h>
#include <qnamespace.h>
#include <qobject.h>
#include <qqml.h>
#include <qqmlcomponent.h>
#include <qqmlengine.h>

#include <utility>

#include "moc_qmlskinmanager.cpp"
#include "qml/qmlcoreservices.h"
#include "util/assert.h"

namespace {

const QString kSkinFolders = QStringLiteral("qml/skins");
const QString kSkinExtension = QStringLiteral(".qml");
} // namespace
namespace mixxx {
namespace qml {

QmlSkin::QmlSkin(QObject* parent)
        : QObject(parent),
          m_main(),
          m_loader() {
}

QmlSkin::~QmlSkin() = default;

void QmlSkinManager::initialize(QmlCoreServices* pCoreServices) {
    // TODO like for mapping, should also explore user folder
    auto pQmlEngine = qmlEngine(this);
    DEBUG_ASSERT(pQmlEngine);
    const QStringList skinPaths = {
            pCoreServices->get()->getSettings()->getResourcePath() + kSkinFolders};
    for (const QString& skinPath : std::as_const(skinPaths)) {
        QDirIterator it(skinPath);
        while (it.hasNext()) {
            it.next();
            const QFileInfo fileInfo = it.fileInfo();
            const QString path = fileInfo.filePath();

            if (path.endsWith(kSkinExtension, Qt::CaseInsensitive)) {
                auto uri = QUrl::fromLocalFile(fileInfo.absoluteFilePath());
                auto* pQmlComponent = new QQmlComponent(
                        pQmlEngine, uri, QQmlComponent::Asynchronous, this);
                QFile skin = QFile(fileInfo.absoluteFilePath());
                if (!skin.open(QIODevice::ReadOnly)) {
                    qWarning() << "Unable to open skin manifest:"
                               << fileInfo.absoluteFilePath();
                    continue;
                }

                m_skinManifests.insert(uri, pQmlComponent);
                connect(pQmlComponent,
                        &QQmlComponent::statusChanged,
                        this,
                        [this, uri](QQmlComponent::Status status) {
                            slotSkinLoaded(uri, status);
                        });

                pQmlComponent->setData(
                        skin.readAll(),
                        // Obfuscate the scene filename to make it appear in the QML folder.
                        // This allows a smooth integration with QML components.
                        uri);
                // skin.close();
            }
        }
    }
}

void QmlSkinManager::teardown() {
    qDeleteAll(m_skinManifests);
    qDeleteAll(m_pSkins);
}

void QmlSkinManager::slotSkinLoaded(const QUrl& uri, QQmlComponent::Status status) {
    VERIFY_OR_DEBUG_ASSERT(m_skinManifests.contains(uri)) {
        return;
    }
    auto* pQmlComponent = m_skinManifests[uri];
    switch (status) {
    case QQmlComponent::Status::Loading:
        qDebug() << "Skin" << uri << "is loading";
        break;
    case QQmlComponent::Status::Error: {
        const QList<QQmlError> errorList = pQmlComponent->errors();
        for (const QQmlError& error : errorList) {
            qWarning() << "Unable to load skin manifest -" << error;
        }
        m_skinManifests.take(uri)->deleteLater();
    } break;
    case QQmlComponent::Status::Ready: {
        DEBUG_ASSERT(pQmlComponent->isReady() && !pQmlComponent->isError());
        QObject* pRootObject = pQmlComponent->create();
        mixxx::qml::QmlSkin* rootItem =
                qobject_cast<mixxx::qml::QmlSkin*>(pRootObject);
        if (!rootItem) {
            qWarning() << "Unable to load skin manifest" << uri << "- Not a Mixxx.Skin!";
            pRootObject->deleteLater();
            m_skinManifests.take(uri)->deleteLater();
            return;
        }
        rootItem->setParent(this);
        m_pSkins.insert(uri, rootItem);
        m_skinManifests.take(uri)->deleteLater();
        emit skinsChanged();

    } break;
    case QQmlComponent::Status::Null:
        DEBUG_ASSERT(!"Unexpected status");
        break;
    }
}

QmlSkin* QmlSkinManager::getSelectedSkin() {
    return m_pSkins.isEmpty() ? nullptr : m_pSkins.first();
}

} // namespace qml
} // namespace mixxx
