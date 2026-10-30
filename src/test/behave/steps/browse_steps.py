"""Feature-specific step definitions for browse.

Split out of the former monolithic step modules; shared machinery
lives in mixxx_steps.py / settings_steps.py / helpers.py.
All imports are module-level: behave discovers steps/*.py
alphabetically, and the common modules must not be pulled in ahead
of this file's own (more specific) step registrations."""

from helpers import (
    COLUMN_HEADER_PATH,
    COLUMN_PICKER_MENU_PATH,
    KNOWN_COLUMNS,
    LIBRARY_CONTENT,
    LIBRARY_TREEVIEW_CREATE_POPUP,
    LIBRARY_TREEVIEW_PATH,
    MUSIC_DIRECTORY_LIST,
    QT_KEY_DOWN,
    QT_KEY_ENTER,
    QT_KEY_ESCAPE,
    QT_KEY_SPACE,
    QT_KEY_TAB,
    QT_KEY_UP,
    QT_KEY_LEFT,
    RIGHT_TRACKLIST_PATH,
    RIGHT_TRACKLIST_TABLE_PATH,
    SEARCH_APPLY_DELAY,
    SEARCH_CLEAR_BUTTON_PATH,
    SEARCH_FIELD_PATH,
    SEARCH_PANE_PATH,
    SEARCH_RECENT_LIST_PATH,
    SEARCH_SUGGESTION_FIELD_LIST_PATH,
    SEARCH_SUGGESTION_LIST_PATH,
    SPLIT_VIEW_BUTTON_PATH,
    TRACKLIST_PATH,
    TRACK_CONTEXT_MENU_PATH,
    TRACK_TABLE_PATH,
    _SEARCH_KEYS,
    _activate_library_search,
    _click,
    _column_header_path,
    _column_index,
    _deactivate_library_search,
    _expectation_matches,
    _find_sidebar_named_entity_path,
    _get_bb,
    _get_library_state,
    _get_property,
    _is_column_visible,
    _is_visible,
    _last_track_row,
    _library_command,
    _perform_track_action,
    _recent_row_path,
    _remember_catalog_track,
    _remembered_track,
    _right_click,
    _search_activated,
    _search_criteria_fields,
    _set_control_value,
    _set_property,
    _sidebar_feature_row_path,
    _suggestion_row_path,
    _this_track_field,
    _this_track_results_visible,
    _track_row_by_title,
    _track_row_is_on_screen,
    _track_row_path,
    _track_rows,
    _type_into_library_search,
    _type_this_track,
    _wait_for_clickable,
    _wait_for_hidden,
    _wait_for_search_suggestion,
    _wait_for_visible,
    search_field_quote,
    wait_clickable,
    wait_hidden,
    wait_visible,
)
from behave import given, when, then

import glob
import json
import shutil
from pathlib import Path
import os
import re
import time


# --- relocated from settings_steps.py (browse-exclusive) ---

MUSIC_DIRECTORY_ROW = "mainWindow/sourceRow_%d"
SOURCE_REMOVE_BUTTON = "mainWindow/sourceRemoveButton_%d"
SOURCE_REMOVE_MODE_SELECTOR = "mainWindow/sourceRemoveModeSelector_%d"
SOURCE_REMOVE_MODE_OPTIONS = ["keep", "hide", "purge"]
SOURCE_RELINK_BUTTON = "mainWindow/sourceRelinkButton_%d"
ADD_SOURCE_BUTTON = "mainWindow/addSourceButton"
LIBRARY_SCAN_OVERLAY = "mainWindow/libraryScanOverlay"
ADD_FOLDER_DIALOG_TEST = "mainWindow/addFolderDialogTest"
MUSIC_DIRECTORY_DEFAULT_TRACK_COUNT = 1

def _wait_for_music_directory_count(context, expected, timeout=10):
    """Wait for the settings list to hold `expected` entries.
    Returns (ok, last_seen_count) so a failure message can report what the
    model actually contained instead of just "does not".
    """
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        try:
            if _is_visible(context, MUSIC_DIRECTORY_LIST):
                last = int(_get_property(context, MUSIC_DIRECTORY_LIST, "count"))
                if last == expected:
                    return True, last
        except Exception:
            pass
        time.sleep(0.3)
    return False, last

def _parse_library_state_expectation(value):
    value = value.strip()
    match = re.match(r"([<>]=?|!=|=)\s*(-?\d+)", value)
    if match:
        return {"op": match.group(1), "num": int(match.group(2))}
    return {"op": "=", "num": int(value)}

def _wait_for_library_state(context, expected, timeout=30):
    """Wait until the library state matches ``expected``.
    Returns ``(matched, last_state)`` so a failure can report the last state
    actually observed (or the RPC error that prevented reading it) instead of
    a bare "does not".
    """
    deadline = time.time() + timeout
    last_state = None
    while time.time() < deadline:
        try:
            state = _get_library_state(context)
            last_state = state
            matched = True
            for key, expectation in expected.items():
                actual = state.get(key)
                if key == "sources" and isinstance(actual, list):
                    actual = len(actual)
                if not _expectation_matches(actual, expectation):
                    matched = False
                    break
            if matched:
                return True, state
        except Exception as e:
            last_state = f"RPC error: {e}"
        time.sleep(0.3)
    return False, last_state

def _create_music_directory(context, dir_id, tracks, permission, dirname):
    """Create a folder under the profile's Music dir and register it."""
    parent = os.path.join(context.profile_dir, "Music")
    path = os.path.join(parent, dirname)
    os.makedirs(path, exist_ok=True)
    if permission == "no-read":
        os.chmod(path, 0o000)
    elif permission != "read":
        raise ValueError(f"Unknown directory permission '{permission}'")
    if tracks:
        tracks_dir = context.config.userdata["tracks_dir"]
        sources = glob.glob(os.path.join(tracks_dir, "*.mp3"))
        if len(sources) < tracks:
            raise RuntimeError(
                f"Not enough tracks in tracks_dir: need {tracks}, have {len(sources)}"
            )
        for track in sources[:tracks]:
            shutil.copy2(track, path)
    context.music_dirs[dir_id] = path
    context.current_music_dir = path

