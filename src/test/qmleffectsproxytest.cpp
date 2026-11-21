#include <gtest/gtest.h>

#include <QDragEnterEvent>
#include <QDragLeaveEvent>
#include <QDropEvent>
#include <QFile>
#include <QFontMetrics>
#include <QGuiApplication>
#include <QImage>
#include <QMetaMethod>
#include <QMimeData>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QSignalSpy>
#include <QStringView>
#include <QTemporaryDir>
#include <QTest>
#include <QTimer>
#include <algorithm>
#include <memory>

#include "control/controlobject.h"
#include "control/controlproxy.h"
#include "effects/backends/builtin/echoeffect.h"
#include "effects/backends/builtin/parametriceqeffect.h"
#include "effects/backends/effectmanifest.h"
#include "effects/backends/effectmanifestparameter.h"
#include "effects/backends/effectsbackendmanager.h"
#include "effects/effectchain.h"
#include "effects/effectparameter.h"
#include "effects/effectslot.h"
#include "effects/effectsmanager.h"
#include "effects/presets/effectchainpreset.h"
#include "effects/presets/effectchainpresetmanager.h"
#include "effects/presets/effectpreset.h"
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
        const QString masterGroup = QStringLiteral("[Master]");
        m_pEffectsManager->registerOutputChannel(ChannelHandleAndGroup(
                m_pChannelHandleFactory->getOrCreateHandle(masterGroup),
                masterGroup));
        const QString headphoneGroup = QStringLiteral("[Headphone]");
        m_pEffectsManager->registerOutputChannel(ChannelHandleAndGroup(
                m_pChannelHandleFactory->getOrCreateHandle(headphoneGroup),
                headphoneGroup));
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

TEST_F(QmlEffectsProxyTest, ParameterLabelWidth) {
    std::unique_ptr<mixxx::qml::QmlEffectSlotProxy> slot(m_pProxy->getEffectSlot(1, 1));
    const auto* model = slot->getParametersModel();
    QFont font(QStringLiteral("Open Sans"));
    font.setPixelSize(10);
    const QFontMetrics metrics(font);
    EXPECT_EQ(metrics.size(0, QStringLiteral("Feedback")).width(),
            model->labelWidth(QStringLiteral("Feedback"), 1, QString(), font, false));
    EXPECT_EQ(QFontMetrics(QGuiApplication::font()).size(0, QStringLiteral("Feedback")).width(),
            model->labelWidth(QStringLiteral("Feedback"), 1, QString(), font, true));
    EXPECT_EQ(std::max(metrics.size(0, QStringLiteral("999.99 Hz")).width(),
                      metrics.size(0, QStringLiteral("1000.01 Hz")).width()),
            model->labelWidth(QStringLiteral("F"), 1000, QStringLiteral("Hz"), font, false));
}

