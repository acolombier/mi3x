#pragma once
#include <QObject>
#include <QQmlEngine>
#include <QVariantList>

#include "effects/effectsmanager.h"
#include "qml/qmlchainpresetmodel.h"
#include "qml/qmleffectmanifestmodel.h"
#include "qml/qmleffectslotproxy.h"
#include "qml/qmleffectunitproxy.h"
#include "qml/qmlvisibleeffectsmodel.h"

namespace mixxx {
namespace qml {

class QmlChainPresetModel;

class QmlEffectsManagerProxy : public QObject {
    Q_OBJECT
    Q_PROPERTY(mixxx::qml::QmlVisibleEffectsModel* visibleEffectsModel
                    MEMBER m_pVisibleEffectsModel CONSTANT)
    Q_PROPERTY(mixxx::qml::QmlChainPresetModel* quickChainPresetModel
                    MEMBER m_pQuickChainPresetModel CONSTANT)
    Q_PROPERTY(mixxx::qml::QmlChainPresetModel* standardChainPresetModel
                    MEMBER m_pStandardChainPresetModel CONSTANT)
    Q_PROPERTY(mixxx::qml::QmlChainPresetModel* standardChainPresetSettingsModel
                    MEMBER m_pStandardChainPresetSettingsModel CONSTANT)
    Q_PROPERTY(mixxx::qml::QmlChainPresetModel* quickChainPresetSettingsModel
                    MEMBER m_pQuickChainPresetSettingsModel CONSTANT)
    Q_PROPERTY(mixxx::qml::QmlEffectManifestModel* allEffectsModel
                    MEMBER m_pAllEffectsModel CONSTANT)
    Q_PROPERTY(mixxx::qml::QmlEffectManifestModel* visibleEffectsSettingsModel
                    MEMBER m_pVisibleEffectsSettingsModel CONSTANT)
    Q_PROPERTY(mixxx::qml::QmlEffectManifestModel* hiddenEffectsSettingsModel
                    MEMBER m_pHiddenEffectsSettingsModel CONSTANT)
    Q_PROPERTY(mixxx::qml::QmlEffectManifestModel* mixingEqEffectsModel
                    MEMBER m_pMixingEqEffectsModel CONSTANT)
    Q_PROPERTY(mixxx::qml::QmlEffectManifestModel* mainEqEffectsModel
                    MEMBER m_pMainEqEffectsModel CONSTANT)
    QML_NAMED_ELEMENT(EffectsManager)
    QML_SINGLETON

  public:
    explicit QmlEffectsManagerProxy(
            std::shared_ptr<EffectsManager> pEffectsManager,
            QObject* parent = nullptr);

    Q_INVOKABLE mixxx::qml::QmlEffectSlotProxy* getEffectSlot(
            int unitNumber, int effectNumber) const;
    Q_INVOKABLE mixxx::qml::QmlEffectUnitProxy* getEffectUnit(int unitNumber) const;
    Q_INVOKABLE mixxx::qml::QmlEffectSlotProxy* getMainEqEffectSlot() const;
    Q_INVOKABLE mixxx::qml::QmlEffectSlotProxy* getDeckEqEffectSlot(int deckNumber) const;
    Q_INVOKABLE mixxx::qml::QmlEffectSlotProxy* getDeckQuickEffectSlot(int deckNumber) const;
    Q_INVOKABLE int numDecks() const;
    Q_INVOKABLE void migrateLegacyEffectSettings();
    Q_INVOKABLE void applyDeckEqSettings(bool bypass,
            bool eqsOnly,
            bool singleEq,
            const QVariantList& eqUniqueIds);
    Q_INVOKABLE void applyQuickEffectSettings(const QVariantList& presetIndices);
    Q_INVOKABLE void loadDefaultEqsAndQuickEffects();
    Q_INVOKABLE void setEffectVisible(const QString& uniqueId, bool visible);
    Q_INVOKABLE void moveVisibleEffect(int fromIndex, int toIndex);
    Q_INVOKABLE void setVisibleEffects(const QStringList& uniqueIds);
    Q_INVOKABLE void setChainPresetOrder(const QStringList& names, bool quickEffectPresets);

    static QmlEffectsManagerProxy* create(QQmlEngine* pQmlEngine, QJSEngine* pJsEngine);
    static void registerEffectsManager(std::shared_ptr<EffectsManager> pEffectsManager) {
        s_pEffectManager = std::move(pEffectsManager);
    }

  private:
    static inline std::shared_ptr<EffectsManager> s_pEffectManager;

    const std::shared_ptr<EffectsManager> m_pEffectsManager;
    QmlVisibleEffectsModel* m_pVisibleEffectsModel;
    QmlChainPresetModel* m_pQuickChainPresetModel;
    QmlChainPresetModel* m_pStandardChainPresetModel;
    QmlChainPresetModel* m_pQuickChainPresetSettingsModel;
    QmlChainPresetModel* m_pStandardChainPresetSettingsModel;
    QmlEffectManifestModel* m_pAllEffectsModel;
    QmlEffectManifestModel* m_pVisibleEffectsSettingsModel;
    QmlEffectManifestModel* m_pHiddenEffectsSettingsModel;
    QmlEffectManifestModel* m_pMixingEqEffectsModel;
    QmlEffectManifestModel* m_pMainEqEffectsModel;
    QList<QmlEffectUnitProxy*> m_effectUnitProxies;
    mutable QList<QmlEffectSlotProxy*> m_deckEqSlotProxies;
    mutable QList<QmlEffectSlotProxy*> m_deckQuickEffectSlotProxies;
    mutable QmlEffectSlotProxy* m_pMainEqSlotProxy = nullptr;
};

} // namespace qml
} // namespace mixxx
