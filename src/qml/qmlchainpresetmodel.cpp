#include "qml/qmlchainpresetmodel.h"

#include <QModelIndex>

#include "effects/backends/effectmanifest.h"
#include "effects/effectsmanager.h"
#include "effects/presets/effectchainpreset.h"
#include "effects/presets/effectpreset.h"
#include "moc_qmlchainpresetmodel.cpp"

namespace mixxx {
namespace qml {
namespace {
const QHash<int, QByteArray> kRoleNames = {
        {Qt::DisplayRole, "display"},
        {Qt::ToolTipRole, "tooltip"},
        {QmlChainPresetModel::NameRole, "name"},
        {QmlChainPresetModel::ReadOnlyRole, "readOnly"},
        {QmlChainPresetModel::PresetDisplayRole, "presetDisplay"},
};
}

QmlChainPresetModel::QmlChainPresetModel(
        std::shared_ptr<EffectsManager> pEffectsManager,
        PresetType presetType,
        QObject* parent,
        bool includeEmptyPreset)
        : QAbstractListModel(parent),
          m_pEffectsManager(std::move(pEffectsManager)),
          m_pEffectChainPresetManager(m_pEffectsManager->getChainPresetManager()),
          m_presetType(presetType),
          m_includeEmptyPreset(includeEmptyPreset) {
    slotUpdated();
    if (m_presetType == PresetType::Quick) {
        connect(m_pEffectChainPresetManager.get(),
                &EffectChainPresetManager::quickEffectChainPresetListUpdated,
                this,
                &QmlChainPresetModel::slotUpdated);
    } else {
        connect(m_pEffectChainPresetManager.get(),
                &EffectChainPresetManager::effectChainPresetListUpdated,
                this,
                &QmlChainPresetModel::slotUpdated);
    }
}

void QmlChainPresetModel::slotUpdated() {
    beginResetModel();
    m_effectChainPresets = m_presetType == PresetType::Quick
            ? m_pEffectChainPresetManager->getQuickEffectPresetsSorted()
            : m_pEffectChainPresetManager->getPresetsSorted();
    if (!m_includeEmptyPreset) {
        m_effectChainPresets.removeIf([](const EffectChainPresetPointer& pPreset) {
            return pPreset->name() == kNoEffectString;
        });
    }
    endResetModel();
}

QVariant QmlChainPresetModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_effectChainPresets.size()) {
        return QVariant();
    }

    const EffectChainPresetPointer pPreset = m_effectChainPresets.at(index.row());
    switch (role) {
    case Qt::DisplayRole:
    case NameRole:
    case PresetDisplayRole:
        return pPreset->name();
    case ReadOnlyRole:
        return pPreset->isReadOnly();
    case Qt::ToolTipRole: {
        QStringList effectNames;
        for (const auto& pEffectPreset : pPreset->effectPresets()) {
            if (pEffectPreset->isEmpty()) {
                continue;
            }
            const EffectManifestPointer pManifest =
                    m_pEffectsManager->getBackendManager()->getManifest(pEffectPreset);
            if (pManifest) {
                effectNames.append(pManifest->name());
            }
        }
        QString tooltip = QStringLiteral("<b>%1</b>").arg(pPreset->name().toHtmlEscaped());
        if (effectNames.size() > 1) {
            tooltip.append(QStringLiteral("<br/>"));
            tooltip.append(effectNames.join(QStringLiteral("<br/>")));
        }
        return tooltip;
    }
    default:
        return QVariant();
    }
}

int QmlChainPresetModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) {
        return 0;
    }

    return m_effectChainPresets.size();
}

QHash<int, QByteArray> QmlChainPresetModel::roleNames() const {
    return kRoleNames;
}

QString QmlChainPresetModel::presetName(int row) const {
    if (row < 0 || row >= m_effectChainPresets.size()) {
        return {};
    }
    return m_effectChainPresets.at(row)->name();
}

bool QmlChainPresetModel::renamePreset(int row, const QString& newName) {
    if (row < 0 || row >= m_effectChainPresets.size()) {
        return false;
    }
    QString error;
    const bool success = m_pEffectChainPresetManager->renamePresetTo(
            m_effectChainPresets.at(row)->name(), newName, &error);
    m_lastError = success ? QString() : error;
    emit lastErrorChanged();
    return success;
}

bool QmlChainPresetModel::deletePreset(int row) {
    if (row < 0 || row >= m_effectChainPresets.size()) {
        return false;
    }
    QString error;
    const bool success = m_pEffectChainPresetManager->deletePresetByName(
            m_effectChainPresets.at(row)->name(), &error);
    m_lastError = success ? QString() : error;
    emit lastErrorChanged();
    return success;
}

bool QmlChainPresetModel::exportPresetToFile(int row, const QString& filePath) {
    if (row < 0 || row >= m_effectChainPresets.size()) {
        return false;
    }
    QString error;
    const bool success = m_pEffectChainPresetManager->exportPresetToFile(
            m_effectChainPresets.at(row)->name(), filePath, &error);
    m_lastError = success ? QString() : error;
    emit lastErrorChanged();
    return success;
}

QStringList QmlChainPresetModel::importPresets(const QStringList& filePaths) {
    QStringList errors;
    const QStringList imported = m_pEffectChainPresetManager->importPresetsFromFiles(
            filePaths, &errors);
    m_lastError = errors.join(QStringLiteral("\n"));
    emit lastErrorChanged();
    return imported;
}

bool QmlChainPresetModel::movePreset(int fromIndex, int toIndex) {
    if (fromIndex < 0 || fromIndex >= m_effectChainPresets.size() ||
            toIndex < 0 || toIndex >= m_effectChainPresets.size() ||
            fromIndex == toIndex) {
        return false;
    }
    QStringList order;
    order.reserve(m_effectChainPresets.size());
    for (const auto& pPreset : std::as_const(m_effectChainPresets)) {
        order.append(pPreset->name());
    }
    order.move(fromIndex, toIndex);
    if (m_presetType == PresetType::Quick) {
        m_pEffectChainPresetManager->setQuickEffectPresetOrder(order);
    } else {
        m_pEffectChainPresetManager->setPresetOrder(order);
    }
    return true;
}

void QmlChainPresetModel::resetToDefaults() {
    m_pEffectChainPresetManager->resetToDefaults();
}

QVariant QmlChainPresetModel::get(int row) const {
    QVariantMap dataMap;
    QModelIndex idx = index(row, 0);

    if (!idx.isValid()) {
        return dataMap;
    }

    for (auto it = kRoleNames.constBegin(); it != kRoleNames.constEnd(); it++) {
        dataMap.insert(it.value(), data(idx, it.key()));
    }
    return dataMap;
}

} // namespace qml
} // namespace mixxx