TEST_F(QmlEffectsProxyTest, ParameterDragUsesWidgetPreviewAndMixedDrop) {
    std::unique_ptr<mixxx::qml::QmlEffectSlotProxy> slot(m_pProxy->getEffectSlot(1, 1));
    slot->setEffectId(EchoEffect::getId());
    QQmlEngine::setObjectOwnership(slot.get(), QQmlEngine::CppOwnership);
    std::unique_ptr<mixxx::qml::QmlEffectSlotProxy> destination(m_pProxy->getEffectSlot(1, 2));
    destination->setEffectId(EchoEffect::getId());
    QQmlEngine::setObjectOwnership(destination.get(), QQmlEngine::CppOwnership);
    QQmlEngine engine;
    QQmlComponent component(&engine);
    component.setData(R"(
import QtQuick
import "Effects"

Item {
    id: root
    required property var effectSlot
    required property var destinationSlot
    EffectParameterDragArea {
        x: 20
        y: 80
        width: 60
        height: 10
        controlKey: "button_parameter1"
        dragItem: root
        effectSlot: root.destinationSlot
        parameterType: 1
    }
    property var capturedGrab
    readonly property bool mixedPayloadAccepted: dragArea.draggedParameter({
        hasText: true,
        text: "Mixxx effect parameter 1\n" + root.effectSlot.uniqueId + "\n0"
    }).type === 1
    readonly property bool foreignPayloadRejected: dragArea.draggedParameter({
        hasText: true, text: "Mixxx effect parameter 0\nother-effect\n0"
    }) === null
    readonly property bool malformedPayloadRejected: dragArea.draggedParameter({
        hasText: true,
        text: "Mixxx effect parameter 0\n" + root.effectSlot.uniqueId + "\n-1"
    }) === null
    signal previewReady(point hotSpot)
    width: 100
    height: 100

    Rectangle {
        id: parameter
        x: 20
        y: 20
        width: 60
        height: 50
        color: "red"

        EffectParameterDragArea {
            id: dragArea
            y: 30
            width: 60
            height: 10
            controlKey: "parameter1"
            dragItem: parameter
            effectSlot: root.effectSlot
            parameterType: 0
            Drag.onDragStarted: {
                root.capturedGrab = dragArea.dragImage;
                root.previewReady(dragArea.Drag.hotSpot);
            }
        }
    }
}
)",
            QUrl::fromLocalFile(QStringLiteral(RESOURCE_FOLDER "/qml/parameterdrag_test.qml")));
    QQuickWindow window;
    window.resize(100, 100);
    std::unique_ptr<QObject> root(component.createWithInitialProperties(
            {{QStringLiteral("effectSlot"), QVariant::fromValue(slot.get())},
                    {QStringLiteral("destinationSlot"), QVariant::fromValue(destination.get())}}));
    ASSERT_TRUE(root) << qPrintable(component.errorString());
    EXPECT_TRUE(root->property("mixedPayloadAccepted").toBool());
    EXPECT_TRUE(root->property("foreignPayloadRejected").toBool());
    EXPECT_TRUE(root->property("malformedPayloadRejected").toBool());
    auto* item = qobject_cast<QQuickItem*>(root.get());
    ASSERT_TRUE(item);
    item->setParentItem(window.contentItem());
    window.show();
    ASSERT_TRUE(QTest::qWaitForWindowExposed(&window));
    QSignalSpy previewSpy(root.get(),
            root->metaObject()->method(root->metaObject()->indexOfSignal("previewReady(QPointF)")));
    ASSERT_TRUE(previewSpy.isValid());
    const QPoint pressPosition(35, 55);
    QTest::mousePress(&window, Qt::LeftButton, Qt::NoModifier, pressPosition);
    QTimer::singleShot(500, &window, [&window] {
        QTest::mouseRelease(&window, Qt::LeftButton, Qt::NoModifier, QPoint(60, 55));
    });
    QTest::mouseMove(&window, QPoint(60, 55));
    if (previewSpy.isEmpty()) {
        EXPECT_TRUE(previewSpy.wait(2000));
    }
    ASSERT_EQ(previewSpy.count(), 1);
    EXPECT_EQ(previewSpy.at(0).at(0).toPointF(), QPointF(15, 35));
    auto* grab = root->property("capturedGrab").value<QObject*>();
    ASSERT_TRUE(grab);
    const QImage image = grab->property("image").value<QImage>();
    ASSERT_FALSE(image.isNull());
    EXPECT_EQ(image.size(), QSize(60, 50));
    EXPECT_EQ(image.pixelColor(30, 25), QColor(Qt::red));
    QTest::qWait(550);
    auto* model = destination->getParametersModel();
    const int originalOrder = model->get(0).toMap().value("displayOrder").toInt();
    QMimeData mimeData;
    mimeData.setText(QStringLiteral("Mixxx effect parameter 0\n%1\n0")
                    .arg(slot->getUniqueId()));
    QDragEnterEvent enter(QPoint(35, 85),
            Qt::MoveAction,
            &mimeData,
            Qt::LeftButton,
            Qt::NoModifier);
    QCoreApplication::sendEvent(&window, &enter);
    EXPECT_TRUE(enter.isAccepted());
    QDropEvent drop(QPointF(35, 85), Qt::MoveAction, &mimeData, Qt::LeftButton, Qt::NoModifier);
    QCoreApplication::sendEvent(&window, &drop);
    EXPECT_TRUE(drop.isAccepted());
    EXPECT_EQ(originalOrder, model->get(0).toMap().value("displayOrder").toInt());
    QTRY_COMPARE(model->get(0).toMap().value("displayOrder").toInt(), 0);
    EXPECT_EQ(originalOrder,
            slot->getParametersModel()
                    ->get(0)
                    .toMap()
                    .value("displayOrder")
                    .toInt());
    destination->completeParameterSwap(true);
    EXPECT_EQ(0, model->get(0).toMap().value("displayOrder").toInt());
}