@given(u'a {entity} named "{name}" already exists with {track_count:d} tracks')
@given(u'a {entity} named "{name}" already exists')
def step_library_feature_entity_exists(context, entity, name, track_count=0):
    state = _get_library_state(context).get(entity + 's', [])

    for p in state:
        if p["name"] == name:
            return

    _library_command(context, payload={"action": "createFeatureItem", "type": entity, "name": name, "random_track_count": track_count})
    result = json.loads(_get_property(context, "mainWindow", "lastLibraryState"))
    assert result["result"] == "success", f"Could not create the {entity}: {result}"

@given(u'no {entity} named "{name}" exists')
def step_library_feature_entity_exists(context, entity, name):
    state = _get_library_state(context).get(entity + 's', [])

    for p in state:
        if p["name"] == name:
            _library_command(context, payload={"action": "deleteFeatureItem", "type": entity, "id": p["id"]})
            result = json.loads(_get_property(context, "mainWindow", "lastLibraryState"))
            assert result["result"] == "success", f"Could not delete the {entity} with id {p["id"]}: {result}"

@given("the library columns are in their default state")
def step_library_columns_default(context):
    context.rpc.invokeMethod(TRACKLIST_PATH, "resetColumns", [])
    time.sleep(0.5)

@when('I click the column header "{column}"')
def step_click_column_header(context, column):
    path = _column_header_path(column)
    _click(context, path)
    time.sleep(0.5)

@when('I drag the column "{column}" before the column "{target}"')
def step_drag_column(context, column, target):
    # FIXME not working with column, using bare "moveColumn" instead
    column_idx = _column_index(context, column)
    assert column_idx >= 0, f"Column '{column}' cannot be found ({column_idx})"
    target_idx = _column_index(context, target)
    assert target_idx >= 0, f"Column '{target}' cannot be found ({target_idx})"
    context.rpc.invokeMethod(TRACK_TABLE_PATH, "moveColumn", [column_idx, target_idx])
    time.sleep(0.5)

@when("I open the column picker menu")
def step_open_column_picker(context):
    _right_click(context, _column_header_path("Title"))
    _wait_for_visible(context, COLUMN_PICKER_MENU_PATH)

@when('I toggle the column "{column}" in the column picker')
def step_toggle_column(context, column):
    index = _column_index(context, column)
    if index < 0:
        raise KeyError(f'column {column} unknown')
    _get_current_action = lambda: int(_get_property(context, COLUMN_PICKER_MENU_PATH, "currentIndex"))
    # Needed if QPA == xcb
    # if _get_current_action() == -1:
    #     _click(context, COLUMN_PICKER_MENU_PATH)
    #     time.sleep(0.3)
    # assert _is_visible(context, COLUMN_PICKER_MENU_PATH), "Context menu disappear"
    if _get_current_action() == -1:
        context.rpc.enterKey("mainWindow", QT_KEY_DOWN, 0)
        time.sleep(0.3)
    assert _is_visible(context, COLUMN_PICKER_MENU_PATH), "Context menu disappear"
    if _get_current_action() == -1:
        context.rpc.enterKey("mainWindow", QT_KEY_TAB, 0)
        time.sleep(0.3)
    assert _is_visible(context, COLUMN_PICKER_MENU_PATH), "Context menu disappear"
    assert _get_current_action() != -1, "Unable to focus the context menu"

    current = _get_current_action()
    delta = int(index) - current
    key = QT_KEY_DOWN if delta > 0 else QT_KEY_UP
    for i in range(abs(delta)):
        context.rpc.enterKey("mainWindow", key, 0)
        context.rpc.wait(200)
    context.rpc.wait(200)
    context.rpc.enterKey("mainWindow", QT_KEY_SPACE, 0)
    time.sleep(0.5)

@when("I {action} the track at row {row:d}")
@when("I {action} the track at row {row:d} on the {panel} track list")
def step_track_action(context, action, row, panel="left"):
    _perform_track_action(context, action, row, RIGHT_TRACKLIST_TABLE_PATH if panel == "right" else TRACK_TABLE_PATH)

@when("I click a track below the fold")
def step_click_track_below_fold(context):
    row = _last_track_row(context)
    context._fold_track_row = row
    _perform_track_action(context, "click", row)

