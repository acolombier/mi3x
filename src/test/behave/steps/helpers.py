"""Shared helpers for all step modules, in two conventions:

* RPC primitives (no underscore prefix): take the spix ``rpc`` proxy and
  return a plain value; they never raise for "condition not met" — callers
  decide whether that is an assertion failure (Then steps) or a
  keep-polling signal (retry loops). Having exactly one implementation of
  each primitive keeps the timeout/poll behavior identical across step
  modules.
* Context-based helpers (underscore prefix): take the behave ``context``
  and extract the ``rpc`` connection themselves, so step code never threads
  an rpc through. Helpers reaching for state raise AssertionError on
  "condition not met"; they are thin semantic layers over the primitives
  below, not re-implementations.

Wait defaults are 5 s (visible/hidden/clickable): a tight default is the
tradeoff between catching responsiveness regressions and E2E stability.
Call sites that need a longer horizon pass an explicit ``timeout=``.

Wait-site choice: use the context-based family (``_wait_for_*``) for the
common "wait, else raise with the generic message" case; call sites that
want a custom failure message use the non-raising primitive on
``context.rpc`` and assert on it themselves
(``assert wait_visible(context.rpc, path, timeout=10), "custom message"``).
"""


import random
import re
from typing import Optional

import dataclasses
import json
import time

QT_LEFT_BUTTON = 1
QT_RIGHT_BUTTON = 2
QT_CONTROL_MODIFIER = 2

QT_KEY_ENTER = 0x01000005
QT_KEY_SPACE = 0x20
QT_KEY_DOWN = 0x01000015
QT_KEY_UP = 0x01000013
QT_KEY_LEFT = 0x01000012
QT_KEY_TAB = 0x01000001
QT_KEY_A = 0x41
QT_KEY_DELETE = 0x01000007
QT_KEY_ESCAPE = 0x01000000

def _track_is_selected(context, path):
    try:
        return _get_property(context, path, "selected") == "true"
    except Exception:
        return False

@dataclasses.dataclass(frozen=True)
class RememberedTrack:
    """A tracks-catalog entry remembered by an earlier step under a name.

    Scenarios reference it as "this track" and must not depend on which tracks
    happen to be in the test profile or on their order. The catalog (persisted
    by the runner from ``load_track_manifest`` at download time) supplies both
    the track choice and its metadata, so no live-library introspection is
    needed. Later scenarios (crates, playlists, ...) can remember tracks under
    their own names through the same store.
    """
    title: str
    artist: str
    location: str
    bpm: Optional[float]
    first_beat: Optional[int]
    samplerate: Optional[float]
    tags: Optional[str]

    def __str__(self):
        return f"{repr(self.title)} - {repr(self.artist)} | {self.location}"

# Model of Mixxx.Config.paletteNames(), i.e. PredefinedColorPalettes::kPalettes
# order. Index in this list == currentIndex of the palette ComboBoxes.
PALETTE_NAMES = [
    "Mixxx Hotcue Colors",
    "Serato DJ Pro Hotcue Colors",
    "Rekordbox COLD1 Hotcue Colors",
    "Rekordbox COLD2 Hotcue Colors",
    "Rekordbox COLORFUL Hotcue Colors",
    "Mixxx Track Colors",
    "Rekordbox Track Colors",
    "Serato DJ Pro Track Colors",
    "Traktor Pro Track Colors",
    "VirtualDJ Track Colors",
    "Mixxx Key Colors",
    "Traktor Key Colors",
    "Mixed In Key - Key Colors",
    "Protanopia / Protanomaly Key Colors",
    "Deuteranopia / Deuteranomaly Key Colors",
    "Tritanopia / Tritanomaly Key Colors",
]


QT_KEY_BACKSPACE = 0x01000003

QT_KEY_F = 0x46

QT_KEY_LEFT = 0x01000012

QT_KEY_RIGHT = 0x01000014

ROUTER_MODE = "mainWindow/routerMode"


# --- RPC primitives (rpc-based, value-returning) -----------------------------

def is_visible(rpc, path):
    """True when the item exists, is visible, and has a non-degenerate box."""
    x, y, width, height = rpc.getBoundingBox(path)
    return rpc.existsAndVisible(path) and width * height > 0


def wait_visible(rpc, path, timeout=5):
    """Poll ``existsAndVisible`` until true or ``timeout`` seconds elapse."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if rpc.existsAndVisible(path):
                return True
        except Exception:
            pass
        time.sleep(0.3)
    return False


def wait_hidden(rpc, path, timeout=5):
    """Poll ``existsAndVisible`` until false or ``timeout`` seconds elapse."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if not rpc.existsAndVisible(path):
                return True
        except Exception:
            pass
        time.sleep(0.3)
    return False


def wait_clickable(rpc, path, timeout=5):
    """Wait until an item is visible with a non-degenerate bounding box.

    spix's ``existsAndVisible`` reports an item as visible as soon as its
    ``visible`` chain is true, before its layout has settled. A recycled
    delegate can briefly report a stale/zero-sized box, and clicking such a
    stale position silently misses (spix records "Item not found" without
    raising; see ``getErrors``). Only return true once the item has a real
    on-screen box.
    """
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if rpc.existsAndVisible(path):
                x, y, width, height = rpc.getBoundingBox(path)
                if x >= 0 and y >= 0 and width > 0 and height > 0:
                    return True
        except Exception:
            pass
        time.sleep(0.3)
    return False


def click(rpc, path):
    rpc.mouseClick(path)


def get_control_value(rpc, group, key):
    """Read a ControlObject via the custom ``getControlValue`` command."""
    rpc.command("getControlValue", f"{group},{key}")
    return float(rpc.getStringProperty("mainWindow", "lastControlValue"))


# --- Context-based helpers (behave ``context``, raising) ----------------------

DECK_PATHS = {deck: f"mainWindow/deck{deck}" for deck in range(1, 5)}

DECK_GROUPS = {deck: f"[Channel{deck}]" for deck in range(1, 5)}


# --- Mouse helpers ---

def _click(context, path):
    click(context.rpc, path)


def _double_click(context, path):
    _click(context, path)
    time.sleep(0.2)
    _click(context, path)