// FIXME: Incomplete case
TEST_F(QmlEffectsProxyTest, DISABLED_EffectsKnobCursorStaysHiddenOutsideKnob) {
    mixxx::qml::QmlConfigProxy::registerUserSettings(config());
    QQmlEngine engine;
    engine.addImportPath(QStringLiteral(":/mixxx.org/imports"));
    QQmlComponent component(&engine);
    component.setData(R"(
import QtQuick
import "Controls"
Item {
    width: 200
    height: 200
    Knob {
        width: 30
        height: 30
        group: "[EffectRack1_EffectUnit1_Effect1]"
        key: "parameter1"
    }
}
)",
            QUrl::fromLocalFile(QStringLiteral(
                    RESOURCE_FOLDER "/skins/LateNightQML/cursor_test.qml")));
    QQuickWindow window;
    window.resize(200, 200);
    std::unique_ptr<QObject> root(component.create());
    ASSERT_TRUE(root) << qPrintable(component.errorString());
    auto* item = qobject_cast<QQuickItem*>(root.get());
    ASSERT_TRUE(item);
    item->setParentItem(window.contentItem());
    window.show();
    ASSERT_TRUE(QTest::qWaitForWindowExposed(&window));
    EXPECT_EQ(QGuiApplication::overrideCursor(), nullptr);
    QTest::mousePress(&window, Qt::LeftButton, Qt::NoModifier, QPoint(15, 15));
    QTRY_COMPARE(window.cursor().shape(), Qt::BlankCursor);
    QTest::mouseMove(&window, QPoint(180, 180));
    QTRY_COMPARE(window.cursor().shape(), Qt::BlankCursor);
    EXPECT_EQ(QGuiApplication::overrideCursor(), nullptr);
    QTest::mouseRelease(&window, Qt::LeftButton, Qt::NoModifier, QPoint(180, 180));
    QTRY_COMPARE(window.cursor().shape(), Qt::ArrowCursor);
    EXPECT_EQ(QGuiApplication::overrideCursor(), nullptr);
}

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

