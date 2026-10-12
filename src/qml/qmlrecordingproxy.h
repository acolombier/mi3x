#pragma once

#include <qtmetamacros.h>

#include <QJSEngine>
#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <memory>

#include "encoder/encoder.h"

class RecordingManager;

namespace mixxx {
namespace qml {

struct EncoderFormat {
    Q_GADGET

    Q_PROPERTY(QString label READ getLabel);
    Q_PROPERTY(QString internalName READ getInternalName);
    Q_PROPERTY(bool lossless READ getLossless);
    Q_PROPERTY(QString fileExtension READ getFileExtension);

  public:
    EncoderFormat(const Encoder::Format& format)
            : inner(format) {
    }

  private:
    Encoder::Format inner;
    QString getLabel() const {
        return inner.label;
    }
    QString getInternalName() const {
        return inner.internalName;
    }
    bool getLossless() const {
        return inner.lossless;
    }
    QString getFileExtension() const {
        return inner.fileExtension;
    }
};

class QmlRecordingProxy : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString durationText READ durationText NOTIFY durationTextChanged)
    QML_NAMED_ELEMENT(Recording)
    QML_SINGLETON
  public:
    explicit QmlRecordingProxy(std::shared_ptr<RecordingManager> pRecordingManager,
            QObject* parent = nullptr);
    ~QmlRecordingProxy() override = default;

    static QmlRecordingProxy* create(QQmlEngine* pQmlEngine, QJSEngine* pJsEngine);

    const QString& durationText() const {
        return m_durationText;
    }

    Q_INVOKABLE QVariantList formats() const;

    static inline std::shared_ptr<RecordingManager> s_pRecordingManager;

  signals:
    void durationTextChanged();

  private slots:
    void slotDurationRecorded(const QString& durationText);
    void slotRecordingActiveChanged(bool isRecording);

  private:
    std::shared_ptr<RecordingManager> m_pRecordingManager;
    QString m_durationText;
};

} // namespace qml
} // namespace mixxx
