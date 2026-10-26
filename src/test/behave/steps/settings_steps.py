import time
from helpers import (
    COMMITTING_OVERLAY,
    QT_CONTROL_MODIFIER,
    QT_KEY_A,
    QT_KEY_DOWN,
    QT_KEY_ENTER,
    QT_KEY_UP,
    SETTINGS_POPUP_ITEM,
    SETTING_CATEGORY_SLUG,
    TREE_NAMESPACED_PAGES,
    _active_button,
    _click,
    _click_active_button,
    _edge_path,
    _get_control_value,
    _get_property,
    _is_visible,
    _set_property,
    _setting_spec,
    _wait_for_hidden,
    _wait_for_visible,
)
from helpers import (
    wait_hidden,
    wait_visible,
)
from behave import given, when, then

# --- Path constants ---

SETTINGS_POPUP = "mainWindow/settingsPopup"
CATEGORY_LIST = f"{SETTINGS_POPUP_ITEM}/categoryList"
TAB_BAR = f"{SETTINGS_POPUP_ITEM}/tabBar"
SEARCH_SETTING = f"{SETTINGS_POPUP_ITEM}/searchSetting"
SEARCH_INPUT = f"{SETTINGS_POPUP_ITEM}/searchInput"
CATEGORIES_ITEM = f"{SETTINGS_POPUP_ITEM}/categories"
SHOW_CATEGORIES_BUTTON = f"{SETTINGS_POPUP_ITEM}/showCategories"

CATEGORY_SCROLLBARS_TEMPLATE = "mainWindow/%sSettingsScrollBar"
CATEGORY_SCROLLBARS = {
    index: (
        "mainWindow/settingsPopupItem/%sPage/scrollBar"
        if slug in TREE_NAMESPACED_PAGES
        else CATEGORY_SCROLLBARS_TEMPLATE
    ) % slug
    for index, slug in SETTING_CATEGORY_SLUG.items()
}
STATS_SECTION = "mainWindow/statsSection"


