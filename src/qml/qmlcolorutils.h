#pragma once

#include <QColor>
#include <QObject>
#include <QQmlEngine>

namespace mixxx {
namespace qml {

class QmlColorUtils : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(ColorUtils)
    QML_SINGLETON

  public:
    explicit QmlColorUtils(QObject* parent = nullptr);

    Q_INVOKABLE int brightness(int red, int green, int blue);
    Q_INVOKABLE int brightness(const QColor& color);
    Q_INVOKABLE bool isDimColor(const QColor& color);
    Q_INVOKABLE bool isDimColorCustom(const QColor& color, int threshold);
    Q_INVOKABLE QColor chooseColorByBrightness(QColor colorToChooseBy,
            QColor dimColor,
            QColor brightColor,
            int dimBrightThreshold);
    Q_INVOKABLE QColor chooseContrastColor(QColor baseColor, int dimBrightThreshold);
    Q_INVOKABLE QColor blendColors(QColor color1, QColor color2);
};

} // namespace qml
} // namespace mixxx
