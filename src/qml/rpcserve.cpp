#include "qml/rpcserve.h"

#include <Spix/AnyRpcServer.h>
#include <Spix/QtQmlBot.h>

#include <QDebug>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QSqlQuery>
#include <atomic>
#include <memory>
#include <utility>

#include "control/controlobject.h"
#include "coreservices.h"
#include "library/dao/trackdao.h"
#include "library/trackcollection.h"
#include "library/trackcollectionmanager.h"
#include "library/trackset/crate/cratesummary.h"
#include "mixer/playermanager.h"
#include "qml/qmlapplication.h"
#include "soundio/soundmanager.h"
#include "track/track.h"
#include "util/assert.h"
#include "util/cmdlineargs.h"
#include "util/fileinfo.h"
#include "util/versionstore.h"

namespace {
void persistLibraryJsonState(const QJsonObject& state) {
    QString json = QString::fromUtf8(
            QJsonDocument(state).toJson(QJsonDocument::Compact));
    qDebug() << "persistLibraryJsonState:" << json;

    auto windows = QGuiApplication::topLevelWindows();
    DEBUG_ASSERT(!windows.isEmpty());
    for (auto* w : std::as_const(windows)) {
        w->setProperty("lastLibraryState", json);
    }
}
} // namespace

namespace mixxx {
namespace qml {

RpcServe::RpcServe(
        QmlApplication* pQmlApplication,
        std::shared_ptr<CoreServices> pCoreServices)
        : m_pQmlApplication(pQmlApplication),
          m_server(9000),
          m_pBot(std::make_unique<spix::QtQmlBot>()) {
    auto pPlayerManager = pCoreServices->getPlayerManager();
    auto pTrackCollectionManager = pCoreServices->getTrackCollectionManager();

    // Track library scan progress so tests can wait for an asynchronous scan
    // to finish instead of blocking the main thread in a nested event loop.
    // The scanner emits its signals from the scanner thread, hence the atomics.
    auto pActiveScanCount = std::make_shared<std::atomic<int>>(0);
    auto pCompletedScanCount = std::make_shared<std::atomic<int>>(0);
    QObject::connect(pTrackCollectionManager.get(),
            &TrackCollectionManager::libraryScanStarted,
            [pActiveScanCount]() { pActiveScanCount->fetch_add(1); });
    QObject::connect(pTrackCollectionManager.get(),
            &TrackCollectionManager::libraryScanFinished,
            [pActiveScanCount, pCompletedScanCount]() {
                pCompletedScanCount->fetch_add(1);
                // Saturating decrement; a stray finished without a matching
                // started must not underflow.
                int active = pActiveScanCount->load();
                while (active > 0 &&
                        !pActiveScanCount->compare_exchange_weak(active, active - 1)) {
                }
            });

    onQmlLoaded();

    m_server.setGenericCommandHandler(
            [pCoreServices,
                    pPlayerManager,
                    pTrackCollectionManager,
                    pActiveScanCount,
                    pCompletedScanCount,
                    pQmlApplication](const std::string& command,
                    const std::string& payload) {
                if (command == "getControlValue") {
                    QString rest = QString::fromStdString(payload);
                    int comma = rest.indexOf(',');
                    if (comma < 0) {
                        qWarning() << "getControlValue: invalid payload, expected "
                                      "'group,item', got:"
                                   << rest;
                        return;
                    }
                    QString group = rest.left(comma);
                    QString item = rest.mid(comma + 1);

                    ConfigKey key(group, item);
                    if (!ControlObject::exists(key)) {
                        qWarning() << "getControlValue: ControlObject does not "
                                      "exist:"
                                   << group << item;
                        return;
                    }

                    double value = ControlObject::get(key);

                    qDebug() << "getControlValue:" << group << item << "=" << value;

                    auto windows = QGuiApplication::topLevelWindows();
                    for (auto* w : std::as_const(windows)) {
                        w->setProperty("lastControlValue", value);
                    }
                } else if (command == "setControlValue") {
                    QString rest = QString::fromStdString(payload);
                    int firstComma = rest.indexOf(',');
                    if (firstComma < 0) {
                        qWarning() << "setControlValue: invalid payload, expected "
                                      "'group,item,value', got:"
                                   << rest;
                        return;
                    }
                    int secondComma = rest.indexOf(',', firstComma + 1);
                    if (secondComma < 0) {
                        qWarning() << "setControlValue: invalid payload, expected "
                                      "'group,item,value', got:"
                                   << rest;
                        return;
                    }
                    QString group = rest.left(firstComma);
                    QString item = rest.mid(firstComma + 1, secondComma - firstComma - 1);
                    QString valueStr = rest.mid(secondComma + 1);
                    bool ok = false;
                    double value = valueStr.toDouble(&ok);
                    if (!ok) {
                        qWarning() << "setControlValue: invalid value:" << valueStr;
                        return;
                    }
                    ConfigKey key(group, item);
                    if (!ControlObject::exists(key)) {
                        qWarning() << "setControlValue: ControlObject does not "
                                      "exist:"
                                   << group << item;
                        return;
                    }
                    ControlObject::set(key, value);
                    qDebug() << "setControlValue:" << group << item << "=" << value;
                } else if (command == "getConfigValue") {
                    QString rest = QString::fromStdString(payload);
                    int comma = rest.indexOf(',');
                    if (comma < 0) {
                        qWarning() << "getConfigValue: invalid payload, expected "
                                      "'group,key', got:"
                                   << rest;
                        return;
                    }
                    QString group = rest.left(comma);
                    QString key = rest.mid(comma + 1);

                    QString value = pCoreServices->getSettings()->getValueString(
                            ConfigKey(group, key));

                    qDebug() << "getConfigValue:" << group << key << "=" << value;

                    auto windows = QGuiApplication::topLevelWindows();
                    for (auto* w : std::as_const(windows)) {
                        w->setProperty("lastConfigValue", value);
                    }
                } else if (command == "setConfigValue") {
                    QString rest = QString::fromStdString(payload);
                    int firstComma = rest.indexOf(',');
                    if (firstComma < 0) {
                        qWarning() << "setConfigValue: invalid payload, expected "
                                      "'group,key,value', got:"
                                   << rest;
                        return;
                    }
                    int secondComma = rest.indexOf(',', firstComma + 1);
                    if (secondComma < 0) {
                        qWarning() << "setConfigValue: invalid payload, expected "
                                      "'group,key,value', got:"
                                   << rest;
                        return;
                    }
                    QString group = rest.left(firstComma);
                    QString key = rest.mid(firstComma + 1, secondComma - firstComma - 1);
                    QString valueStr = rest.mid(secondComma + 1);
                    pCoreServices->getSettings()->setValue(ConfigKey(group, key), valueStr);
                    qDebug() << "setConfigValue:" << group << key << "=" << valueStr;
                } else if (command == "loadTrack") {
                    QString rest = QString::fromStdString(payload);
                    int comma = rest.indexOf(',');
                    if (comma < 0) {
                        qWarning() << "loadTrack: invalid payload, expected "
                                      "'deck,filepath', got:"
                                   << rest;
                        return;
                    }
                    int deck = rest.left(comma).toInt();
                    QString filePath = rest.mid(comma + 1);
                    QString group = QString("[Channel%1]").arg(deck);
                    pPlayerManager->slotLoadLocationToPlayer(filePath, group, false);
                    qDebug() << "loadTrack: loaded" << filePath << "into" << group;
                } else if (command == "library") {
                    QJsonDocument doc =
                            QJsonDocument::fromJson(
                                    QByteArray::fromStdString(payload));
                    QJsonObject obj = doc.object();
                    QString action = obj["action"].toString();

                    if (action == "addDirectory") {
                        QString path = obj["path"].toString();
                        bool scan = obj["scan"].toBool(false);
                        auto result = pCoreServices->getTrackCollectionManager()
                                              ->addDirectory(mixxx::FileInfo(path));
                        if (result == DirectoryDAO::AddResult::AlreadyWatching) {
                            qDebug() << "library: directory already watched:" << path;
                        } else if (result != DirectoryDAO::AddResult::Ok) {
                            qWarning() << "library addDirectory failed:"
                                       << static_cast<int>(result);
                            return;
                        }
                        if (scan) {
                            pTrackCollectionManager->startLibraryScan();
                        }
                        qDebug() << "library: added directory" << path
                                 << "scan=" << scan;
                    } else if (action == "removeDirectory") {
                        QString path = obj["path"].toString();
                        bool scan = obj["scan"].toBool(false);
                        auto result = pCoreServices->getTrackCollectionManager()
                                              ->removeDirectory(mixxx::FileInfo(path));
                        if (result != DirectoryDAO::RemoveResult::Ok) {
                            qWarning() << "library removeDirectory failed:"
                                       << static_cast<int>(result);
                            return;
                        }
                        if (scan) {
                            pTrackCollectionManager->startLibraryScan();
                        }
                        qDebug() << "library: removed directory" << path
                                 << "scan=" << scan;
                    } else if (action == "deleteFeatureItem") {
                        QJsonObject state;
                        state["result"] = "failed";

                        qDebug() << "deleteFeatureItem" << obj;
                        QString type = obj["type"].toString();
                        QString id = obj["id"].toString();

                        auto pCollection =
                                pCoreServices->getTrackCollectionManager();

                        if (type == "playlist") {
                            auto& paylistsDao = pCollection->internalCollection()->getPlaylistDAO();
                            paylistsDao.deletePlaylist(id.toInt());
                            state["result"] = "success";
                        } else if (type == "crate") {
                            if (pCollection->internalCollection()->deleteCrate(CrateId(id))) {
                                state["result"] = "success";
                            }
                        }

                        persistLibraryJsonState(state);
                    } else if (action == "createFeatureItem") {
                        QJsonObject state;
                        state["result"] = "failed";

                        QString type = obj["type"].toString();
                        QString name = obj["name"].toString();
                        int random_track_count = obj["random_track_count"].toInt(0);
                        auto pCollection =
                                pCoreServices->getTrackCollectionManager();

                        if (type == "playlist") {
                            auto& paylistsDao = pCollection->internalCollection()->getPlaylistDAO();
                            int playlistId = paylistsDao.createPlaylist(name);
                            if (random_track_count > 0) {
                                auto& trackDao = pCollection->internalCollection()->getTrackDAO();
                                auto allTracks = trackDao.getAllExistingTrackLocations().values();
                                while (!allTracks.isEmpty() && random_track_count > 0) {
                                    auto trackLocation = allTracks.at(
                                            std::rand() % allTracks.size());
                                    auto track = pCollection->getTrackByRef(
                                            TrackRef::fromFilePath(
                                                    trackLocation));
                                    paylistsDao.appendTrackToPlaylist(track->getId(), playlistId);
                                    random_track_count--;
                                }
                            }
                            state["result"] = "success";
                            state["id"] = QString::number(playlistId);
                        } else if (type == "crate") {
                            Crate newCrate;
                            newCrate.setName(std::move(name));
                            CrateId newCrateId;
                            if (pCollection->internalCollection()->insertCrate(
                                        newCrate, &newCrateId) &&
                                    newCrateId.isValid()) {
                                DEBUG_ASSERT(newCrateId.isValid());
                                newCrate.setId(newCrateId);
                                state["result"] = "success";
                                state["id"] = newCrateId.toString();
                                qDebug() << "Created new crate" << newCrate;
                            } else {
                                DEBUG_ASSERT(!newCrateId.isValid());
                                qWarning() << "Failed to create new crate"
                                           << "->" << newCrate.getName();
                            }

                            if (newCrateId.isValid() && random_track_count > 0) {
                                auto& trackDao = pCollection->internalCollection()->getTrackDAO();
                                auto allTracks = trackDao.getAllExistingTrackLocations().values();
                                QList<TrackId> tracksToAdd = {};
                                while (!allTracks.isEmpty() && random_track_count > 0) {
                                    auto trackLocation = allTracks.at(
                                            std::rand() % allTracks.size());
                                    auto track = pCollection->getTrackByRef(
                                            TrackRef::fromFilePath(
                                                    trackLocation));
                                    tracksToAdd.push_back(track->getId());
                                    random_track_count--;
                                }
                                pCollection->internalCollection()
                                        ->addCrateTracks(
                                                newCrateId, tracksToAdd);
                            }
                        }

                        persistLibraryJsonState(state);
                    } else {
                        qWarning() << "library: unknown action" << action;
                    }
                } else if (command == "getLibraryState") {
                    auto* pCollection =
                            pCoreServices->getTrackCollectionManager()->internalCollection();

                    QJsonArray sources, playlists, crates;
                    const auto rootDirectories = pCollection->getRootDirectories();
                    for (const auto& dirInfo : rootDirectories) {
                        QJsonObject source;
                        source["path"] = dirInfo.path;
                        source["trackCount"] = static_cast<int>(dirInfo.trackCount);
                        source["totalSecond"] = static_cast<int>(dirInfo.totalSecond);
                        sources.append(source);
                    }
                    auto& paylistsDao = pCollection->getPlaylistDAO();
                    auto playlistsList = paylistsDao.getPlaylists(PlaylistDAO::PLHT_NOT_HIDDEN);
                    for (const auto& [id, name] : std::as_const(playlistsList)) {
                        QJsonObject paylist;
                        paylist["id"] = QString::number(id);
                        paylist["name"] = name;
                        playlists.append(paylist);
                    }
                    const auto& cratesDao = pCollection->crates();
                    CrateSummarySelectResult crateSummaries(
                            cratesDao.selectCrateSummaries());
                    CrateSummary crateSummary;
                    while (crateSummaries.populateNext(&crateSummary)) {
                        QJsonObject crate;
                        crate["id"] = crateSummary.getId().toString();
                        crate["name"] = crateSummary.getName();
                        crates.append(crate);
                    }

                    auto countTracks = [pCollection](bool hidden) {
                        QSqlQuery query(pCollection->database());
                        query.prepare(
                                "SELECT COUNT(*) FROM library WHERE mixxx_deleted = :hidden");
                        query.bindValue(":hidden", hidden ? 1 : 0);
                        query.exec();
                        return query.next() ? query.value(0).toInt() : 0;
                    };

                    QJsonObject state;
                    state["sources"] = sources;
                    state["playlists"] = playlists;
                    state["crates"] = crates;
                    state["visibleTrackCount"] = countTracks(false);
                    state["hiddenTrackCount"] = countTracks(true);
                    state["scanInProgress"] = pActiveScanCount->load() > 0;
                    state["scanGeneration"] = pCompletedScanCount->load();

                    persistLibraryJsonState(state);
                } else if (command == "registerMockDevices") {
                    QJsonDocument doc =
                            QJsonDocument::fromJson(
                                    QByteArray::fromStdString(payload));
                    QJsonObject obj = doc.object();
                    QJsonArray devices = obj["devices"].toArray();
                    pCoreServices->getSoundManager()->registerMockDevices(devices);
                    qDebug() << "registerMockDevices: injected"
                             << devices.size() << "devices";
                } else if (command == "clearMockDevices") {
                    pCoreServices->getSoundManager()->clearMockDevices();
                    auto config = pCoreServices->getSoundManager()->getConfig();
                    config.clearOutputs();
                    config.clearInputs();
                    pCoreServices->getSoundManager()->setConfig(config);
                    qDebug() << "clearMockDevices: cleared";
                } else if (command == "reloadQml") {
                    pQmlApplication->loadQml(pQmlApplication->mainFilePath());
                    qDebug() << "reloadQml: QML engine reloaded";
                } else {
                    qWarning() << "Unknown generic command:" << QString::fromStdString(command);
                }
            });

    m_pBot->runTestServer(m_server);
}

void RpcServe::onQmlLoaded() {
    auto rootObjects = m_pQmlApplication->qmlEngine()->rootObjects();
    for (auto* root : std::as_const(rootObjects)) {
        if (auto* window = qobject_cast<QQuickWindow*>(root)) {
            if (window->objectName().isEmpty()) {
                window->setObjectName(root->objectName());
            }
        }
    }
}

RpcServe::~RpcServe() = default;

} // namespace qml
} // namespace mixxx