# Config keys written by saveInterface()/saveDeck() (see QmlConfigProxy).
CONFIG_SAVE_MAP = {
    "Main Mix": {
        "group": "[Config]",
        "key": "InhibitScreensaver",
        "expected": {"no": "0", "while running": "1", "while playing": "2"},
    },
    "disable screen saver": {
        "group": "[Config]",
        "key": "InhibitScreensaver",
        "expected": {"no": "0", "while running": "1", "while playing": "2"},
    },
    "slider range": {
        "group": "[Control]",
        "key": "RateRangePercent",
        "expected": lambda value: str(int(float(value.rstrip("%")))),
    },
    "slider orientation": {
        "group": "[Control]",
        "key": "RateDir",
        "expected": {"down": "", "up": "0"},
    },
    "track palette": {"group": "[Config]", "key": "TrackColorPalette"},
    # Interface category — waveform tab. See Interface.qml saveWaveform() and
    # QmlConfigProxy. Mixxx removes a config key whose value equals its
    # declared default, so assertions only use non-default values (or map
    # onto the empty string where a default is saved anyway).
    "end of track warning": {
        "group": "[Waveform]",
        "key": "EndOfTrackWarningTime",
        "expected": lambda value: str(int(float(value))),
    },
    "beat grid opacity": {
        "group": "[Waveform]",
        "key": "beatGridAlpha",
        "expected": lambda value: str(int(float(value))),
    },
    "default zoom level": {
        "group": "[Waveform]",
        "key": "DefaultZoom",
        # The feature's saved-as value is already in config form (zoom,
        # not the slider's zoom*10 display).
        "expected": lambda value: _format_double(float(value)),
    },
    "synchronise zoom level across waveforms": {
        "group": "[Waveform]",
        "key": "ZoomSynchronization",
        "expected": {"on": "1", "off": "0"},
    },
    "normalise waveform overview": {
        "group": "[Waveform]",
        "key": "OverviewNormalized",
        "expected": {"on": "1", "off": "0"},
    },
    "play marker position": {
        "group": "[Waveform]",
        "key": "PlayMarkerPosition",
        # The feature's saved-as value is already in config form (a 0..1
        # ratio, not the slider's percent display).
        "expected": lambda value: _format_double(float(value)),
    },
    "beats until next marker": {
        "group": "[Waveform]",
        "key": "UntilMarkShowBeats",
        "expected": {"on": "1", "off": "0"},
    },
    "time until next marker": {
        "group": "[Waveform]",
        "key": "UntilMarkShowTime",
        "expected": {"on": "1", "off": "0"},
    },
    "marker hint font size": {
        "group": "[Waveform]",
        "key": "UntilMarkTextPointSize",
        "expected": lambda value: str(int(value.split()[0])),
    },
    "global visual gain": {
        "group": "[Waveform]",
        "key": "VisualGain_0",
        # The feature's saved-as value is already in config form (a gain
        # factor, not the slider's percent display).
        "expected": lambda value: _format_double(float(value)),
    },
    "low visual gain": {
        "group": "[Waveform]",
        "key": "VisualGain_1",
        "expected": lambda value: _format_double(float(value)),
    },
    "medium visual gain": {
        "group": "[Waveform]",
        "key": "VisualGain_2",
        "expected": lambda value: _format_double(float(value)),
    },
    "high visual gain": {
        "group": "[Waveform]",
        "key": "VisualGain_3",
        "expected": lambda value: _format_double(float(value)),
    },
    "waveform type": {
        "group": "[Waveform]",
        "key": "WaveformType",
        # QmlWaveformDisplay::Type values, i.e. the legacy
        # WaveformWidgetType::Type ids.
        "expected": {
            "Filtered": "7",
            "HSV": "8",
            "RGB": "12",
            "Simple": "5",
            "Stacked": "16",
        },
    },
    # Computed from the stereo split / high details checkboxes
    # (QmlWaveformDisplay::Options bitmask). "none" removes the key
    # (QmlConfigProxy::set_waveformOptions), hence the empty string.
    "waveform options": {
        "group": "[Waveform]",
        "key": "waveform_options",
        "expected": {"stereo split": "1", "high details": "2", "none": ""},
    },
    # Library category — see Library.qml save() and QmlConfigProxy
    "Serato integration": {"group": "[Library]", "key": "ShowSeratoLibrary", "expected": {"on": "1", "off": "0"}},
    "synchronise metadata with file": {"group": "[Library]", "key": "SyncTrackMetadataExport", "expected": {"on": "1", "off": "0"}},
    "prefer relative path on playlist export": {"group": "[Library]", "key": "UseRelativePathOnExport", "expected": {"on": "1", "off": "0"}},
    "track duplicate distance": {"group": "[Library]", "key": "history_track_duplicate_distance", "expected": lambda value: str(int(float(value)))},
    "delete history playlist with less than": {"group": "[Library]", "key": "history_min_tracks_to_keep", "expected": lambda value: str(int(float(value)))},
    "search-as-you-type timeout": {"group": "[Library]", "key": "SearchDebouncingTimeoutMillis", "expected": lambda value: str(int(float(value) * 1000))},
    # Analyzer category — see Analyzer.qml save() and QmlConfigProxy.
    # Mixxx removes a config key whose value equals its declared default, so
    # assertions for default values map onto the empty string.
    "BPM detection": {"group": "[BPM]", "key": "BPMDetectionEnabled", "expected": {"on": "", "off": "0"}},
    "BPM analyser": {"group": "[Vamp]", "key": "AnalyserBeatPluginID", "expected": {"queenmary": "", "soundtouch": "mixxxbpmdetection"}},
    "assume constant tempo": {"group": "[BPM]", "key": "BeatDetectionFixedTempoAssumption", "expected": {"on": "", "off": "0"}},
    "re-analysis when settings change": {"group": "[BPM]", "key": "ReanalyzeWhenSettingsChange", "expected": {"on": "1", "off": ""}},
    "BPM fast analysis": {"group": "[BPM]", "key": "FastAnalysisEnabled", "expected": {"on": "1", "off": ""}},
    "re-analysis of beatgrids imported from other DJ software": {"group": "[BPM]", "key": "ReanalyzeImported", "expected": {"on": "1", "off": ""}},
    "key detection": {"group": "[Key]", "key": "KeyDetectionEnabled", "expected": {"on": "", "off": "0"}},
    "key analyser": {"group": "[Vamp]", "key": "AnalyserKeyPluginID", "expected": {"queenmary": "", "keyfinder": "keyfinder:2"}},
    "key fast analysis": {"group": "[Key]", "key": "FastAnalysisEnabled", "expected": {"on": "1", "off": ""}},
    "key re-analysis when settings change": {"group": "[Key]", "key": "ReanalyzeWhenSettingsChange", "expected": {"on": "1", "off": ""}},
    "key notation": {"group": "[Key]", "key": "KeyNotation", "expected": {"lancelot": "Lancelot", "traditional": "", "openkey": "OpenKey", "custom": "Custom"}},
    "ReplayGain normalization": {"group": "[ReplayGain]", "key": "ReplayGainEnabled", "expected": {"on": "", "off": "0"}},
    "ReplayGain analyser": {"group": "[ReplayGain]", "key": "ReplayGainAnalyserVersion", "expected": {"replaygain20": "", "replaygain10": "1"}},
    "ReplayGain target loudness": {"group": "[ReplayGain]", "key": "InitialReplayGainBoost", "expected": lambda value: str(int(float(value)))},
    "ReplayGain re-analysis": {"group": "[ReplayGain]", "key": "ReplayGainReanalyze", "expected": {"on": "1", "off": ""}},
    "ReplayGain default boost": {"group": "[ReplayGain]", "key": "InitialDefaultBoost", "expected": lambda value: str(int(float(value)))},
}

# ControlObject side-effects of saveDeck().
CONTROL_VALUE_MAP = {
    "slider range": {"key": "rateRange", "expected": lambda value: float(value.rstrip("%"))/100},
    "slider orientation": {"key": "rate_dir", "expected": {"down": -1, "up": 1}},
}

WAVEFORM_SETTINGS_TAB_PATH = "mainWindow/waveformSettingsTab"


WAVEFORM_TYPE_IDS = [  # as stored by QmlWaveformDisplay::Type
    "Filtered",
    "HSV",
    "RGB",
    "Simple",
    "Stacked",
]

# --- Helpers ---

