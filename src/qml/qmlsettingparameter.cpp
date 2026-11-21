#include "qml/qmlsettingparameter.h"

#include <qobject.h>

#include <QDebug>
#include <QObject>
#include <QQmlContext>
#include <QQmlEngine>
#include <Qt>
#include <utility>

#include "moc_qmlsettingparameter.cpp"
#include "util/assert.h"

namespace mixxx {
namespace qml {

QmlSettingGroup::QmlSettingGroup(QQuickItem* parent)
        : QQuickItem(parent) {
}
QmlSettingParameter::QmlSettingParameter(QQuickItem* parent)
        : QmlSettingGroup(parent) {
}

void QmlSettingParameter::componentComplete() {
    QmlSettingGroup::componentComplete();
    QList<QmlSettingGroup*> pathItems;
    auto* pParent = parentItem();
    while (pParent != nullptr) {
        auto* pManager = qobject_cast<QmlSettingParameterManager*>(pParent);
        if (pManager) {
            pManager->registerSettingParamater(this, pathItems);
            return;
        }
        auto* pGroup = qobject_cast<QmlSettingGroup*>(pParent);
        if (pGroup) {
            pathItems.prepend(pGroup);
        }
        pParent = pParent->parentItem();
    }
    DEBUG_ASSERT(!"Couldn't find manager!");
}

QmlSettingParameterManager::QmlSettingParameterManager(QQuickItem* parent)
        : QQuickItem(parent),
          m_model(this) {
    m_model.setSourceModel(&m_sourceModel);
    m_model.setFilterRole(Qt::UserRole);
    m_model.setFilterCaseSensitivity(Qt::CaseInsensitive);
}
QmlSettingParameterManager::~QmlSettingParameterManager() {
    // Manually deleting children so they can complete deregistration
    qDeleteAll(childItems());
}

void QmlSettingParameterManager::registerSettingParamater(
        QmlSettingParameter* pParameter, const QList<QmlSettingGroup*>& pathItems) {
    auto generateRow = [pParameter](QList<QmlSettingGroup*> pathItems, QStandardItem* pItem) {
        QStringList component;
        for (const auto* pItemGroup : pathItems) {
            component.append(pItemGroup->label());
        }
        QString path = component.join(" > ");

        component.append(pParameter->label());
        component.append(pParameter->keywords());
        pathItems.append(pParameter);

        if (pItem == nullptr) {
            pItem = new QStandardItem(pParameter->label());
        } else {
            pItem->setText(pParameter->label());
        }
        pItem->setData(component.join(" "), Qt::UserRole);
        pItem->setData(path, Qt::WhatsThisRole);
        pItem->setData(QVariant::fromValue(pathItems), Qt::ToolTipRole);
        return pItem;
    };
    auto* pRowItem = generateRow(pathItems, nullptr);
    m_sourceModel.appendRow(QList<QStandardItem*>{pRowItem});
    connect(pParameter, &QObject::destroyed, this, [this, pRowItem](QObject*) {
        VERIFY_OR_DEBUG_ASSERT(pRowItem->index().isValid()) {
            return;
        };
        m_sourceModel.removeRow(pRowItem->index().row());
    });
    connect(pParameter,
            &QmlSettingParameter::labelChanged,
            this,
            [pathItems, generateRow, pRowItem]() {
                generateRow(pathItems, pRowItem);
            });
    connect(pParameter,
            &QmlSettingParameter::keywordsChanged,
            this,
            [pathItems, generateRow, pRowItem]() {
                generateRow(pathItems, pRowItem);
            });
}

void QmlSettingParameterManager::search(const QString& criteria) {
    m_model.setFilterFixedString(criteria);
}

namespace {

bool isAncestorOf(QObject* pObject, const QObject* pAncestor) {
    while (pObject != nullptr && pObject != pAncestor) {
        pObject = pObject->parent();
    }
    return pObject == pAncestor;
}

// Resolves one name within the subtree rooted at pRoot. The name may be a
// QML id, found through the QML context of any object in the subtree, or an
// objectName, found through direct comparison. Since a QML context also
// exposes ids of enclosing scopes, an id hit is only accepted when it
// belongs to the searched subtree.
QObject* findObjectRecursive(QObject* pRoot, const QString& name) {
    if (pRoot == nullptr) {
        return nullptr;
    }

    QQmlContext* pContext = QQmlEngine::contextForObject(pRoot);
    if (pContext != nullptr) {
        QObject* pObject = pContext->objectForName(name);
        if (pObject != nullptr &&
                (pObject == pRoot || isAncestorOf(pObject, pRoot))) {
            return pObject;
        }
    }

    if (pRoot->objectName() == name) {
        return pRoot;
    }

    const QObjectList children = pRoot->children();
    for (auto* pChild : children) {
        QObject* pObject = findObjectRecursive(pChild, name);
        if (pObject != nullptr) {
            return pObject;
        }
    }
    return nullptr;
}

} // namespace

QmlSettingGroup* QmlSettingParameterManager::findSettings(QStringList names) {
    VERIFY_OR_DEBUG_ASSERT(!names.isEmpty()) {
        return nullptr;
    }

    QObject* pMatch = this;
    for (const QString& name : std::as_const(names)) {
        pMatch = findObjectRecursive(pMatch, name);
        if (pMatch == nullptr) {
            qDebug() << "QmlSettingParameterManager::findSettings - Settings "
                        "section"
                     << name << "not found";
            return nullptr;
        }
    }

    auto* pGroup = qobject_cast<QmlSettingGroup*>(pMatch);
    if (pGroup == nullptr) {
        qDebug() << "QmlSettingParameterManager::findSettings - Settings section" << names.last()
                 << "is not a SettingGroup:" << pMatch;
        return nullptr;
    }
    return pGroup;
}

} // namespace qml
} // namespace mixxx