// FIXME: Incomplete case
TEST_F(QmlEffectsProxyTest, DISABLED_MixedParameterOrderPreservesControlSlotsAndPresets) {
    using Model = mixxx::qml::QmlEffectSlotParametersModel;
    std::unique_ptr<mixxx::qml::QmlEffectSlotProxy> slot(m_pProxy->getEffectSlot(1, 1));
    slot->setEffectId(EchoEffect::getId());
    auto* model = slot->getParametersModel();
    auto* orderedModel = model->orderedModel();
    const auto coreSlot = m_pEffectsManager->getStandardEffectChain(0)->getEffectSlot(0);
    const auto knobs = coreSlot->getLoadedParameters().value(EffectParameterType::Knob);
    const auto buttons = coreSlot->getLoadedParameters().value(EffectParameterType::Button);
    ASSERT_FALSE(knobs.isEmpty());
    ASSERT_FALSE(buttons.isEmpty());
    knobs.at(0)->setValue(0.37);
    const QString firstKnobId = knobs.at(0)->manifest()->id();
    const QString firstButtonId = buttons.at(0)->manifest()->id();
    const auto displayedId = [orderedModel](int row) {
        return orderedModel->data(orderedModel->index(row, 0), Model::IdRole).toString();
    };
    EXPECT_EQ(firstButtonId, displayedId(0));
    slot->queueParameterSwap(Model::Button, 0, 0, Model::Knob);
    EXPECT_EQ(firstButtonId, displayedId(0));
    slot->completeParameterSwap(false);
    EXPECT_EQ(firstButtonId, displayedId(0));
    slot->queueParameterSwap(Model::Button, 0, 0, Model::Knob);
    slot->completeParameterSwap(true);
    EXPECT_EQ(firstKnobId, displayedId(0));
    EXPECT_EQ(knobs, coreSlot->getLoadedParameters().value(EffectParameterType::Knob));
    EXPECT_EQ(buttons, coreSlot->getLoadedParameters().value(EffectParameterType::Button));
    EXPECT_EQ(QStringLiteral("parameter1"),
            orderedModel->data(orderedModel->index(0, 0), Model::ControlKeyRole).toString());

    slot->swapParameters(Model::Knob, 0, 1);
    EXPECT_EQ(knobs.at(1)->manifest()->id(), displayedId(0));
    slot->swapParameters(Model::Knob, 0, 1);
    slot->swapParameters(99, 0, 0, Model::Knob);
    slot->swapParameters(Model::Button, -1, 0, Model::Knob);
    slot->swapParameters(Model::Button, 0, 999, Model::Knob);
    EXPECT_EQ(firstKnobId, displayedId(0));

    QDomDocument document;
    const EffectPreset snapshot(coreSlot);
    const auto element = snapshot.toXml(&document);
    coreSlot->loadEffectFromPreset(EffectPresetPointer::create(element));
    EXPECT_EQ(firstKnobId, displayedId(0));
    EXPECT_DOUBLE_EQ(0.37,
            coreSlot->getLoadedParameters()
                    .value(EffectParameterType::Knob)
                    .at(0)
                    ->getValue());
    EXPECT_EQ(firstButtonId,
            coreSlot->getLoadedParameters()
                    .value(EffectParameterType::Button)
                    .at(0)
                    ->manifest()
                    ->id());

    slot->setParameterVisible(firstKnobId, false);
    slot->setParameterVisible(firstKnobId, true);
    EXPECT_EQ(firstKnobId, displayedId(model->rowCount({}) - 1));

    auto legacyElement = snapshot.toXml(&document);
    const auto parameters = legacyElement.elementsByTagName(QStringLiteral("Parameter"));
    for (int index = 0; index < parameters.size(); ++index) {
        auto parameter = parameters.at(index).toElement();
        parameter.removeChild(parameter.firstChildElement(QStringLiteral("DisplayOrder")));
    }
    coreSlot->loadEffectFromPreset(EffectPresetPointer::create(legacyElement));
    EXPECT_EQ(firstButtonId, displayedId(0));
    EXPECT_EQ(firstKnobId,
            coreSlot->getLoadedParameters()
                    .value(EffectParameterType::Knob)
                    .at(0)
                    ->manifest()
                    ->id());
    EXPECT_DOUBLE_EQ(0.37,
            coreSlot->getLoadedParameters()
                    .value(EffectParameterType::Knob)
                    .at(0)
                    ->getValue());
}

// FIXME: Incomplete case
TEST_F(QmlEffectsProxyTest, DISABLED_ParameterInsertionPreservesValuesAndPersists) {
    using Model = mixxx::qml::QmlEffectSlotParametersModel;
    std::unique_ptr<mixxx::qml::QmlEffectSlotProxy> slot(m_pProxy->getEffectSlot(1, 1));
    slot->setEffectId(EchoEffect::getId());
    const auto core = m_pEffectsManager->getStandardEffectChain(0)->getEffectSlot(0);
    auto* model = slot->getParametersModel();
    auto* ordered = model->orderedModel();
    const auto ids = [ordered] {
        QStringList result;
        for (int row = 0; row < ordered->rowCount(); ++row) {
            const auto index = ordered->index(row, 0);
            if (ordered->data(index, Model::LoadedRole).toBool()) {
                result.append(ordered->data(index, Model::IdRole).toString());
            }
        }
        return result;
    };
    const auto original = ids();
    ASSERT_GE(original.size(), 3);
    const auto first = ordered->index(0, 0);
    const auto last = ordered->index(original.size() - 1, 0);
    const int firstType = ordered->data(first, Model::TypeRole).toInt();
    const int lastType = ordered->data(last, Model::TypeRole).toInt();
    const auto slotNumber = [ordered](const QModelIndex& index) {
        const auto key = ordered->data(index, Model::ControlKeyRole).toString();
        return QStringView(key).mid(key.lastIndexOf(QLatin1Char('r')) + 1).toInt() - 1;
    };
    const int firstSlot = slotNumber(first);
    const int lastSlot = slotNumber(last);
    const auto parameter = core->getLoadedParameters()
                                   .value(static_cast<EffectParameterType>(firstType))
                                   .at(firstSlot);
    const double value = parameter->getValue();
    slot->queueParameterMove(firstType, firstSlot, lastType, lastSlot, true);
    EXPECT_EQ(original, ids());
    slot->completeParameterSwap(false);
    EXPECT_EQ(original, ids());
    slot->queueParameterMove(firstType, firstSlot, lastType, lastSlot, true);
    slot->completeParameterSwap(true);
    auto expected = original;
    expected.move(0, expected.size() - 1);
    EXPECT_EQ(expected, ids());
    EXPECT_DOUBLE_EQ(value, parameter->getValue());
    QDomDocument document;
    const EffectPreset snapshot(core);
    core->loadEffectFromPreset(EffectPresetPointer::create(snapshot.toXml(&document)));
    EXPECT_EQ(expected, ids());
    const auto moved = ordered->index(expected.size() - 1, 0);
    const auto target = ordered->index(0, 0);
    slot->queueParameterMove(ordered->data(moved, Model::TypeRole).toInt(),
            slotNumber(moved),
            ordered->data(target, Model::TypeRole).toInt(),
            slotNumber(target),
            false);
    slot->completeParameterSwap(true);
    EXPECT_EQ(original, ids());
    slot->queueParameterMove(99, 0, lastType, 0, true);
    slot->completeParameterSwap(true);
    EXPECT_EQ(original, ids());
}