def _format_double(value):
    """Format a double the way ConfigObject does (QString::number, 'g', 6)."""
    return format(value, ".6g")

def _settings_path(*parts):
    return "/".join([SETTINGS_POPUP_ITEM] + list(parts))


def _setting_option_visible(context, path):
    try:
        return _is_visible(context, path)
    except Exception:
        return False


def _get_config_value(context, group, key):
    context.rpc.command("getConfigValue", f"{group},{key}")
    return _get_property(context, "mainWindow", "lastConfigValue")


def _category_path(label):
    return f"{SETTINGS_POPUP_ITEM}/category_{label}"


def _tab_path(name):
    return f"{TAB_BAR}/tab_{name}"


def _tap(context, path):
    """Slow left-tap (250 ms hold) for TapHandler-driven controls.

    A plain synthetic click posts the press and release almost back-to-back,
    which Qt's TapHandler can miss when the machine is under load (e.g. a CI
    runner that is also capturing video). A short hold lets the press be fully
    delivered before the release, so the tap is recognised reliably.
    """
    context.rpc.mouseClickAndHold(path, 1, 0, 250)


# --- Given steps ---

@given("the settings popup is open")
def step_settings_popup_open(context):
    if not _is_visible(context, SETTINGS_POPUP_ITEM):
        _click(context, "mainWindow/showPreferencesButton")
        # Sometimes pretty slow on Windows Server CI runner
        assert wait_visible(context.rpc, SETTINGS_POPUP_ITEM, timeout=10), "Settings popup did not open"
        time.sleep(0.5)


@given('the "{category}" category is selected')
def step_category_selected(context, category):
    path = _category_path(category)
    _wait_for_visible(context, path)
    index = _get_property(context, path, "index")
    _set_property(context, CATEGORY_LIST, "currentIndex", index)
    time.sleep(0.3)


@given('the "{tab}" tab is selected')
def step_tab_selected(context, tab):
    path = _tab_path(tab)
    _wait_for_visible(context, path)
    _click(context, path)
    time.sleep(0.3)


@given('the "{setting}" setting is "{value}"')
def step_setting_is(context, setting, value):
    spec = _setting_spec(setting)
    if spec["kind"] != "ratio":
        raise ValueError(f"Cannot preset non-ratio setting: {setting}")
    _set_property(context, spec["path"], "selected", value)
    time.sleep(0.3)
    step_click_action(context, 'save')
    # Certain operation may take more than 5 second to apply, such as the ALSA API switch
    _wait_for_hidden(context, COMMITTING_OVERLAY, timeout=10)
    # Verify the preset survived the save, so scenarios do not build on
    # silent no-op preconditions.
    _assert_setting_value_matches(context, setting, spec, value)


@given("I have the following sound devices")
def step_register_mock_devices(context):
    context._soundMockDevices = []
    for row in context.table:
        context._soundMockDevices.append({
            "name": row["name"],
            "api": row.get("api", "Mock"),
            "outputChannels": int(row.get("outputChannels", 0)),
            "inputChannels": int(row.get("inputChannels", 0)),
        })


# --- When steps ---

@when("I click the settings close button")
def step_click_close_button(context):
    _click(context, f"{SETTINGS_POPUP_ITEM}/settingsCloseButton")
    time.sleep(0.3)


@when('I select the "{category}" category')
def step_select_category(context, category):
    path = _category_path(category)
    assert wait_visible(context.rpc, path), f"Category '{category}' not visible"
    index = _get_property(context, path, "index")
    _set_property(context, CATEGORY_LIST, "currentIndex", index)
    time.sleep(0.3)


@when('I click the "{tab}" tab')
def step_click_tab(context, tab):
    path = _tab_path(tab)
    assert wait_visible(context.rpc, path), f"Tab '{tab}' not visible"
    _click(context, path)
    time.sleep(0.3)


