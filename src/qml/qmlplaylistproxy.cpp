#include "qml/qmlplaylistproxy.h"

#include <QBuffer>
#include <QQmlEngine>

#include "moc_qmlplaylistproxy.cpp"
#include "qmltrackproxy.h"
#include "track/track.h"
#include "util/assert.h"

namespace mixxx {
namespace qml {

QmlPlaylistProxy::QmlPlaylistProxy(QObject* parent, PlaylistDAO& dao, int pid, const QString& name)
        : QObject(parent),
          m_id(pid),
          m_name(name),
          m_dao(dao) {
}

Q_INVOKABLE void QmlPlaylistProxy::addTracks(const QList<QmlTrackProxy*>& tracks) {
    if (tracks.isEmpty())
        return;

    QList<TrackId> trackIds;
    for (const auto& track : tracks) {
        VERIFY_OR_DEBUG_ASSERT(track && track->internal()) {
            continue;
        }
        trackIds.push_back(track->internal()->getId());
    }
    m_dao.appendTracksToPlaylist(trackIds, m_id);
}

QmlLibraryTrackListModel* QmlPlaylistProxy::model() const {
    return nullptr;
}

} // namespace qml
} // namespace mixxx