// FIXME: Incomplete case
TEST_F(QmlEffectsProxyTest, DISABLED_ParameterReorderingPreservesQmlAndFixedControlBindings) {
    using Model = mixxx::qml::QmlEffectSlotParametersModel;
    std::unique_ptr<mixxx::qml::QmlEffectSlotProxy> slot(m_pProxy->getEffectSlot(1, 1));
    slot->setEffectId(EchoEffect::getId());
    const auto core = m_pEffectsManager->getStandardEffectChain(0)->getEffectSlot(0);
    QHash<QString, EffectParameterPointer> parameters;
    QHash<QString, double> values;
    QHash<QString, QSharedPointer<ControlProxy>> fixedControls;
    QStringList expectedOrder;
    for (const auto type : {EffectParameterType::Button, EffectParameterType::Knob}) {
        const auto loaded = core->getLoadedParameters().value(type);
        for (int index = 0; index < loaded.size(); ++index) {
            const auto& parameter = loaded.at(index);
            const auto id = parameter->manifest()->id();
            const auto key = (type == EffectParameterType::Button
                            ? QStringLiteral("button_parameter%1")
                            : QStringLiteral("parameter%1"))
                                     .arg(index + 1);
            auto control = QSharedPointer<ControlProxy>::create(slot->getGroup(), key);
            ASSERT_TRUE(control->valid());
            const double value = type == EffectParameterType::Button
                    ? index % 2
                    : 0.1 * (index + 1);
            control->set(value);
            EXPECT_DOUBLE_EQ(value, parameter->getValue());
            parameters.insert(id, parameter);
            values.insert(id, value);
            fixedControls.insert(key, control);
            expectedOrder.append(id);
        }
    }
    ASSERT_EQ(6, expectedOrder.size());
    QQmlEngine engine;
    engine.addImportPath(QStringLiteral(":/mixxx.org/imports"));
    QQmlComponent component(&engine);
    component.setData(R"(
import QtQuick
import Mixxx 1.0 as Mixxx
Item {
    id: root
    required property string group
    required property var parametersModel
    function rowFor(id) {
        for (let index = 0; index < repeater.count; ++index) {
            const row = repeater.itemAt(index);
            if (row.parameterId === id) return row;
        }
        return null;
    }
    Repeater {
        id: repeater
        model: root.parametersModel
        delegate: Item {
            id: row
            required property string parameterId
            required property string controlKey
            property alias value: control.value
            Mixxx.ControlProxy {
                id: control
                group: root.group
                key: row.controlKey
            }
        }
    }
}
)",
            QUrl::fromLocalFile(QStringLiteral(RESOURCE_FOLDER "/qml/parameter_values_test.qml")));
    auto* ordered = slot->getParametersModel()->orderedModel();
    std::unique_ptr<QObject> root(component.createWithInitialProperties(
            {{QStringLiteral("group"), slot->getGroup()},
                    {QStringLiteral("parametersModel"), QVariant::fromValue(ordered)}}));
    ASSERT_TRUE(root) << qPrintable(component.errorString());
    const auto rowFor = [&root](const QString& id) -> QObject* {
        QVariant result;
        if (!QMetaObject::invokeMethod(root.get(),
                    "rowFor",
                    Q_RETURN_ARG(QVariant, result),
                    Q_ARG(QVariant, id))) {
            return nullptr;
        }
        return result.value<QObject*>();
    };
    const auto verifyBindings = [&] {
        QStringList displayed;
        for (int row = 0; row < ordered->rowCount(); ++row) {
            displayed.append(ordered->data(ordered->index(row, 0), Model::IdRole).toString());
        }
        EXPECT_EQ(expectedOrder, displayed);
        QHash<int, int> slotNumbers;
        for (const auto& id : expectedOrder) {
            SCOPED_TRACE(id.toStdString());
            const auto parameter = parameters.value(id);
            const auto type = parameter->manifest()->parameterType();
            const int number = ++slotNumbers[static_cast<int>(type)];
            const auto key = (type == EffectParameterType::Button
                            ? QStringLiteral("button_parameter%1")
                            : QStringLiteral("parameter%1"))
                                     .arg(number);
            EXPECT_EQ(parameter, core->getLoadedParameters().value(type).at(number - 1));
            EXPECT_DOUBLE_EQ(values.value(id), parameter->getValue());
            EXPECT_DOUBLE_EQ(values.value(id), fixedControls.value(key)->get());
            auto* row = rowFor(id);
            ASSERT_NE(nullptr, row);
            EXPECT_EQ(key, row->property("controlKey").toString());
            QTRY_COMPARE(row->property("value").toDouble(), values.value(id));
        }
    };
    const auto verifyWrites = [&] {
        for (const auto& id : expectedOrder) {
            const bool button =
                    parameters.value(id)->manifest()->parameterType() ==
                    EffectParameterType::Button;
            auto* row = rowFor(id);
            ASSERT_NE(nullptr, row);
            values[id] = button ? 1.0 - values.value(id) : values.value(id) + 0.03;
            ASSERT_TRUE(row->setProperty("value", values.value(id)));
            verifyBindings();
            const auto key = row->property("controlKey").toString();
            values[id] = button ? 1.0 - values.value(id) : values.value(id) + 0.02;
            fixedControls.value(key)->set(values.value(id));
            verifyBindings();
        }
    };
    verifyBindings();
    slot->queueParameterMove(Model::Knob, 3, Model::Button, 0, false);
    slot->completeParameterSwap(false);
    verifyBindings();
    slot->queueParameterMove(Model::Knob, 3, Model::Button, 0, false);
    slot->completeParameterSwap(true);
    expectedOrder.move(5, 0);
    verifyBindings();
    verifyWrites();
    slot->queueParameterMove(Model::Button, 1, Model::Knob, 0, false);
    slot->completeParameterSwap(true);
    expectedOrder.move(2, 0);
    verifyBindings();
    verifyWrites();
    core->swapParameters(EffectParameterType::Knob, 0, 2);
    expectedOrder.swapItemsAt(1, 4);
    verifyBindings();
    verifyWrites();
    core->swapParameters(EffectParameterType::Button, 0, 1);
    expectedOrder.swapItemsAt(0, 2);
    verifyBindings();
    verifyWrites();
}