@when('I select {path} on the track menu')
def step_select_track_menu(context, path):

    steps = list(map(lambda raw: raw.strip()[1:-1], path.split('>')))
    time.sleep(1)

    def activate(steps, depth=0):
        menu_path = TRACK_CONTEXT_MENU_PATH if not depth else f"{TRACK_CONTEXT_MENU_PATH}_Sub{depth}"
        assert wait_visible(context.rpc, menu_path, timeout=5), f"Context {'menu' if not depth else 'submenu'} is not visible"
        step = steps.pop(0)
        menu = json.loads(context.rpc.invokeMethod(menu_path, "serialisedDump", []))
        entry = [(i, item) for i, item in enumerate(menu["items"]) if item.get("text") == step]
        if not entry:
            print("Content menu content was:", menu)
        assert entry, f"Unable to find the item {repr(step)} in context menu"
        target_index, item = entry[0]
        path = menu_path + "/" + item["objectName"]

        context.rpc.invokeMethod(menu_path, "forceActiveFocus", [])
        current_index = menu["currentIndex"]
        while current_index != target_index and current_index < menu["count"] - 1:
            if context.rpc.existsAndVisible(f"{TRACK_CONTEXT_MENU_PATH}_Sub{depth+1}"):
                context.rpc.enterKey(f"{TRACK_CONTEXT_MENU_PATH}_Sub{depth+1}", QT_KEY_LEFT, 0)
                time.sleep(0.5)
            # Later, we could extend the DSL to request a click on the item. This may be useful to assert granularly the context menu behaviour
            # _click(context, path)
            # time.sleep(0.3)
            # new_index = int(_get_property(context, menu_path, "currentIndex"))
            context.rpc.enterKey(menu_path, QT_KEY_DOWN if current_index < target_index else QT_KEY_UP, 0)
            time.sleep(0.5)
            new_index = int(_get_property(context, menu_path, "currentIndex"))
            # Some platform may struggle with dispatching the emulated keyboard input, so we use the direct setter as fallback
            if new_index == current_index:
                context.rpc.invokeMethod(menu_path, "setMenuIndex", [target_index])
                new_index = int(_get_property(context, menu_path, "currentIndex"))
            assert new_index != current_index, "Unable to change the context menu index"
            current_index = new_index
        assert target_index == current_index, "Unable to reach the target context menu item"
        context.rpc.enterKey(menu_path, QT_KEY_ENTER, 0)
        time.sleep(0.5)
        if steps:
            activate(steps, depth+1)
        else:
            # Not all menu actions will hide the menu, so we don't assert here
            wait_hidden(context.rpc, menu_path, timeout=3)

    activate(steps)

@when('I discard the track menu')
def step_select_track_menu(context):
    deadline = time.time() + 5
    while time.time() < deadline and _is_visible(context, TRACK_CONTEXT_MENU_PATH):
        context.rpc.mouseClickWithProportion("mainWindow", 0.99, 0.99)
        time.sleep(0.2)
    assert not _is_visible(context, TRACK_CONTEXT_MENU_PATH), "Context menu is still visible"

@then("the library is shown for {operator} than {percent:d}% of the Window's height")
def step_library_width(context, operator, percent):
    mw = _get_bb(context, "mainWindow")
    lb = _get_bb(context, LIBRARY_CONTENT)
    ratio = float(lb["height"]) / float(mw["height"])
    if operator == "less":
        assert ratio < percent / 100.0, f"Library covers {ratio*100:.1f}%, expected less than {percent}%"
    else:
        assert ratio > percent / 100.0, f"Library covers {ratio*100:.1f}%, expected more than {percent}%"

@then('the library sidebar should show the source "{name}"')
def step_library_show_source(context, name):
    path = _sidebar_feature_row_path(context, name)
    assert path and _is_visible(context, path), f"Could not find the feature \"{name}\" in the library sidebar"

@then('the option to create a new item should {expect} available for the selected library source')
def step_library_source_create_option(context, expect):
    assert _is_visible(context, LIBRARY_TREEVIEW_PATH), "The library sidebar is not visible"
    selected = context.rpc.invokeMethod(LIBRARY_TREEVIEW_PATH, "getSelectedPath", [])
    path = f"{LIBRARY_TREEVIEW_PATH}/index{selected}"
    assert path and _is_visible(context, path), "No library sidebar feature currently selected"
    expected = expect == "be"
    assert _is_visible(context, f"{path}/newItem") == expected, f"Library sidebar feature's create item should {expect}"

@then('a create popup for the library source should be {state}')
def step_library_source_create_visible(context, state="visible"):
    if state == "visible":
        _wait_for_visible(context, LIBRARY_TREEVIEW_CREATE_POPUP)
        return
    elif state == "hidden":
        _wait_for_hidden(context, LIBRARY_TREEVIEW_CREATE_POPUP)
        return
    assert False, f"Unsupported state assertion {repr(state)}"

@then('a {entity} named "{name}" should appear in the library sidebar')
def step_library_playlist_visible(context, entity, name):
    path = _find_sidebar_named_entity_path(context, entity, name)
    assert path, f"Could not find the library {repr(name)} in the sidebar"

@then('the {entity} named "{name}" should be shown in tracklist')
@then('all tracks should be shown in tracklist')
def step_library_playlist_visible(context, entity=None, name=None):
    selected = context.rpc.invokeMethod(TRACK_TABLE_PATH, "currentlyActiveModel", [])
    if not entity or not name:
        assert selected == "all_tracks", "Current active track list is not all track"
        return

    state = _get_library_state(context).get(entity + 's', [])
    entity_id = [e["id"] for e in state if e["name"] == name]
    assert entity_id, f"Cannot find the {entity} named {repr(name)}"

    assert selected == f"{entity}_{entity_id[0]}", f"Current active track list is not the {entity} named {repr(name)} (ID: {entity_id[0]}, currently: {selected})"

@then(u'a {entity} named "{name}" should exist in the library')
def step_library(context, entity, name):
    state = _get_library_state(context).get(entity + 's', [])
    entity_id = [e["id"] for e in state if e["name"] == name]
    assert entity_id, f"Cannot find the {entity} named {repr(name)}"

@then(u'no new {entity} should be created')
def step_library(context, entity):
    # TODO pre snapshot?
    raise AssertionError("WIP")

@then(u'the create popup for the library source should remain visible')
def step_library(context):
    # No wait here as it is expected to already be visible
    assert _is_visible(context, LIBRARY_TREEVIEW_CREATE_POPUP), "The create entity popup is not visible"

@then(u'the create popup for the library source should show an error state')
def step_library(context):
    errors = _get_property(context, f"{LIBRARY_TREEVIEW_CREATE_POPUP}/newItemName", "hasError")
    assert errors == "true", f"The create entity popup should show an error but is showing none (is: {repr(errors)})"

