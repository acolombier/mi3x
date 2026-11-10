#include "qml/qmlcolorutils.h"

#include <QQmlEngine>

#include "moc_qmlcolorutils.cpp"
#include "util/color/color.h"

namespace mixxx {
namespace qml {

QmlColorUtils::QmlColorUtils(QObject* parent)
        : QObject(parent) {
}

int QmlColorUtils::brightness(int red, int green, int blue) {
    return Color::brightness(red, green, blue);
}
int QmlColorUtils::brightness(const QColor& color) {
    return Color::brightness(color);
}
bool QmlColorUtils::isDimColor(const QColor& color) {
    return Color::isDimColor(color);
}
bool QmlColorUtils::isDimColorCustom(const QColor& color, int threshold) {
    return Color::isDimColorCustom(color, threshold);
}
QColor QmlColorUtils::chooseColorByBrightness(QColor colorToChooseBy,
        QColor dimColor,
        QColor brightColor,
        int dimBrightThreshold) {
    return Color::chooseColorByBrightness(
            colorToChooseBy, dimColor, brightColor, dimBrightThreshold);
}
QColor QmlColorUtils::chooseContrastColor(QColor baseColor, int dimBrightThreshold) {
    return Color::chooseContrastColor(baseColor, dimBrightThreshold);
}
QColor QmlColorUtils::blendColors(QColor color1, QColor color2) {
    return Color::blendColors(color1, color2);
}

} // namespace qml
} // namespace mixxx