// FIXME feature incomplete
TEST_F(QmlEffectsProxyTest, DISABLE_LiveParameterPreviewPreservesDelegatesAndCancels) {
    QQmlEngine engine;
    QQmlComponent component(&engine);
    component.setData(R"(
import QtQuick
import "Effects"
Item {
    width: 250
    height: 60
    property var capturedItem
    function capture() { capturedItem = repeater.itemAt(0); }
    function preview() { return visualModel.preview(0, 0, "parameter3"); }
    function cancel() { visualModel.restore(); }
    function replaceModel() { visualModel.sourceModel = visualModel.sourceModel.slice(); }
    function capturedIndex() {
        for (let i = 0; i < repeater.count; ++i) {
            if (repeater.itemAt(i) === capturedItem) return i;
        }
        return -1;
    }
    function keyAt(index) { return repeater.itemAt(index).modelData.controlKey; }
    readonly property string draggedKey: visualModel.draggedKey
    Row {
        Repeater {
            id: repeater
            model: visualModel
        }
    }
    EffectParameterReorderModel {
        id: visualModel
        sourceModel: [
            {controlKey: "parameter1", type: 0},
            {controlKey: "button_parameter1", type: 1},
            {controlKey: "parameter2", type: 0},
            {controlKey: "parameter3", type: 0}
        ]
        delegate: Item {
            required property var modelData
            width: 50
            height: 50
        }
    }
}
)",
            QUrl::fromLocalFile(QStringLiteral(RESOURCE_FOLDER "/qml/reorder_test.qml")));
    std::unique_ptr<QObject> root(component.create());
    ASSERT_TRUE(root) << qPrintable(component.errorString());
    QQuickWindow window;
    window.resize(250, 60);
    auto* item = qobject_cast<QQuickItem*>(root.get());
    ASSERT_TRUE(item);
    item->setParentItem(window.contentItem());
    window.show();
    ASSERT_TRUE(QTest::qWaitForWindowExposed(&window));
    ASSERT_TRUE(QMetaObject::invokeMethod(root.get(), "capture"));
    QVariant result;
    ASSERT_TRUE(QMetaObject::invokeMethod(root.get(), "preview", Q_RETURN_ARG(QVariant, result)));
    EXPECT_TRUE(result.toBool());
    EXPECT_EQ(QStringLiteral("parameter1"), root->property("draggedKey").toString());
    QTest::qWait(20);
    ASSERT_TRUE(QMetaObject::invokeMethod(
            root.get(), "capturedIndex", Q_RETURN_ARG(QVariant, result)));
    EXPECT_EQ(3, result.toInt());
    EXPECT_EQ(150, root->property("capturedItem").value<QObject*>()->property("x").toInt());
    ASSERT_TRUE(QMetaObject::invokeMethod(root.get(),
            "keyAt",
            Q_RETURN_ARG(QVariant, result),
            Q_ARG(QVariant, 0)));
    EXPECT_EQ(QStringLiteral("button_parameter1"), result.toString());
    ASSERT_TRUE(QMetaObject::invokeMethod(root.get(), "cancel"));
    QTest::qWait(20);
    EXPECT_TRUE(root->property("draggedKey").toString().isEmpty());
    ASSERT_TRUE(QMetaObject::invokeMethod(
            root.get(), "capturedIndex", Q_RETURN_ARG(QVariant, result)));
    EXPECT_EQ(0, result.toInt());
    ASSERT_TRUE(QMetaObject::invokeMethod(root.get(), "preview", Q_RETURN_ARG(QVariant, result)));
    EXPECT_TRUE(result.toBool());
    ASSERT_TRUE(QMetaObject::invokeMethod(root.get(), "replaceModel"));
    EXPECT_TRUE(root->property("draggedKey").toString().isEmpty());
}

