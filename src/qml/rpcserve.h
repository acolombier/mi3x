#ifdef __RPC_SERVER__

#pragma once

#include <Spix/AnyRpcServer.h>
#include <Spix/QtQmlBot.h>

#include <memory>

#include "coreservices.h"

namespace mixxx {
namespace qml {

class QmlApplication;

/// Automation server (spix XML-RPC on port 9000) hosted by the main
/// QmlApplication, enabled by the '--serve' command line flag. Used to drive
/// the E2E (QML UI) tests against any installed Mixxx.
class RpcServe {
  public:
    RpcServe(
            QmlApplication* pQmlApplication,
            std::shared_ptr<CoreServices> pCoreServices);
    ~RpcServe();

    /// (Re)name the root objects of the current QML engine after a fresh
    /// (re)load. Called by QmlApplication for the initial load and on every
    /// QML auto-reload.
    void onQmlLoaded();

  private:
    QmlApplication* m_pQmlApplication;
    spix::AnyRpcServer m_server;
    std::unique_ptr<spix::QtQmlBot> m_pBot;
};

} // namespace qml
} // namespace mixxx

#endif