@then(u'the library should not create a duplicate {entity} named "{name}"')
def step_library(context, entity, name):
    assert _is_visible(context, LIBRARY_TREEVIEW_PATH), "The library sidebar is not visible"
    rows = int(_get_property(context, LIBRARY_TREEVIEW_PATH, "rows"))
    in_section = False
    row = 0
    count = 0
    # No expansion here: a duplicate check only scans the visible labels.
    # (The loop was copied from _find_sidebar_named_entity_path and used to
    # reference its expand_if_needed parameter without binding it.)
    expand_if_needed = False
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
            count += 1

    assert count == 1, f"Found an unexpected number of occurrence ({count}) of {entity} named {repr(name)} in the sidebar"

    state = _get_library_state(context).get(entity + 's', [])
    entity_id = [e["id"] for e in state if e["name"] == name]
    assert len(entity_id) == 1, f"Found an unexpected number of occurrence ({count}) of {entity} named {repr(name)} in the backend"

@then(u'the selected library source item should be "{name}"')
def step_library(context, name):
    assert _is_visible(context, LIBRARY_TREEVIEW_PATH), "The library sidebar is not visible"
    row = int(_get_property(context, LIBRARY_TREEVIEW_PATH, "currentRow"))
    path = f"{LIBRARY_TREEVIEW_PATH}/index{row}"
    label = _get_property(context, f"{path}/labelItem", "text")
    assert label == name, f"The expected selected source is {repr(label)} but should be {repr(name)}"

@then(u'the sidebar should list "{name}" under {entity}')
def step_library(context, entity, name):
    path = _find_sidebar_named_entity_path(context, entity, name, expand_if_needed=True)
    assert path, f"Could not find the {entity} named \"{name}\" in the library sidebar"

@when(u'I enter "{name}" as the new {entity} context-menu input and submit')
def step_library(context, entity, name):
    path = "mainWindow/contextMenuCreateEntityItem/input"
    _wait_for_visible(context, path)
    context.rpc.inputText(path, name)
    context.rpc.enterKey(path, QT_KEY_ENTER, 0)
    time.sleep(1)

@then('only the column "{columns}" are shown')
def step_only_columns_shown(context, columns):
    expected = [c.strip() for c in re.split(r"[,\.]", columns)]
    for col in expected:
        if not col:
            continue
        assert _is_column_visible(context, col, 0), (
            f"Column '{col}' should be visible but is not"
        )
    for col in KNOWN_COLUMNS:
        if col and col not in expected:
            assert not _is_column_visible(context, col, 0), (
                f"Column '{col}' should not be visible but is"
            )

@then('the column "{column}" should {state} visible')
def step_column_visible(context, column, state):
    requested = "not" not in state
    currentState = "not" if requested else "still"
    assert _is_column_visible(context, column) is requested, f"Column {column} is {currentState} visible"

@then('the column "{column}" should appear before the column "{other}"')
def step_column_order(context, column, other):
    col_bb = _get_bb(context, _column_header_path(column))
    other_bb = _get_bb(context, _column_header_path(other))
    assert col_bb["x"] < other_bb["x"], (
        f"Column {column} (x={col_bb['x']}) is not before {other} (x={other_bb['x']})"
    )

@then('the results should be sorted by "{column}" in "{order}" order')
def step_sorted_by(context, column, order):
    column_idx = _column_index(context, column)
    assert column_idx >= 0, f"Unknown column: {column}"
    sort_col = _get_property(context, COLUMN_HEADER_PATH, "sortingColumn")
    assert sort_col == str(column_idx), (
        f"Expected results sorted by '{column}' (column index {column_idx}) "
        f"but sortingColumn is {sort_col}"
    )
    assert order in ("ascending", "descending"), f"Unknown order: {order}"
    expected_order = "0" if order == "ascending" else "1"
    sort_order = _get_property(context, COLUMN_HEADER_PATH, "sortingOrder")
    assert sort_order == expected_order, (
        f"Expected {order} sort (Qt value {expected_order}), got {sort_order}"
    )

@then("the track at row {row:d} should be selected")
@then("the track at row {row:d} should be selected on the {panel} track list")
@then('the track at row {row:d} on the {panel} track list should be selected')
def step_track_selected(context, row, panel="left"):
    path = _track_row_path(row, panel)
    selected = _get_property(context, path, "selected")
    assert selected == "true", f"Track at row {row} is not selected (selected={selected})"

@then("the track at row {row:d} should be visible on screen")
def step_track_on_screen(context, row):
    assert _track_row_is_on_screen(context, row), (
        f"Track at row {row} was not scrolled into the visible viewport"
    )

@then("the track below the fold should be visible on screen")
def step_fold_track_on_screen(context):
    row = getattr(context, "_fold_track_row", None)
    assert row is not None, "No track below the fold was clicked"
    assert _track_row_is_on_screen(context, row), (
        f"Track at row {row} was not scrolled into the visible viewport"
    )

@then("the track context menu should be visible")
def step_track_context_menu_visible(context):
    assert _is_visible(context, TRACK_CONTEXT_MENU_PATH), "Track context menu is not visible"

@then('the library should {assertion} visible')
def step_library_visible(context, assertion):
    if assertion == "be":
        # Showing the library might be slow due to the model being built
        _wait_for_visible(context, LIBRARY_CONTENT, timeout=10)
    else:
        _wait_for_hidden(context, LIBRARY_CONTENT)

@given("the library is not maximized")
def step_library_not_maximized(context):
    _set_control_value(context, "[Skin]", "show_maximized_library", 0)
    time.sleep(0.5)

@given("the library is maximized")
def step_library_maximized(context):
    _set_control_value(context, "[Skin]", "show_maximized_library", 1)
    _wait_for_visible(context, LIBRARY_CONTENT)


# --- Library search --------------------------------------------------------
@when("I activate the library search")
def step_activate_library_search(context):
    _activate_library_search(context)

@when("I deactivate the library search")
def step_deactivate_library_search(context):
    _deactivate_library_search(context)

