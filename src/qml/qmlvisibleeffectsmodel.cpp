#include "qml/qmlvisibleeffectsmodel.h"

#include <QModelIndex>

#include "effects/backends/effectmanifest.h"
#include "effects/defs.h"
#include "effects/effectsmanager.h"
#include "effects/visibleeffectslist.h"
#include "moc_qmlvisibleeffectsmodel.cpp"

namespace mixxx {
namespace qml {
namespace {
const QHash<int, QByteArray> kRoleNames = {
        {Qt::DisplayRole, "display"},
        {Qt::ToolTipRole, "tooltip"},
        {QmlVisibleEffectsModel::EffectIdRole, "effectId"},
};
}

QmlVisibleEffectsModel::QmlVisibleEffectsModel(
        std::shared_ptr<EffectsManager> pEffectsManager,
        QObject* parent)
        : QAbstractListModel(parent), m_pEffectsManager(pEffectsManager) {
    slotVisibleEffectsUpdated();
    connect(m_pEffectsManager->getVisibleEffectsList().get(),
            &VisibleEffectsList::visibleEffectsListChanged,
            this,
            &QmlVisibleEffectsModel::slotVisibleEffectsUpdated);
}

void QmlVisibleEffectsModel::slotVisibleEffectsUpdated() {
    beginResetModel();
    m_visibleEffectManifests = m_pEffectsManager->getVisibleEffectsList()->getList();
    endResetModel();
}

QVariant QmlVisibleEffectsModel::data(const QModelIndex& index, int role) const {
    if (index.row() == 0) {
        switch (role) {
        case Qt::DisplayRole:
            return kNoEffectString;
        case Qt::ToolTipRole:
            return tr("No effect loaded.");
        default:
            return QVariant();
        }
    }

    if (index.row() > m_visibleEffectManifests.size()) {
        return QVariant();
    }

    const EffectManifestPointer pManifest = m_visibleEffectManifests.at(index.row() - 1);
    switch (role) {
    case Qt::DisplayRole:
        return pManifest->displayName();
    case Qt::ToolTipRole:
        return pManifest->description();
    case QmlVisibleEffectsModel::EffectIdRole:
        return pManifest->uniqueId();
    default:
        return QVariant();
    }
}

int QmlVisibleEffectsModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) {
        return 0;
    }

    // Add +1 because we also include "no effect" in the model
    return m_visibleEffectManifests.size() + 1;
}

QHash<int, QByteArray> QmlVisibleEffectsModel::roleNames() const {
    return kRoleNames;
}

QVariant QmlVisibleEffectsModel::get(int row) const {
    QModelIndex idx = index(row, 0);
    QVariantMap dataMap;
    for (auto it = kRoleNames.constBegin(); it != kRoleNames.constEnd(); it++) {
        dataMap.insert(it.value(), data(idx, it.key()));
    }
    return dataMap;
}

} // namespace qml
} // namespace mixxx

// SEGFAULT
// Thread 43 "ControllerManag" received signal SIGSEGV, Segmentation fault.
// [Switching to Thread 0x7f6da3fff6c0 (LWP 478277)]
// QSharedPointer<EffectManifest>::QSharedPointer (this=0x7f6da3ffaf50, other=...) at /usr/include/x86_64-linux-gnu/qt6/QtCore/qsharedpointer_impl.h:315
// 315         { if (d) ref(); }
// (gdb) bt
// #0  QSharedPointer<EffectManifest>::QSharedPointer (this=0x7f6da3ffaf50, other=...) at /usr/include/x86_64-linux-gnu/qt6/QtCore/qsharedpointer_impl.h:315
// #1  mixxx::qml::QmlVisibleEffectsModel::data (this=<optimized out>, index=<optimized out>, role=257) at /workspaces/mixxx/src/qml/qmlvisibleeffectsmodel.cpp:54
// #2  0x0000559005baf405 in mixxx::qml::QmlVisibleEffectsModel::get (this=this@entry=0x7f6d986a0b90, row=<optimized out>) at /workspaces/mixxx/src/qml/qmlvisibleeffectsmodel.cpp:84
// #3  0x0000559005baf612 in mixxx::qml::QmlVisibleEffectsModel::qt_static_metacall (_o=0x7f6d986a0b90, _c=QMetaObject::InvokeMetaMethod, _id=1, _a=0x7f6da3ffb388)
//     at mixxx-qml-lib_autogen/include/moc_qmlvisibleeffectsmodel.cpp:98
// #4  mixxx::qml::QmlVisibleEffectsModel::qt_metacall (this=0x7f6d986a0b90, _c=<optimized out>, _id=1, _a=0x7f6da3ffb388) at mixxx-qml-lib_autogen/include/moc_qmlvisibleeffectsmodel.cpp:125
// #5  0x00007f6e5e22ac42 in ??? () at /usr/lib/x86_64-linux-gnu/libQt6Qml.so.6
// #6  0x00007f6e5e0e0561 in QV4::QObjectMethod::callPrecise(QQmlObjectOrGadget const&, QQmlPropertyData const&, QV4::ExecutionEngine*, QV4::CallData*, QMetaObject::Call) () at /usr/lib/x86_64-linux-gnu/libQt6Qml.so.6
// #7  0x00007f6e5e0ea305 in QV4::QObjectMethod::callInternal(QV4::Value const*, QV4::Value const*, int) const () at /usr/lib/x86_64-linux-gnu/libQt6Qml.so.6
// #8  0x00007f6e5e1080dd in QV4::Runtime::CallPropertyLookup::call(QV4::ExecutionEngine*, QV4::Value const&, unsigned int, QV4::Value*, int) () at /usr/lib/x86_64-linux-gnu/libQt6Qml.so.6
// #9  0x00007f6cc40142a7 in ??? ()
// #10 0x0000000000000000 in ??? ()