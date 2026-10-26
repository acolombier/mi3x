import http.client
import json
import os
import time
import socket
import xmlrpc.client
from helpers import (
    _click,
    _get_property,
    _is_visible,
    _library_command,
    _set_property,
    _wait_for_hidden,
    _wait_for_visible,
    remember_track,
    scenario_rng,
)
from behave import given, when, then
import mixxx_profile as profile
_RPC_ERRORS = (
    xmlrpc.client.Fault,
    ConnectionRefusedError,
    socket.timeout,
    TimeoutError,
    OSError,
    EOFError,
    BrokenPipeError,
)

# --- RPC helpers ---

class _TimeoutTransport(xmlrpc.client.Transport):
    """Transport that sets a per-connection timeout instead of global socket timeout."""

    def __init__(self, timeout=15, **kwargs):
        super().__init__(**kwargs)
        self._timeout = timeout

    def make_connection(self, host):
        if self._connection and host == self._connection[0]:
            return self._connection[1]
        chost, self._extra_headers, x509 = self.get_host_info(host)
        conn = http.client.HTTPConnection(chost, timeout=self._timeout)
        self._connection = host, conn
        return conn


class RobustRpcProxy:
    """XML-RPC proxy with connection recovery.

    Read-only methods are safe to retry: ladder is retry with the same
    proxy, then reconnect (fresh proxy), then retry once more.

    Everything else (mouseClick, command, enterKey, inputText, invokeMethod,
    setStringProperty, quit, ...) is stateful: a timed-out call may already
    have been executed server-side, so blindly retrying it could duplicate
    the action (a double click, a directory added twice, ...). Those calls
    are attempted exactly once; on a transport error the proxy is recreated
    so that the *next* call gets a fresh connection, and the error is raised
    immediately. The sanctioned retry layer for stateful actions is the
    step-level polling helpers (they verify state and re-issue an action
    only when it did not take effect) and the scenario autoretry.
    """

    URL = "http://localhost:9000/"

    READ_ONLY_METHODS = frozenset({
        "getStringProperty",
        "getBoundingBox",
        "existsAndVisible",
        "getErrors",
    })

    def __init__(self):
        self._proxy = self._make_proxy()

    @staticmethod
    def _make_proxy():
        transport = _TimeoutTransport(timeout=15)
        return xmlrpc.client.ServerProxy(
            RobustRpcProxy.URL, transport=transport, allow_none=True
        )

    def __getattr__(self, name):
        def wrapped(*args, **kwargs):
            if name in self.READ_ONLY_METHODS:
                return self._call_read_only(name, args, kwargs)
            return self._call_stateful(name, args, kwargs)
        return wrapped

    def _call_read_only(self, name, args, kwargs):
        # Level 1: retry with current proxy
        try:
            return getattr(self._proxy, name)(*args, **kwargs)
        except xmlrpc.client.Fault:
            # The server processed the read and answered with an error;
            # repeating it would fail the same way.
            raise
        except _RPC_ERRORS:
            pass
        time.sleep(0.5)
        # Level 2: reconnect (fresh proxy)
        self._proxy = self._make_proxy()
        try:
            return getattr(self._proxy, name)(*args, **kwargs)
        except _RPC_ERRORS as e:
            raise ConnectionError(
                f"RPC call {name}() failed after all recovery attempts"
            ) from e

    def _call_stateful(self, name, args, kwargs):
        try:
            return getattr(self._proxy, name)(*args, **kwargs)
        except xmlrpc.client.Fault:
            raise
        except _RPC_ERRORS as e:
            # Transport-level failure: the call may or may not have been
            # executed server-side. Refresh the proxy for subsequent calls,
            # but never re-run the failed call itself.
            self._proxy = self._make_proxy()
            raise ConnectionError(
                f"RPC call {name}() failed; not retried to avoid duplicating "
                f"a possibly executed action"
            ) from e

    def __repr__(self):
        return f"<RobustRpcProxy for {self.URL}>"


# --- Static path resolution ---

BUTTON_PATHS = {
    "LIBRARY": "mainWindow/maximizeLibraryButton",
    "4DECKS": "mainWindow/show4DecksButton",
    "EDIT": "mainWindow/editDeckButton",
    "PREFERENCES": "mainWindow/showPreferencesButton",
}


# --- View helpers ---


def _load_track(context, deck, filepath):
    context.rpc.command("loadTrack", f"{deck},{filepath}")


# --- Path resolution ---

def _button_path(name):
    return BUTTON_PATHS.get(name, f"mainWindow/{name.lower()}")


# --- Library search / split view paths ---


# --- Session helpers ---