@when('I type "{text}" into the library search')
def step_type_library_search(context, text):
    _type_into_library_search(context, text)

@when('I paste "{query}" into the library search')
def step_paste_library_search(context, query):
    """Entry of a whole query in one edit; text is set via RPC and
    tryConvertToFieldToken() is called explicitly, mirroring the sidebar
    restore in Library.qml (setting text does not fire onTextEdited)."""
    query = re.sub(
            r"<(\w+) of this track>",
            lambda match: str(_this_track_field(context, match.group(1))),
            query)
    _activate_library_search(context)
    _set_property(context, SEARCH_FIELD_PATH, "text", query)
    time.sleep(0.3)
    context.rpc.invokeMethod(SEARCH_PANE_PATH, "tryConvertToFieldToken", [])
    time.sleep(SEARCH_APPLY_DELAY)

@when("I clear the library search")
def step_clear_library_search(context):
    _click(context, SEARCH_CLEAR_BUTTON_PATH)
    _wait_for_hidden(context, SEARCH_CLEAR_BUTTON_PATH, 5)
    # Adding sleep to let the track table settle, as it sometime leads to Spix event loss
    time.sleep(3)

@when('I select the library search suggestion "{suggestion}"')
@then('I select the library search suggestion "{suggestion}"')
def step_select_suggestion(context, suggestion):
    suggestion_path = _suggestion_row_path(context, suggestion)
    _click(context, suggestion_path)
    time.sleep(0.5)

@when('I {action} the source "{feature}" in the library sidebar')
def step_select_source_sidebar(context, action, feature):
    target_property = ({
        "expand": "expanded",
        "select": "current",
    }).get(action)
    assert target_property, f"Action {repr(action)} is not supported"

    path = _sidebar_feature_row_path(context, feature)
    assert path, f"Could not find the feature \"{feature}\" in the library sidebar"
    # If a popup is still active (e.g item creation, context-menu, ...), the first click will only close the menu, so we retry twice
    for attempt in range(2):
        prop = _get_property(context, path, target_property)
        assert target_property, f"Could not fetch the feature \"{feature}\" sidebar property ({target_property}={repr(prop)})"
        if prop == "true":
            return
        _wait_for_visible(context, path)
        _click(context, path)
        time.sleep(1)
    assert _get_property(context, path, "expanded") == "true", f"Could not expand the feature \"{feature}\" in the library sidebar"

@when('I select the {entity} named "{name}" in the library sidebar')
def step_select_named_entity_sidebar(context, entity, name):
    path = _find_sidebar_named_entity_path(context, entity, name, expand_if_needed=True)
    assert path, f"Could not find the {entity} named \"{name}\" in the library sidebar"
    _wait_for_visible(context, path)
    _click(context, path)
    time.sleep(1)

@when('I initiate creating a new item in the selected library source')
def step_select_source_sidebar_feature_create(context):
    assert _is_visible(context, LIBRARY_TREEVIEW_PATH), "The library sidebar is not visible"
    path = f"{LIBRARY_TREEVIEW_PATH}/newItem"
    _wait_for_visible(context, path)
    _click(context, path)

@when('I enter "{label}" as the new item name')
def step_select_source_sidebar_feature_create_type(context, label):
    assert _is_visible(context, LIBRARY_TREEVIEW_PATH), "The library sidebar is not visible"
    _wait_for_visible(context, LIBRARY_TREEVIEW_CREATE_POPUP)
    path = f"{LIBRARY_TREEVIEW_CREATE_POPUP}/newItemName"
    _wait_for_visible(context, path)
    _click(context, path)

    context.rpc.inputText(SEARCH_FIELD_PATH, label)

@when('I {outcome} the create action')
def step_select_source_sidebar_feature_create_confirm(context, outcome):
    path = f"{LIBRARY_TREEVIEW_CREATE_POPUP}/create" if outcome == "confirm" else f"{LIBRARY_TREEVIEW_CREATE_POPUP}/cancel"
    _wait_for_visible(context, path)
    _click(context, path)

@when("I click the split view button")
def step_click_split_view(context):
    _click(context, SPLIT_VIEW_BUTTON_PATH)
    time.sleep(1)

@then("the library search bar should be visible")
def step_library_search_bar_visible(context):
    assert _search_activated(context), "Library search bar is not open"

@then("this track should be visible in the {side} track list")
def step_this_track_visible_in_side_list(context, side):
    track = _remembered_track(context)
    tracklist = RIGHT_TRACKLIST_PATH if side == "right" else TRACKLIST_PATH
    # The track may take some time to appear due to the model being built/updated
    _wait_for_visible(context, tracklist, timeout=10)
    found = _track_row_by_title(context, tracklist, track.title)
    assert found >= 0, f"Track '{track}' is not in the {side} track list"

@then("all tracks in the library should be shown again")
def step_all_tracks_shown_again(context, ):
    total = _get_library_state(context).get("visibleTrackCount", 0)
    deadline = time.time() + 5
    rows = -1
    while time.time() < deadline:
        rows = _track_rows(context, TRACKLIST_PATH)
        if rows == total:
            return
        time.sleep(0.3)
    raise AssertionError(
            f"{rows} tracks are shown, expected all {total}")

@then("all tracks in the library should be shown without a search filter")
def step_all_tracks_shown_without_filter(context):
    step_all_tracks_shown_again(context)

@then('the library search suggestion "{suggestion}" should be visible')
def step_suggestion_visible(context, suggestion):
    # While a query is being typed, the suggestion list replaces the recent
    # searches, so the recents must have been dismissed first.
    _wait_for_hidden(context, SEARCH_RECENT_LIST_PATH)
    _wait_for_visible(context, _suggestion_row_path(context, suggestion))