@when('I toggle the "{setting}" setting to "{value}"')
@when('I set the "{setting}" setting to "{value}"')
@when('I toggle the "{setting}" setting to "{value}" with {method}')
@when('I set the "{setting}" setting to "{value}" with {method}')
def step_set_setting(context, setting, value, method=None):
    spec = _setting_spec(setting)
    path = spec["path"]
    _scroll_setting_into_view(context, path)
    kind = spec["kind"]
    if kind == "ratio":
        options = spec.get("options")
        if not options:
            raise ValueError(
                f"Ratio setting '{setting}' has no options mapping; "
                "cannot resolve a clickable option"
            )
        try:
            index = options.index(value)
        except ValueError:
            raise ValueError(f"Setting '{setting}' has no option '{value}'")
        option_path = f"{path}/option{index}"
        if _setting_option_visible(context, option_path):
            _click(context, option_path)
        else:
            # Maximum 40 attempts
            for _ in range(40):
                current = _get_property(context, path, "selected")
                # contentSpin (compacted) mode: the options are not individually
                # clickable, so drive the SpinBox next/prev buttons (real user
                # input) the needed number of times from the current selection.
                try:
                    current_idx = options.index(current)
                except ValueError:
                    raise RuntimeError(
                        f"Setting '{setting}' (in path {repr(path)}) current '{current}' not in options (out of {', '.join(options)})"
                    )
                delta = index - current_idx
                if delta == 0: break
                button = f"{path}/nextButton" if delta > 0 else f"{path}/prevButton"
                assert wait_visible(context.rpc, button), (
                    f"Setting '{setting}' next/prev button not visible"
                )
                _click(context, button)
                time.sleep(1)
    elif kind == "combo":
        try:
            index = spec["model"].index(value)
        except (ValueError, AttributeError):
            raise ValueError(f"Setting '{setting}' has no option '{value}'")
        assert wait_visible(context.rpc, path), f"Setting '{setting}' control not visible"
        _click(context, path)
        option_path = f"{path}_option_{index}"
        in_view = bool(wait_visible(context.rpc, option_path)) and _scroll_combo_option_into_view(
            context, path, index
        )
        if in_view:
            _click(context, option_path)
        else:
            _combo_select_keyboard(context, path, index)
    elif kind == "spinbox":
        precision = spec.get("precision", 0)
        step = 1.0 / (10 ** precision)
        # Maximum 40 attempts
        for _ in range(40):
            current = float(_get_property(context, path, "realValue"))
            target = float(value)
            clicks = int(round((target - current) / step))
            if clicks == 0: break
            button = f"{path}/upButton" if clicks > 0 else f"{path}/downButton"
            assert wait_visible(context.rpc, button), f"Setting '{setting}' button not visible"
            _click(context, button)
            time.sleep(1)
    elif kind == "slider":
        method = method or "a drag"
        if method == "a drag":
            _drag_slider_handle(context, spec, value)
        elif method == "the spinbox":
            assert wait_visible(context.rpc, f"{path}/Value"), (
                f"Setting '{setting}' value field not visible"
            )
            _enter_text_value(context, f"{path}/Value", value)
        else:
            raise ValueError(f"Unsupported method '{method}' for slider")
    elif kind == "color":
        option_path = f"{path}_color_{value}"
        assert wait_visible(context.rpc, option_path), (
            f"Setting '{setting}' color '{value}' not visible"
        )
        _click(context, option_path)
    else:
        raise ValueError(f"Unknown setting kind: {kind}")
    # Prove the change actually took effect; a stuck control fails here
    # instead of at a later (or missing) Then. The bounded poll returns as
    # soon as the value matches instead of always burning a fixed sleep.
    _wait_for_setting_value(context, setting, spec, value)


@when("I click the {button} button")
def step_click_action(context, button):
    _click_active_button(context, button)


@when('I search for "{text}"')
def step_search_settings(context, text):
    _tap(context, SEARCH_SETTING)
    if not _wait_for_search_active(context):
        _tap(context, SEARCH_SETTING)
    time.sleep(0.3)
    context.rpc.inputText(SEARCH_INPUT, text)
    time.sleep(0.5)


def _wait_for_search_active(context, timeout=2):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if _get_property(context, SEARCH_SETTING, "active") == "true":
                return True
        except Exception:
            pass
        time.sleep(0.1)
    return False


@when('I connect the "{source_edge}" edge on "{source_entity}" to the "{sink_edge}" edge on "{sink_entity}"')
def step_connect_edge_to_edge(context, source_edge, source_entity, sink_edge, sink_entity):
    source_path = _edge_path(source_entity, source_edge)
    assert wait_visible(context.rpc, source_path), f"Source edge {source_edge} on {source_entity} not visible"
    _click(context, source_path)
    time.sleep(0.5)
    sink_path = _edge_path(sink_entity, sink_edge)
    assert wait_visible(context.rpc, sink_path), f"Sink edge {sink_edge} on {sink_entity} not visible"
    _click(context, sink_path)
    time.sleep(0.5)


# --- Then steps ---

@then("the settings popup should be visible")
def step_settings_visible(context):
    assert wait_visible(context.rpc, SETTINGS_POPUP_ITEM), "Settings popup is not visible"


@then("the settings popup should not be visible")
def step_settings_not_visible(context):
    assert wait_hidden(context.rpc, SETTINGS_POPUP_ITEM), "Settings popup is still visible"


@then('the "{category}" category should be selected')
def step_category_should_be_selected(context, category):
    path = _category_path(category)
    assert _is_visible(context, path), f"Category '{category}' is not visible"
    expected = _get_property(context, path, "index")
    actual = _get_property(context, CATEGORY_LIST, "currentIndex")
    assert actual == expected, (
        f"Category '{category}' should be selected (index {expected}) "
        f"but the selected index is {actual}"
    )


@then('the "{tab}" tab should be visible')
def step_tab_visible(context, tab):
    path = _tab_path(tab)
    assert _is_visible(context, path), f"Tab '{tab}' is not visible"


@then('the "{tab}" tab should be selected')
def step_tab_selected_then(context, tab):
    path = _tab_path(tab)
    assert wait_visible(context.rpc, path), f"Tab '{tab}' not visible"
    checked = _get_property(context, path, "checked")
    assert checked == "true", f"Tab '{tab}' should be selected but checked={checked}"


def _button_is_enabled(context, path):
    """Read the ``enabled`` property, failing loudly when it is missing.

    Treating an unreadable property as ``false`` used to make a ``should be
    disabled`` assertion pass vacuously (e.g. after the button disappeared).
    """
    enabled = _get_property(context, path, "enabled")
    assert enabled in ("true", "false"), (
        f"Cannot read 'enabled' of '{path}' (got '{enabled}')"
    )
    return enabled == "true"


