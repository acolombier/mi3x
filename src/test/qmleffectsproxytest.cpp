#include <gtest/gtest.h>

#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <memory>

#include "control/controlobject.h"
#include "effects/backends/builtin/echoeffect.h"
#include "effects/backends/builtin/parametriceqeffect.h"
#include "effects/backends/effectmanifest.h"
#include "effects/backends/effectmanifestparameter.h"
#include "effects/backends/effectsbackendmanager.h"
#include "effects/effectchain.h"
#include "effects/effectsmanager.h"
#include "effects/presets/effectchainpreset.h"
#include "effects/presets/effectchainpresetmanager.h"
#include "engine/channelhandle.h"
#include "engine/enginexfader.h"
#include "mixer/playermanager.h"
#include "qml/qmlchainpresetmodel.h"
#include "qml/qmlconfigproxy.h"
#include "qml/qmleffectmanifestmodel.h"
#include "qml/qmleffectslotparametersmodel.h"
#include "qml/qmleffectslotproxy.h"
#include "qml/qmleffectsmanagerproxy.h"
#include "qml/qmleffectunitproxy.h"
#include "test/mixxxtest.h"

namespace {

constexpr int kTestDeckCount = 4;

class QmlEffectsProxyTest : public MixxxTest {
  protected:
    void SetUp() override {
        m_pNumDecks = std::make_unique<ControlObject>(
                ConfigKey(QStringLiteral("[App]"), QStringLiteral("num_decks")));
        m_pNumDecks->forceSet(kTestDeckCount);

        m_pChannelHandleFactory = std::make_shared<ChannelHandleFactory>();
        m_pEffectsManager =
                std::make_shared<EffectsManager>(config(), m_pChannelHandleFactory);
        const QString mainOutputGroup = QStringLiteral("[MasterOutput]");
        m_pEffectsManager->registerInputChannel(ChannelHandleAndGroup(
                m_pChannelHandleFactory->getOrCreateHandle(mainOutputGroup),
                mainOutputGroup));
        m_pEffectsManager->setup();
        for (int deckIndex = 0; deckIndex < kTestDeckCount; ++deckIndex) {
            const QString deckGroup = PlayerManager::groupForDeck(deckIndex);
            ChannelHandleAndGroup deckHandleGroup(
                    m_pChannelHandleFactory->getOrCreateHandle(deckGroup), deckGroup);
            m_pEffectsManager->registerInputChannel(deckHandleGroup);
            m_pEffectsManager->addDeck(deckHandleGroup);
        }
        mixxx::qml::QmlConfigProxy::registerUserSettings(config());
        m_pProxy = std::make_unique<mixxx::qml::QmlEffectsManagerProxy>(
                m_pEffectsManager);
    }

    void TearDown() override {
        m_pProxy.reset();
        mixxx::qml::QmlConfigProxy::registerUserSettings(nullptr);
        for (int unitIndex = 0; unitIndex < kNumStandardEffectUnits; ++unitIndex) {
            const auto pChain = m_pEffectsManager->getStandardEffectChain(unitIndex);
            auto pEmptyPreset = EffectChainPresetPointer::create();
            pEmptyPreset->setName(QString());
            pChain->loadChainPreset(pEmptyPreset);
            EXPECT_TRUE(pChain->isEmpty());
            EXPECT_TRUE(pChain->presetName().isEmpty());
        }
        m_pEffectsManager.reset();
        m_pChannelHandleFactory.reset();
        m_pNumDecks.reset();
    }