@then('the library search suggestion "{suggestion}" should not be visible')
def step_suggestion_not_visible(context, suggestion):
    time.sleep(SEARCH_APPLY_DELAY)
    # A stale row would fake a pass if the assertion only checked an
    # obsolete path, so scan the rows of the relevant list instead.
    list_path = SEARCH_SUGGESTION_FIELD_LIST_PATH
    row_property = "display"
    if not suggestion.endswith(":"):
        list_path = SEARCH_SUGGESTION_LIST_PATH
        row_property = "value"
    count = int(_get_property(context, list_path, "count") or 0)
    for index in range(count):
        row_text = _get_property(context, f"{list_path}/suggestion_{index}", row_property)
        assert row_text != suggestion, (
            f'The suggestion "{suggestion}" is still listed')

@then('the library recent search "{needle}" should be visible')
def step_recent_search_visible(context, needle):
    expected = _remembered_track(context).title if "title of this track" in needle else needle
    _wait_for_visible(context, SEARCH_RECENT_LIST_PATH)
    recent_path = _recent_row_path(context, expected)
    _wait_for_visible(context, recent_path)
    # Verify that token labels are correctly shown (not empty strings)
    token_field_names = _get_property(context, recent_path, "tokenFieldNames")
    if not token_field_names:
        return
    fields = json.loads(token_field_names)
    for i, field in enumerate(fields):
        assert field, (
            f"Recent search token {i} has empty label "
            f"(fields={fields}, recent_path={recent_path})"
        )

@then('a search token "{field}" should be shown in the search bar')
def step_search_token_shown(context, field):
    count = int(_get_property(context, SEARCH_PANE_PATH, "criteriaCount") or 0)
    assert count > 0, f"Search bar has no criteria tokens ({count})"
    fields = _search_criteria_fields(context)
    assert field in fields, (
        f"Search bar has no token for '{field}' (criteria: {fields})"
    )

@then('the track list on the right should {assertion} visible')
def step_right_tracklist_visible(context, assertion):
    if assertion == "be":
        # Showing the library might be slow due to the model being built
        _wait_for_visible(context, RIGHT_TRACKLIST_PATH, timeout=10)
    else:
        _wait_for_hidden(context, RIGHT_TRACKLIST_PATH)

@given("a track available in the library")
@given("a track available in the library {rules}")
def step_remember_any_track(context, rules=None):
    unique_attr = None
    # No by default, too many issues with it for now
    include_track_with_search_op = False
    if rules:
        for rule in rules.split(" and "):
            rule = rule.strip()
            if rule.lower().startswith("with a unique"):
                unique_attr=rule[len("with a unique"):].strip()
            elif rule.lower() == "with search operator in its metadata":
                include_track_with_search_op = True

    _remember_catalog_track(context, unique_attr, include_track_with_search_op)

@given("no search is currently active")
def step_no_search_active(context):
    """Reset the search bar to its fresh state: no criteria tokens, no query
    and deactivated. Clears without persisting, so no recent-search entry is
    created for a leftover query."""
    pane = SEARCH_PANE_PATH
    has_criteria = int(_get_property(context, pane, "criteriaCount") or 0) > 0
    has_query = bool(_get_property(context, pane, "activeQuery"))
    if has_criteria or has_query:
        context.rpc.invokeMethod(pane, "clearAllCriteria", [])
    if _search_activated(context):
        context.rpc.invokeMethod(pane, "deactivatePane", [])
    deadline = time.time() + 5
    criteria_count = -1
    query = ""
    while time.time() < deadline:
        criteria_count = int(_get_property(context, pane, "criteriaCount") or 0)
        query = _get_property(context, pane, "activeQuery") or ""
        if criteria_count == 0 and query == "" and not _search_activated(context):
            return
        time.sleep(0.3)
    raise AssertionError(
            f"The search bar could not be reset (criteria: {criteria_count}, "
            f"query: \"{query}\")")

@given('the library search criteria include the field "{field}" with the value "{value}"')
def step_search_criteria_include(context, field, value):
    _type_into_library_search(context, f"{field.lower()}:")
    _type_into_library_search(context, value)

@when('I type the {attr_with_transform} of this track into the library search')
@when('I type the {attr_with_transform} of this track into the library search {rule}')
def step_type_this_title(context, attr_with_transform, rule=None):
    def wrap(transform, wrapper):
        return lambda v: wrapper(transform(v) if transform else v)
    transform = None

    if rule and rule.startswith("prefixed with"):
        prefix = rule[len("prefixed with") + 1:]
        if prefix.startswith("\"") and prefix.endswith("\""):
            prefix = prefix[1:-1]
        assert prefix, "Prefix cannot be empty"
        transform = wrap(transform, lambda value: f"{prefix}{value}")

    attr = attr_with_transform
    if attr_with_transform.startswith("first word of the "):
        attr = attr_with_transform[len("first word of the "):]
        transform = wrap(transform, lambda value: value.split(" ")[0])

    _type_this_track(context, attr, transform)

@when('I press the "{key}" key in the library search')
@then('I press the "{key}" key in the library search')
def step_press_key_in_search(context, key):
    binding = _SEARCH_KEYS.get(key)
    assert binding is not None, f"Unsupported key '{key}'"
    if isinstance(binding, tuple):
        code, modifiers = binding
    else:
        code, modifiers = binding, 0
    context.rpc.enterKey("mainWindow", code, modifiers)
    time.sleep(1)

@when('I click the recent library search "{search}"')
def step_click_recent_search(context, search):
    expected = _remembered_track(context).title if "title of this track" in search else search
    path = _recent_row_path(context, expected)
    _wait_for_clickable(context, path)
    _click(context, path)
    time.sleep(0.5)

@when("I wait for the search to settle")
def step_wait_search_settle(context):
    # The query is applied through an 800 ms debounce timer; allow one full
    # cycle plus reaction time.
    time.sleep(SEARCH_APPLY_DELAY + 0.5)