@then("the {button} button should be enabled")
def step_button_enabled(context, button):
    path = _active_button(context, button)
    assert _button_is_enabled(context, path), f"{button.title()} button is not enabled"


@then("the {button} button should be disabled")
def step_button_disabled(context, button):
    path = _active_button(context, button)
    assert not _button_is_enabled(context, path), f"{button.title()} button is not disabled"


@then("the {button} button should be visible")
def step_button_visible(context, button):
    path = _active_button(context, button)
    assert _is_visible(context, path), f"{button.title()} button is not visible"


@then("the {button} button should not be visible")
def step_button_not_visible(context, button):
    path = _active_button(context, button)
    assert not _is_visible(context, path), f"{button.title()} button is visible"


def _wait_for_setting_value(context, setting, spec, value, timeout=3):
    """Poll the setting until it matches ``value`` (bounded settle wait).

    Equivalent to a fixed sleep followed by :func:`_assert_setting_value_matches`,
    but returns as soon as the value settles and keeps the same failure
    message when the timeout expires.
    """
    deadline = time.time() + timeout
    while True:
        try:
            _assert_setting_value_matches(context, setting, spec, value)
            return
        except AssertionError as err:
            last_error = err
        if time.time() >= deadline:
            raise last_error
        time.sleep(0.1)


def _assert_setting_value_matches(context, setting, spec, value):
    """Assert the setting control's current value matches ``value``.

    Shared by the ``should be`` Then step and by the When/Given steps that
    change a setting, so a change that silently did not happen fails right
    where it was made instead of at a later (or missing) assertion.
    """
    assert wait_visible(context.rpc, spec['path']), "Unable to find setting"
    actual = _read_setting_value(context, spec)
    kind = spec["kind"]
    if kind == "combo":
        try:
            expected_index = str(spec["model"].index(value))
        except (ValueError, AttributeError):
            raise ValueError(f"Setting '{setting}' has no option '{value}'")
        assert actual == expected_index, (
            f"Setting '{setting}' should be '{value}' (index {expected_index}) "
            f"but is index '{actual}'"
        )
    elif kind == "slider":
        tolerance = min(1.0, 0.01 * (spec["max"] - spec["min"]))
        diff = abs(float(actual) - float(value))
        assert diff <= tolerance, (
            f"Setting '{setting}' should be '{value}' but is '{actual}' "
            f"(diff {diff} > tolerance {tolerance})"
        )
    else:
        assert actual == value, f"Setting '{setting}' ({repr(spec['path'])}) should be '{value}' but is '{actual}'"


@then('the "{setting}" setting should be "{value}"')
def step_setting_should_be(context, setting, value):
    _assert_setting_value_matches(context, setting, _setting_spec(setting), value)


@then('the "{setting}" setting should be enabled')
def step_setting_should_be_enabled(context, setting):
    spec = _setting_spec(setting)
    actual = _get_property(context, spec["path"], "enabled")
    assert actual == "true", f"Setting '{setting}' should be enabled but enabled={actual}"


@then('the "{setting}" setting should be disabled')
def step_setting_should_be_disabled(context, setting):
    spec = _setting_spec(setting)
    actual = _get_property(context, spec["path"], "enabled")
    assert actual == "false", f"Setting '{setting}' should be disabled but enabled={actual}"


@then('the "{setting}" should be saved as "{value}"')
def step_setting_saved_as(context, setting, value):
    spec = CONFIG_SAVE_MAP.get(setting)
    if not spec:
        raise ValueError(f"No config mapping for setting: {setting}")
    actual = _get_config_value(context, spec["group"], spec["key"])
    expected = spec["expected"]
    if callable(expected):
        expected = expected(value)
    elif isinstance(expected, dict):
        expected = expected[value]
    assert actual == expected, (
        f"Config for '{setting}' ([{spec['group']}],{spec['key']}) should be saved as '{value}' but is '{actual}'"
    )


@then('the "{setting}" config key should be unset')
def step_setting_key_unset(context, setting):
    spec = CONFIG_SAVE_MAP.get(setting)
    if not spec:
        raise ValueError(f"No config mapping for setting: {setting}")
    actual = _get_config_value(context, spec["group"], spec["key"])
    assert actual == "", (
        f"Config key '{spec['group']},{spec['key']}' should be unset but is '{actual}'"
    )


@then('the "{setting}" should be saved')
def step_setting_saved(context, setting):
    spec = CONFIG_SAVE_MAP.get(setting)
    if not spec:
        raise ValueError(f"No config mapping for setting: {setting}")
    actual = _get_config_value(context, spec["group"], spec["key"])
    widget = _setting_spec(setting)
    current = _get_property(context, widget["path"], "currentText")
    assert actual == current, (
        f"Config for '{setting}' should be saved as '{current}' but is '{actual}'"
    )


@then('the "{setting}" on deck {deck:d} should be "{value}"')
def step_setting_control(context, setting, deck, value):
    spec = CONTROL_VALUE_MAP.get(setting)
    if not spec:
        raise ValueError(f"No control mapping for setting: {setting}")
    actual = _get_control_value(context, f"[Channel{deck}]", spec["key"])
    expected = spec["expected"]
    if callable(expected):
        expected = expected(value)
    elif isinstance(expected, dict):
        expected = expected[value]
    assert abs(actual - expected) < 1e-6, (
        f"Setting '{setting}' on deck {deck} should be '{value}'({expected}) but is '{actual}'"
    )