// FIXME: Incomplete case
TEST_F(QmlEffectsProxyTest, DISABLED_ParameterDropPreviewsInsertionBeforeCommit) {
    using Model = mixxx::qml::QmlEffectSlotParametersModel;
    std::unique_ptr<mixxx::qml::QmlEffectSlotProxy> slot(m_pProxy->getEffectSlot(1, 1));
    slot->setEffectId(EchoEffect::getId());
    QQmlEngine::setObjectOwnership(slot.get(), QQmlEngine::CppOwnership);
    QQmlEngine engine;
    QQmlComponent component(&engine);
    component.setData(R"(
import QtQuick
import "Effects"
Item {
    id: root
    required property var effectSlot
    readonly property var rows: {
        const rows = [];
        const model = effectSlot.parametersModel;
        for (let i = 0; i < model.rowCount(); ++i) {
            const row = model.get(i);
            if (row.loaded) rows.push(row);
        }
        return rows.sort((a, b) => a.displayOrder - b.displayOrder);
    }
    readonly property int count: rows.length
    readonly property string draggedKey: visualModel.draggedKey
    width: count * 60
    height: 50
    function firstKey() { return repeater.itemAt(0).modelData.controlKey; }
    Row {
        Repeater { id: repeater; model: visualModel }
    }
    EffectParameterReorderModel {
        id: visualModel
        sourceModel: root.rows
        delegate: Item {
            id: parameter
            required property var modelData
            width: 60
            height: 50
            EffectParameterDragArea {
                anchors.fill: parent
                dragItem: parameter
                controlKey: parameter.modelData.controlKey
                parameterType: parameter.modelData.type
                effectSlot: root.effectSlot
                reorderModel: visualModel
            }
        }
    }
}
)",
            QUrl::fromLocalFile(QStringLiteral(RESOURCE_FOLDER "/qml/drop_reorder_test.qml")));
    std::unique_ptr<QObject> root(component.createWithInitialProperties(
            {{QStringLiteral("effectSlot"), QVariant::fromValue(slot.get())}}));
    ASSERT_TRUE(root) << qPrintable(component.errorString());
    auto* item = qobject_cast<QQuickItem*>(root.get());
    ASSERT_TRUE(item);
    QQuickWindow window;
    window.resize(root->property("count").toInt() * 60, 50);
    item->setParentItem(window.contentItem());
    window.show();
    ASSERT_TRUE(QTest::qWaitForWindowExposed(&window));
    auto* model = slot->getParametersModel()->orderedModel();
    const auto first = model->index(0, 0);
    const auto firstId = model->data(first, Model::IdRole).toString();
    const auto firstKey = model->data(first, Model::ControlKeyRole).toString();
    QMimeData mime;
    mime.setText(QStringLiteral("Mixxx effect parameter %1\n%2\n0")
                    .arg(model->data(first, Model::TypeRole).toInt())
                    .arg(slot->getUniqueId()));
    const QPoint position(window.width() - 30, 25);
    QDragEnterEvent enter(position, Qt::MoveAction, &mime, Qt::LeftButton, Qt::NoModifier);
    QCoreApplication::sendEvent(&window, &enter);
    ASSERT_TRUE(enter.isAccepted());
    QTest::qWait(20);
    EXPECT_EQ(firstKey, root->property("draggedKey").toString());
    QVariant result;
    ASSERT_TRUE(QMetaObject::invokeMethod(root.get(), "firstKey", Q_RETURN_ARG(QVariant, result)));
    EXPECT_NE(firstKey, result.toString());
    EXPECT_EQ(firstId, model->data(first, Model::IdRole).toString());
    QDragLeaveEvent leave;
    QCoreApplication::sendEvent(&window, &leave);
    EXPECT_TRUE(root->property("draggedKey").toString().isEmpty());
    QCoreApplication::sendEvent(&window, &enter);
    ASSERT_TRUE(enter.isAccepted());
    QDropEvent drop(QPointF(position), Qt::MoveAction, &mime, Qt::LeftButton, Qt::NoModifier);
    QCoreApplication::sendEvent(&window, &drop);
    ASSERT_TRUE(drop.isAccepted());
    EXPECT_EQ(firstId, model->data(first, Model::IdRole).toString());
    const int last = root->property("count").toInt() - 1;
    QTRY_COMPARE(model->data(model->index(last, 0), Model::IdRole).toString(), firstId);
    EXPECT_TRUE(root->property("draggedKey").toString().isEmpty());
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
    EXPECT_TRUE(pModel->roleNames().values().contains("maximum"));
    EXPECT_TRUE(pModel->roleNames().values().contains("neutralPoint"));
    const auto pManifest = EchoEffect::getManifest();
    EXPECT_DOUBLE_EQ(pManifest->metaknobDefault(), pSlot->getMetaDefault());
    for (int row = 0; row < kExpectedParameterCount; ++row) {
        const auto parameter = pModel->get(row).toMap();
        EXPECT_DOUBLE_EQ(pManifest->parameters().at(row)->getMaximum(),
                parameter.value("maximum").toDouble());
        EXPECT_DOUBLE_EQ(pManifest->parameters().at(row)->neutralPointOnScale(),
                parameter.value("neutralPoint").toDouble());
    }
    EXPECT_EQ(QString::number(-0.000001), pModel->formatNumber(-0.000001));
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
    pSlot->setEffectId(QString());
    EXPECT_DOUBLE_EQ(-1.0, pSlot->getMetaDefault());
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