@then("the library search bar should be present")
def step_search_bar_present(context):
    assert _is_visible(context, SEARCH_PANE_PATH), (
        "The search bar is not present in the library pane")

@then("the library search bar should be anchored to the bottom-right of the library pane")
def step_search_bar_anchored(context):
    pane = _get_bb(context, SEARCH_PANE_PATH)
    host = _get_bb(context, f"{LIBRARY_CONTENT}/browsingView")
    tolerance = 10
    right = abs((pane["x"] + pane["width"]) - (host["x"] + host["width"])) <= tolerance
    bottom = abs((pane["y"] + pane["height"]) - (host["y"] + host["height"])) <= tolerance
    assert right and bottom, (
        f"Search bar {pane} is not anchored to the bottom-right of the "
        f"library pane {host}")

@then("the library search bar should be expanded")
def step_search_bar_expanded(context):
    deadline = time.time() + 5
    state = ""
    while time.time() < deadline:
        state = _get_property(context, SEARCH_PANE_PATH, "state") or ""
        if state == "expanded":
            return
        time.sleep(0.3)
    raise AssertionError(f"The search bar is not expanded (state={state})")

@then('the search placeholder "{text}" should be visible')
def step_search_placeholder_visible(context, text):
    deadline = time.time() + 5
    seen = ""
    while time.time() < deadline:
        for path in (
                f"{SEARCH_PANE_PATH}/searchPlaceholder",
                f"{SEARCH_PANE_PATH}/collapsedPlaceholder"):
            if _is_visible(context, path):
                seen = _get_property(context, path, "text") or ""
                if seen == text:
                    return
        time.sleep(0.3)
    raise AssertionError(
        f'The search placeholder "{text}" is not visible (visible text: "{seen}")')

@then('the search hint "{text}" should be visible')
def step_search_hint_visible(context, text):
    path = f"{SEARCH_PANE_PATH}/typingTip"
    deadline = time.time() + 5
    seen = ""
    while time.time() < deadline:
        if _is_visible(context, path):
            seen = _get_property(context, path, "text") or ""
            if seen == text:
                return
        time.sleep(0.3)
    raise AssertionError(
        f'The search hint "{text}" is not visible (visible text: "{seen}")')

@then('the search token "{field}" should be active')
def step_search_token_active(context, field):
    deadline = time.time() + 5
    fields = []
    index = -1
    while time.time() < deadline:
        fields = _search_criteria_fields(context)
        index = int(_get_property(context, SEARCH_PANE_PATH, "activeTokenIndex") or -1)
        if 0 <= index < len(fields) and fields[index] == field:
            return
        time.sleep(0.3)
    active = fields[index] if 0 <= index < len(fields) else "none"
    raise AssertionError(
        f'The token "{field}" is not active (active: {active}, criteria: {fields})')

@then('the library search query should be "{query}"')
def step_search_query_is(context, query):
    expected = query
    if "title of this track" in expected:
        expected = expected.replace(
                "<title of this track>", _remembered_track(context).title)
    deadline = time.time() + 5
    seen = ""
    while time.time() < deadline:
        seen = _get_property(context, SEARCH_PANE_PATH, "activeQuery") or ""
        if seen == expected:
            return
        time.sleep(0.3)
    raise AssertionError(
            f'The search query is "{seen}", expected "{expected}"')

@then('the library search criteria should be "{fields}"')
def step_search_criteria_equal(context, fields):
    """Criteria token field names in insertion order."""
    expected = [field for field in fields.split(",") if field]
    deadline = time.time() + 5
    seen = []
    while time.time() < deadline:
        seen = _search_criteria_fields(context)
        if seen == expected:
            return
        time.sleep(0.3)
    raise AssertionError(
            f"The search criteria are {seen}, expected {expected}")

@then('the library search free text should be "{text}"')
@then("the library search free text should be empty")
def step_search_free_text(context, text=None):
    expected = text or ""
    if "title of this track" in expected:
        expected = expected.replace(
                "<title of this track>", _remembered_track(context).title)
    deadline = time.time() + 5
    seen = ""
    while time.time() < deadline:
        seen = _get_property(context, SEARCH_FIELD_PATH, "text") or ""
        if seen == expected:
            return
        time.sleep(0.3)
    raise AssertionError(
            f'The library search free text is "{seen}", expected "{expected}"')

@then("the library search bar should be empty")
def step_search_bar_empty(context):
    deadline = time.time() + 5
    seen = None
    while time.time() < deadline:
        count = int(_get_property(context, SEARCH_PANE_PATH, "criteriaCount") or 0)
        text = _get_property(context, SEARCH_FIELD_PATH, "text") or ""
        seen = (count, text)
        if count == 0 and text == "":
            return
        time.sleep(0.3)
    raise AssertionError(
        f"The search bar is not empty: {seen[0]} criteria, text \"{seen[1]}\"")

@then("the library search suggestion showing the artist of this track should be visible")
def step_artist_suggestion_visible(context):
    track = _remembered_track(context)
    assert track.artist, "The remembered track has no artist"
    _wait_for_search_suggestion(context, track.artist)

@then("the library search query should contain the artist of this track")
def step_query_contains_artist(context):
    expected = "artist:" + search_field_quote(_this_track_field(context, "artist"))
    deadline = time.time() + 5
    query = ""
    while time.time() < deadline:
        query = _get_property(context, SEARCH_PANE_PATH, "activeQuery") or ""
        if expected in query:
            return
        time.sleep(0.3)
    raise AssertionError(
        f"The search query \"{query}\" does not contain \"{expected}\"")

@then("this track should be visible in the results")
def step_this_track_visible(context):
    assert _this_track_results_visible(context), (
        f'The remembered track "{_remembered_track(context)}" '
        "is not in the results")