    std::shared_ptr<ChannelHandleFactory> m_pChannelHandleFactory;
    std::shared_ptr<EffectsManager> m_pEffectsManager;
    std::unique_ptr<ControlObject> m_pNumDecks;
    std::unique_ptr<mixxx::qml::QmlEffectsManagerProxy> m_pProxy;
};

TEST_F(QmlEffectsProxyTest, UnitLookup) {
    auto* pUnit1 = m_pProxy->getEffectUnit(1);
    ASSERT_NE(nullptr, pUnit1);
    EXPECT_EQ(pUnit1, m_pProxy->getEffectUnit(1));
    EXPECT_EQ(1, pUnit1->getUnitNumber());
    EXPECT_EQ(QStringLiteral("[EffectRack1_EffectUnit1]"), pUnit1->getGroup());
    EXPECT_EQ(nullptr, m_pProxy->getEffectUnit(0));
    EXPECT_EQ(nullptr, m_pProxy->getEffectUnit(5));
}

TEST_F(QmlEffectsProxyTest, PresetModelsResetSeparately) {
    auto* pStandardModel = m_pProxy->property("standardChainPresetModel")
                                   .value<mixxx::qml::QmlChainPresetModel*>();
    auto* pQuickModel = m_pProxy->property("quickChainPresetModel")
                                .value<mixxx::qml::QmlChainPresetModel*>();
    ASSERT_NE(nullptr, pStandardModel);
    ASSERT_NE(nullptr, pQuickModel);
    EXPECT_GT(pStandardModel->rowCount({}), 0);
    EXPECT_GT(pQuickModel->rowCount({}), 0);
    EXPECT_TRUE(pStandardModel->roleNames().values().contains("name"));
    EXPECT_TRUE(pStandardModel->roleNames().values().contains("readOnly"));

    QSignalSpy standardResetSpy(pStandardModel, &QAbstractItemModel::modelReset);
    QSignalSpy quickResetSpy(pQuickModel, &QAbstractItemModel::modelReset);
    QMetaObject::invokeMethod(m_pEffectsManager->getChainPresetManager().get(),
            "effectChainPresetListUpdated");
    EXPECT_EQ(1, standardResetSpy.count());
    EXPECT_EQ(0, quickResetSpy.count());
    QMetaObject::invokeMethod(m_pEffectsManager->getChainPresetManager().get(),
            "quickEffectChainPresetListUpdated");
    EXPECT_EQ(1, standardResetSpy.count());
    EXPECT_EQ(1, quickResetSpy.count());
}

TEST_F(QmlEffectsProxyTest, UnitPresetStateAndLoading) {
    auto* pUnit1 = m_pProxy->getEffectUnit(1);
    ASSERT_NE(nullptr, pUnit1);
    QSignalSpy presetSpy(pUnit1, &mixxx::qml::QmlEffectUnitProxy::presetChanged);
    pUnit1->loadPreset(-1);
    EXPECT_EQ(0, presetSpy.count());
    pUnit1->loadPreset(0);
    EXPECT_EQ(0, pUnit1->getPresetIndex());
    EXPECT_FALSE(pUnit1->getPresetName().isEmpty());
    EXPECT_EQ(!pUnit1->isPresetReadOnly(), pUnit1->canUpdatePreset());
    EXPECT_EQ(pUnit1->canUpdatePreset() && !pUnit1->getPresetName().isEmpty(),
            pUnit1->canRenamePreset());
    EXPECT_GE(presetSpy.count(), 1);
}

TEST_F(QmlEffectsProxyTest, SlotEffectAndParameterVisibility) {
    constexpr int kExpectedParameterCount = 6;
    constexpr int kParameter1Index = 0;
    constexpr int kParameter2Index = 1;
    constexpr int kParameter3Index = 2;
    constexpr int kButtonParameter1Index = 4;

    std::unique_ptr<mixxx::qml::QmlEffectSlotProxy> pSlot(
            m_pProxy->getEffectSlot(1, 1));
    ASSERT_NE(nullptr, pSlot);
    QSignalSpy effectSpy(
            pSlot.get(), &mixxx::qml::QmlEffectSlotProxy::effectIdChanged);
    auto* pModel = pSlot->getParametersModel();
    ASSERT_NE(nullptr, pModel);
    QSignalSpy modelResetSpy(pModel, &QAbstractItemModel::modelReset);
    QSignalSpy dataChangedSpy(pModel, &QAbstractItemModel::dataChanged);

    pSlot->setEffectId(EchoEffect::getId());
    ASSERT_TRUE(pSlot->isLoaded());
    EXPECT_GE(effectSpy.count(), 1);
    EXPECT_GE(modelResetSpy.count(), 1);

    ASSERT_EQ(kExpectedParameterCount, pModel->rowCount({}));
    EXPECT_TRUE(pModel->roleNames().values().contains("unitString"));
    EXPECT_EQ(QStringLiteral("parameter1"),
            pModel->get(kParameter1Index).toMap().value("controlKey").toString());
    EXPECT_EQ(QStringLiteral("parameter2"),
            pModel->get(kParameter2Index).toMap().value("controlKey").toString());
    EXPECT_EQ(QStringLiteral("button_parameter1"),
            pModel->get(kButtonParameter1Index)
                    .toMap()
                    .value("controlKey")
                    .toString());

    pSlot->setParameterVisible(QStringLiteral("feedback_amount"), false);
    EXPECT_GE(dataChangedSpy.count(), 1);
    EXPECT_FALSE(pModel->get(kParameter2Index).toMap().value("loaded").toBool());
    EXPECT_TRUE(pModel->get(kParameter2Index)
                    .toMap()
                    .value("controlKey")
                    .toString()
                    .isEmpty());
    EXPECT_EQ(QStringLiteral("parameter2"),
            pModel->get(kParameter3Index).toMap().value("controlKey").toString());

    pSlot->setParameterVisible(QStringLiteral("feedback_amount"), true);
    EXPECT_TRUE(pModel->get(kParameter2Index).toMap().value("loaded").toBool());
    pSlot->saveDefaultSnapshot();

    pSlot->setEffectId(ParametricEQEffect::getId());
    EXPECT_EQ(QStringLiteral("dB"),
            pModel->get(kParameter1Index).toMap().value("unitString").toString());
}

TEST_F(QmlEffectsProxyTest, EffectManifestModels) {
    auto* pAllEffects = m_pProxy->property("allEffectsModel")
                                .value<mixxx::qml::QmlEffectManifestModel*>();
    auto* pVisibleEffects = m_pProxy->property("visibleEffectsSettingsModel")
                                    .value<mixxx::qml::QmlEffectManifestModel*>();
    auto* pHiddenEffects = m_pProxy->property("hiddenEffectsSettingsModel")
                                   .value<mixxx::qml::QmlEffectManifestModel*>();
    auto* pMixingEqEffects = m_pProxy->property("mixingEqEffectsModel")
                                     .value<mixxx::qml::QmlEffectManifestModel*>();
    auto* pMainEqEffects = m_pProxy->property("mainEqEffectsModel")
                                   .value<mixxx::qml::QmlEffectManifestModel*>();
    ASSERT_NE(nullptr, pAllEffects);
    ASSERT_NE(nullptr, pVisibleEffects);
    ASSERT_NE(nullptr, pHiddenEffects);
    ASSERT_NE(nullptr, pMixingEqEffects);
    ASSERT_NE(nullptr, pMainEqEffects);

    EXPECT_TRUE(pAllEffects->roleNames().values().contains("uniqueId"));
    EXPECT_TRUE(pAllEffects->roleNames().values().contains("effectId"));
    EXPECT_TRUE(pAllEffects->roleNames().values().contains("isMixingEq"));

    const auto pEchoManifest = m_pEffectsManager->getBackendManager()
                                       ->getManifestFromUniqueId(EchoEffect::getId());
    ASSERT_NE(nullptr, pEchoManifest);
    const QString echoUniqueId = pEchoManifest->uniqueId();
    const int echoRow = pAllEffects->rowForUniqueId(echoUniqueId);
    ASSERT_GE(echoRow, 0);
    const QVariantMap echoData = pAllEffects->get(echoRow).toMap();
    EXPECT_EQ(echoUniqueId, echoData.value("uniqueId").toString());
    EXPECT_EQ(EchoEffect::getId(), echoData.value("effectId").toString());
    EXPECT_EQ(pEchoManifest->displayName(),
            echoData.value("displayName").toString());
    EXPECT_EQ(-1, pAllEffects->rowForUniqueId(QString()));

    EXPECT_GT(pMixingEqEffects->rowCount({}), 0);
    for (int row = 0; row < pMixingEqEffects->rowCount({}); ++row) {
        EXPECT_TRUE(pMixingEqEffects->get(row).toMap().value("isMixingEq").toBool());
    }

    EXPECT_GE(pMainEqEffects->rowCount({}), 2);
    const QVariantMap emptyMainEq = pMainEqEffects->get(0).toMap();
    EXPECT_TRUE(emptyMainEq.value("uniqueId").toString().isEmpty());
    EXPECT_FALSE(emptyMainEq.value("isMainEq").toBool());
    EXPECT_EQ(0, pMainEqEffects->rowForUniqueId(QString()));
    for (int row = 1; row < pMainEqEffects->rowCount({}); ++row) {
        EXPECT_TRUE(pMainEqEffects->get(row).toMap().value("isMainEq").toBool());
    }

    m_pProxy->setVisibleEffects({echoUniqueId});
    EXPECT_EQ(1, pVisibleEffects->rowCount({}));
    EXPECT_EQ(0, pVisibleEffects->rowForUniqueId(echoUniqueId));
    EXPECT_EQ(-1, pHiddenEffects->rowForUniqueId(echoUniqueId));

    m_pProxy->setEffectVisible(echoUniqueId, false);
    EXPECT_EQ(0, pVisibleEffects->rowCount({}));
    EXPECT_GE(pHiddenEffects->rowForUniqueId(echoUniqueId), 0);
    m_pProxy->setEffectVisible(echoUniqueId, true);
    EXPECT_EQ(0, pVisibleEffects->rowForUniqueId(echoUniqueId));

    ASSERT_GE(pAllEffects->rowCount({}), 2);
    const QString firstUniqueId =
            pAllEffects->get(0).toMap().value("uniqueId").toString();
    const QString secondUniqueId =
            pAllEffects->get(1).toMap().value("uniqueId").toString();
    ASSERT_NE(firstUniqueId, secondUniqueId);
    m_pProxy->setVisibleEffects({firstUniqueId, secondUniqueId});
    m_pProxy->moveVisibleEffect(0, 1);
    EXPECT_EQ(secondUniqueId,
            pVisibleEffects->get(0).toMap().value("uniqueId").toString());
    EXPECT_EQ(firstUniqueId,
            pVisibleEffects->get(1).toMap().value("uniqueId").toString());
}

TEST_F(QmlEffectsProxyTest, SlotParameterValuesAndEnabledState) {
    std::unique_ptr<mixxx::qml::QmlEffectSlotProxy> pSlot(
            m_pProxy->getEffectSlot(1, 1));
    ASSERT_NE(nullptr, pSlot);
    pSlot->setEffectId(EchoEffect::getId());
    ASSERT_TRUE(pSlot->isLoaded());
    const auto pEchoManifest = m_pEffectsManager->getBackendManager()
                                       ->getManifestFromUniqueId(EchoEffect::getId());
    ASSERT_NE(nullptr, pEchoManifest);
    EXPECT_EQ(pEchoManifest->uniqueId(), pSlot->getUniqueId());
    EXPECT_EQ(pSlot->getUniqueId(), pSlot->getEffectId());

    auto* pModel = pSlot->getParametersModel();
    ASSERT_NE(nullptr, pModel);
    constexpr int kParameterIndex = 0;
    const QVariantMap parameter = pModel->get(kParameterIndex).toMap();
    const QString parameterId = parameter.value("parameterId").toString();
    const double minimum = parameter.value("minimum").toDouble();
    const double maximum = parameter.value("maximum").toDouble();
    const double defaultValue = parameter.value("defaultValue").toDouble();
    EXPECT_DOUBLE_EQ(defaultValue, parameter.value("value").toDouble());
    EXPECT_DOUBLE_EQ(defaultValue, pSlot->getParameterValue(parameterId));

    const double targetValue = minimum + (maximum - minimum) / 2.0;
    ASSERT_TRUE(pSlot->setParameterValue(parameterId, targetValue));
    EXPECT_NEAR(targetValue, pSlot->getParameterValue(parameterId), 1e-9);
    EXPECT_NEAR(targetValue,
            pModel->get(kParameterIndex).toMap().value("value").toDouble(),
            1e-9);
    EXPECT_TRUE(pSlot->resetParameterToDefault(parameterId));
    EXPECT_NEAR(defaultValue, pSlot->getParameterValue(parameterId), 1e-9);
    EXPECT_FALSE(pSlot->setParameterValue(QStringLiteral("missing"), 1.0));

    QSignalSpy enabledSpy(
            pSlot.get(), &mixxx::qml::QmlEffectSlotProxy::enabledChanged);
    const bool initialEnabled = pSlot->isEnabled();
    pSlot->setEnabled(!initialEnabled);
    EXPECT_EQ(!initialEnabled, pSlot->isEnabled());
    EXPECT_EQ(1, enabledSpy.count());
}

TEST_F(QmlEffectsProxyTest, DeckEqualizerAndQuickEffectSlots) {
    EXPECT_EQ(kTestDeckCount, m_pProxy->numDecks());
    auto* pEq1 = m_pProxy->getDeckEqEffectSlot(1);
    auto* pQuick1 = m_pProxy->getDeckQuickEffectSlot(1);
    ASSERT_NE(nullptr, pEq1);
    ASSERT_NE(nullptr, pQuick1);
    EXPECT_EQ(pEq1, m_pProxy->getDeckEqEffectSlot(1));
    EXPECT_EQ(pQuick1, m_pProxy->getDeckQuickEffectSlot(1));
    EXPECT_EQ(nullptr, m_pProxy->getDeckEqEffectSlot(kTestDeckCount + 1));
    EXPECT_EQ(nullptr, m_pProxy->getDeckQuickEffectSlot(kTestDeckCount + 1));

    auto* pMixingEqModel = m_pProxy->property("mixingEqEffectsModel")
                                   .value<mixxx::qml::QmlEffectManifestModel*>();
    ASSERT_NE(nullptr, pMixingEqModel);
    ASSERT_GE(pMixingEqModel->rowCount({}), 2);
    const QString firstEqUniqueId =
            pMixingEqModel->get(0).toMap().value("uniqueId").toString();
    const QString secondEqUniqueId =
            pMixingEqModel->get(1).toMap().value("uniqueId").toString();

    const QVariantList distinctEqIds = {
            firstEqUniqueId, secondEqUniqueId, firstEqUniqueId, secondEqUniqueId};
    m_pProxy->applyDeckEqSettings(false, true, false, distinctEqIds);
    EXPECT_EQ(firstEqUniqueId, m_pProxy->getDeckEqEffectSlot(1)->getUniqueId());
    EXPECT_EQ(secondEqUniqueId, m_pProxy->getDeckEqEffectSlot(2)->getUniqueId());
    EXPECT_TRUE(m_pProxy->getDeckEqEffectSlot(1)->isEnabled());

    m_pProxy->applyDeckEqSettings(true, true, false, distinctEqIds);
    EXPECT_FALSE(m_pProxy->getDeckEqEffectSlot(1)->isEnabled());
    EXPECT_FALSE(m_pProxy->getDeckEqEffectSlot(2)->isEnabled());

    m_pProxy->applyDeckEqSettings(false, true, true, distinctEqIds);
    for (int deckIndex = 0; deckIndex < kTestDeckCount; ++deckIndex) {
        EXPECT_EQ(firstEqUniqueId,
                m_pProxy->getDeckEqEffectSlot(deckIndex + 1)->getUniqueId());
        EXPECT_TRUE(m_pProxy->getDeckEqEffectSlot(deckIndex + 1)->isEnabled());
    }

    auto* pQuickPresetModel = m_pProxy->property("quickChainPresetModel")
                                      .value<mixxx::qml::QmlChainPresetModel*>();
    ASSERT_NE(nullptr, pQuickPresetModel);
    ASSERT_GT(pQuickPresetModel->rowCount({}), 0);
    const int quickPresetIndex = pQuickPresetModel->rowCount({}) - 1;
    const QString quickPresetName = pQuickPresetModel->presetName(quickPresetIndex);
    ASSERT_FALSE(quickPresetName.isEmpty());
    const QVariantList quickPresetIndices = {
            quickPresetIndex, quickPresetIndex, quickPresetIndex, quickPresetIndex};
    m_pProxy->applyQuickEffectSettings(quickPresetIndices);
    for (int deckIndex = 0; deckIndex < kTestDeckCount; ++deckIndex) {
        EXPECT_EQ(quickPresetName,
                m_pProxy->getDeckQuickEffectSlot(deckIndex + 1)->getChainPresetName());
    }
}

TEST_F(QmlEffectsProxyTest, MigratesLegacyEffectSettings) {
    const auto pEqManifest = m_pEffectsManager->getBackendManager()
                                     ->getManifestFromUniqueId(ParametricEQEffect::getId());
    ASSERT_NE(nullptr, pEqManifest);
    const QString eqUniqueId = pEqManifest->uniqueId();
    const ConfigKey mainEqKey(
            QStringLiteral("[Mixer Profile]"), QStringLiteral("EffectForGroup_[Master]"));
    config()->setValue(mainEqKey, eqUniqueId);

    const auto& parameters = pEqManifest->parameters();
    ASSERT_FALSE(parameters.isEmpty());
    const auto pKnobParameter = parameters.first();
    ASSERT_EQ(EffectManifestParameter::ParameterType::Knob,
            pKnobParameter->parameterType());
    const double parameterValue =
            pKnobParameter->getMinimum() +
            (pKnobParameter->getMaximum() - pKnobParameter->getMinimum()) / 2.0;
    const ConfigKey mainEqParameterKey(
            QStringLiteral("[Mixer Profile]"),
            QStringLiteral("EffectForGroup_[Master]_parameter%1")
                    .arg(pKnobParameter->index() + 1));
    config()->setValue(mainEqParameterKey, QString::number(parameterValue));

    const QString deckGroup = PlayerManager::groupForDeck(0);
    const ConfigKey deckEqKey(
            QStringLiteral("[Mixer Profile]"),
            QStringLiteral("EffectForGroup_") + deckGroup);
    config()->setValue(deckEqKey, eqUniqueId);

    m_pProxy->migrateLegacyEffectSettings();

    auto* pMainEqSlot = m_pProxy->getMainEqEffectSlot();
    ASSERT_NE(nullptr, pMainEqSlot);
    EXPECT_EQ(eqUniqueId, pMainEqSlot->getUniqueId());
    EXPECT_NEAR(parameterValue,
            pMainEqSlot->getParameterValue(pKnobParameter->id()),
            1e-9);
    EXPECT_EQ(eqUniqueId, m_pProxy->getDeckEqEffectSlot(1)->getUniqueId());
    EXPECT_FALSE(config()->exists(mainEqKey));
    EXPECT_FALSE(config()->exists(mainEqParameterKey));
    EXPECT_FALSE(config()->exists(deckEqKey));
}

TEST_F(QmlEffectsProxyTest, ChainPresetModelEdits) {
    auto* pStandardSettingsModel =
            m_pProxy->property("standardChainPresetSettingsModel")
                    .value<mixxx::qml::QmlChainPresetModel*>();
    auto* pQuickSettingsModel =
            m_pProxy->property("quickChainPresetSettingsModel")
                    .value<mixxx::qml::QmlChainPresetModel*>();
    ASSERT_NE(nullptr, pStandardSettingsModel);
    ASSERT_NE(nullptr, pQuickSettingsModel);
    ASSERT_GT(pStandardSettingsModel->rowCount({}), 0);
    EXPECT_TRUE(pStandardSettingsModel->presetName(-1).isEmpty());
    EXPECT_FALSE(pStandardSettingsModel->renamePreset(-1, QStringLiteral("invalid")));
    EXPECT_FALSE(pStandardSettingsModel->deletePreset(-1));
    EXPECT_FALSE(pStandardSettingsModel->exportPresetToFile(-1, QString()));

    QSignalSpy errorSpy(
            pStandardSettingsModel,
            &mixxx::qml::QmlChainPresetModel::lastErrorChanged);
    EXPECT_TRUE(pStandardSettingsModel->importPresets({QStringLiteral("/does/not/exist.xml")})
                    .isEmpty());
    EXPECT_GE(errorSpy.count(), 1);
    EXPECT_FALSE(pStandardSettingsModel->lastError().isEmpty());

    QTemporaryDir tempDir;
    ASSERT_TRUE(tempDir.isValid());
    const QString exportPath = tempDir.filePath(QStringLiteral("preset.xml"));
    const QString presetName = pStandardSettingsModel->presetName(0);
    ASSERT_FALSE(presetName.isEmpty());
    ASSERT_TRUE(pStandardSettingsModel->exportPresetToFile(0, exportPath));
    EXPECT_TRUE(QFile::exists(exportPath));

    const QStringList importedPresets =
            pQuickSettingsModel->importPresets({exportPath});
    ASSERT_EQ(1, importedPresets.size());
    EXPECT_TRUE(pQuickSettingsModel->lastError().isEmpty());
    int importedRow = -1;
    for (int row = 0; row < pQuickSettingsModel->rowCount({}); ++row) {
        if (pQuickSettingsModel->presetName(row) == importedPresets.first()) {
            importedRow = row;
            break;
        }
    }
    ASSERT_GE(importedRow, 0);
    EXPECT_TRUE(pQuickSettingsModel->deletePreset(importedRow));
}

TEST_F(QmlEffectsProxyTest, MovesPresetOrder) {
    auto* pStandardSettingsModel =
            m_pProxy->property("standardChainPresetSettingsModel")
                    .value<mixxx::qml::QmlChainPresetModel*>();
    ASSERT_NE(nullptr, pStandardSettingsModel);
    ASSERT_GE(pStandardSettingsModel->rowCount({}), 2);
    const QString first = pStandardSettingsModel->presetName(0);
    const QString second = pStandardSettingsModel->presetName(1);
    const int lastRow = pStandardSettingsModel->rowCount({}) - 1;
    const QString last = pStandardSettingsModel->presetName(lastRow);
    EXPECT_TRUE(pStandardSettingsModel->movePreset(0, lastRow));
    EXPECT_EQ(second, pStandardSettingsModel->presetName(0));
    EXPECT_EQ(first, pStandardSettingsModel->presetName(lastRow));
    EXPECT_EQ(last, pStandardSettingsModel->presetName(lastRow - 1));
}

TEST_F(QmlEffectsProxyTest, ApplyMixerEqFrequencies) {
    // The EQ shelf setters only store the *Precise config keys, but the EQ
    // effects read the coarse [Mixer Profile] HiEQFrequency/LoEQFrequency
    // ControlObjects (owned by EffectsManager). applyMixerEqFrequencies()
    // bridges the two, so saving the shelves must drive those controls.
    mixxx::qml::QmlConfigProxy configProxy;
    const ConfigKey highCoarseKey(QStringLiteral("[Mixer Profile]"),
            QStringLiteral("HiEQFrequency"));
    const ConfigKey lowCoarseKey(QStringLiteral("[Mixer Profile]"),
            QStringLiteral("LoEQFrequency"));

    configProxy.set_mixerHighEqFrequency(5000.0);
    configProxy.set_mixerLowEqFrequency(1000.0);
    configProxy.applyMixerEqFrequencies();

    auto* pHighControl = ControlObject::getControl(highCoarseKey);
    ASSERT_NE(nullptr, pHighControl);
    auto* pLowControl = ControlObject::getControl(lowCoarseKey);
    ASSERT_NE(nullptr, pLowControl);

    EXPECT_NEAR(5000.0, pHighControl->get(), 1e-6);
    EXPECT_NEAR(1000.0, pLowControl->get(), 1e-6);
}

class QmlConfigProxyTest : public MixxxTest {
  protected:
    void SetUp() override {
        mixxx::qml::QmlConfigProxy::registerUserSettings(config());
        m_pProxy = std::make_unique<mixxx::qml::QmlConfigProxy>();
    }