def _right_click(context, path):
    rpc = context.rpc
    assert rpc.existsAndVisible(path), (
        f"{path} cannot be clicked as it does not exists")
    rpc.mouseClickWithButton(path, QT_RIGHT_BUTTON, 0)


def _long_press(context, path, button=QT_LEFT_BUTTON, hold_ms=1000):
    context.rpc.mouseClickAndHold(path, button, 0, hold_ms)


# --- Visibility ---

def _wait_for_visible(context, path, timeout=5):
    if not wait_visible(context.rpc, path, timeout):
        raise AssertionError(f"Timed out waiting for '{path}' to be visible/opened")


def _wait_for_hidden(context, path, timeout=5):
    if not wait_hidden(context.rpc, path, timeout):
        raise AssertionError(f"Timed out waiting for '{path}' to be hidden")


def _wait_for_clickable(context, path, timeout=5):
    if not wait_clickable(context.rpc, path, timeout):
        raise AssertionError(f"Timed out waiting for '{path}' to be clickable")


def _is_visible(context, path):
    return is_visible(context.rpc, path)


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
    return get_control_value(context.rpc, group, key)


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


# --- Library settings paths/expectations (shared by settings_steps and browse_steps) ---

MUSIC_DIRECTORY_LIST = "mainWindow/librarySourceList"

def _expectation_matches(actual, expectation):
    op, num = expectation["op"], expectation["num"]
    if op == "=":
        return actual == num
    if op == "!=":
        return actual != num
    if op == ">":
        return actual > num
    if op == ">=":
        return actual >= num
    if op == "<":
        return actual < num
    if op == "<=":
        return actual <= num
    return False


# --- Shared step machinery donated by the step modules ---------
# (used by more than one feature module; see docs/e2e-matrix-reorg-kickoff.md)


# --- from settings_steps.py (used by multiple feature modules) ---

def _click_active_button(context, button):
    path = _active_button(context, button)
    assert _is_visible(context, path), f"{button.title()} ({path}) button not visible"
    _click(context, path)
    time.sleep(0.5)

def _active_button(context, button):
    # The save/cancel/reset buttons are per-category, so the target of a
    # bare "I click the save button" is whatever category the popup has
    # active at that moment. Scenarios must select their category first
    # (the feature Backgrounds do) for this resolution to be unambiguous.
    active_category_idx = _get_property(context, SETTINGS_POPUP_ITEM, "activeCategoryIndex")
    assert active_category_idx != "", "Cannot resolve the currently active category"
    active_category_slug = SETTING_CATEGORY_SLUG[int(active_category_idx)]
    if active_category_slug in TREE_NAMESPACED_PAGES:
        return "%s/%sPage/%s" % (SETTINGS_POPUP_ITEM, active_category_slug, button)
    return ACTION_BUTTON_TEMPLATE % (active_category_slug, button.title())

ACTION_BUTTON_TEMPLATE = "mainWindow/%s%sButton"

# Categories whose page was moved onto object-namespaced paths
# ("mainWindow/settingsPopupItem/<slug>Page/...") already resolve their controls
# through the settings popup tree; all other categories keep their flat
# "mainWindow/<name>" object names.
TREE_NAMESPACED_PAGES = ["analyzer"]

# Slug ("sound", "library", ...) per active category index in the settings
# popup (see res/qml/Settings.qml;Analyzer is index 8). Categories without an
# implemented save/cancel/reset footer are not listed.
SETTING_CATEGORY_SLUG = {
    0: "sound",
    1: "library",
    2: "controller",
    3: "interface",
    8: "analyzer",
}

SETTINGS_POPUP_ITEM = "mainWindow/settingsPopupItem"

COMMITTING_OVERLAY = "mainWindow/committingOverlay"

ENGINE_SECTION = "mainWindow/engineSection"

DELAYS_SECTION = "mainWindow/delaysSection"

ROUTER_SECTION = "mainWindow/routerSection"

INPUT_COLUMN = "mainWindow/inputColumn"

OUTPUT_COLUMN = "mainWindow/outputColumn"

# Waveform tab live-feedback paths. The "waveformSettingsTab" SettingGroup
# exposes the derived values the settings' own preview renderers consume
# ("waveformPreview" reacts to the controls immediately); the deck waveforms
# in res/qml/WaveformDisplay.qml expose the same config-derived values.
WAVEFORM_PREVIEW_PATH = "mainWindow/waveformPreview"

COLOR_PICKER_TEST_PATH = "mainWindow/colorPickerTest"

# Bands for the visual gain color parameters (QmlConfigProxy keys), shared by
# the settings preview waveformsTab properties ("globalGain") and the deck
# WaveformDisplay properties ("gainAll").
GAIN_BAND_MAP = {
    "global": {"preview": "gainAll", "settings": "globalGain", "deck": "gainAll"},
    "low": {"preview": "gainLow", "settings": "lowGain", "deck": "gainLow"},
    "middle": {"preview": "gainMid", "settings": "middleGain", "deck": "gainMid"},
    "high": {"preview": "gainHigh", "settings": "highGain", "deck": "gainHigh"},
}

COLOR_BAND_MAP = {"all": 0, "low": 0, "mid": 1, "high": 2}

WAVEFORM_OPTION_BITS = {"stereo split": 1, "high details": 2}

def _entity_path(name):
    return f"mainWindow/entity_{name.replace('/', '')}"

def _edge_path(entity, address, channel=0):
    return f"mainWindow/entity_{entity}/edge_{address}{channel}"

def _setting_spec(setting):
    spec = SETTING_MAP.get(setting)
    if not spec:
        raise ValueError(f"Unknown setting: {setting}")
    return spec

def _deck_waveform_path(deck):
    return f"mainWindow/waveformDisplay_Channel{deck}"

def _read_float_property(context, path, prop):
    value = _get_property(context, path, prop)
    try:
        return float(value)
    except (TypeError, ValueError) as e:
        raise AssertionError(
            f"Expected a numeric '{prop}' on '{path}' but read '{value}' ({e})"
        )

