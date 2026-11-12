#pragma once
#include <QAbstractListModel>
#include <QQmlEngine>
#include <QStringList>
#include <memory>

#include "effects/defs.h"

class EffectsManager;

namespace mixxx {
namespace qml {

class QmlChainPresetModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    QML_NAMED_ELEMENT(ChainPresetModel)
    QML_UNCREATABLE("Only accessible via Mixxx.EffectsManager preset model properties")
  public:
    enum class PresetType {
        Standard,
        Quick,
    };

    enum Roles {
        NameRole = Qt::UserRole + 1,
        ReadOnlyRole,
        PresetDisplayRole,
    };
    Q_ENUM(Roles)

    explicit QmlChainPresetModel(
            std::shared_ptr<EffectsManager> pEffectsManager,
            PresetType presetType,
            QObject* parent = nullptr,
            bool includeEmptyPreset = true);

    QVariant data(const QModelIndex& index, int role) const override;
    int rowCount(const QModelIndex& parent) const override;
    QHash<int, QByteArray> roleNames() const override;
    Q_INVOKABLE QVariant get(int row) const;
    Q_INVOKABLE QString presetName(int row) const;
    Q_INVOKABLE bool renamePreset(int row, const QString& newName);
    Q_INVOKABLE bool deletePreset(int row);
    Q_INVOKABLE bool exportPresetToFile(int row, const QString& filePath);
    Q_INVOKABLE QStringList importPresets(const QStringList& filePaths);
    Q_INVOKABLE bool movePreset(int fromIndex, int toIndex);
    Q_INVOKABLE void resetToDefaults();

    QString lastError() const {
        return m_lastError;
    }

  signals:
    void lastErrorChanged();

  private slots:
    void slotUpdated();

  private:
    const std::shared_ptr<EffectsManager> m_pEffectsManager;
    const EffectChainPresetManagerPointer m_pEffectChainPresetManager;
    const PresetType m_presetType;
    const bool m_includeEmptyPreset;
    QList<EffectChainPresetPointer> m_effectChainPresets;
    QString m_lastError;
};

} // namespace qml
} // namespace mixxx