@then("the search results should be visible")
def step_search_results_visible(context):
    result_list = f"{SETTINGS_POPUP_ITEM}/settingResultList"
    assert wait_visible(context.rpc, result_list, timeout=10), "Search results are not visible"


valid = None
# --- Waveform tab live feedback ---
#
# Property reads on two objectName-proxied levels (see the constants at the
# top): the live waveform preview inside the settings popup, which values the
# settings' own renderer bindings, and the deck waveforms of
# res/qml/WaveformDisplay.qml, which consume the persisted Mixxx.Config
# values.


@then('the "{setting}" setting should not be visible')
def step_setting_not_visible(context, setting):
    spec = _setting_spec(setting)
    assert wait_hidden(context.rpc, spec["path"]), f"Setting '{setting}' is still visible"

# --- Responsiveness steps ---


def _active_scrollbar(context):
    idx = int(_get_property(context, SETTINGS_POPUP_ITEM, "activeCategoryIndex"))
    bar = CATEGORY_SCROLLBARS.get(idx)
    assert bar, f"No known vertical scrollbar for active category index {idx}"
    return bar


def _scroll_setting_into_view(context, path):
    """Scroll the active settings category so that the item at ``path`` is
    fully inside the visible scroll viewport, mirroring a user scrolling to
    reach a below-the-fold setting."""
    bar = _active_scrollbar(context)
    try:
        size = float(_get_property(context, bar, "size") or 0)
    except ValueError:
        size = 0
    if size >= 1.0:
        return
    max_value = 1.0 - size
    deadline = time.time() + 8
    while time.time() < deadline:
        try:
            x, y, w, h = context.rpc.getBoundingBox(path)
            bx, by, bw, bh = context.rpc.getBoundingBox(bar)
        except Exception:
            return
        if y >= by and y + h <= by + bh:
            return
        target = max_value if y + h > by + bh else 0.0
        _set_property(context, bar, "position", str(target))
        time.sleep(0.3)


@then("the settings categories should {assertion} visible")
def step_settings_categories_visible(context, assertion):
    expected = assertion == "be"
    assert _is_visible(context, CATEGORIES_ITEM) is expected, (
        f"Settings categories should {assertion} visible"
    )


@then("the button to reveal the categories should {assertion} visible")
def step_categories_button_visible(context, assertion):
    expected = assertion == "be"
    assert _is_visible(context, SHOW_CATEGORIES_BUTTON) is expected, (
        f"Categories button should {assertion} visible"
    )


@when("I click the button to reveal the categories")
def step_click_categories_button(context):
    assert wait_visible(context.rpc, SHOW_CATEGORIES_BUTTON), "Categories button is not visible"
    _click(context, SHOW_CATEGORIES_BUTTON)
    time.sleep(0.3)


@then('the "{setting}" setting should be visible')
def step_setting_visible(context, setting):
    spec = _setting_spec(setting)
    assert wait_visible(context.rpc, spec["path"]), f"Setting '{setting}' is not visible"


@then('the "{setting}" setting should be expanded')
def step_setting_expanded(context, setting):
    spec = _setting_spec(setting)
    assert wait_visible(context.rpc, f"{spec['path']}/option0"), (
        f"Setting '{setting}' should be expanded but its option pills are not visible"
    )


LIBRARY_GRIDS = {
    "Library sources": "mainWindow/librarySourcesGrid",
    "Library integrations": "mainWindow/libraryIntegrationsGrid",
    "Library metadata": "mainWindow/libraryMetadataGrid",
    "Library history": "mainWindow/libraryHistoryGrid",
    # Analyzer page grids (objectNamespaced paths)
    "BPM analyzer": "mainWindow/settingsPopupItem/analyzerPage/bpm/grid",
    "key analyzer": "mainWindow/settingsPopupItem/analyzerPage/key/grid",
    "ReplayGain analyzer": "mainWindow/settingsPopupItem/analyzerPage/replayGain/grid",
}


@then('the {grid} grid should be displayed in {columns:d} columns')
@then('the {grid} grid should be displayed in {columns:d} column')
def step_grid_columns(context, grid, columns):
    path = LIBRARY_GRIDS.get(grid, f"mainWindow/{grid}")
    assert wait_visible(context.rpc, path), f"Grid '{grid}' is not visible"
    actual = int(_get_property(context, path, "columns"))
    assert actual == columns, (
        f"Grid '{grid}' should be displayed in {columns} columns but has {actual}"
    )


SPATIAL_ITEM_PATHS = {
    "integrations grid": "mainWindow/libraryIntegrationsGrid",
    "library source pane": "mainWindow/librarySourcePane",
}


