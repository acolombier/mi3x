#include "qml/qmleffectmanifestmodel.h"

#include <QModelIndex>

#include "effects/backends/effectmanifest.h"
#include "effects/visibleeffectslist.h"
#include "moc_qmleffectmanifestmodel.cpp"

namespace mixxx {
namespace qml {
namespace {
const QHash<int, QByteArray> kRoleNames = {
        {Qt::DisplayRole, "display"},
        {Qt::ToolTipRole, "tooltip"},
        {QmlEffectManifestModel::UniqueIdRole, "uniqueId"},
        {QmlEffectManifestModel::EffectIdRole, "effectId"},
        {QmlEffectManifestModel::NameRole, "name"},
        {QmlEffectManifestModel::TypeRole, "type"},
        {QmlEffectManifestModel::AuthorRole, "author"},
        {QmlEffectManifestModel::VersionRole, "version"},
        {QmlEffectManifestModel::DisplayNameRole, "displayName"},
        {QmlEffectManifestModel::DescriptionRole, "description"},
        {QmlEffectManifestModel::IsMixingEqRole, "isMixingEq"},
        {QmlEffectManifestModel::IsMainEqRole, "isMainEq"},
        {QmlEffectManifestModel::VisibleRole, "visible"},
};
} // namespace

QmlEffectManifestModel::QmlEffectManifestModel(
        std::shared_ptr<EffectsManager> pEffectsManager,
        Filter filter,
        bool includeEmptyEffect,
        QObject* parent)
        : QAbstractListModel(parent),
          m_pEffectsManager(std::move(pEffectsManager)),
          m_filter(filter),
          m_includeEmptyEffect(includeEmptyEffect) {
    refresh();
    connect(m_pEffectsManager->getVisibleEffectsList().get(),
            &VisibleEffectsList::visibleEffectsListChanged,
            this,
            &QmlEffectManifestModel::visibleEffectsChanged);
}

bool QmlEffectManifestModel::matchesFilter(
        const EffectManifestPointer& pManifest) const {
    switch (m_filter) {
    case Filter::All:
        return true;
    case Filter::Visible:
        return m_pEffectsManager->getVisibleEffectsList()->getList().contains(pManifest);
    case Filter::Hidden:
        return !m_pEffectsManager->getVisibleEffectsList()->getList().contains(pManifest);
    case Filter::MixingEq:
        return pManifest->isMixingEQ();
    case Filter::MainEq:
        return pManifest->isMainEQ();
    }
    return false;
}

void QmlEffectManifestModel::refresh() {
    beginResetModel();
    if (m_filter == Filter::Visible) {
        m_manifests = m_pEffectsManager->getVisibleEffectsList()->getList();
    } else {
        m_manifests.clear();
        for (const auto& pManifest : m_pEffectsManager->getBackendManager()->getManifests()) {
            if (matchesFilter(pManifest)) {
                m_manifests.append(pManifest);
            }
        }
    }
    endResetModel();
}

void QmlEffectManifestModel::visibleEffectsChanged() {
    if (m_filter == Filter::Visible || m_filter == Filter::Hidden) {
        refresh();
        return;
    }
    if (m_manifests.isEmpty()) {
        return;
    }
    emit dataChanged(index(0, 0),
            index(m_manifests.size() - 1, 0),
            {VisibleRole});
}

EffectManifestPointer QmlEffectManifestModel::manifestForRow(int row) const {
    if (m_includeEmptyEffect) {
        if (row == 0) {
            return {};
        }
        --row;
    }
    if (row < 0 || row >= m_manifests.size()) {
        return {};
    }
    return m_manifests.at(row);
}

QVariant QmlEffectManifestModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid()) {
        return QVariant();
    }
    const int row = index.row();
    const int firstManifestRow = m_includeEmptyEffect ? 1 : 0;
    if (m_includeEmptyEffect && row == 0) {
        switch (role) {
        case Qt::DisplayRole:
        case NameRole:
        case DisplayNameRole:
        case TypeRole:
        case AuthorRole:
        case VersionRole:
            return kNoEffectString;
        case Qt::ToolTipRole:
        case DescriptionRole:
            return tr("No effect loaded.");
        case UniqueIdRole:
        case EffectIdRole:
            return QString();
        case IsMixingEqRole:
        case IsMainEqRole:
            return false;
        case VisibleRole:
            return true;
        default:
            return QVariant();
        }
    }
    if (row < firstManifestRow || row - firstManifestRow >= m_manifests.size()) {
        return QVariant();
    }

    const EffectManifestPointer pManifest = m_manifests.at(row - firstManifestRow);
    switch (role) {
    case Qt::DisplayRole:
        return pManifest->displayName();
    case Qt::ToolTipRole:
        return pManifest->description();
    case UniqueIdRole:
        return pManifest->uniqueId();
    case EffectIdRole:
        return pManifest->id();
    case NameRole:
        return pManifest->name();
    case TypeRole:
        return static_cast<BackendType>(pManifest->backendType());
    case AuthorRole:
        return pManifest->author();
    case VersionRole:
        return pManifest->version();
    case DisplayNameRole:
        return pManifest->displayName();
    case DescriptionRole:
        return pManifest->description();
    case IsMixingEqRole:
        return pManifest->isMixingEQ();
    case IsMainEqRole:
        return pManifest->isMainEQ();
    case VisibleRole:
        return m_pEffectsManager->getVisibleEffectsList()->getList().contains(pManifest);
    default:
        return QVariant();
    }
}

int QmlEffectManifestModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) {
        return 0;
    }
    return m_manifests.size() + (m_includeEmptyEffect ? 1 : 0);
}

QHash<int, QByteArray> QmlEffectManifestModel::roleNames() const {
    return kRoleNames;
}

QVariant QmlEffectManifestModel::get(int row) const {
    const QModelIndex idx = index(row, 0);
    QVariantMap dataMap;
    for (auto it = kRoleNames.constBegin(); it != kRoleNames.constEnd(); it++) {
        dataMap.insert(it.value(), data(idx, it.key()));
    }
    return dataMap;
}

int QmlEffectManifestModel::rowForUniqueId(const QString& uniqueId) const {
    const int firstManifestRow = m_includeEmptyEffect ? 1 : 0;
    if (uniqueId.isEmpty()) {
        return m_includeEmptyEffect ? 0 : -1;
    }
    for (int i = 0; i < m_manifests.size(); ++i) {
        if (m_manifests.at(i)->uniqueId() == uniqueId) {
            return i + firstManifestRow;
        }
    }
    return -1;
}

} // namespace qml
} // namespace mixxx
