#include "qml/qmlsidebarmodelproxy.h"

#include <qalgorithms.h>

#include <QAbstractListModel>
#include <QVariant>
#include <QtDebug>

#include "library/treeitem.h"
#include "moc_qmlsidebarmodelproxy.cpp"
#include "qml/qmllibrarysource.h"
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
        VERIFY_OR_DEBUG_ASSERT(index.row() >= 0 && index.row() < m_sFeatures.length()) {
            return nullptr;
        }
        return m_pQmlFeatures[index.row()];
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

QmlSidebarModelProxy::QmlSidebarModelProxy(QObject* parent)
        : SidebarModel(parent),
          m_tracklist(nullptr) {
}
QmlSidebarModelProxy::~QmlSidebarModelProxy() = default;

QVariant QmlSidebarModelProxy::data(const QModelIndex& index, int role) const {
    if (index.internalPointer() != this) {
        return SidebarModel::data(index, role);
    }
    VERIFY_OR_DEBUG_ASSERT(index.isValid() && index.row() >= 0 &&
            index.row() < m_pQmlFeatures.length()) {
        return {};
    }
    switch (role) {
    case Qt::DisplayRole:
        return m_pQmlFeatures[index.row()]->label();
    case QmlSidebarModelProxy::IconRole:
        return m_pQmlFeatures[index.row()]->icon();
    case QmlSidebarModelProxy::ItemNameRole:
        return m_pQmlFeatures[index.row()]->itemName();
    case QmlSidebarModelProxy::CapabilitiesRole:
        return m_pQmlFeatures[index.row()]->capabilities();
    default:
        return SidebarModel::data(index, role);
    }
}

void QmlSidebarModelProxy::update(const QList<QmlLibraryAbstractSource*>& sources) {
    beginResetModel();
    qDeleteAll(m_sFeatures);
    qDeleteAll(m_pQmlFeatures);
    for (auto* pLibrarySource : sources) {
        VERIFY_OR_DEBUG_ASSERT(pLibrarySource) {
            continue;
        }
        connect(pLibrarySource,
                &QmlLibraryAbstractSource::requestTrackModel,
                this,
                &QmlSidebarModelProxy::slotShowTrackModel);
        m_pQmlFeatures.append(pLibrarySource);
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