@then('the {item} should be below the {target}')
def step_below(context, item, target):
    item_path = SPATIAL_ITEM_PATHS[item]
    target_path = SPATIAL_ITEM_PATHS[target]
    # Hidden or zero-sized items make the geometric comparison below vacuous
    # (e.g. a 0x0 box trivially lies "below" anything), so require both to be
    # really on screen first.
    assert _is_visible(context, item_path), f"'{item}' is not visible"
    assert _is_visible(context, target_path), f"'{target}' is not visible"
    item_bb = context.rpc.getBoundingBox(item_path)
    target_bb = context.rpc.getBoundingBox(target_path)
    assert item_bb[1] >= target_bb[1] + target_bb[3], (
        f"'{item}' is not below '{target}' "
        f"(item_top={item_bb[1]}, target_bottom={target_bb[1] + target_bb[3]})"
    )


@then('the {item} should not overlap the {target}')
def step_not_overlap(context, item, target):
    item_path = SPATIAL_ITEM_PATHS[item]
    target_path = SPATIAL_ITEM_PATHS[target]
    assert _is_visible(context, item_path), f"'{item}' is not visible"
    assert _is_visible(context, target_path), f"'{target}' is not visible"
    a = context.rpc.getBoundingBox(item_path)
    b = context.rpc.getBoundingBox(target_path)
    overlap_x = a[0] < b[0] + b[2] and a[0] + a[2] > b[0]
    overlap_y = a[1] < b[1] + b[3] and a[1] + a[3] > b[1]
    assert not (overlap_x and overlap_y), (
        f"'{item}' overlaps '{target}' "
        f"(item=({a[0]},{a[1]},{a[2]},{a[3]}), target=({b[0]},{b[1]},{b[2]},{b[3]}))"
    )


@then('the "{setting}" setting should be compacted')
def step_setting_compacted(context, setting):
    spec = _setting_spec(setting)
    assert wait_visible(context.rpc, f"{spec['path']}/nextButton"), (
        f"Setting '{setting}' should be compacted but its spinbox buttons are not visible"
    )


@when("I scroll down in the settings")
def step_scroll_down_settings(context):
    bar = _active_scrollbar(context)
    assert wait_visible(context.rpc, bar), "The vertical scrollbar is not visible (nothing to scroll)"
    before = _get_property(context, bar, "position")

    # 1) Real interaction: a click on the scrollbar groove.
    context.rpc.mouseClickWithProportion(bar, 0.5, 0.9)
    time.sleep(0.5)
    if _get_property(context, bar, "position") != before:
        return

    # 2) Real interaction: a drag on the scrollbar. spix has no wheel API,
    #    so a drag is the closest real-interaction equivalent of a wheel
    #    spin. mouseDrag deltas are item-local pixels (see spix Drag.cpp).
    bar_height = context.rpc.getBoundingBox(bar)[3]
    context.rpc.mouseDrag(bar, 0.5, 0.2, 0, bar_height * 0.5, 300)
    time.sleep(0.5)
    if _get_property(context, bar, "position") != before:
        return

    # 3) Last resort: drive the scrollbar position directly. This bypasses
    #    the UI and only covers environments where the synthetic events do
    #    not reach the scrollbar; the warning keeps the bypass visible in
    #    the transcript/video.
    print(
        "WARNING: 'I scroll down in the settings' fell back to writing the "
        "scrollbar position directly (synthetic click and drag had no effect)"
    )
    _set_property(context, bar, "position", str(1.0 - float(_get_property(context, bar, "size"))))
    time.sleep(0.5)


@then('the "{setting}" setting should {assertion} visible on screen')
def step_setting_on_screen(context, setting, assertion):
    spec = _setting_spec(setting)
    expected = assertion == "be"
    assert wait_visible(context.rpc, spec["path"]), f"Setting '{setting}' is not present"
    setting_bb = context.rpc.getBoundingBox(spec["path"])
    bar = _active_scrollbar(context)
    bar_bb = context.rpc.getBoundingBox(bar) if _is_visible(context, bar) else None
    on_screen = True
    if bar_bb and bar_bb[2] > 0 and bar_bb[3] > 0:
        _, setting_y, _, setting_h = setting_bb
        _, bar_y, _, bar_h = bar_bb
        on_screen = setting_y + setting_h > bar_y and setting_y < bar_y + bar_h
    assert on_screen is expected, (
        f"Setting '{setting}' should {assertion} visible on screen"
    )


# --- Internal helpers ---


def _value_to_ratio(value, minv, maxv, markers):
    """Port of Slider.qml valueToRatio (markers-aware inverse mapping)."""
    if not markers:
        return (value - minv) / (maxv - minv)
    m = list(markers)
    if m[-1] != maxv:
        m.append(maxv)
    value_count = len(m) - 1
    step_idx = 0
    for step in m:
        if step >= value:
            break
        step_idx += 1
    step_idx = min(step_idx - 1, value_count - 1)
    delta = m[step_idx + 1] - m[step_idx]
    return (step_idx + (value - m[step_idx]) / delta) / value_count


def _drag_slider_handle(context, spec, value):
    """Drag the slider handle (real user input) to set an approximate value.

    Mirrors the deck "component move" drag: begin a drag on the {path}/Handler
    and drop it at the target ratio position along the {path}/Track. Lands
    within ~1-2px, so the caller asserts with tolerance.
    """
    path = spec["path"]
    handler = f"{path}/Handler"
    track = f"{path}/Track"
    assert wait_visible(context.rpc, handler), f"Slider handle not visible at {handler}"
    assert wait_visible(context.rpc, track), f"Slider track not visible at {track}"
    target_vp = _value_to_ratio(
        float(value), spec["min"], spec["max"], spec.get("markers", [])
    )
    context.rpc.mouseBeginDrag(handler, 0.5, 0.5, track, target_vp, 0.5)
    context.rpc.mouseEndDrag(handler)
    time.sleep(0.5)


