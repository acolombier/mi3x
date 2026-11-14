#pragma once

#include <QAbstractListModel>
#include <QQmlEngine>
#include <memory>

#include "effects/effectsmanager.h"

namespace mixxx {
namespace qml {

class QmlEffectManifestModel : public QAbstractListModel {
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(QmlEffectManifestModel)
    QML_NAMED_ELEMENT(EffectManifestModel)
    QML_UNCREATABLE("Only accessible via Mixxx.EffectsManager models")
  public:
    enum class Filter {
        All,
        Visible,
        Hidden,
        MixingEq,
        MainEq,
    };
    Q_ENUM(Filter)

    enum Roles {
        UniqueIdRole = Qt::UserRole + 1,
        EffectIdRole,
        NameRole,
        TypeRole,
        AuthorRole,
        VersionRole,
        DisplayNameRole,
        DescriptionRole,
        IsMixingEqRole,
        IsMainEqRole,
        VisibleRole,
    };
    Q_ENUM(Roles)
    enum BackendType {
        BuiltIn,
        AudioUnit,
        LV2,
        Unknown
    };
    Q_ENUM(BackendType);

    explicit QmlEffectManifestModel(
            std::shared_ptr<EffectsManager> pEffectsManager,
            Filter filter,
            bool includeEmptyEffect,
            QObject* parent = nullptr);

    QVariant data(const QModelIndex& index, int role) const override;
    int rowCount(const QModelIndex& parent) const override;
    QHash<int, QByteArray> roleNames() const override;
    Q_INVOKABLE QVariant get(int row) const;
    Q_INVOKABLE int rowForUniqueId(const QString& uniqueId) const;

  private slots:
    void refresh();
    void visibleEffectsChanged();

  private:
    bool matchesFilter(const EffectManifestPointer& pManifest) const;
    EffectManifestPointer manifestForRow(int row) const;

    const std::shared_ptr<EffectsManager> m_pEffectsManager;
    const Filter m_filter;
    const bool m_includeEmptyEffect;
    QList<EffectManifestPointer> m_manifests;
};

} // namespace qml
} // namespace mixxx