def _waveform_color_props(context, band, color):
    assert band in COLOR_BAND_MAP, f"Unknown waveform color '{band}'"
    actual = _get_property(context, WAVEFORM_PREVIEW_PATH, "colorCode" if band == "all" else f"{band}ColorCode")
    assert actual.lower() == color.lower(), (
        f"The '{band}' waveform color should be '{color}' but is '{actual}'"
    )

def _assert_deck_until_mark(context, prop, deck, expected, description):
    actual = _get_property(context, _deck_waveform_path(deck), prop)
    assert actual == str(expected).lower(), (
        f"The until-marker hint on deck {deck} should "
        f"{'show' if expected else 'not show'} {description} "
        f"but '{prop}' is '{actual}'"
    )

def _get_router_mode(context):
    try:
        return _get_property(context, ROUTER_MODE, "selected")
    except Exception:
        return None

# routerMode RatioChoice options: ["simple", "advanced"|"advanced (!)", "legacy"]
# (AudioRouter.qml); multiSoundcard: ["experimental", "default", "disabled"].
# Index-based option objectNames replaced the former modelData objectNames.
_ROUTER_MODE_OPTION_INDEX = {"simple": 0, "advanced": 1, "advanced (!)": 1, "legacy": 2}

_MULTI_SOUNDCARD_OPTION_INDEX = {"experimental": 0, "default": 1, "disabled": 2}

def _set_router_mode(context, mode):
    index = _ROUTER_MODE_OPTION_INDEX.get(mode)
    if index is None:
        raise ValueError(f"Unknown router mode option '{mode}'")
    path = f"{ROUTER_MODE}/option{index}"
    assert wait_visible(context.rpc, path), f"Router mode option '{mode}' not visible"
    _click(context, path)
    time.sleep(0.5)

def _find_first_free_output_edge(context):
    return _find_first_output_edge(context, only_not_connected=True)


# --- from mixxx_steps.py (used by multiple feature modules) ---

LIBRARY_CONTENT = "mainWindow/libraryContent"

LIBRARY_TREEVIEW_PATH = f"{LIBRARY_CONTENT}/featureTree"

LIBRARY_TREEVIEW_CREATE_POPUP = f"mainWindow/createFeaturePopup"

TRACKLIST_PATH = f"{LIBRARY_CONTENT}/trackList"

COLUMN_HEADER_PATH = f"{TRACKLIST_PATH}/columnHeader"

COLUMN_PICKER_MENU_PATH = "mainWindow/columnPickerMenu"

TRACK_TABLE_PATH = f"{TRACKLIST_PATH}/trackTableView"

TRACK_CONTEXT_MENU_PATH = "mainWindow/trackContextMenu"

def _is_column_visible(context, col, stabilize_duration=1):
    # Letting time for UI to stabilize
    time.sleep(stabilize_duration)
    index = _column_index(context, col)
    if index < 0:
        return False
    columnWidth = float(context.rpc.invokeMethod(TRACK_TABLE_PATH, "columnWidth", [index]) or 0)
    return columnWidth > 0

def _track_row_is_on_screen(context, row):
    """True when ``row`` is inside the visible TableView viewport.

    Reliable against delegate recycling: derived from the flickable geometry
    rather than a specific delegate instance (whose ``isVisible()`` is flaky
    for table cells).
    """
    y = float(_get_property(context, TRACK_TABLE_PATH, "contentY"))
    height = float(_get_property(context, TRACK_TABLE_PATH, "contentHeight"))
    viewport = float(_get_property(context, TRACK_TABLE_PATH, "height")) or 0
    if viewport <= 0:
        return False
    if height <= viewport:
        return True
    target = row * _ROW_HEIGHT
    return y <= target and y + viewport >= target + _ROW_HEIGHT

