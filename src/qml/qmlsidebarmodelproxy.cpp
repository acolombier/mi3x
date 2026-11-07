#include "qml/qmlsidebarmodelproxy.h"

#include <QAbstractListModel>
#include <QVariant>
#include <QtDebug>

#include "library/treeitem.h"
#include "moc_qmlsidebarmodelproxy.cpp"
#include "qml/qmllibrarysource.h"
#include "qml/qmllibrarysourcetree.h"
#include "util/assert.h"
#include "util/parented_ptr.h"

namespace mixxx {
namespace qml {

namespace {
const QHash<int, QByteArray> kRoleNames = {
        {Qt::DisplayRole, "label"},
        {QmlSidebarModelProxy::IconRole, "icon"},
        {QmlSidebarModelProxy::ItemNameRole, "itemName"},
        {QmlSidebarModelProxy::CapabilitiesRole, "capabilities"},
};
} // namespace

QHash<int, QByteArray> QmlSidebarModelProxy::roleNames() const {
    return kRoleNames;
}

QmlLibraryAbstractSource* QmlSidebarModelProxy::get(const QModelIndex& index) const {
    VERIFY_OR_DEBUG_ASSERT(index.isValid()) {
        return nullptr;
    }
    if (index.internalPointer() == this) {
        const auto& sources = qobject_cast<QmlLibrarySourceTree*>(parent())->sources();
        VERIFY_OR_DEBUG_ASSERT(index.row() >= 0 &&
                index.row() < m_sFeatures.length() &&
                index.row() < sources.length()) {
            return nullptr;
        }
        return sources[index.row()];
    } else {
        return nullptr;
    }
}

void QmlSidebarModelProxy::activate(const QModelIndex& index) {
    VERIFY_OR_DEBUG_ASSERT(index.isValid()) {
        return;
    }
    if (index.internalPointer() == this) {
        VERIFY_OR_DEBUG_ASSERT(index.row() >= 0 && index.row() < m_sFeatures.length()) {
            return;
        }
        m_sFeatures[index.row()]->activate();
    } else {
        TreeItem* pTreeItem = static_cast<TreeItem*>(index.internalPointer());
        VERIFY_OR_DEBUG_ASSERT(pTreeItem != nullptr) {
            return;
        }
        LibraryFeature* pFeature = pTreeItem->feature();
        VERIFY_OR_DEBUG_ASSERT(pFeature) {
            return;
        }
        pFeature->activateChild(index);
        pFeature->onLazyChildExpandation(index);
    }
}

QmlSidebarModelProxy::QmlSidebarModelProxy(QmlLibrarySourceTree* parent)
        : SidebarModel(parent),
          m_tracklist(nullptr) {
}
QmlSidebarModelProxy::~QmlSidebarModelProxy() = default;

QVariant QmlSidebarModelProxy::data(const QModelIndex& index, int role) const {
    if (index.internalPointer() != this) {
        return SidebarModel::data(index, role);
    }
    const auto& sources = qobject_cast<QmlLibrarySourceTree*>(parent())->sources();
    VERIFY_OR_DEBUG_ASSERT(index.isValid() && index.row() >= 0 &&
            index.row() < sources.size()) {
        return {};
    }
    switch (role) {
    case Qt::DisplayRole:
        return sources[index.row()]->label();
    case QmlSidebarModelProxy::IconRole:
        return sources[index.row()]->icon();
    case QmlSidebarModelProxy::ItemNameRole:
        return sources[index.row()]->itemName();
    case QmlSidebarModelProxy::CapabilitiesRole:
        return sources[index.row()]->capabilities();
    default:
        return SidebarModel::data(index, role);
    }
}

void QmlSidebarModelProxy::update() {
    beginResetModel();
    // Do not delete the features: they are owned by the QmlLibraryAbstractSource
    // instances (std::unique_ptr), not by the model.
    m_sFeatures.clear();
    auto sources = qobject_cast<QmlLibrarySourceTree*>(parent())->sources();
    for (auto* pLibrarySource : sources) {
        VERIFY_OR_DEBUG_ASSERT(pLibrarySource) {
            continue;
        }
        connect(pLibrarySource,
                &QmlLibraryAbstractSource::requestTrackModel,
                this,
                &QmlSidebarModelProxy::slotShowTrackModel,
                Qt::UniqueConnection);
        addLibraryFeature(pLibrarySource->internal());
        const auto newIndex = index(m_sFeatures.length() - 1, 0);
        connect(pLibrarySource,
                &QmlLibraryAbstractSource::labelChanged,
                this,
                [this, newIndex]() {
                    emit dataChanged(newIndex, newIndex, {Qt::DisplayRole});
                });
        connect(pLibrarySource,
                &QmlLibraryAbstractSource::itemNameChanged,
                this,
                [this, newIndex]() {
                    emit dataChanged(newIndex, newIndex, {QmlSidebarModelProxy::IconRole});
                });
        connect(pLibrarySource,
                &QmlLibraryAbstractSource::iconChanged,
                this,
                [this, newIndex]() {
                    emit dataChanged(newIndex, newIndex, {QmlSidebarModelProxy::ItemNameRole});
                });
        connect(pLibrarySource,
                &QmlLibraryAbstractSource::capabilitiesChanged,
                this,
                [this, newIndex]() {
                    emit dataChanged(newIndex, newIndex, {QmlSidebarModelProxy::CapabilitiesRole});
                });
    }
    endResetModel();
}

void QmlSidebarModelProxy::slotShowTrackModel(std::shared_ptr<QmlLibraryTrackListModel> pModel) {
    m_tracklist = pModel;
    emit tracklistChanged();
}

} // namespace qml
} // namespace mixxx
