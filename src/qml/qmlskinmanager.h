#pragma once

#include <QJSEngine>
#include <QObject>
#include <QPointer>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QString>

namespace mixxx {
namespace qml {

class QmlCoreServices;

class QmlColorPalette : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(ColorPalette)
  public:
    explicit QmlColorPalette(QObject* parent = nullptr)
            : QObject(parent) {
    }
    ~QmlColorPalette() override = default;
};

class QmlSkin : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(Skin)
    Q_PROPERTY(QString name MEMBER m_name NOTIFY nameChanged)
    Q_PROPERTY(QString version MEMBER m_version NOTIFY versionChanged)
    Q_PROPERTY(QString description MEMBER m_description NOTIFY descriptionChanged)
    Q_PROPERTY(QQmlListProperty<mixxx::qml::QmlColorPalette> colorPalettes READ
                    colorPalettes NOTIFY colorPalettesChanged)
    Q_PROPERTY(uint defaultHeight MEMBER m_defaultHeight NOTIFY defaultHeightChanged)
    Q_PROPERTY(uint defaultWidth MEMBER m_defaultWidth NOTIFY defaultWidthChanged)
    Q_PROPERTY(uint minimumWidth MEMBER m_minimumWidth NOTIFY minimumWidthChanged)
    Q_PROPERTY(uint minimumHeight MEMBER m_minimumHeight NOTIFY minimumHeightChanged)
    Q_PROPERTY(QQmlComponent* main MEMBER m_main NOTIFY mainChanged)
    Q_PROPERTY(QQmlComponent* loader MEMBER m_loader NOTIFY loaderChanged)
  public:
    explicit QmlSkin(QObject* parent = nullptr);
    ~QmlSkin() override;

    QQmlListProperty<mixxx::qml::QmlColorPalette> colorPalettes() {
        return {this, &m_colorPalettes};
    }
  signals:
    void mainChanged();
    void loaderChanged();
    void nameChanged();
    void versionChanged();
    void descriptionChanged();
    void colorPalettesChanged();
    void defaultHeightChanged();
    void defaultWidthChanged();
    void minimumWidthChanged();
    void minimumHeightChanged();

  private:
    QQmlComponent* m_main;
    QQmlComponent* m_loader;
    QString m_name;
    QString m_version;
    QString m_description;
    QList<mixxx::qml::QmlColorPalette*> m_colorPalettes;
    uint m_defaultHeight;
    uint m_defaultWidth;
    uint m_minimumWidth;
    uint m_minimumHeight;
};

class QmlSkinManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QList<mixxx::qml::QmlSkin*> skins READ getSkins NOTIFY skinsChanged)
    QML_NAMED_ELEMENT(SkinManager)
    QML_SINGLETON
  public:
    static QmlSkinManager* create(QQmlEngine* pQmlEngine, QJSEngine* pJsEngine);

    QList<mixxx::qml::QmlSkin*> getSkins() const {
        return m_pSkins.values();
    }

    Q_INVOKABLE void initialize(mixxx::qml::QmlCoreServices* pCoreServices);
    Q_INVOKABLE void teardown();
    QmlSkin* getSelectedSkin();

  signals:
    void skinsChanged();

    // protected:
    //   QmlSkinManager(QQmlEngine* pQmlEngine);
    //   ~QmlSkinManager() override = default;

  private slots:
    void slotSkinLoaded(const QUrl& fileInfo, QQmlComponent::Status status);

  private:
    QMap<QUrl, QQmlComponent*> m_skinManifests;
    QMap<QUrl, QmlSkin*> m_pSkins;
};

} // namespace qml
} // namespace mixxx
