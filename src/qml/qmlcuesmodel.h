#pragma once
#include <QAbstractListModel>
#include <memory>

#include "track/track_decl.h"

class CuePointer;

namespace mixxx {
namespace qml {

class QmlCuesModel : public QAbstractListModel {
    Q_OBJECT
    // Bumped whenever the cue data changes, so that QML bindings that access
    // the data via invokables (e.g. get(), getByHotcueNumber()) can be
    // re-evaluated on demand.
    Q_PROPERTY(int revision READ getRevision NOTIFY revisionChanged)
  public:
    enum Roles {
        StartPositionRole = Qt::UserRole + 1,
        EndPositionRole,
        LabelRole,
        IsLoopRole,
        HotcueNumberRole,
        TypeRole,
    };
    Q_ENUM(Roles)

    explicit QmlCuesModel(QObject* pParent = nullptr);

    void setTrack(TrackPointer pTrack);
    void setCues(QList<CuePointer> cues);

    QVariant data(const QModelIndex& index, int role) const override;
    int rowCount(const QModelIndex& parent) const override;
    QHash<int, QByteArray> roleNames() const override;
    Q_INVOKABLE QVariant get(int row) const;
    Q_INVOKABLE QMap<QString, QVariant> getByHotcueNumber(int hotcueNumber) const;
    Q_INVOKABLE int findIndexByHotcueNumber(int hotcueNumber) const;

    /// Writes the label of the cue with the given hotcue number.
    Q_INVOKABLE void setLabelByHotcueNumber(
            int hotcueNumber, const QString& label);

    /// Converts the cue with the given hotcue number into a cue of the
    /// given type (CueType: 1 = hotcue, 4 = loop, 5 = jump), keeping
    /// positions where sensible.
    Q_INVOKABLE bool convertTypeByHotcueNumber(
            int hotcueNumber, int newType, const QString& playerGroup);

    int getRevision() const {
        return m_revision;
    }

  signals:
    void revisionChanged();

  private:
    void bumpRevision();

    QList<CuePointer> m_cues;
    TrackPointer m_pTrack;
    int m_revision = 0;
};

} // namespace qml
} // namespace mixxx