    void TearDown() override {
        m_pProxy.reset();
        mixxx::qml::QmlConfigProxy::registerUserSettings(nullptr);
    }

    std::unique_ptr<mixxx::qml::QmlConfigProxy> m_pProxy;
};

TEST_F(QmlConfigProxyTest, MixerEqualizerSettings) {
    const ConfigKey enableEqsKey(
            QStringLiteral("[Mixer Profile]"), QStringLiteral("EnableEQs"));
    config()->setValue(enableEqsKey, QStringLiteral("yes"));
    EXPECT_FALSE(m_pProxy->mixerEqsBypassed());
    config()->setValue(enableEqsKey, QStringLiteral("no"));
    EXPECT_TRUE(m_pProxy->mixerEqsBypassed());
    config()->setValue(enableEqsKey, QStringLiteral("1"));
    EXPECT_FALSE(m_pProxy->mixerEqsBypassed());
    config()->setValue(enableEqsKey, QStringLiteral("no"));
    EXPECT_TRUE(m_pProxy->mixerEqsBypassed());
    m_pProxy->set_mixerEqsBypassed(false);
    EXPECT_FALSE(m_pProxy->mixerEqsBypassed());
    EXPECT_EQ(1, config()->getValue<int>(enableEqsKey));
    m_pProxy->set_mixerEqsBypassed(true);
    EXPECT_TRUE(m_pProxy->mixerEqsBypassed());
    EXPECT_EQ(0, config()->getValue<int>(enableEqsKey));

    const ConfigKey eqsOnlyKey(
            QStringLiteral("[Mixer Profile]"), QStringLiteral("EQsOnly"));
    config()->setValue(eqsOnlyKey, QStringLiteral("no"));
    EXPECT_FALSE(m_pProxy->mixerEqsOnly());
    m_pProxy->set_mixerEqsOnly(true);
    EXPECT_TRUE(m_pProxy->mixerEqsOnly());
    EXPECT_EQ(1, config()->getValue<int>(eqsOnlyKey));

    const ConfigKey singleEqKey(
            QStringLiteral("[Mixer Profile]"), QStringLiteral("SingleEQEffect"));
    config()->setValue(singleEqKey, QStringLiteral("no"));
    EXPECT_FALSE(m_pProxy->mixerSingleEq());
    m_pProxy->set_mixerSingleEq(true);
    EXPECT_TRUE(m_pProxy->mixerSingleEq());

    m_pProxy->set_mixerEqAutoReset(true);
    EXPECT_TRUE(m_pProxy->mixerEqAutoReset());
    m_pProxy->set_mixerGainAutoReset(true);
    EXPECT_TRUE(m_pProxy->mixerGainAutoReset());
    m_pProxy->set_mixerStemAutoReset(false);
#ifdef __STEM__
    EXPECT_FALSE(m_pProxy->mixerStemAutoReset());
    EXPECT_TRUE(m_pProxy->mixerStemSupported());
#else
    EXPECT_TRUE(m_pProxy->mixerStemAutoReset());
    EXPECT_FALSE(m_pProxy->mixerStemSupported());
#endif

    const ConfigKey highEqCoarseKey(
            QStringLiteral("[Mixer Profile]"), QStringLiteral("HiEQFrequency"));
    const ConfigKey highEqPreciseKey(
            QStringLiteral("[Mixer Profile]"), QStringLiteral("HiEQFrequencyPrecise"));
    config()->setValue(highEqCoarseKey, QStringLiteral("1800"));
    EXPECT_DOUBLE_EQ(1800.0, m_pProxy->mixerHighEqFrequency());
    config()->setValue(highEqPreciseKey, QStringLiteral("2345.5"));
    EXPECT_DOUBLE_EQ(2345.5, m_pProxy->mixerHighEqFrequency());
    m_pProxy->set_mixerHighEqFrequency(0.0);
    EXPECT_DOUBLE_EQ(16.0, m_pProxy->mixerHighEqFrequency());
    m_pProxy->set_mixerLowEqFrequency(500.0);
    EXPECT_DOUBLE_EQ(500.0, m_pProxy->mixerLowEqFrequency());
}

TEST_F(QmlConfigProxyTest, EffectsAndXfaderSettings) {
    EXPECT_TRUE(m_pProxy->effectsAdoptMetaknobValue());
    m_pProxy->set_effectsAdoptMetaknobValue(false);
    EXPECT_FALSE(m_pProxy->effectsAdoptMetaknobValue());
    EXPECT_FALSE(config()->getValue<bool>(
            ConfigKey(QStringLiteral("[Effects]"),
                    QStringLiteral("AdoptMetaknobValue")),
            true));

    EXPECT_EQ(0, m_pProxy->mixerXfaderMode());
    m_pProxy->set_mixerXfaderMode(-1);
    EXPECT_EQ(0, m_pProxy->mixerXfaderMode());
    m_pProxy->set_mixerXfaderMode(1);
    EXPECT_EQ(1, m_pProxy->mixerXfaderMode());

    m_pProxy->set_mixerXfaderCurve(0.1);
    EXPECT_DOUBLE_EQ(EngineXfader::kTransformMin, m_pProxy->mixerXfaderCurve());
    EXPECT_DOUBLE_EQ(EngineXfader::getPowerCalibration(
                             m_pProxy->mixerXfaderCurve()),
            m_pProxy->mixerXfaderCalibration());
    EXPECT_EQ(0,
            m_pProxy->mixerXfaderSliderPositionFromCurve(
                    m_pProxy->mixerXfaderCurveFromSliderPosition(0)));
    EXPECT_EQ(100,
            m_pProxy->mixerXfaderSliderPositionFromCurve(
                    m_pProxy->mixerXfaderCurveFromSliderPosition(100)));

    ControlObject modeControl(ConfigKey(
            QStringLiteral("[Mixer Profile]"), QStringLiteral("xFaderMode")));
    ControlObject curveControl(ConfigKey(
            QStringLiteral("[Mixer Profile]"), QStringLiteral("xFaderCurve")));
    ControlObject calibrationControl(ConfigKey(
            QStringLiteral("[Mixer Profile]"), QStringLiteral("xFaderCalibration")));
    ControlObject reverseControl(ConfigKey(
            QStringLiteral("[Mixer Profile]"), QStringLiteral("xFaderReverse")));
    ControlObject crossfaderControl(
            ConfigKey(QStringLiteral("[Master]"), QStringLiteral("crossfader")));
    reverseControl.forceSet(0.0);
    crossfaderControl.forceSet(0.5);
    m_pProxy->set_mixerXfaderCurve(2.0);
    m_pProxy->set_mixerXfaderReverse(true);
    m_pProxy->applyMixerXfaderSettings();

    EXPECT_DOUBLE_EQ(1.0, modeControl.get());
    EXPECT_DOUBLE_EQ(2.0, curveControl.get());
    EXPECT_DOUBLE_EQ(EngineXfader::getPowerCalibration(2.0),
            calibrationControl.get());
    EXPECT_TRUE(reverseControl.toBool());
    EXPECT_DOUBLE_EQ(-0.5, crossfaderControl.get());

    m_pProxy->set_mixerXfaderReverse(false);
    m_pProxy->applyMixerXfaderSettings();
    EXPECT_FALSE(reverseControl.toBool());
    EXPECT_DOUBLE_EQ(0.5, crossfaderControl.get());
}

} // namespace
