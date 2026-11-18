#include "qml/asyncimageprovider.h"

#include <QCoreApplication>
#include <QDataStream>
#include <QThread>
#include <QtDebug>

#include "library/coverartcache.h"
#include "moc_asyncimageprovider.cpp"

namespace {
const QString kCoverArtPrefix = QStringLiteral("coverart/");
}

namespace mixxx {

namespace qml {

AsyncImageResponse::AsyncImageResponse(
        QString id,
        QSize requestedSize)
        : m_id(std::move(id)),
          m_requestedSize(requestedSize) {
}

QQuickTextureFactory* AsyncImageResponse::textureFactory() const {
    return QQuickTextureFactory::textureFactoryForImage(m_image);
}

void AsyncImageResponse::initialize() {
    if (!m_id.startsWith(kCoverArtPrefix)) {
        qWarning() << "ImageProvider: Unsupported ID" << m_id;
        emit finished();
        return;
    }
    m_coverInfo = AsyncImageProvider::coverArtUrlIdToCoverInfo(m_id);
    if (!m_coverInfo.hasImage()) {
        emit finished();
        return;
    }

    const int width = m_requestedSize.isValid() ? m_requestedSize.width() : 0;

    // Synchronous cache lookup. CoverArtCache uses QPixmapCache which
    // is only safe to access from the main thread, hence initialize()
    // is expected to run on the main thread.
    QPixmap pixmap = CoverArtCache::getCachedCover(m_coverInfo, width);
    if (!pixmap.isNull()) {
        m_image = pixmap.toImage();
        emit finished();
        return;
    }

    // Cache miss: request an asynchronous load from CoverArtCache.
    // The coverFound signal is emitted on the main thread when the
    // load completes. Since this response has been moved to the main
    // thread (see AsyncImageProvider::requestImageResponse), the
    // slot is invoked directly.
    CoverArtCache* pCache = CoverArtCache::instance();
    if (pCache) {
        connect(pCache,
                &CoverArtCache::coverFound,
                this,
                &AsyncImageResponse::slotCoverFound);
        CoverArtCache::requestUncachedCover(this, m_coverInfo, width);
    } else {
        qWarning() << "ImageProvider: CoverArtCache is not available";
        emit finished();
    }
}

void AsyncImageResponse::slotCoverFound(
        const QObject* pRequester,
        const CoverInfo& coverInfo,
        const QPixmap& pixmap) {
    if (pRequester != this) {
        return;
    }
    if (coverInfo.cacheKey() != m_coverInfo.cacheKey()) {
        return;
    }
    disconnect(CoverArtCache::instance(),
            &CoverArtCache::coverFound,
            this,
            &AsyncImageResponse::slotCoverFound);
    if (!pixmap.isNull()) {
        m_image = pixmap.toImage();
    }
    emit finished();
}

AsyncImageProvider::AsyncImageProvider()
        : QQuickAsyncImageProvider() {
}

QQuickImageResponse* AsyncImageProvider::requestImageResponse(
        const QString& id, const QSize& requestedSize) {
    auto* pResponse = new AsyncImageResponse(
            id, requestedSize);
    // The response must live on the same thread as the CoverArtCachethread (the
    // main thread) because:
    //  - CoverArtCache::getCachedCover() accesses QPixmapCache which
    //    is not thread-safe.
    //  - CoverArtCache::coverFound is emitted on the main thread and
    //    the slot should be invoked there.
    // Move the response before connecting any signals.
    pResponse->moveToThread(CoverArtCache::instance()->thread());
    if (QThread::currentThread() != CoverArtCache::instance()->thread()) {
        // requestImageResponse is called from the QQuickPixmapReader thread.
        // initialize() must run on the main thread, but it must not block this
        // thread: the main thread may simultaneously be tearing down the QML
        // engine (e.g. on reloadQml), in which case QQuickPixmapReader's
        // destructor waits for this thread while this thread would wait for the
        // main thread, deadlocking the whole application.
        //
        // Use a queued invocation with the response as context so it is
        // cancelled automatically if the response is destroyed first.
        QMetaObject::invokeMethod(
                pResponse,
                [pResponse] {
                    pResponse->initialize();
                },
                Qt::QueuedConnection);
    } else {
        pResponse->initialize();
    }
    return pResponse;
}

// static
const QString AsyncImageProvider::kProviderName = QStringLiteral("mixxx");

// static
QUrl AsyncImageProvider::coverInfoToCoverArtUrl(const CoverInfo& coverInfo) {
    QByteArray data;
    QDataStream stream(&data, QIODevice::WriteOnly);
    stream << coverInfo.trackLocation
           << coverInfo.coverLocation
           << static_cast<qint32>(coverInfo.type)
           << static_cast<qint32>(coverInfo.source)
           << coverInfo.imageDigest()
           << coverInfo.legacyHash();

    QUrl url("image://" + kProviderName + "/" + kCoverArtPrefix);
    return url.resolved(
            QString::fromLatin1(data.toBase64(
                    QByteArray::Base64UrlEncoding)));
}

//static
CoverInfo AsyncImageProvider::coverArtUrlIdToCoverInfo(const QString& coverArtUrlId) {
    CoverInfo coverInfo;
    const QByteArray data = QByteArray::fromBase64(
            coverArtUrlId.mid(kCoverArtPrefix.size()).toLatin1(),
            QByteArray::Base64UrlEncoding);
    QDataStream stream(data);

    qint32 type = 0;
    qint32 source = 0;
    QByteArray digest;
    quint16 legacyHash = 0;
    stream >> coverInfo.trackLocation >> coverInfo.coverLocation >> type >>
            source >> digest >> legacyHash;
    coverInfo.type = static_cast<CoverInfo::Type>(type);
    coverInfo.source = static_cast<CoverInfo::Source>(source);
    coverInfo.setImageDigest(digest, legacyHash);
    return coverInfo;
}

} // namespace qml
} // namespace mixxx