def _mixxx_running(context):
    mixxx = getattr(context, "mixxx", None)
    if mixxx is None or mixxx.process is None or mixxx.process.poll():
        return False
    try:
        if hasattr(context, "rpc") and context.rpc:
            # Only checking this isn't an empty string or a False boolean
            return bool(_get_property(context, "mainWindow", "visible"))
    except Exception as e:
        print(f"Unable to probe RPC: {e}")
    return False


def _mixxx_process_alive(context):
    """True when a Mixxx process this session owns is still running, RPC or not.

    Unlike :func:`_mixxx_running` this deliberately ignores the RPC probe: an
    instance that is stuck starting up, or whose RPC server never came up, is
    exactly the one holding port 9000. Treating the failed RPC probe as "not
    running" used to let such instances leak, and every later fresh-profile
    spawn of the run then timed out against the port they held.
    """
    session = context._session
    for mixxx in (session.get("mixxx"), getattr(context, "mixxx", None)):
        if mixxx is not None and mixxx.process is not None and mixxx.process.poll() is None:
            return True
    return False


def _stop_mixxx(context):
    """Stop every Mixxx process this session owns, RPC-responsive or not.

    The session instance and ``context.mixxx`` can diverge after a failed
    ``start()`` (context then holds the never-ready process), so both are
    reaped. A graceful quit is attempted first when the RPC still answers;
    ``MixxxProcess.stop()`` escalates to SIGKILL, which reliably frees
    port 9000.
    """
    session = context._session
    quit_attempted = False
    for mixxx in (session.get("mixxx"), getattr(context, "mixxx", None)):
        if mixxx is None:
            continue
        if not quit_attempted and mixxx.process is not None and mixxx.process.poll() is None:
            quit_attempted = True
            try:
                rpc = getattr(context, "rpc", None)
                if rpc is not None:
                    rpc.quit()
                    time.sleep(1)
            except Exception:
                pass
        mixxx.stop()
    session["mixxx"] = None
    session["rpc"] = None
    session["ready_key"] = None
    session["registered_devices"] = None
    context.mixxx = None
    context.rpc = None


def _device_signature(context):
    devices = getattr(context, "_soundMockDevices", None)
    if not devices:
        return None
    return tuple(
        sorted(
            (
                d["name"],
                d.get("api", "Mock"),
                d.get("outputChannels", 0),
                d.get("inputChannels", 0),
            )
            for d in devices
        )
    )


def _mock_devices_key(devices):
    """Canonical form of a scenario's mock-device table, for change detection.

    ``None`` and ``[]`` both normalize to "no devices" so a device-less
    scenario compares equal to an instance with nothing registered.
    """
    return json.dumps(devices or [], sort_keys=True)


def _session_key(context):
    return (getattr(context, "profile_dir", None), _device_signature(context))


def _ensure_profile(context, profile_type, force=False):
    session = context._session
    if not force and session.get("active_profile_type") == profile_type and _mixxx_running(context):
        return
    if _mixxx_process_alive(context):
        # Reap whatever instance we still own before abandoning its profile.
        # An RPC-unresponsive instance must not be mistaken for "not
        # running": it holds port 9000, and leaving it alive makes the next
        # spawn time out and cascade through the rest of the run.
        _stop_mixxx(context)
    profile_dir = profile.make_temp_profile(
        profile_type,
        container=profile.macos_sandbox_container(
            context.config.userdata.get("binary")),
    )
    context.profile_dir = profile_dir
    context.active_profile_type = profile_type
    session["profile_dir"] = profile_dir
    session["active_profile_type"] = profile_type
    session["profile_dirs"].append(profile_dir)

@given("a {profile_type} profile")
def step_new_empty_profile(context, profile_type):
    # The Gherkin text is "a fresh new empty profile", so {profile_type} binds
    # to "fresh new empty" -- the leading "a " belongs to the pattern, not the
    # capture. Testing for "a fresh" here could therefore never match, which
    # silently disabled the fresh-profile opt-out and made every scenario
    # reuse the first scenario's profile and library.
    _ensure_profile(
        context,
        profile_type.split(" ")[-1],
        force=profile_type.startswith("fresh"),
    )