def _enter_text_value(context, path, value):
    """Type an exact value into an editable value field (real user input).

    Click to focus, select all, type the value, and commit with Enter. Used by
    the slider 'with the spinbox' method (the right-hand numeric field).
    """
    _click(context, path)
    time.sleep(0.2)
    context.rpc.enterKey("mainWindow", QT_KEY_A, QT_CONTROL_MODIFIER)
    context.rpc.wait(100)
    context.rpc.inputText(path, value)
    context.rpc.wait(100)
    context.rpc.enterKey("mainWindow", QT_KEY_ENTER, 0)
    time.sleep(0.3)


def _scroll_combo_option_into_view(context, path, index):
    """Scroll the combo popup's list so that the option at ``index`` is fully
    inside the visible list viewport, mirroring a user wheel-spinning the
    popup to reach the option before clicking it.

    The popup's ListView (``<path>_popupList``, named in ComboBox.qml) only
    instantiates delegates inside its viewport, so an option above or below
    the fold either has no bounding box yet or is clipped. Scroll by driving
    the list's ``contentY``, computing the shift from both bounding boxes
    (option vs. list), iterating until the option is contained in view or a
    bounded deadline runs out.

    Returns True when the option is clickable in view; False when the popup
    list is not reachable or the option could not be brought in view (the
    caller then falls back to keyboard selection).
    """
    list_path = f"{path}_popupList"
    option_path = f"{path}_option_{index}"
    deadline = time.time() + 8
    while time.time() < deadline:
        try:
            content_y = float(_get_property(context, list_path, "contentY") or 0)
            content_height = float(_get_property(context, list_path, "contentHeight") or 0)
            lx, ly, lw, lh = context.rpc.getBoundingBox(list_path)
        except Exception:
            # Popup list not reachable (popup closed, or the combo does not
            # use the shared Skin.ComboBox popup with a named list).
            return False
        max_y = max(0.0, content_height - lh)
        option_bb = None
        try:
            option_bb = context.rpc.getBoundingBox(option_path)
        except Exception:
            pass
        if option_bb is None or option_bb[2] <= 0 or option_bb[3] <= 0:
            # A zero-sized (or failed) bounding box means the delegate is not
            # instantiated yet. Scroll toward the list end so it is created;
            # give up when there is nothing left to scroll.
            if max_y <= 0.0 or content_y >= max_y:
                return False
            _set_property(context, list_path, "contentY", str(max_y))
            time.sleep(0.3)
            continue
        _, oy, _, oh = option_bb
        if lw <= 0 or lh <= 0:
            return False
        if oy >= ly and oy + oh <= ly + lh:
            return True
        if oy + oh > ly + lh:
            # Below the fold: scroll down by the overshoot.
            shift = (oy + oh) - (ly + lh)
        else:
            # Above the fold: scroll up by the overshoot.
            shift = -(ly - oy)
        target_y = max(0.0, min(content_y + shift, max_y))
        if abs(target_y - content_y) < 1.0:
            # Already at the scroll limit (or sub-pixel movement): the
            # option may still be clickable if its center is in the
            # viewport; otherwise the click would land on a clipped item.
            center = oy + oh / 2
            if ly <= center <= ly + lh:
                return True
            return False
        _set_property(context, list_path, "contentY", str(target_y))
        time.sleep(0.3)
    return False


def _combo_select_keyboard(context, path, index):
    """Select a combo option via keyboard when its delegate is not rendered.

    The ComboBox popup only creates `popupMaxItem` (6) delegates, so options
    beyond that index have no objectName path to click. Keyboard events are
    posted to the window and follow normal Qt focus routing into the open
    popup (same pattern as the column picker step).
    """
    highlighted = int(_get_property(context, path, "highlightedIndex"))
    if highlighted == -1:
        context.rpc.enterKey("mainWindow", QT_KEY_DOWN, 0)
        context.rpc.wait(200)
        highlighted = int(_get_property(context, path, "highlightedIndex"))
    key = QT_KEY_DOWN if index > highlighted else QT_KEY_UP
    for _ in range(abs(index - highlighted)):
        context.rpc.enterKey("mainWindow", key, 0)
        context.rpc.wait(200)
    time.sleep(0.3)
    context.rpc.enterKey("mainWindow", QT_KEY_ENTER, 0)
    time.sleep(0.3)


def _read_setting_value(context, spec):
    kind = spec["kind"]
    if kind == "ratio":
        return _get_property(context, spec["path"], "selected")
    if kind == "combo":
        return _get_property(context, spec["path"], "currentIndex")
    if kind == "spinbox":
        return _get_property(context, spec["path"], "realValue")
    if kind == "slider":
        return _get_property(context, spec["path"], "value")
    if kind == "color":
        return _get_property(context, spec["path"], "currentIndex")
    raise ValueError(f"Unknown setting kind: {kind}")
