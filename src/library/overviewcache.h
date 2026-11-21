#pragma once

#include <QHash>
#include <QList>
#include <QSet>
#include <QSqlDatabase>

#include "analyzer/analyzerprogress.h"
#include "preferences/usersettings.h"
#include "track/trackid.h"
#include "util/db/dbconnectionpool.h"
#include "util/singleton.h"
#include "waveform/overviewtype.h"
#include "waveform/waveform.h"

class WaveformSignalColors;

class OverviewCache : public QObject, public Singleton<OverviewCache> {
    Q_OBJECT
  public:
    void onTrackSummaryChanged(TrackId);

    QPixmap requestCachedOverview(
            mixxx::OverviewType type,
            TrackId trackId,
            const QObject* pRequester,
            QSize desiredSize);
    QPixmap requestUncachedOverview(
            mixxx::OverviewType type,
            const WaveformSignalColors& signalColors,
            TrackId trackId,
            const QObject* pRequester,
            QSize desiredSize);

    void requestWaveformSummary(
            TrackId trackId,
            const QObject* pRequester);

    struct FutureResult {
        TrackId trackId;
        mixxx::OverviewType type;
        QImage image;
        QSize resizedToSize;
    };

    struct WaveformSummaryResult {
        TrackId trackId;
        ConstWaveformPointer waveform;
    };

  public slots:
    void overviewPrepared();
    void waveformSummaryPrepared();
    void onTrackAnalysisProgress(TrackId trackId, AnalyzerProgress analyzerProgress);

  signals:
    void overviewReady(
            const QObject* pRequester,
            TrackId trackId,
            bool pixmapValid);

    void waveformSummaryReady(
            const QObject* pRequester,
            TrackId trackId,
            ConstWaveformPointer waveform);

    void overviewChanged(TrackId);

    void analyzerProgress(TrackId trackId, AnalyzerProgress analyzerProgress);

  protected:
    OverviewCache(UserSettingsPointer pConfig,
            mixxx::DbConnectionPoolPtr m_pDbConnectionPool);
    virtual ~OverviewCache() override = default;
    friend class Singleton<OverviewCache>;

    static FutureResult prepareOverview(
            UserSettingsPointer pConfig,
            mixxx::DbConnectionPoolPtr pDbConnectionPool,
            mixxx::OverviewType type,
            const WaveformSignalColors& signalColors,
            TrackId trackId,
            QSize desiredSize);

    static WaveformSummaryResult prepareWaveformSummary(
            UserSettingsPointer pConfig,
            mixxx::DbConnectionPoolPtr pDbConnectionPool,
            TrackId trackId);

  private:
    UserSettingsPointer m_pConfig;
    mixxx::DbConnectionPoolPtr m_pDbConnectionPool;

    QHash<TrackId, QList<const QObject*>> m_overviewRequesters;
    QHash<TrackId, QList<const QObject*>> m_summaryRequesters;
    QSet<TrackId> m_tracksWithoutOverview;
    QSet<TrackId> m_tracksWithoutWaveformSummary;
    QMultiHash<TrackId, QString> m_cacheKeysByTrackId;
};
