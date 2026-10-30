#include "qml/qmllibrarysourcetree.h"

#include <qalgorithms.h>
#include <qvariant.h>

#include <QAbstractListModel>
#include <QVariant>

#include "library/library.h"
#include "library/librarytablemodel.h"
#include "moc_qmllibrarysourcetree.cpp"
#include "qml_owned_ptr.h"
#include "qmllibraryproxy.h"
#include "qmllibrarytracklistmodel.h"
#include "qmlsidebarmodelproxy.h"
#include "util/parented_ptr.h"

namespace mixxx {
namespace qml {

QmlLibrarySourceTree::QmlLibrarySourceTree(QQuickItem* parent)
        : QQuickItem(parent),
          m_model(make_parented<QmlSidebarModelProxy>(this)) {
    QJSEngine::setObjectOwnership(m_model.get(), QJSEngine::CppOwnership);
}
QmlLibrarySourceTree::~QmlLibrarySourceTree() = default;

Q_INVOKABLE QmlLibraryTrackListModel* QmlLibrarySourceTree::allTracks() const {
    return make_qml_owned<QmlLibraryTrackListModel>(
            m_defaultColumns, QmlLibraryProxy::get()->trackTableModel());
};

void QmlLibrarySourceTree::append_source(
        QQmlListProperty<QmlLibraryAbstractSource>* p, QmlLibraryAbstractSource* source) {
    reinterpret_cast<QList<QmlLibraryAbstractSource*>*>(p->data)->append(source);
    QmlLibrarySourceTree* librarySourceTree = qobject_cast<QmlLibrarySourceTree*>(p->object);
    if (librarySourceTree->isComponentComplete()) {
        librarySourceTree->m_model->update();
        emit librarySourceTree->sidebarChanged();
    }
}

void QmlLibrarySourceTree::clear_source(QQmlListProperty<QmlLibraryAbstractSource>* p) {
    reinterpret_cast<QList<QmlLibraryAbstractSource*>*>(p->data)->clear();
    QmlLibrarySourceTree* librarySourceTree = qobject_cast<QmlLibrarySourceTree*>(p->object);
    if (librarySourceTree->isComponentComplete()) {
        librarySourceTree->m_model->update();
        emit librarySourceTree->sidebarChanged();
    }
}
void QmlLibrarySourceTree::replace_source(QQmlListProperty<QmlLibraryAbstractSource>* p,
        qsizetype idx,
        QmlLibraryAbstractSource* v) {
    reinterpret_cast<QList<QmlLibraryAbstractSource*>*>(p->data)->replace(idx, v);
    QmlLibrarySourceTree* librarySourceTree = qobject_cast<QmlLibrarySourceTree*>(p->object);
    if (librarySourceTree->isComponentComplete()) {
        librarySourceTree->m_model->update();
        emit librarySourceTree->sidebarChanged();
    }
}
void QmlLibrarySourceTree::removeLast_source(QQmlListProperty<QmlLibraryAbstractSource>* p) {
    reinterpret_cast<QList<QmlLibraryAbstractSource*>*>(p->data)->removeLast();
    QmlLibrarySourceTree* librarySourceTree = qobject_cast<QmlLibrarySourceTree*>(p->object);
    if (librarySourceTree->isComponentComplete()) {
        librarySourceTree->m_model->update();
        emit librarySourceTree->sidebarChanged();
    }
}

QQmlListProperty<QmlLibraryAbstractSource> QmlLibrarySourceTree::qmlSources() {
    return QQmlListProperty<QmlLibraryAbstractSource>(this,
            &m_sources,
            &QmlLibrarySourceTree::append_source,
            &QmlLibrarySourceTree::count_source,
            &QmlLibrarySourceTree::at_source,
            &QmlLibrarySourceTree::clear_source,
            &QmlLibrarySourceTree::replace_source,
            &QmlLibrarySourceTree::removeLast_source);
}

void QmlLibrarySourceTree::componentComplete() {
    QQuickItem::componentComplete();
    m_model->update();
}

} // namespace qml
} // namespace mixxx
