#include "qml/qmlwaveformoverview.h"

#include <QPainterPath>
#include <QPixmapCache>
#include <algorithm>

#include "library/library.h"
#include "library/trackcollectionmanager.h"
#include "moc_qmlwaveformoverview.cpp"
#include "qmllibraryproxy.h"
#include "qmlplayerproxy.h"
#include "qmltrackproxy.h"
#include "track/globaltrackcache.h"
#include "track/track.h"
#include "track/trackid.h"
#include "util/assert.h"
#include "waveform/waveformwidgetfactory.h"

namespace {
constexpr double kDesiredChannelHeight = 255;

constexpr const char* kPixmapCachePrefix = "QmlWaveformOverview";
} // namespace

namespace mixxx {
namespace qml {

QmlWaveformOverview::QmlWaveformOverview(QQuickItem* parent)
        : QQuickPaintedItem(parent),
          m_pTrack(nullptr),
          m_channels(ChannelFlag::BothChannels),
          m_renderer(Renderer::RGB),
          m_colorHigh(0xFF0000),
          m_colorMid(0x00FF00),
          m_colorLow(0x0000FF),
          m_trackId() {
    connect(this,
            &QmlWaveformOverview::rendererChanged,
            this,
            &QmlWaveformOverview::slotWaveformUpdated);
    connect(this,
            &QmlWaveformOverview::colorHighChanged,
            this,
            &QmlWaveformOverview::slotWaveformUpdated);
    connect(this,
            &QmlWaveformOverview::colorMidChanged,
            this,
            &QmlWaveformOverview::slotWaveformUpdated);
    connect(this,
            &QmlWaveformOverview::colorLowChanged,
            this,
            &QmlWaveformOverview::slotWaveformUpdated);
}

void QmlWaveformOverview::componentComplete() {
    // The unit tests construct the item directly, so the OverviewCache
    // subscription has to happen lazily (unique connection) and deferred.
    if (OverviewCache::isCreated()) {
        connect(OverviewCache::instance(),
                &OverviewCache::overviewChanged,
                this,
                &QmlWaveformOverview::slotOverviewChanged,
                Qt::UniqueConnection);
        connect(OverviewCache::instance(),
                &OverviewCache::analyzerProgress,
                this,
                &QmlWaveformOverview::slotWaveformUpdated,
                Qt::UniqueConnection);
    }
    QQuickPaintedItem::componentComplete();
}

void QmlWaveformOverview::setGroup(const QString& group) {
    if (m_group == group) {
        return;
    }

    m_group = group;
    m_pReplayGain.reset();
    m_pReplayGainEnabled.reset();
    m_pReplayGainBoost.reset();
    m_pReplayGainDefaultBoost.reset();

    if (!m_group.isEmpty()) {
        m_pReplayGain = std::make_unique<ControlProxy>(
                m_group, QStringLiteral("replaygain"), this);
        m_pReplayGainEnabled = std::make_unique<ControlProxy>(
                QStringLiteral("[ReplayGain]"), QStringLiteral("ReplayGainEnabled"), this);
        m_pReplayGainBoost = std::make_unique<ControlProxy>(
                QStringLiteral("[ReplayGain]"), QStringLiteral("ReplayGainBoost"), this);
        m_pReplayGainDefaultBoost = std::make_unique<ControlProxy>(
                QStringLiteral("[ReplayGain]"), QStringLiteral("DefaultBoost"), this);

        m_pReplayGain->connectValueChanged(this, &QmlWaveformOverview::slotWaveformUpdated);
        m_pReplayGainEnabled->connectValueChanged(this, &QmlWaveformOverview::slotWaveformUpdated);
        m_pReplayGainBoost->connectValueChanged(this, &QmlWaveformOverview::slotWaveformUpdated);
        m_pReplayGainDefaultBoost->connectValueChanged(
                this, &QmlWaveformOverview::slotWaveformUpdated);
    }

    emit groupChanged();
    invalidatePixmapCacheForCurrent();
    update();
}

double QmlWaveformOverview::amplitudeScale() const {
    double scale = 1.0;
    if (m_pReplayGainEnabled && m_pReplayGainBoost &&
            m_pReplayGainDefaultBoost && m_pReplayGain) {
        // Match the legacy overview's non-normalized scaling: apply the
        // track's ReplayGain (or its default boost before analysis) together
        // with the global visual gain used by scrolling waveforms.
        double trackGainRatio = 1.0;
        if (m_pReplayGainEnabled->toBool()) {
            const double replayGain = m_pReplayGain->get();
            trackGainRatio = replayGain == 0.0
                    ? m_pReplayGainDefaultBoost->get()
                    : replayGain * m_pReplayGainBoost->get();
        }
        scale = std::max(0.0,
                trackGainRatio *
                        (WaveformWidgetFactory::isCreated()
                                        ? WaveformWidgetFactory::instance()
                                                  ->getVisualGain(
                                                          BandIndex::AllBand)
                                        : 1.0));
    }
    return scale;
}

QmlTrackProxy* QmlWaveformOverview::getTrack() const {
    return m_pTrack;
}

void QmlWaveformOverview::setTrack(QmlTrackProxy* pTrack) {
    if (m_pTrack == pTrack) {
        return;
    }

    invalidatePixmapCacheForCurrent();
    m_waveformSummary.reset();
    m_trackUrl = QUrl();
    m_trackId = TrackId();

    if (m_pTrack != nullptr && m_pTrack->internal() != nullptr) {
        m_pTrack->internal()->disconnect(this);
    }

    m_pTrack = pTrack;

    if (m_pTrack != nullptr && m_pTrack->internal() != nullptr) {
        m_trackId = m_pTrack->internal()->getId();
        m_waveformSummary = m_pTrack->internal()->getWaveformSummary();
        connect(m_pTrack->internal().get(),
                &Track::waveformSummaryUpdated,
                this,
                &QmlWaveformOverview::slotWaveformUpdated);
    }
    if (OverviewCache::isCreated()) {
        connect(OverviewCache::instance(),
                &OverviewCache::overviewChanged,
                this,
                &QmlWaveformOverview::slotOverviewChanged,
                Qt::UniqueConnection);
    }
    emit trackChanged();
    slotWaveformUpdated();
}

void QmlWaveformOverview::setTrackUrl(const QUrl& trackUrl) {
    if (m_trackUrl == trackUrl) {
        return;
    }

    m_waveformSummary.reset();
    if (m_pTrack != nullptr && m_pTrack->internal() != nullptr) {
        m_pTrack->internal()->disconnect(this);
    }
    m_pTrack = nullptr;

    Library* pLibrary = QmlLibraryProxy::get();
    VERIFY_OR_DEBUG_ASSERT(pLibrary) {
        return;
    }

    auto trackIds = pLibrary->trackCollectionManager()->resolveTrackIdsFromUrls({trackUrl});
    VERIFY_OR_DEBUG_ASSERT(trackIds.size() == 1) {
        return;
    }
    m_trackId = trackIds.first();
    m_waveformSummary = OverviewCache::instance()->fetchWaveformSummary(m_trackId);
    slotWaveformUpdated();
}

QmlWaveformOverview::Channels QmlWaveformOverview::getChannels() const {
    return m_channels;
}

void QmlWaveformOverview::setChannels(QmlWaveformOverview::Channels channels) {
    if (m_channels == channels) {
        return;
    }

    m_channels = channels;
    emit channelsChanged(channels);
}

void QmlWaveformOverview::slotWaveformUpdated() {
    invalidatePixmapCacheForCurrent();
    update();
}

void QmlWaveformOverview::setStereo(bool stereo) {
    if (m_stereo == stereo) {
        return;
    }
    m_stereo = stereo;
    emit stereoChanged();
    invalidatePixmapCacheForCurrent();
    update();
}

void QmlWaveformOverview::setNormalized(bool normalized) {
    if (m_normalized == normalized) {
        return;
    }
    m_normalized = normalized;
    emit normalizedChanged();
    invalidatePixmapCacheForCurrent();
    update();
}

void QmlWaveformOverview::setMinuteMarkers(bool minuteMarkers) {
    if (m_minuteMarkers == minuteMarkers) {
        return;
    }
    m_minuteMarkers = minuteMarkers;
    emit minuteMarkersChanged();
    invalidatePixmapCacheForCurrent();
    update();
}

void QmlWaveformOverview::setAnalyzerProgress(double analyzerProgress) {
    if (m_analyzerProgress == analyzerProgress) {
        return;
    }
    m_analyzerProgress = analyzerProgress;
    emit analyzerProgressChanged();
    update();
}

void QmlWaveformOverview::drawMinuteMarkers(QPainter* pPainter, double duration) const {
    if (duration <= 60.0 || width() <= 0) {
        return;
    }
    pPainter->save();
    pPainter->setPen(QPen(QColor(245, 245, 245, 180), 1));
    const double markerHeight = height() * 0.08;
    for (double seconds = 60.0; seconds < duration; seconds += 60.0) {
        const double x = width() * seconds / duration;
        pPainter->drawLine(QPointF(x, 0), QPointF(x, markerHeight));
        if (m_stereo) {
            pPainter->drawLine(QPointF(x, height() - markerHeight),
                    QPointF(x, height()));
        }
    }
    pPainter->restore();
}

void QmlWaveformOverview::slotOverviewChanged(TrackId trackId) {
    if (!m_trackId.isValid() || m_trackId != trackId) {
        return;
    }
    if (m_pTrack && m_pTrack->internal()) {
        m_waveformSummary = m_pTrack->internal()->getWaveformSummary();
    } else {
        m_waveformSummary = OverviewCache::instance()->fetchWaveformSummary(m_trackId);
    }
    slotWaveformUpdated();
}

void QmlWaveformOverview::paint(QPainter* pPainter) {
    if (!m_waveformSummary) {
        return;
    }

    const int dataSize = m_waveformSummary->getDataSize();
    if (dataSize == 0) {
        return;
    }

    constexpr int actualCompletion = 0;
    // Always multiple of 2
    const int waveformCompletion = m_waveformSummary->getCompletion();
    // Test if there is some new to draw (at least of pixel width)
    const int completionIncrement = waveformCompletion - actualCompletion;

    const qreal desiredWidth = static_cast<qreal>(dataSize) / 2;
    const double visiblePixelIncrement = completionIncrement * desiredWidth / dataSize;
    if (waveformCompletion < (dataSize - 2) &&
            (completionIncrement < 2 || visiblePixelIncrement == 0)) {
        return;
    }

    const int nextCompletion = actualCompletion + completionIncrement;

    const QString cacheKey = pixmapCacheKey(m_trackId) + '_' +
            QString::number(quintptr(this));
    QPixmap pixmap;
    if (QPixmapCache::find(cacheKey, &pixmap)) {
        pPainter->drawPixmap(0, 0, pixmap);
    } else {
        pixmap = renderWaveformToPixmap(m_waveformSummary, nextCompletion);
        VERIFY_OR_DEBUG_ASSERT(!pixmap.isNull()) {
        }
        else {
            QPixmapCache::insert(cacheKey, pixmap);
        }
    }

    VERIFY_OR_DEBUG_ASSERT(!pixmap.isNull()) {
        return;
    }
    pPainter->drawPixmap(0, 0, pixmap);
}

QPixmap QmlWaveformOverview::renderWaveformToPixmap(
        ConstWaveformPointer pWaveform, int nextCompletion) const {
    constexpr int actualCompletion = 0;

    const QSize size(qRound(width()), qRound(height()));
    if (size.isEmpty()) {
        return QPixmap();
    }

    const qreal desiredWidth = static_cast<qreal>(pWaveform->getDataSize()) / 2;

    // Non-normalized overviews scale by the track's ReplayGain together with
    // the global visual gain; normalized ones rescale to the waveform peak.
    double amplitudeScale = 1.0;
    if (m_normalized) {
        unsigned char peak = 0;
        for (int i = 0; i < nextCompletion; ++i) {
            peak = std::max(peak, pWaveform->getAll(i));
        }
        if (peak > 0) {
            amplitudeScale = 255.0 / peak;
        }
    } else {
        amplitudeScale = this->amplitudeScale();
    }

    QPixmap pixmap(size);
    pixmap.fill(Qt::transparent);
    QPainter pPainter(&pixmap);

    const Channels channels = m_channels;
    pPainter.save();

    if (!m_stereo) {
        // Mono overview: fold both channels into a single symmetric waveform
        // spanning the full item height (left channel above the center axis,
        // right channel below it).
        pPainter.translate(0.0, height() / 2);
        pPainter.scale(width() / desiredWidth,
                height() / (2 * kDesiredChannelHeight) * amplitudeScale);
    } else {
        switch (channels) {
        case static_cast<int>(ChannelFlag::LeftChannel):
            // Draw only the left channel on the full item height.
            // Set the y axis to the bottom of the item
            pPainter.translate(0.0, height());
            // Set the x axis to half the height of the item
            pPainter.scale(width() / desiredWidth,
                    height() / kDesiredChannelHeight * amplitudeScale);
            break;
        case static_cast<int>(ChannelFlag::RightChannel):
            // Set the x axis to half the height of the item
            pPainter.scale(width() / desiredWidth,
                    height() / kDesiredChannelHeight * amplitudeScale);
            break;
        default:
            // Draw both channels.
            // Set the y axis to half the height of the item
            pPainter.translate(0.0, height() / 2);
            // Set the x axis to half the height of the item
            pPainter.scale(width() / desiredWidth,
                    height() / (2 * kDesiredChannelHeight) * amplitudeScale);
        }
    }

    const Renderer renderer = m_renderer;
    for (int currentCompletion = actualCompletion;
            currentCompletion < nextCompletion;
            currentCompletion += 2) {
        switch (renderer) {
        case Renderer::Filtered:
            drawFiltered(&pPainter, channels, pWaveform, currentCompletion);
            break;
        default:
            drawRgb(&pPainter, channels, pWaveform, currentCompletion);
        }
    }
    pPainter.restore();

    pPainter.end();

    if (m_minuteMarkers) {
        // Minute markers are drawn unscaled onto the finished pixmap. They
        // need the track duration, which is only available through the track
        // proxy (not for trackUrl-only overviews).
        if (m_pTrack != nullptr && m_pTrack->internal() != nullptr) {
            pPainter.begin(&pixmap);
            drawMinuteMarkers(&pPainter, m_pTrack->internal()->getDuration());
            pPainter.end();
        }
    }
    return pixmap;
}

// static
QString QmlWaveformOverview::pixmapCacheKey(TrackId trackId) {
    return QStringLiteral("%1_%2")
            .arg(QString::fromLatin1(kPixmapCachePrefix),
                    trackId.toString());
}

void QmlWaveformOverview::invalidatePixmapCacheForCurrent() {
    QPixmapCache::remove(pixmapCacheKey(m_trackId) + '_' +
            QString::number(quintptr(this)));
}

void QmlWaveformOverview::drawRgb(QPainter* pPainter,
        Channels channels,
        ConstWaveformPointer pWaveform,
        int completion) const {
    const double offsetX = completion / 2.0;

    if (channels.testFlag(ChannelFlag::LeftChannel)) {
        // Draw left channel
        const QColor leftColor = getRgbPenColor(pWaveform, completion);
        if (leftColor.isValid()) {
            const uint8_t leftValue = pWaveform->getAll(completion);
            pPainter->setPen(leftColor);
            pPainter->drawLine(QPointF(offsetX, -leftValue), QPointF(offsetX, 0.0));
        }
    }

    if (channels.testFlag(ChannelFlag::RightChannel)) {
        // Draw right channel
        QColor rightColor = getRgbPenColor(pWaveform, completion + 1);
        if (rightColor.isValid()) {
            const uint8_t rightValue = pWaveform->getAll(completion + 1);
            pPainter->setPen(rightColor);
            pPainter->drawLine(QPointF(offsetX, 0.0), QPointF(offsetX, rightValue));
        }
    }
}

void QmlWaveformOverview::drawFiltered(QPainter* pPainter,
        Channels channels,
        ConstWaveformPointer pWaveform,
        int completion) const {
    const double offsetX = completion / 2.0;

    if (channels.testFlag(ChannelFlag::LeftChannel)) {
        const uint8_t leftHigh = pWaveform->getHigh(completion);
        pPainter->setPen(m_colorHigh);
        pPainter->drawLine(QPointF(offsetX, 2 * -leftHigh), QPointF(offsetX, 0.0));

        const uint8_t leftMid = pWaveform->getMid(completion);
        pPainter->setPen(m_colorMid);
        pPainter->drawLine(QPointF(offsetX, 1.5 * -leftMid), QPointF(offsetX, 0.0));

        const uint8_t leftLow = pWaveform->getLow(completion);
        pPainter->setPen(m_colorLow);
        pPainter->drawLine(QPointF(offsetX, -leftLow), QPointF(offsetX, 0.0));
    }

    if (channels.testFlag(ChannelFlag::RightChannel)) {
        const uint8_t rightHigh = pWaveform->getHigh(completion + 1);
        pPainter->setPen(m_colorHigh);
        pPainter->drawLine(QPointF(offsetX, 0), QPointF(offsetX, 2 * rightHigh));

        const uint8_t rightMid = pWaveform->getMid(completion + 1) * 2;
        pPainter->setPen(m_colorMid);
        pPainter->drawLine(QPointF(offsetX, 0), QPointF(offsetX, 1.5 * rightMid));

        const uint8_t rightLow = pWaveform->getLow(completion + 1);
        pPainter->setPen(m_colorLow);
        pPainter->drawLine(QPointF(offsetX, 0), QPointF(offsetX, rightLow));
    }
}

QColor QmlWaveformOverview::getRgbPenColor(ConstWaveformPointer pWaveform, int completion) const {
    // Retrieve "raw" LMH values from waveform
    qreal low = static_cast<qreal>(pWaveform->getLow(completion));
    qreal mid = static_cast<qreal>(pWaveform->getMid(completion));
    qreal high = static_cast<qreal>(pWaveform->getHigh(completion));

    // Do matrix multiplication
    qreal red = low * m_colorLow.redF() + mid * m_colorMid.redF() + high * m_colorHigh.redF();
    qreal green = low * m_colorLow.greenF() + mid * m_colorMid.greenF() +
            high * m_colorHigh.greenF();
    qreal blue = low * m_colorLow.blueF() + mid * m_colorMid.blueF() + high * m_colorHigh.blueF();

    // Normalize and draw
    qreal max = math_max3(red, green, blue);
    if (max > 0.0) {
        QColor color;
        color.setRgbF(
                static_cast<float>(red / max),
                static_cast<float>(green / max),
                static_cast<float>(blue / max));
        return color;
    }
    return QColor();
}

} // namespace qml
} // namespace mixxx
