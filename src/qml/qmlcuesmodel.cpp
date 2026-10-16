#include "qml/qmlcuesmodel.h"

#include <QModelIndex>

#include "moc_qmlcuesmodel.cpp"
#include "qml/qmlconfigproxy.h"
#include "track/cue.h"
#include "track/cueconversion.h"

namespace mixxx {
namespace qml {
namespace {
const QHash<int, QByteArray> kRoleNames = {
        {QmlCuesModel::StartPositionRole, "startPosition"},
        {QmlCuesModel::EndPositionRole, "endPosition"},
        {QmlCuesModel::LabelRole, "label"},
        {QmlCuesModel::IsLoopRole, "isLoop"},
        {QmlCuesModel::HotcueNumberRole, "hotcueNumber"},
        {QmlCuesModel::TypeRole, "type"},
};
}

QmlCuesModel::QmlCuesModel(
        QObject* pParent)
        : QAbstractListModel(pParent) {
}

void QmlCuesModel::setTrack(TrackPointer pTrack) {
    m_pTrack = pTrack;
}

void QmlCuesModel::setCues(QList<CuePointer> cues) {
    beginResetModel();
    m_cues = QList<CuePointer>(std::move(cues));
    endResetModel();
    bumpRevision();
}

QVariant QmlCuesModel::data(const QModelIndex& index, int role) const {
    if (index.row() < 0 || index.row() >= m_cues.size()) {
        return QVariant();
    }

    const CuePointer& pCue = m_cues.at(index.row());
    VERIFY_OR_DEBUG_ASSERT(pCue.get()) {
        return QVariant();
    }

    switch (role) {
    case QmlCuesModel::StartPositionRole: {
        const auto position = pCue->getPosition();
        return position.isValid() ? position.value() : QVariant();
    }
    case QmlCuesModel::EndPositionRole: {
        const auto position = pCue->getEndPosition();
        return position.isValid() ? position.value() : QVariant();
    }
    case QmlCuesModel::LabelRole:
        return pCue->getLabel();
    case QmlCuesModel::IsLoopRole:
        return pCue->getType() == CueType::Loop;
    case QmlCuesModel::HotcueNumberRole:
        return pCue->getHotCue();
    case QmlCuesModel::TypeRole:
        return static_cast<int>(pCue->getType());
    default:
        return QVariant();
    }
}

int QmlCuesModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) {
        return 0;
    }

    return m_cues.size();
}

QHash<int, QByteArray> QmlCuesModel::roleNames() const {
    return kRoleNames;
}

QVariant QmlCuesModel::get(int row) const {
    QModelIndex idx = index(row, 0);
    QVariantMap dataMap;
    for (auto it = kRoleNames.constBegin(); it != kRoleNames.constEnd(); it++) {
        dataMap.insert(it.value(), data(idx, it.key()));
    }
    return dataMap;
}

int QmlCuesModel::findIndexByHotcueNumber(int hotcueNumber) const {
    for (int row = 0; row < m_cues.size(); ++row) {
        const CuePointer& pCue = m_cues.at(row);
        if (pCue && pCue->getHotCue() == hotcueNumber) {
            return row;
        }
    }
    return -1;
}

QMap<QString, QVariant> QmlCuesModel::getByHotcueNumber(int hotcueNumber) const {
    const int row = findIndexByHotcueNumber(hotcueNumber);
    if (row < 0) {
        return {};
    }

    QModelIndex idx = index(row, 0);
    QMap<QString, QVariant> dataMap;
    for (auto it = kRoleNames.constBegin(); it != kRoleNames.constEnd(); it++) {
        dataMap.insert(it.value(), data(idx, it.key()));
    }
    return dataMap;
}

void QmlCuesModel::setLabelByHotcueNumber(
        int hotcueNumber, const QString& label) {
    const int row = findIndexByHotcueNumber(hotcueNumber);
    VERIFY_OR_DEBUG_ASSERT(row >= 0) {
        return;
    }
    const CuePointer& pCue = m_cues.at(row);
    VERIFY_OR_DEBUG_ASSERT(pCue.get()) {
        return;
    }
    // The model will be reset whenever the track emits cuesUpdated in
    // response to the cue change (-> revisionChanged).
    pCue->setLabel(label);
}

bool QmlCuesModel::convertTypeByHotcueNumber(
        int hotcueNumber, int newType, const QString& playerGroup) {
    const int row = findIndexByHotcueNumber(hotcueNumber);
    VERIFY_OR_DEBUG_ASSERT(row >= 0) {
        return false;
    }
    const CuePointer& pCue = m_cues.at(row);
    VERIFY_OR_DEBUG_ASSERT(pCue.get()) {
        return false;
    }

    VERIFY_OR_DEBUG_ASSERT(m_pTrack) {
        return false;
    }

    const auto config = mixxx::qml::QmlConfigProxy::get();
    VERIFY_OR_DEBUG_ASSERT(config) {
        return false;
    }

    // The model will be reset whenever the track emits cuesUpdated in
    // response to the cue change (-> revisionChanged).
    mixxx::cueconversion::convertCueType(m_pTrack,
            pCue,
            playerGroup,
            config,
            static_cast<CueType>(newType));
    return true;
}

bool QmlCuesModel::swapPositionsByHotcueNumber(int hotcueNumber) {
    const int row = findIndexByHotcueNumber(hotcueNumber);
    VERIFY_OR_DEBUG_ASSERT(row >= 0) {
        return false;
    }
    const CuePointer& pCue = m_cues.at(row);
    VERIFY_OR_DEBUG_ASSERT(pCue.get()) {
        return false;
    }
    const auto positions = pCue->getStartAndEndPosition();
    if (!positions.endPosition.isValid()) {
        return false;
    }
    // The model will be reset whenever the track emits cuesUpdated in
    // response to the cue change (-> revisionChanged).
    pCue->setStartAndEndPosition(positions.endPosition, positions.startPosition);
    return true;
}

void QmlCuesModel::bumpRevision() {
    ++m_revision;
    emit revisionChanged();
}

} // namespace qml
} // namespace mixxx