@then("not all tracks should be visible in the results")
def step_not_all_tracks_visible(context):
    total = _get_library_state(context).get("visibleTrackCount", 0)
    rows = _track_rows(context, TRACKLIST_PATH)
    assert rows < total, (
        f"{rows} track rows are shown, expected fewer than all {total}")


# --- Music directories (settings) ------------------------------------------
@given("a music directory")
@given("the following music directories")
def step_create_music_directory(context):
    context.music_dirs = {}
    if context.table:
        for row in context.table:
            _create_music_directory(
                context,
                row["id"],
                int(row.get("tracks", MUSIC_DIRECTORY_DEFAULT_TRACK_COUNT)),
                row.get("permission", "read"),
                row.get("dir", f"MusicDir{row['id']}"),
            )
    else:
        _create_music_directory(
            context, "0", MUSIC_DIRECTORY_DEFAULT_TRACK_COUNT, "read", "MusicDir0"
        )

@given("the library contains {count:d} music directories")
def step_library_contains_music_directories(context, count):
    assert count >= 0, "A library cannot contain a negative number of music directories"
    if count == 0:
        return
    parent = os.path.join(context.profile_dir, "Music")
    os.makedirs(parent, exist_ok=True)
    for index in range(count):
        path = os.path.join(parent, f"MusicDir{index + 1}")
        os.makedirs(path, exist_ok=True)
        # The last add runs a blocking scan, which also refreshes the sources
        # list in the already-open settings popup via the scanner's
        # onRunningChanged -> loadSources() connection.
        _library_command(context, "addDirectory", path, scan=(index == count - 1))

@given("the tracks directory is in the library")
def step_tracks_directory_in_library(context):
    tracks_dir = context.config.userdata["tracks_dir"]
    _library_command(context, "addDirectory", tracks_dir, scan=True)

@when("I select the music directory at row {row:d}")
def step_select_music_directory(context, row):
    path = MUSIC_DIRECTORY_ROW % row
    assert wait_clickable(context.rpc, path), f"Music directory row {row} is not visible"
    _click(context, path)
    time.sleep(0.3)

@when("the scanning overlay is hidden")
def step_scanning_overlay_hidden(context):
    # Rescanning library may be slow
    assert wait_hidden(context.rpc, LIBRARY_SCAN_OVERLAY, timeout=10), "Library scanning overlay is still visible"

@when("I click the remove button for the music directory at row {row:d}")
def step_click_remove_music_directory(context, row):
    path = SOURCE_REMOVE_BUTTON % row
    assert wait_clickable(context.rpc, path), (
        f"Remove button for music directory row {row} is not visible"
    )
    _click(context, path)
    time.sleep(0.5)

@when("I choose to {action} the tracks of the music directory at row {row:d}")
def step_choose_track_handling(context, action, row):
    try:
        option_index = SOURCE_REMOVE_MODE_OPTIONS.index(action)
    except ValueError:
        raise ValueError(f"Unknown track handling action '{action}'")
    path = f"{SOURCE_REMOVE_MODE_SELECTOR % row}/option{option_index}"
    assert wait_clickable(context.rpc, path), (
        f"Track handling option '{action}' for music directory row {row} is not visible"
    )
    # Let the animation settle
    time.sleep(2)
    _click(context, path)

@when("I add the test music directory {directory_id}")
def step_add_test_music_directory(context, directory_id):
    path = context.music_dirs[directory_id]
    before = int(_get_property(context, MUSIC_DIRECTORY_LIST, "count"))
    # Route the "Add" button to the test dialog mock and inject the folder,
    # emulating a real folder picker selection. selectedFolder is a QML `url`
    # property and the QML model steps carry urls end-to-end, so we must bind
    # a real file URL: constructing one by string concatenation ("file://" +
    # path) is rejected by Qt on Windows (backslashes and only two slashes)
    # and silently yields an empty url. Path.as_uri() produces the correct,
    # percent-encoded file:// URL on every platform.
    _set_property(context, ADD_FOLDER_DIALOG_TEST, "testMode", "true")
    _set_property(context,
        ADD_FOLDER_DIALOG_TEST, "selectedFolder", Path(path).as_uri()
    )
    _click(context, ADD_SOURCE_BUTTON)
    deadline = time.time() + 10
    while time.time() < deadline:
        try:
            if int(_get_property(context, ADD_FOLDER_DIALOG_TEST, "openCount")) >= 1:
                break
        except Exception:
            pass
        time.sleep(0.3)
    else:
        raise AssertionError("The Add button did not open the dialog")
    ok, actual = _wait_for_music_directory_count(context, before + 1)
    assert ok, (
        f"Music directory '{directory_id}' did not appear in the list "
        f"(count stayed at {actual}, expected {before + 1})"
    )

@then("the music directory list should be empty")
def step_music_directory_list_empty(context):
    ok, actual = _wait_for_music_directory_count(context, 0)
    assert ok, (
        f"The music directory list should be empty but contains {actual}"
    )

@then("the music directory list should contain {count:d} source")
@then("the music directory list should contain {count:d} sources")
def step_music_directory_list_count(context, count):
    ok, actual = _wait_for_music_directory_count(context, count)
    assert ok, (
        f"The music directory list should contain {count} sources but "
        f"contains {actual}"
    )

@then("the library state should match the following")
def step_library_state_matches(context):
    expected = {}
    for row in context.table:
        expected[row["key"]] = _parse_library_state_expectation(row["value"])
    matched, last_state = _wait_for_library_state(context, expected)
    assert matched, (
        f"The library state should match {expected} but the last observed "
        f"state is {last_state}"
    )

@then("the {button} button of the music directory at row {row:d} should be visible")
def step_source_button_visible(context, button, row):
    path = SOURCE_REMOVE_BUTTON % row if button == "remove" else SOURCE_RELINK_BUTTON % row
    assert wait_clickable(context.rpc, path), (
        f"The {button} button for music directory row {row} is not visible"
    )
