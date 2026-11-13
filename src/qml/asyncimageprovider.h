#pragma once

#include <QImage>
#include <QPixmap>
#include <QQuickAsyncImageProvider>
#include <QSize>
#include <QString>
#include <QUrl>
#include <memory>

#include "library/coverart.h"

namespace mixxx {
namespace qml {

class AsyncImageResponse : public QQuickImageResponse {
    Q_OBJECT
  public:
    AsyncImageResponse(
            QString id,
            QSize requestedSize);

    QQuickTextureFactory* textureFactory() const override;

    /// Must be called on the main thread (the thread that the
    /// CoverArtCache lives on) before the response is
    /// returned to the QML engine. It performs the lightweight
    /// CoverInfo lookup (decoded from the image id), checks the
    /// CoverArtCache for a synchronous cache hit, and otherwise
    /// initiates an asynchronous load via CoverArtCache and connects
    /// to its coverFound signal.
    void initialize();

  private slots:
    void slotCoverFound(
            const QObject* pRequester,
            const CoverInfo& coverInfo,
            const QPixmap& pixmap);

  private:
    QString m_id;
    QSize m_requestedSize;
    CoverInfo m_coverInfo;
    QImage m_image;
};

class AsyncImageProvider : public QQuickAsyncImageProvider {
  public:
    AsyncImageProvider();

    QQuickImageResponse* requestImageResponse(
            const QString& id, const QSize& requestedSize) override;

    static const QString kProviderName;
    static QUrl coverInfoToCoverArtUrl(const CoverInfo& coverInfo);
    static CoverInfo coverArtUrlIdToCoverInfo(const QString& coverArtUrlId);
};

} // namespace qml
} // namespace mixxx
