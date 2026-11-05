#include "qml/qmlcontrollerproxy.h"

#include <qglobal.h>

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QtEndian>

#include "moc_qmlcontrollerproxy.cpp"

namespace mixxx {
namespace qml {

QmlControllerElement::QmlControllerElement(QQuickItem* parent)
        : QQuickItem(parent),
          m_values() {
    //   auto learner = HIDLearner::instance();
    //   connect(learner->hid(),
    //           &HidIoThread::receive,
    //           this,
    //           &QmlControllerElement::slotReceivePacket,
    //           Qt::DirectConnection);
}

QmlControllerElement::~QmlControllerElement() {
    if (m_type != Type::Controller) {
        return;
    }
    QJsonArray data;
    save(&data);

    QFile file("out.json");
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << data;
        return;
    }

    file.write(QJsonDocument(data.first().toObject()).toJson());
    file.flush();
}
void QmlControllerElement::save(QJsonArray* data) {
    QJsonObject element{
            {"width", width()},
            {"height", height()},
    };

    if (m_type != Type::Controller) {
        const QMetaObject* metaObject = this->metaObject();
        for (int i = metaObject->propertyOffset(); i < metaObject->propertyCount(); ++i) {
            element.insert(metaObject->property(i).name(),
                    QJsonValue::fromVariant(
                            metaObject->property(i).read(this)));
        }
        element.insert("type", static_cast<int>(m_type));
        element.insert("x", x());
        element.insert("y", y());
        //   if (!m_modifiers.isEmpty()){
        //     element.insert("modifiers", QJsonArray::fromVariantList(getModifiers()));
        //   }
    }

    if (m_type == Type::Controller || m_type == Type::Zone) {
        QJsonArray obj;
        const auto& childrenList = children();
        for (auto* child : childrenList) {
            child->save(&obj);
        }
        element.insert("children", obj);
    }
    data->push_back(element);
}

QVariantMap QmlControllerElement::properties() const {
    const QMetaObject* metaObject = this->metaObject();
    QVariantMap properties{{"width", width()}, {"height", height()}};
    for (int i = metaObject->propertyOffset(); i < metaObject->propertyCount(); ++i) {
        properties.insert(metaObject->property(i).name(),
                QJsonValue::fromVariant(metaObject->property(i).read(this)));
    }
    return properties;
}

QJsonObject QmlControllerElement::seed() {
    QFile file("out.json");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QJsonObject();
    }

    auto doc = QJsonDocument::fromJson(file.readAll());
    return doc.object();
}

void QmlControllerElement::learn() {
    //   auto learner = HIDLearner::instance();

    //   if (learner->learner() != this) {
    //     learner->capture(this);
    //     return;
    //   }
    //   switch (learner->phase()) {
    //     case HIDLearner::Phase::Capture:
    //       learner->refine();
    //       break;
    //     case HIDLearner::Phase::Refine:
    //       learner->clean();
    //       break;
    //     case HIDLearner::Phase::Clean:
    //       learner->finish();
    //       break;
    //   }
}

void QmlControllerElement::slotReceivePacket(const QByteArray& data,
        std::chrono::time_point<std::chrono::system_clock>) {
    //   if (m_modifiers.isEmpty()){
    return;
    //   }
    //   int valueIdx = 0;
    //   for (const auto* pModifier: m_modifiers){
    //     if (pModifier->getReportId() != data[0]) continue;

    //     QByteArray fullValue(sizeof(uint), 0);
    //     QByteArray subdata = data.sliced(pModifier->getByteOffset() + 1);
    //     fullValue.replace(0, subdata.size(), subdata);
    //     auto value = qFromLittleEndian<uint>(fullValue);
    //     uint newValue = (value & pModifier->getMask()) >> pModifier->bitShift();

    //     if (newValue != m_values[valueIdx]) {
    //       // qWarning() << "Value" << this << (value & pModifier->getMask())
    //       << newValue << pModifier->valueCount() << pModifier->bitShift();
    //       m_values[valueIdx] = newValue;
    //       emit valuesChanged();
    //     }
    //     valueIdx++;
    //   }
    // m_value = newValue;
}

} // namespace qml
} // namespace mixxx