def _last_track_row(context, timeout=5):
    """Index of the last row in the track table, derived from its content height.

    Keeps the "below the fold" scenario independent of the number of tracks
    that happen to be in the database.
    """
    deadline = time.time() + timeout
    while time.time() < deadline:
        height = float(_get_property(context, TRACK_TABLE_PATH, "contentHeight"))
        row = int(height // _ROW_HEIGHT) - 1
        if row >= 0:
            return row
        time.sleep(0.3)
    raise AssertionError("The track table has no rows")

def _find_sidebar_named_entity_path(context, entity, name, expand_if_needed=False):
    assert _is_visible(context, LIBRARY_TREEVIEW_PATH), "The library sidebar is not visible"
    rows = int(_get_property(context, LIBRARY_TREEVIEW_PATH, "rows"))
    in_section = False
    row = 0
    while row < rows:
        path = f"{LIBRARY_TREEVIEW_PATH}/index{row}"
        depth = int(context.rpc.invokeMethod(LIBRARY_TREEVIEW_PATH, "depth", [row]))
        label = _get_property(context, f"{path}/labelItem", "text")
        row += 1

        if not in_section:
            in_section = label.startswith(entity.title())
            if not in_section:
                continue
            is_expanded = _get_property(context, path, "expanded") == "true"
            if is_expanded or not expand_if_needed:
                continue
            _wait_for_visible(context, path)
            _click(context, path)
            time.sleep(0.3)
            rows = int(_get_property(context, LIBRARY_TREEVIEW_PATH, "rows"))
            continue
        if not depth:
            # Reached the end of the entity section
            break
        if label.startswith(f"{name} ("):
            return path
    assert in_section, f"Could not find the section for {entity} in the sidebar"

def _column_header_path(column):
    return f"{COLUMN_HEADER_PATH}/{column}"

def _column_index(context, column):
    """Return the model column index for a display label, or -1 if unknown.

    Resolved from the column model rather than the header delegate, because a
    hidden column has no header delegate to read ``index`` from.
    """
    raw = _get_property(context, TRACKLIST_PATH, "columnLabels")
    if not raw:
        return -1
    try:
        return json.loads(raw).index(column)
    except (ValueError, json.JSONDecodeError):
        return -1

def _track_row_path(row, panel="left"):
    return (RIGHT_TRACKLIST_TABLE_PATH if panel == "right" else TRACK_TABLE_PATH) + f"/trackRow_{row}"

def _sidebar_feature_row_path(context, feature):
    assert _is_visible(context, LIBRARY_TREEVIEW_PATH), "The library sidebar is not visible"
    rows = int(_get_property(context, LIBRARY_TREEVIEW_PATH, "rows"))
    for row in range(rows):
        path = f"{LIBRARY_TREEVIEW_PATH}/index{row}"
        label = _get_property(context, f"{path}/labelItem", "text")
        if label == feature:
            return path
    return None

DECK_PATH_MAP = {f"[Channel{deck}]": f"mainWindow/deck{deck}" for deck in range(1, 5)}

DECK_PROPERTY_MAP = {
    "BPM": "bpm",
    "tempo rate": "rate",
}

LOOP_BUTTONS = {
    ("halve", "beatloop"): "loop_halve",
    ("double", "beatloop"): "loop_double",
}

REMEMBERED_CO_KEYS = {
    "beatloop size": "beatloop_size",
    "rate range": "rateRange",
    "playback position": "playposition",
}

def _deck_button_path(deck, button):
    suffix = DECK_BUTTON_PATHS.get(button, button)
    return f"{_deck_path(deck)}/{suffix}"

KNOWN_COLUMNS = [
    "", "Preview", "Title", "Artist", "Album", "AlbumArtist", "Year",
    "Genre", "Composer", "Grouping", "Track Number", "File Type",
    "Comment", "Duration", "Bitrate", "BPM", "ReplayGain", "Key",
    "Color", "Cover", "Rating", "Date Added", "Times Played",
]

SEARCH_PANE_PATH = f"{LIBRARY_CONTENT}/browsingView/searchPane"

SEARCH_FIELD_PATH = f"{SEARCH_PANE_PATH}/searchField"

SEARCH_CLEAR_BUTTON_PATH = f"{SEARCH_PANE_PATH}/clearButton"

SEARCH_SUGGESTION_LIST_PATH = f"{SEARCH_PANE_PATH}/suggestionList"

SEARCH_SUGGESTION_FIELD_LIST_PATH = f"{SEARCH_PANE_PATH}/suggestionFieldList"

SEARCH_RECENT_LIST_PATH = f"{SEARCH_PANE_PATH}/recentList"

SPLIT_VIEW_BUTTON_PATH = f"{LIBRARY_CONTENT}/tracklistMenu/splitViewButton"

RIGHT_TRACKLIST_PATH = f"{LIBRARY_CONTENT}/rightTrackList"

RIGHT_TRACKLIST_TABLE_PATH = f"{RIGHT_TRACKLIST_PATH}/trackTableView"

def _suggestion_row_path(context, needle, timeout=5):
    """Path of the suggestion row displaying needle: field suggestions
    ("Artist:") live in suggestionFieldList and match the rows'
    display; value suggestions live in suggestionList and match the
    rows' value."""
    if needle.endswith(":"):
        return _find_list_row_path(
                context,
                SEARCH_SUGGESTION_FIELD_LIST_PATH,
                "suggestion_",
                needle,
                ("display",),
                timeout)
    return _find_list_row_path(
            context,
            SEARCH_SUGGESTION_LIST_PATH,
            "suggestion_",
            needle,
            ("value",),
            timeout)

# Delay after typing into the search bar: the query is applied through a
# debouncing timer (searchDebounce, 800 ms in res/qml/Library.qml).
SEARCH_APPLY_DELAY = 1.5

def _search_activated(context):
    return _get_property(context, SEARCH_PANE_PATH, "activated") == "true"

def _recent_row_path(context, needle, timeout=5):
    """Path of the recent-search row displaying needle (free text, or the
    serialized query for token rows)."""
    return _find_list_row_path(
            context,
            SEARCH_RECENT_LIST_PATH,
            "recent_",
            needle,
            ("freeText", "queryString"),
            timeout)

def _activate_library_search(context, timeout=15):
    # AGENTS.md click-retry exception: the collapsed bar opens via TapHandler
    # and spix synthetic taps on TapHandlers can be dropped silently; every
    # retry is verified against the pane's activated state.
    deadline = time.time() + timeout
    while time.time() < deadline:
        if _search_activated(context):
            return
        _click(context, SEARCH_PANE_PATH)
        time.sleep(0.3)
    assert _search_activated(context), "Library search bar did not open"

def _deactivate_library_search(context, timeout=5):
    # Escape triggers persistSearch() + deactivateSearch() in the search bar's
    # key handler, which is the deterministic way to give up focus. Re-Escape
    # is needed after a dropped synthetic tap re-opened the bar.
    deadline = time.time() + timeout
    while time.time() < deadline:
        if not _search_activated(context):
            return
        context.rpc.enterKey("mainWindow", QT_KEY_ESCAPE, 0)
        time.sleep(0.3)
    assert not _search_activated(context), "Library search bar is still activated"

def _track_rows(context, tracklist_path):
    table = f"{tracklist_path}/trackTableView"
    height = float(_get_property(context, table, "contentHeight") or 0)
    return max(0, int(height // _ROW_HEIGHT))

def _track_row_by_title(context, tracklist_path, title, timeout=5):
    """Index of the first row whose displayed title matches, or -1."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        rows = _track_rows(context, tracklist_path)
        for row in range(rows):
            track_title = str(
                context.rpc.invokeMethod(tracklist_path, "trackTitleForRow", [row]) or ""
            )
            if track_title == title:
                return row
        time.sleep(0.3)
    return -1

def _perform_track_action(context, action, row, table=TRACK_TABLE_PATH):
    _scroll_tableview_to_row(context, row, table)
    path = f"{table}/trackRow_{row}"
    _wait_for_clickable(context, path, timeout=10) # Some CI platform like Windows 10 are very slow to load the table
    TRACK_ACTIONS[action](context, path)
    # The synthetic tap that selects a row is occasionally dropped under load
    # (e.g. a CI runner that is also capturing video), so re-click once if the
    # row did not end up selected.
    if action == "click" and not _wait_for_track_selected(context, path):
        _click(context, path)
        time.sleep(0.3)
    elif action == "right-click" and not _wait_for_context_menu(context):
        _right_click(context, path)
        time.sleep(0.3)

def _type_into_library_search(context, text):
    _activate_library_search(context)
    # inputText() appends to the text that is already in the field, so clear
    # it first; typing goes through real key events so the search bar's
    # onTextEdited handlers run (setting the `text` property directly would
    # bypass them).
    _set_property(context, SEARCH_FIELD_PATH, "text", "")
    time.sleep(0.3)
    context.rpc.inputText(SEARCH_FIELD_PATH, text)
    time.sleep(SEARCH_APPLY_DELAY)

# Human-readable key names of the search-bar scenarios, mapped to Qt key
# codes.
_SEARCH_KEYS = {
    "Escape": QT_KEY_ESCAPE,
    "Tab": QT_KEY_TAB,
    "Backspace": QT_KEY_BACKSPACE,
    "Enter": QT_KEY_ENTER,
    "Delete": QT_KEY_DELETE,
    "Left": QT_KEY_LEFT,
    "Up": QT_KEY_UP,
    "Right": QT_KEY_RIGHT,
    "Down": QT_KEY_DOWN,
    # "Ctrl+F" is a special case: it keys on a window-level Shortcut and is
    # delivered as a (Qt key code, Qt modifier) pair.
    "Ctrl+F": (QT_KEY_F, QT_CONTROL_MODIFIER),
}

def _search_criteria_fields(context):
    """Field names of the criteria tokens in insertion order (JSON list)."""
    raw = _get_property(context, SEARCH_PANE_PATH, "criteriaFields") or "[]"
    try:
        return json.loads(raw)
    except (TypeError, ValueError):
        return []

def _remembered_track(context, name="this"):
    """The track remembered under ``name`` (default: "this track")."""
    tracks = getattr(context, "remembered_tracks", {})
    assert name in tracks, f"No track was remembered as \"{name} track\""
    return tracks[name]

def _remember_catalog_track(context, unique_attr=None, include_track_with_search_op=False):
    """Randomly remember an available track, optionally with a unique attribute
    among the available tracks.
    """
    catalog = context.config.userdata.get("tracks_catalog")
    assert catalog, "No tracks catalog was persisted by the test runner"
    pool = catalog
    if unique_attr:
        values = [entry.get(unique_attr) for entry in catalog]
        pool = [
            entry for entry in catalog
            if entry.get(unique_attr) and values.count(entry[unique_attr]) == 1
        ]
    aggregator, pred = all, lambda item: not isinstance(item[1], str) or "|" not in item[1]
    if include_track_with_search_op:
        aggregator, pred = any, lambda item: isinstance(item[1], str) and "|" in item[1]
    pool = [
        entry for entry in pool
        if aggregator(map(pred, entry.items()))
    ]
    assert pool, f"No tracks available in the catalog"
    assert all(entry.get("title") for entry in pool), (
        "The catalog contains tracks without a title"
    )
    return remember_track(context, scenario_rng(context).choice(pool))

def _this_track_field(context, field):
    track = _remembered_track(context)
    value = getattr(track, field, None)
    assert value, (
        f"The remembered track has no '{field}'"
    )
    return value

def _type_this_track(context, field, transform=None):
    value = str(_this_track_field(context, field))
    if transform:
        value = transform(value)
    _type_into_library_search(context, value)
    return value

def _wait_for_search_suggestion(context, value, timeout=15):
    deadline = time.time() + timeout
    texts = []
    while time.time() < deadline:
        texts = _search_suggestion_texts(context)
        if value in texts:
            return
        time.sleep(0.3)
    raise AssertionError(
        f'The search suggestion "{value}" is not visible (suggestions: {texts})')

def search_field_quote(value):
    """Quote a criterion value the same way res/qml/Library/SearchPane.qml does."""
    if re.search(r"[\s\"'=~]", value):
        return '"' + value + '"'
    return value

def _this_track_results_visible(context):
    title = _this_track_field(context, "title")
    return _track_row_by_title(context, TRACKLIST_PATH, title) >= 0

DECK_BUTTON_PATHS = {
    "play": "playButton",
    "cue": "cueButton",
    "beatjump": "beatjump",
    "beatjump_forward": "jumpForwardButton",
    "beatjump_backward": "jumpBackButton",
    "hotcue": "hotcueAndStem",
    "loop_in": "loopIn",
    "loop_out": "loopOut",
    "rate": "rateSlider",
    "reloop_toggle": "loopRecallButton",
    "spinny": "spinny",
    "sync": "syncButton",
    "range": "rangeButton",
    "loop_halve": "loopSizeHalfButton",
    "loop_double": "loopSizeDoubleButton",
    "tempo": "rateSlider",
}


# kinds:
#   "ratio"   -> RatioChoice: option item `path/<value>`, read `selected`
#   "combo"   -> ComboBox: open popup and click `path_option_<index>`, read `currentIndex`
#   "spinbox" -> Settings/SpinBox: write/read `realValue`
#   "slider"  -> Settings/Slider: write/read `value`
#   "color"   -> DefaultColorSelector: click `path_color_<index>`, read `currentIndex`
SETTING_MAP = {
    # Sound category (RatioChoice)
    "Main Mix": {"path": "mainWindow/setting_MainMix", "kind": "ratio", "options": ["on", "off"]},
    "Main Output Mode": {"path": "mainWindow/setting_MainOutputMode", "kind": "ratio", "options": ["mono", "stereo"]},
    "Sound Clock": {"path": "mainWindow/setting_SoundClock", "kind": "ratio", "options": ["soundcard", "network"]},
    "Keylock engine": {"path": "mainWindow/setting_KeylockEngine", "kind": "ratio"},
    "Sound API": {"path": "mainWindow/setting_SoundAPI", "kind": "ratio"},
    "Sample Rate": {"path": "mainWindow/setting_SampleRate", "kind": "ratio"},
    # Interface category — theme & color tab
    "skin": {"path": "mainWindow/setting_skin", "kind": "combo", "model": ["Unnamed"]},
    "color": {"path": "mainWindow/setting_color", "kind": "combo", "model": ["Dark", "Light"]},
    "layout": {"path": "mainWindow/setting_layout", "kind": "combo", "model": ["Performance", "Broadcast"]},
    "tool tips": {"path": "mainWindow/setting_toolTips", "kind": "ratio", "options": ["off", "library", "all"]},
    "disable screen saver": {"path": "mainWindow/setting_disableScreenSaver", "kind": "ratio", "options": ["no", "while running", "while playing"]},
    "start in full-screen mode": {"path": "mainWindow/setting_startFullscreen", "kind": "ratio", "options": ["on", "off"]},
    "auto-hide the menu bar": {"path": "mainWindow/setting_autoHideMenuBar", "kind": "ratio", "options": ["on", "off"]},
    "search completion": {"path": "mainWindow/setting_searchCompletion", "kind": "ratio", "options": ["on", "off"]},
    "search history keyboard shortcuts": {"path": "mainWindow/setting_searchHistoryKeyboardShortcuts", "kind": "ratio", "options": ["on", "off"]},
    "bpm display precision": {"path": "mainWindow/setting_bpmDisplayPrecision", "kind": "spinbox", "precision": 0},
    "library row height": {"path": "mainWindow/setting_libraryRowHeight", "kind": "slider", "min": 14, "max": 100, "markers": [14, 20, 50, 80]},
    "track palette": {"path": "mainWindow/setting_trackPalette", "kind": "combo", "model": PALETTE_NAMES},
    "hotcue palette": {"path": "mainWindow/setting_hotcuePalette", "kind": "combo", "model": PALETTE_NAMES},
    "key color palette": {"path": "mainWindow/setting_keyColorPalette", "kind": "combo", "model": PALETTE_NAMES},
    "key color": {"path": "mainWindow/setting_keyColor", "kind": "ratio", "options": ["on", "off"]},
    "hotcue default color": {"path": "mainWindow/setting_hotcueDefaultColor", "kind": "color"},
    "loop default color": {"path": "mainWindow/setting_loopDefaultColor", "kind": "color"},
    # Interface category — decks tab
    "cue mode": {"path": "mainWindow/setting_cueMode", "kind": "combo", "model": ["Mixxx", "Mixxx (no blinking)", "Pioneer", "Denon", "Numark", "CUP"]},
    "time format": {"path": "mainWindow/setting_timeFormat", "kind": "combo", "model": ["Traditional", "Traditional (Coarse)", "Seconds", "Seconds (Long)", "Kiloseconds", "Hectoseconds"]},
    "set intro start to main cue": {"path": "mainWindow/setting_introStartToMainCue", "kind": "ratio", "options": ["on", "off"]},
    "track time display": {"path": "mainWindow/setting_trackTimeDisplay", "kind": "ratio", "options": ["elapsed", "remaining", "both"]},
    "double-press load to clone": {"path": "mainWindow/setting_doublePressLoadToClone", "kind": "ratio", "options": ["on", "off"]},
    "track load point": {"path": "mainWindow/setting_trackLoadPoint", "kind": "combo", "model": ["Main cue", "Beginning of track", "First sound", "Intro start", "First hotcue"]},
    "loading a track when playing": {"path": "mainWindow/setting_loadingTrackWhenPlaying", "kind": "ratio", "options": ["reject", "allow", "when stopped"]},
    "reset on track load": {"path": "mainWindow/setting_resetOnTrackLoad", "kind": "ratio", "options": ["none", "key", "both", "tempo"]},
    "slider range": {"path": "mainWindow/setting_sliderRange", "kind": "combo", "model": ["4%", "6% (semitone)", "8% (Technics SL-1210)", "10%", "16%", "24%", "50%", "90%"]},
    "sync mode": {"path": "mainWindow/setting_syncMode", "kind": "ratio", "options": ["follow soft leader", "use steady"]},
    "slider orientation": {"path": "mainWindow/setting_sliderOrientation", "kind": "ratio", "options": ["down", "up"]},
    "keylock mode": {"path": "mainWindow/setting_keylockMode", "kind": "ratio", "options": ["original key", "current key"]},
    "keyunlock mode": {"path": "mainWindow/setting_keyunlockMode", "kind": "ratio", "options": ["reset key", "keep key"]},
    "pitch bend behaviour": {"path": "mainWindow/setting_pitchBendBehaviour", "kind": "ratio", "options": ["abrupt jump", "smooth ramping"]},
    "temporary coarse adjustment": {"path": "mainWindow/setting_temporaryCoarseAdjustment", "kind": "spinbox", "precision": 2},
    "temporary fine adjustment": {"path": "mainWindow/setting_temporaryFineAdjustment", "kind": "spinbox", "precision": 2},
    "permanent coarse adjustment": {"path": "mainWindow/setting_permanentCoarseAdjustment", "kind": "spinbox", "precision": 2},
    "permanent fine adjustment": {"path": "mainWindow/setting_permanentFineAdjustment", "kind": "spinbox", "precision": 2},
    "ramping sensitivity": {"path": "mainWindow/setting_rampingSensitivity", "kind": "slider", "min": 100, "max": 2500, "markers": []},
    # Interface category — waveform tab
    "end of track warning": {"path": "mainWindow/setting_endOfTrackWarning", "kind": "slider", "min": 0, "max": 120, "markers": [0, 10, 30, 60, 120]},
    "beat grid opacity": {"path": "mainWindow/setting_beatGridAlpha", "kind": "slider", "min": 0, "max": 100, "markers": [0, 50, 100]},
    "default zoom level": {"path": "mainWindow/setting_defaultZoom", "kind": "slider", "min": 10, "max": 100, "markers": [10, 30, 50, 100]},
    "synchronise zoom level across waveforms": {"path": "mainWindow/setting_zoomSynchronization", "kind": "ratio", "options": ["on", "off"]},
    "normalise waveform overview": {"path": "mainWindow/setting_overviewNormalized", "kind": "ratio", "options": ["on", "off"]},
    "waveform type": {"path": "mainWindow/setting_waveformType", "kind": "combo", "model": ["Filtered", "HSV", "RGB", "Simple", "Stacked"]},
    "stereo split": {"path": "mainWindow/setting_stereoSplit", "kind": "ratio", "options": ["on", "off"]},
    "high details": {"path": "mainWindow/setting_highDetails", "kind": "ratio", "options": ["on", "off"]},
    "play marker position": {"path": "mainWindow/setting_playMarkerPosition", "kind": "slider", "min": 0, "max": 100, "markers": [0, 50, 100]},
    "beats until next marker": {"path": "mainWindow/setting_untilMarkShowBeats", "kind": "ratio", "options": ["on", "off"]},
    "time until next marker": {"path": "mainWindow/setting_untilMarkShowTime", "kind": "ratio", "options": ["on", "off"]},
    "marker hint placement": {"path": "mainWindow/setting_untilMarkAlign", "kind": "ratio", "options": ["top", "center", "bottom"]},
    "marker hint font size": {"path": "mainWindow/setting_untilMarkTextPointSize", "kind": "combo", "model": ["10 pt", "12 pt", "15 pt", "18 pt", "24 pt", "32 pt", "48 pt"]},
    "global visual gain": {"path": "mainWindow/setting_visualGainAll", "kind": "slider", "min": 50, "max": 500, "markers": [50, 100, 150, 300, 500]},
    "low visual gain": {"path": "mainWindow/setting_visualGainLow", "kind": "slider", "min": 50, "max": 500, "markers": [50, 100, 150, 300, 500]},
    "medium visual gain": {"path": "mainWindow/setting_visualGainMedium", "kind": "slider", "min": 50, "max": 500, "markers": [50, 100, 150, 300, 500]},
    "high visual gain": {"path": "mainWindow/setting_visualGainHigh", "kind": "slider", "min": 50, "max": 500, "markers": [50, 100, 150, 300, 500]},
    # Library category — sources & integrations
    "Rhythmbox integration": {"path": "mainWindow/setting_integration0", "kind": "ratio", "options": ["on", "off"]},
    "Banshee integration": {"path": "mainWindow/setting_integration1", "kind": "ratio", "options": ["on", "off"]},
    "iTunes integration": {"path": "mainWindow/setting_integration2", "kind": "ratio", "options": ["on", "off"]},
    "Traktor integration": {"path": "mainWindow/setting_integration3", "kind": "ratio", "options": ["on", "off"]},
    "Rekordbox integration": {"path": "mainWindow/setting_integration4", "kind": "ratio", "options": ["on", "off"]},
    "Serato integration": {"path": "mainWindow/setting_integration5", "kind": "ratio", "options": ["on", "off"]},
    # Library category — metadata
    "synchronise metadata with file": {"path": "mainWindow/setting_metadataSync", "kind": "ratio", "options": ["on", "off"]},
    "synchronise metadata with Serato library": {"path": "mainWindow/setting_seratoMetadataSync", "kind": "ratio", "options": ["on", "off"]},
    "prefer relative path on playlist export": {"path": "mainWindow/setting_relativePathOnExport", "kind": "ratio", "options": ["on", "off"]},
    # Library category — history
    "track duplicate distance": {"path": "mainWindow/setting_historyDuplicateDistance", "kind": "spinbox", "precision": 0},
    "delete history playlist with less than": {"path": "mainWindow/setting_historyMinTracksToKeep", "kind": "spinbox", "precision": 0},
    # Library category — search
    "library search completion": {"path": "mainWindow/setting_librarySearchCompletion", "kind": "ratio", "options": ["on", "off"]},
    "library search history keyboard shortcuts": {"path": "mainWindow/setting_librarySearchHistoryShortcuts", "kind": "ratio", "options": ["on", "off"]},
    "search-as-you-type timeout": {"path": "mainWindow/setting_searchTimeout", "kind": "slider", "min": 0.1, "max": 10, "markers": [0.1, 0.5, 1, 5, 10]},
    "pitch slider for fuzz BPM search": {"path": "mainWindow/setting_searchFuzzBpm", "kind": "slider", "min": 0, "max": 100, "markers": [0, 25, 50, 75, 100]},
    # Analyzer category — BPM and beat detection. The Analyzer page resolves
    # through the settings popup tree
    # ("mainWindow/settingsPopupItem/analyzerPage/<section>/<control>").
    "BPM detection": {"path": "mainWindow/settingsPopupItem/analyzerPage/bpm/state", "kind": "ratio", "options": ["off", "on"]},
    "BPM analyser": {"path": "mainWindow/settingsPopupItem/analyzerPage/bpm/plugin", "kind": "ratio", "options": ["queenmary", "soundtouch"]},
    "assume constant tempo": {"path": "mainWindow/settingsPopupItem/analyzerPage/bpm/fixedTempo", "kind": "ratio", "options": ["off", "on"]},
    "re-analysis when settings change": {"path": "mainWindow/settingsPopupItem/analyzerPage/bpm/reanalyze", "kind": "ratio", "options": ["off", "on"]},
    "BPM fast analysis": {"path": "mainWindow/settingsPopupItem/analyzerPage/bpm/fastAnalysis", "kind": "ratio", "options": ["off", "on"]},
    "re-analysis of beatgrids imported from other DJ software": {"path": "mainWindow/settingsPopupItem/analyzerPage/bpm/reanalyzeImported", "kind": "ratio", "options": ["off", "on"]},
    # Analyzer category — key detection
    "key detection": {"path": "mainWindow/settingsPopupItem/analyzerPage/key/state", "kind": "ratio", "options": ["off", "on"]},
    "key analyser": {"path": "mainWindow/settingsPopupItem/analyzerPage/key/plugin", "kind": "ratio", "options": ["queenmary", "keyfinder"]},
    "key fast analysis": {"path": "mainWindow/settingsPopupItem/analyzerPage/key/fastAnalysis", "kind": "ratio", "options": ["off", "on"]},
    "key re-analysis when settings change": {"path": "mainWindow/settingsPopupItem/analyzerPage/key/reanalyze", "kind": "ratio", "options": ["off", "on"]},
    "key notation": {"path": "mainWindow/settingsPopupItem/analyzerPage/key/notation", "kind": "ratio", "options": ["lancelot", "traditional", "openkey", "custom"]},
    # Analyzer category — ReplayGain
    "ReplayGain normalization": {"path": "mainWindow/settingsPopupItem/analyzerPage/replayGain/state", "kind": "ratio", "options": ["off", "on"]},
    "ReplayGain analyser": {"path": "mainWindow/settingsPopupItem/analyzerPage/replayGain/plugin", "kind": "ratio", "options": ["replaygain20", "replaygain10"]},
    "ReplayGain target loudness": {"path": "mainWindow/settingsPopupItem/analyzerPage/replayGain/targetLoudness", "kind": "slider", "min": -12, "max": 12, "markers": [-12, -6, 0, 6, 12]},
    "ReplayGain re-analysis": {"path": "mainWindow/settingsPopupItem/analyzerPage/replayGain/reanalyze", "kind": "ratio", "options": ["off", "on"]},
    "ReplayGain default boost": {"path": "mainWindow/settingsPopupItem/analyzerPage/replayGain/defaultBoost", "kind": "slider", "min": -12, "max": 12, "markers": [-12, -6, 0, 6, 12]},
}

TRACK_ACTIONS = {
    "click": _click,
    "double-click": _double_click,
    "right-click": _right_click,
    "long-press": _long_press,
}

_ROW_HEIGHT = 30

def _find_first_output_edge(context, only_not_connected=False):
    # FIXME: This function is fragile. It depends on:
    #   1. System audio hardware being present (no devices = empty outputList = returns None)
    #   2. The ListView item_0, item_1... naming convention matching spix's ListView traversal
    #   3. Edge addresses being "Default" or "Output" (actual addresses are device-specific)
    # All scenarios using "to an output device" will fail without real audio hardware.
    # Consider adding a custom C++ command to register a fake output device for testing.
    output_count = int(_get_property(context, f"{OUTPUT_COLUMN}/outputList", "count"))
    for i in range(output_count):
        item_path = f"{OUTPUT_COLUMN}/outputList/output{i}"
        name = _get_property(context, item_path, "name")
        assert name, f"Cannot find {item_path}"
        channels = int(_get_property(context, f"{item_path}/node", "count"))
        for channel in range(channels):
            edge_path = f"{item_path}/edge_Default{channel}"
            assert _is_visible(context, edge_path), f"Cannot find {edge_path}"
            if only_not_connected and _get_property(context, edge_path, "state") != "idle":
                continue
            return edge_path
    return None

def _find_list_row_path(context, list_path, row_prefix, needle, row_properties,
        timeout=5):
    """Resolve the index-keyed path of the row in list_path whose first
    non-empty row property equals needle.

    The lists are populated synchronously (no debounce chain), so this is
    a bounded wait for a non-empty list followed by a single scan; a miss
    is a plain failure.
    """
    deadline = time.time() + timeout
    count = 0
    while time.time() < deadline:
        count = int(_get_property(context, list_path, "count") or 0)
        if count > 0:
            break
        time.sleep(0.2)
    assert count > 0, f'The "{list_path.rsplit("/", 1)[1]}" list is empty'

    row_texts = []
    for index in range(count):
        path = f"{list_path}/{row_prefix}{index}"
        row_text = ""
        for row_property in row_properties:
            row_text = _get_property(context, path, row_property)
            if row_text:
                break
        if row_text == needle:
            return path
        row_texts.append(row_text)
    raise AssertionError(
            f'A row displaying "{needle}" is not listed '
            f"({count} rows: {row_texts})")

def _scroll_tableview_to_row(context, row, table=TRACK_TABLE_PATH):
    """Scroll the track TableView so that ``row`` lies inside the visible viewport.

    The TableView recycles its delegates (``reuseItems: true``) and each
    item is a per-column cell named ``trackRow_<row>`` (see Cell.qml). Rows that
    are not currently on screen are never instantiated, so a click targeted at
    ``trackRow_<row>`` resolves to a stale pooled cell or fails outright
    ("Item not found") — the missed click this helper prevents. Driving the
    flickable ``contentY`` scrolls the list the way a user would.
    """
    deadline = time.time() + 15
    last_error = None
    while time.time() < deadline:
        try:
            table_visible = context.rpc.existsAndVisible(table)
            y = float(_get_property(context, table, "contentY"))
            height = float(_get_property(context, table, "contentHeight"))
            viewport = float(_get_property(context, table, "height")) or 0
        except Exception as e:
            last_error = e
            time.sleep(0.3)
            continue
        if not table_visible or viewport <= 0:
            raise AssertionError(
                "The track table is not visible; the library must be open to "
                "interact with tracks"
            )
        if height <= viewport:
            return
        target = row * _ROW_HEIGHT
        if y <= target and y + viewport >= target + _ROW_HEIGHT:
            return
        new_y = target if target < y else target + _ROW_HEIGHT - viewport
        new_y = max(0.0, min(new_y, height - viewport))
        _set_property(context, table, "contentY", str(new_y))
        time.sleep(0.3)
    raise AssertionError(
        f"Failed to scroll track table so row {row} is in view"
        + (f" (last error: {last_error})" if last_error else "")
    )

def _search_suggestion_texts(context):
    """Display texts of the currently suggested values (JSON list)."""
    raw = _get_property(context, SEARCH_PANE_PATH, "suggestionTexts") or "[]"
    try:
        return json.loads(raw)
    except (TypeError, ValueError):
        return []

def _wait_for_context_menu(context, timeout=5):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if _is_visible(context, TRACK_CONTEXT_MENU_PATH):
                return True
        except Exception:
            pass
        time.sleep(0.2)
    return False

def _wait_for_track_selected(context, path, timeout=5):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if _track_is_selected(context, path):
            return True
        time.sleep(0.2)
    return False

def remember_track(context, entry, name="this"):
    """Add ``entry`` (a tracks-catalog entry with ``location``) to
    ``context.remembered_tracks`` under ``name``."""
    if not hasattr(context, "remembered_tracks"):
        context.remembered_tracks = {}
    track = RememberedTrack(
        title=entry["title"],
        artist=entry.get("artist", ""),
        location=entry["location"],
        bpm=entry.get("bpm"),
        first_beat=entry.get("first_beat"),
        samplerate=entry.get("samplerate"),
        tags=entry.get("tags"),
    )
    context.remembered_tracks[name] = track
    print(f"Track picked as {repr(name)}: {track}", flush=True)
    return track

def scenario_rng(context):
    """The scenario's deterministic RNG (derived from the run seed in
    environment.py), falling back to the global module if a step runs
    without a scenario seed."""
    rng = getattr(context, "rng", None)
    return rng if rng is not None else random
