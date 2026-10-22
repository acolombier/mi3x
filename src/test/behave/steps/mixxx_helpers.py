"""Shared step-facing helpers used by all step modules.

Complements spix_helpers.py: helpers here take ``context`` and extract the
``rpc`` connection themselves, so step code never threads an rpc
through. Helpers reaching for state raise AssertionError on "condition not
met"; polled primitives stay value-returning in spix_helpers.
"""

import json
import time

from spix_helpers import (
    QT_LEFT_BUTTON,
    QT_RIGHT_BUTTON,
    click as _click_impl,
    get_control_value as _get_control_value_impl,
    is_visible as _is_visible_impl,
    wait_clickable as _wait_clickable_impl,
    wait_hidden as _wait_hidden_impl,
    wait_visible as _wait_visible_impl,
)

DECK_PATHS = {deck: f"mainWindow/deck{deck}" for deck in range(1, 5)}

DECK_GROUPS = {deck: f"[Channel{deck}]" for deck in range(1, 5)}


# --- Mouse helpers ---

def _click(context, path):
    _click_impl(context.rpc, path)


def _double_click(context, path):
    _click(context, path)
    time.sleep(0.2)
    _click(context, path)


def _right_click(context, path):
    rpc = context.rpc
    assert rpc.existsAndVisible(path), (
        f"{path} cannot be clicked as it does not exists")
    # Use a short hold rather than a plain click so the synthetic press is
    # fully delivered before the release, which makes Qt's TapHandler
    # recognise the right-button tap even under load.
    rpc.mouseClickAndHold(path, QT_RIGHT_BUTTON, 0, 250)


def _long_press(context, path, button=QT_LEFT_BUTTON, hold_ms=1000):
    context.rpc.mouseClickAndHold(path, button, 0, hold_ms)


# --- Visibility ---

def _wait_for_visible(context, path, timeout=15):
    if not _wait_visible_impl(context.rpc, path, timeout):
        raise AssertionError(f"Timed out waiting for '{path}' to be visible/opened")


def _wait_for_hidden(context, path, timeout=15):
    if not _wait_hidden_impl(context.rpc, path, timeout):
        raise AssertionError(f"Timed out waiting for '{path}' to be hidden")


def _wait_for_clickable(context, path, timeout=5):
    if not _wait_clickable_impl(context.rpc, path, timeout):
        raise AssertionError(f"Timed out waiting for '{path}' to be clickable")


def _is_visible(context, path):
    return _is_visible_impl(context.rpc, path)


def _get_bb(context, path):
    bb = context.rpc.getBoundingBox(path)
    if isinstance(bb, (list, tuple)):
        return {"x": bb[0], "y": bb[1], "width": bb[2], "height": bb[3]}
    return bb


# --- Deck path resolution ---

def _deck_hotcue_path(deck, hotcue_number):
    return f"{_deck_path(deck)}/hotcue_{hotcue_number}"


def _deck_path(deck):
    return DECK_PATHS.get(deck, f"mainWindow/deck{deck}")


def _deck_group(deck):
    return DECK_GROUPS.get(deck, f"[Channel{deck}]")


# --- Property/ControlObject access ---

def _get_property(context, path, prop):
    return context.rpc.getStringProperty(path, prop)


def _set_property(context, path, prop, value):
    context.rpc.setStringProperty(path, prop, str(value))


def _get_control_value(context, group, key):
    return _get_control_value_impl(context.rpc, group, key)


def _set_control_value(context, group, key, value):
    context.rpc.command("setControlValue", f"{group},{key},{value}")


def _set_hotcue_label(context, group, hotcue, label):
    context.rpc.command(
        "setHotcueLabel",
        json.dumps({"group": group, "hotcueNumber": hotcue, "label": label}))


# --- Remember store ---

def _remember(context, key, value):
    if not hasattr(context, "_remembered"):
        context._remembered = {}
    context._remembered[key] = value


def _remembered_value(context, key):
    remembered = getattr(context, "_remembered", {})
    assert key in remembered, (
        f"Nothing was remembered under {key!r} (forgot the remember step?)")
    return remembered[key]


# --- Library state/scan ---

def _get_library_state(context, timeout=5):
    """Read the library state JSON via the command/property pair.

    On a cold start the window property can briefly come back empty even
    though the command handler already ran, so re-issue the pair until the
    JSON parses (bounded; a missing state is a harness bug).
    """
    deadline = time.time() + timeout
    rpc = context.rpc
    while True:
        rpc.command("getLibraryState", "")
        raw = rpc.getStringProperty("mainWindow", "lastLibraryState")
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            if time.time() >= deadline:
                raise AssertionError(
                    f"The library state did not become readable (got {raw!r})")
            time.sleep(0.2)


def _wait_for_library_scan(context, scan_generation, timeout=20):
    """Wait for a library scan after ``scan_generation`` to finish.

    The ``library`` command starts the scan asynchronously and returns
    immediately (running a nested event loop while the library models are
    mutated crashes the QML delegate model), so tests poll the
    ``scanGeneration`` counter exposed by ``getLibraryState``.
    """
    deadline = time.time() + timeout
    last_state = None
    while time.time() < deadline:
        try:
            last_state = _get_library_state(context)
            if (last_state.get("scanGeneration", 0) > scan_generation and
                    not last_state.get("scanInProgress", False)):
                return
        except Exception as e:
            last_state = e
        time.sleep(0.2)
    raise AssertionError(
        f"Timed out waiting for the library scan to finish "
        f"(last state: {last_state})"
    )


def _library_command(context, action=None, path=None, scan=False, payload=None):
    if payload is None:
        payload = {"action": action, "path": path, "scan": scan}
    payload = json.dumps(payload)
    scan_generation = None
    if scan:
        scan_generation = _get_library_state(context).get("scanGeneration", 0)
    context.rpc.command("library", payload)
    if scan:
        _wait_for_library_scan(context, scan_generation)
