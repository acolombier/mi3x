#include "qml/qmleffectsmanagerproxy.h"

#include <QQmlEngine>
#include <memory>

#include "control/controlobject.h"
#include "effects/backends/effectmanifest.h"
#include "effects/backends/effectmanifestparameter.h"
#include "effects/chains/equalizereffectchain.h"
#include "effects/chains/quickeffectchain.h"
#include "effects/effectchain.h"
#include "effects/effectslot.h"
#include "effects/presets/effectchainpreset.h"
#include "effects/visibleeffectslist.h"
#include "mixer/playermanager.h"
#include "moc_qmleffectsmanagerproxy.cpp"
#include "qml/qmlchainpresetmodel.h"
#include "qml/qmlconfigproxy.h"

namespace mixxx {
namespace qml {

QmlEffectsManagerProxy::QmlEffectsManagerProxy(
        std::shared_ptr<EffectsManager> pEffectsManager, QObject* parent)
        : QObject(parent),
          m_pEffectsManager(std::move(pEffectsManager)),
          m_pVisibleEffectsModel(
                  new QmlVisibleEffectsModel(m_pEffectsManager, this)),
          m_pQuickChainPresetModel(
                  new QmlChainPresetModel(m_pEffectsManager,
                          QmlChainPresetModel::PresetType::Quick,
                          this)),
          m_pStandardChainPresetModel(
                  new QmlChainPresetModel(m_pEffectsManager,
                          QmlChainPresetModel::PresetType::Standard,
                          this)),
          m_pQuickChainPresetSettingsModel(
                  new QmlChainPresetModel(m_pEffectsManager,
                          QmlChainPresetModel::PresetType::Quick,
                          this,
                          false)),
          m_pStandardChainPresetSettingsModel(
                  new QmlChainPresetModel(m_pEffectsManager,
                          QmlChainPresetModel::PresetType::Standard,
                          this,
                          false)),
          m_pAllEffectsModel(new QmlEffectManifestModel(m_pEffectsManager,
                  QmlEffectManifestModel::Filter::All,
                  false,
                  this)),
          m_pVisibleEffectsSettingsModel(new QmlEffectManifestModel(m_pEffectsManager,
                  QmlEffectManifestModel::Filter::Visible,
                  false,
                  this)),
          m_pHiddenEffectsSettingsModel(new QmlEffectManifestModel(m_pEffectsManager,
                  QmlEffectManifestModel::Filter::Hidden,
                  false,
                  this)),
          m_pMixingEqEffectsModel(new QmlEffectManifestModel(m_pEffectsManager,
                  QmlEffectManifestModel::Filter::MixingEq,
                  false,
                  this)),
          m_pMainEqEffectsModel(new QmlEffectManifestModel(m_pEffectsManager,
                  QmlEffectManifestModel::Filter::MainEq,
                  true,
                  this)) {
    for (int unitIndex = 0; unitIndex < kNumStandardEffectUnits; ++unitIndex) {
        const auto pEffectUnit = m_pEffectsManager->getStandardEffectChain(unitIndex);
        if (pEffectUnit) {
            m_effectUnitProxies.append(new QmlEffectUnitProxy(
                    m_pEffectsManager, unitIndex + 1, pEffectUnit, this));
        }
    }
}

QmlEffectUnitProxy* QmlEffectsManagerProxy::getEffectUnit(int unitNumber) const {
    const int unitIndex = unitNumber - 1;
    if (unitIndex < 0 || unitIndex >= m_effectUnitProxies.size()) {
        qWarning() << "QmlEffectsManagerProxy: Effect Unit" << unitNumber
                   << "not found!";
        return nullptr;
    }
    return m_effectUnitProxies.at(unitIndex);
}

QmlEffectSlotProxy* QmlEffectsManagerProxy::getEffectSlot(int unitNumber, int effectNumber) const {
    // Subtract 1 from all numbers, because internally our indices are
    // zero-based
    const int unitIndex = unitNumber - 1;
    const auto pEffectUnit = m_pEffectsManager->getStandardEffectChain(unitIndex);
    if (!pEffectUnit) {
        qWarning() << "QmlEffectsManagerProxy: Effect Unit" << unitNumber
                   << "not found!";
        return nullptr;
    }

    const int effectIndex = effectNumber - 1;
    const auto pEffectSlot = pEffectUnit->getEffectSlot(effectIndex);
    if (!pEffectSlot) {
        qWarning() << "QmlEffectsManagerProxy: Effect Slot" << effectNumber
                   << "in Unit" << unitNumber << "not found!";
        return nullptr;
    }

    // Don't set a parent here, so that the QML engine deletes the object when
    // the corresponding JS object is garbage collected.
    QmlEffectSlotProxy* pEffectSlotProxy = new QmlEffectSlotProxy(
            m_pEffectsManager, unitNumber, pEffectUnit, pEffectSlot);
    QQmlEngine::setObjectOwnership(pEffectSlotProxy, QQmlEngine::JavaScriptOwnership);
    return pEffectSlotProxy;
}

QmlEffectSlotProxy* QmlEffectsManagerProxy::getMainEqEffectSlot() const {
    const auto pChain = m_pEffectsManager->getOutputEffectChain();
    if (!pChain) {
        return nullptr;
    }
    const auto pEffectSlot = pChain->getEffectSlot(0);
    if (!pEffectSlot) {
        return nullptr;
    }
    if (!m_pMainEqSlotProxy) {
        m_pMainEqSlotProxy = new QmlEffectSlotProxy(m_pEffectsManager,
                1,
                pChain,
                pEffectSlot,
                const_cast<QmlEffectsManagerProxy*>(this));
    }
    return m_pMainEqSlotProxy;
}

QmlEffectSlotProxy* QmlEffectsManagerProxy::getDeckEqEffectSlot(int deckNumber) const {
    const int deckIndex = deckNumber - 1;
    const auto pChain = m_pEffectsManager->getEqualizerEffectChain(
            PlayerManager::groupForDeck(deckIndex));
    if (!pChain) {
        qWarning() << "QmlEffectsManagerProxy: EQ chain for deck" << deckNumber
                   << "not found!";
        return nullptr;
    }
    const auto pEffectSlot = pChain->getEffectSlot(0);
    if (!pEffectSlot) {
        return nullptr;
    }
    while (m_deckEqSlotProxies.size() <= deckIndex) {
        m_deckEqSlotProxies.append(nullptr);
    }
    if (!m_deckEqSlotProxies.at(deckIndex)) {
        m_deckEqSlotProxies[deckIndex] = new QmlEffectSlotProxy(
                m_pEffectsManager,
                deckNumber,
                pChain,
                pEffectSlot,
                const_cast<QmlEffectsManagerProxy*>(this));
    }
    return m_deckEqSlotProxies.at(deckIndex);
}

QmlEffectSlotProxy* QmlEffectsManagerProxy::getDeckQuickEffectSlot(int deckNumber) const {
    const int deckIndex = deckNumber - 1;
    const auto pChain = m_pEffectsManager->getQuickEffectChain(
            PlayerManager::groupForDeck(deckIndex));
    if (!pChain) {
        qWarning() << "QmlEffectsManagerProxy: Quick effect chain for deck"
                   << deckNumber << "not found!";
        return nullptr;
    }
    const auto pEffectSlot = pChain->getEffectSlot(0);
    if (!pEffectSlot) {
        return nullptr;
    }
    while (m_deckQuickEffectSlotProxies.size() <= deckIndex) {
        m_deckQuickEffectSlotProxies.append(nullptr);
    }
    if (!m_deckQuickEffectSlotProxies.at(deckIndex)) {
        m_deckQuickEffectSlotProxies[deckIndex] = new QmlEffectSlotProxy(
                m_pEffectsManager,
                deckNumber,
                pChain,
                pEffectSlot,
                const_cast<QmlEffectsManagerProxy*>(this));
    }
    return m_deckQuickEffectSlotProxies.at(deckIndex);
}

int QmlEffectsManagerProxy::numDecks() const {
    const auto* pControl = ControlObject::getControl(
            ConfigKey(QStringLiteral("[App]"), QStringLiteral("num_decks")));
    return pControl ? static_cast<int>(pControl->get()) : 0;
}

void QmlEffectsManagerProxy::migrateLegacyEffectSettings() {
    const UserSettingsPointer pConfig = QmlConfigProxy::get();
    if (!pConfig) {
        return;
    }

    const auto pBackendManager = m_pEffectsManager->getBackendManager();
    const ConfigKey masterEffectKey(
            QStringLiteral("[Mixer Profile]"),
            QStringLiteral("EffectForGroup_[Master]"));

    const QString configuredMainEq = pConfig->getValueString(masterEffectKey);
    if (configuredMainEq.isNull() || configuredMainEq.isEmpty()) {
        const QList<ConfigKey> mixerKeys = pConfig->getKeysWithGroup(
                QStringLiteral("[Mixer Profile]"));
        for (const auto& key : mixerKeys) {
            if (key.item.contains(QStringLiteral("EffectForGroup_[Master]"))) {
                pConfig->remove(key);
            }
        }
    } else {
        const auto pManifest = pBackendManager->getManifestFromUniqueId(configuredMainEq);
        auto* pSlotProxy = getMainEqEffectSlot();
        if (pManifest && pSlotProxy) {
            pSlotProxy->setEffectId(pManifest->uniqueId());
            for (const auto& pParameter : pManifest->parameters()) {
                if (pParameter->parameterType() !=
                        EffectManifestParameter::ParameterType::Knob) {
                    continue;
                }
                const QString configKey = QStringLiteral(
                        "EffectForGroup_[Master]_parameter%1")
                                                  .arg(pParameter->index() + 1);
                bool ok = false;
                const double value = pConfig->getValueString(
                                                    ConfigKey(QStringLiteral(
                                                                      "[Mixer Profile]"),
                                                            configKey))
                                             .toDouble(&ok);
                if (ok) {
                    pSlotProxy->setParameterValue(pParameter->id(), value);
                }
            }
        }
        const QList<ConfigKey> mixerKeys = pConfig->getKeysWithGroup(
                QStringLiteral("[Mixer Profile]"));
        for (const auto& key : mixerKeys) {
            if (key.item.contains(QStringLiteral("EffectForGroup_[Master]"))) {
                pConfig->remove(key);
            }
        }
    }

    for (int deckIndex = 0; deckIndex < numDecks(); ++deckIndex) {
        const QString deckGroup = PlayerManager::groupForDeck(deckIndex);
        const ConfigKey groupKey(QStringLiteral("[Mixer Profile]"),
                QStringLiteral("EffectForGroup_") + deckGroup);
        const QString configuredEffect = pConfig->getValueString(groupKey);
        if (configuredEffect.isNull()) {
            continue;
        }
        const auto pEqChain = m_pEffectsManager->getEqualizerEffectChain(deckGroup);
        if (pEqChain) {
            const auto pEffectSlot = pEqChain->getEffectSlot(0);
            if (pEffectSlot) {
                pEffectSlot->loadEffectWithDefaults(
                        pBackendManager->getManifestFromUniqueId(configuredEffect));
            }
        }
        pConfig->remove(groupKey);
    }
}

void QmlEffectsManagerProxy::applyDeckEqSettings(bool bypass,
        bool eqsOnly,
        bool singleEq,
        const QVariantList& eqUniqueIds) {
    Q_UNUSED(eqsOnly);
    const auto pBackendManager = m_pEffectsManager->getBackendManager();
    const QString singleEqUniqueId =
            eqUniqueIds.isEmpty() ? QString() : eqUniqueIds.at(0).toString();

    for (int deckIndex = 0; deckIndex < numDecks(); ++deckIndex) {
        const QString deckGroup = PlayerManager::groupForDeck(deckIndex);
        const auto pChain = m_pEffectsManager->getEqualizerEffectChain(deckGroup);
        if (!pChain) {
            continue;
        }
        const auto pEffectSlot = pChain->getEffectSlot(0);
        if (!pEffectSlot) {
            continue;
        }

        const QString desiredUniqueId = singleEq
                ? singleEqUniqueId
                : (deckIndex < eqUniqueIds.size()
                                  ? eqUniqueIds.at(deckIndex).toString()
                                  : QString());
        const auto pManifest = pBackendManager->getManifestFromUniqueId(
                desiredUniqueId);
        const auto pCurrentManifest = pEffectSlot->getManifest();
        const QString currentUniqueId = pCurrentManifest
                ? pCurrentManifest->uniqueId()
                : QString();
        if (currentUniqueId != desiredUniqueId) {
            pEffectSlot->loadEffectWithDefaults(pManifest);
        }
        pEffectSlot->setEnabled(!bypass);
        pChain->setFilterWaveform(pManifest && pManifest->isMixingEQ() && !bypass);
    }
}

void QmlEffectsManagerProxy::applyQuickEffectSettings(
        const QVariantList& presetIndices) {
    const auto pPresetManager = m_pEffectsManager->getChainPresetManager();
    const QList<EffectChainPresetPointer> presets =
            pPresetManager->getQuickEffectPresetsSorted();
    for (int deckIndex = 0; deckIndex < numDecks(); ++deckIndex) {
        const auto pChain = m_pEffectsManager->getQuickEffectChain(
                PlayerManager::groupForDeck(deckIndex));
        if (!pChain || deckIndex >= presetIndices.size()) {
            continue;
        }
        const int presetIndex = presetIndices.at(deckIndex).toInt();
        if (presetIndex < 0 || presetIndex >= presets.size()) {
            continue;
        }
        const auto pPreset = presets.at(presetIndex);
        if (pChain->presetName() != pPreset->name()) {
            pChain->loadChainPreset(pPreset);
        }
    }
}

void QmlEffectsManagerProxy::loadDefaultEqsAndQuickEffects() {
    m_pEffectsManager->loadDefaultEqsAndQuickEffects();
}

void QmlEffectsManagerProxy::setEffectVisible(const QString& uniqueId, bool visible) {
    const auto pManifest = m_pEffectsManager->getBackendManager()
                                   ->getManifestFromUniqueId(uniqueId);
    if (!pManifest) {
        return;
    }
    const auto pVisibleEffectsList = m_pEffectsManager->getVisibleEffectsList();
    QList<EffectManifestPointer> effects = pVisibleEffectsList->getList();
    const int index = effects.indexOf(pManifest);
    if (visible && index == -1) {
        effects.append(pManifest);
    } else if (!visible && index != -1) {
        effects.removeAt(index);
    } else {
        return;
    }
    pVisibleEffectsList->setList(effects);
}

void QmlEffectsManagerProxy::setVisibleEffects(const QStringList& uniqueIds) {
    const auto pBackendManager = m_pEffectsManager->getBackendManager();
    QList<EffectManifestPointer> effects;
    effects.reserve(uniqueIds.size());
    for (const QString& uniqueId : uniqueIds) {
        const auto pManifest = pBackendManager->getManifestFromUniqueId(uniqueId);
        if (pManifest) {
            effects.append(pManifest);
        }
    }
    m_pEffectsManager->getVisibleEffectsList()->setList(effects);
}

void QmlEffectsManagerProxy::setChainPresetOrder(
        const QStringList& names, bool quickEffectPresets) {
    if (quickEffectPresets) {
        m_pEffectsManager->getChainPresetManager()->setQuickEffectPresetOrder(names);
    } else {
        m_pEffectsManager->getChainPresetManager()->setPresetOrder(names);
    }
}

void QmlEffectsManagerProxy::moveVisibleEffect(int fromIndex, int toIndex) {
    const auto pVisibleEffectsList = m_pEffectsManager->getVisibleEffectsList();
    QList<EffectManifestPointer> effects = pVisibleEffectsList->getList();
    if (fromIndex < 0 || fromIndex >= effects.size() ||
            toIndex < 0 || toIndex >= effects.size() || fromIndex == toIndex) {
        return;
    }
    effects.move(fromIndex, toIndex);
    pVisibleEffectsList->setList(effects);
}

// static
QmlEffectsManagerProxy* QmlEffectsManagerProxy::create(
        QQmlEngine* pQmlEngine, QJSEngine* pJsEngine) {
    // The implementation of this method is mostly taken from the code example
    // that shows the replacement for `qmlRegisterSingletonInstance()` when
    // using `QML_SINGLETON`.
    // https://doc.qt.io/qt-6/qqmlengine.html#QML_SINGLETON

    // The instance has to exist before it is used. We cannot replace it.
    VERIFY_OR_DEBUG_ASSERT(s_pEffectManager) {
        qWarning() << "EffectManager hasn't been registered yet";
        return nullptr;
    }
    return new QmlEffectsManagerProxy(s_pEffectManager, pQmlEngine);
}

} // namespace qml
} // namespace mixxx