@given("Mixxx is open and ready to operate")
def step_open_and_ready(context):
    session = context._session
    if session.get("ready_key") == _session_key(context) and _mixxx_running(context):
        context.default_size = session.get("default_size", (None, None))
        return

    tracks_dir = context.config.userdata["tracks_dir"]
    if not _mixxx_running(context):
        if _mixxx_process_alive(context):
            # A live instance whose RPC probe failed (stuck startup, hung
            # RPC) is the one holding port 9000; reap it before spawning a
            # replacement or the replacement's start() will time out.
            _stop_mixxx(context)
        binary = context.config.userdata["binary"]
        flatpak_package = context.config.userdata.get("flatpak_package")
        if "profile_dir" not in context:
            _ensure_profile(context, "empty")
        context.mixxx = profile.MixxxProcess(
            binary,
            context.profile_dir,
            output_dir=context.config.userdata.get("mixxx_output_dir"),
            flatpak_package=flatpak_package,
        )
        context.mixxx.start()
        context.rpc = RobustRpcProxy()
        session["mixxx"] = context.mixxx
        session["rpc"] = context.rpc
        # A fresh instance has no mock devices registered; the sync below
        # must know that to avoid a pointless reload on device-less spawns.
        session["registered_devices"] = _mock_devices_key(None)
        # Initial window may be slow to show on CI runners
        _wait_for_visible(context, "mainWindow", timeout=15)
        if context.active_profile_type == "library-ready":
            _library_command(context, "addDirectory", tracks_dir, scan=True)

    # Sync the mock devices with the scenario's device table. Registering or
    # clearing devices forces a reloadQml (full QML rebuild) because the
    # sound pages cache the device list and do not always pick up device
    # changes on their own — even on a freshly spawned instance. That cost
    # is only justified when the requested device set actually differs from
    # what the running instance already has registered; same-devices
    # scenarios reuse the instance untouched.
    desired_devices = _mock_devices_key(getattr(context, "_soundMockDevices", None))
    if session.get("registered_devices") != desired_devices:
        context.rpc.command("clearMockDevices", "")
        if getattr(context, "_soundMockDevices", None):
            context.rpc.command(
                "registerMockDevices",
                json.dumps({"devices": context._soundMockDevices}),
            )
        context.rpc.command("reloadQml", "")
        session["registered_devices"] = desired_devices
    time.sleep(0.5)

    # First launch on Windows 10 CI runner is quite slow
    _wait_for_hidden(context, "mainWindow/splash", timeout=30)  # FIXME: First launch on Windows 10 CI runner is quite slow
    _set_property(context, "mainWindow", "enableDiagnosticClick", "true")
    # The system might constrain the size below or default one (e.g windows policy), so we keep track of what the system default are in order to reset between scenarios
    session["default_size"] = (_get_property(context, "mainWindow", "width"), _get_property(context, "mainWindow", "height"))
    context.default_size = session["default_size"]
    session["ready_key"] = _session_key(context)

# --- When: window/button steps ---

@given("the window's width is {width:d}px")
def step_window_width_is(context, width):
    step_resize_window_width(context, width)


@given("the window's height is {height:d}px")
def step_window_height_is(context, height):
    step_resize_window_height(context, height)


@given("the window size is default")
def step_window_size_default(context):
    default_width, default_height = context.default_size
    if default_width and _get_property(context, "mainWindow", "width") != default_width:
        _set_property(context, "mainWindow", "width", default_width)
    if default_height and _get_property(context, "mainWindow", "height") != default_height:
        _set_property(context, "mainWindow", "height", default_height)
    time.sleep(0.5)


@when("I resize the window's width to {width:d}px")
def step_resize_window_width(context, width):
    _set_property(context, "mainWindow", "width", width)
    time.sleep(0.5)


@when("I resize the window's height to {height:d}px")
def step_resize_window_height(context, height):
    _set_property(context, "mainWindow", "height", height)
    time.sleep(0.5)


@when('I check on the button "{button}" in the main toolbar')
def step_check_button(context, button):
    path = _button_path(button)
    assert _is_visible(context, path), f"Button {button} (path: {path}) not found or not visible"


@when('I click the "{button}" button')
def step_click_button(context, button):
    _click(context, _button_path(button))
    time.sleep(1)


@given("a track is loaded on deck {deck:d}")
def step_load_track_to_deck(context, deck):
    tracks_dir = context.config.userdata["tracks_dir"]
    track_files = sorted(os.listdir(tracks_dir))
    if not track_files:
        raise RuntimeError(f"No track files found in {tracks_dir}")
    idx = scenario_rng(context).randint(0, len(track_files) - 1)
    filepath = os.path.join(tracks_dir, track_files[idx])
    # Remember the loaded track as "deck N" with catalog metadata when the
    # file is known, so later steps can pin and assert on its tags.
    catalog = context.config.userdata.get("tracks_catalog") or []
    entry = next(
        (e for e in catalog if e.get("location") == filepath), None)
    if entry is None:
        entry = {"title": os.path.splitext(track_files[idx])[0],
                 "location": filepath}
    remember_track(context, entry, name=f"deck {deck}")
    _load_track(context, deck, filepath)
    time.sleep(3)

@given("I wait for {second:d} second")
@when("I wait for {second:d} second")
@then("I wait for {second:d} second")
def step_wait(context, second):
    time.sleep(second)

@then('the "{button}" button in the main toolbar should {assertion} visible')
def step_toolbar_button_visible(context, button, assertion):
    path = _button_path(button)
    if assertion == "be":
        _wait_for_visible(context, path)
    else:
        _wait_for_hidden(context, path)
