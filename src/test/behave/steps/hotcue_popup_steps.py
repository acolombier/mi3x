# -----------------------------------------------------------------------
# Drafted autonomously by an AI agent (for a human reviewer to check,
# amend, and submit).
# -----------------------------------------------------------------------
import json
import time

from behave import given, then, when
from spix_helpers import (
    QT_KEY_ENTER,
    QT_RIGHT_BUTTON,
    wait_visible,
)

QT_KEY_ESCAPE = 0x01000000

# The hotcue popup is re-parented to the window overlay when opened, where
# it is reachable through its generated QQuickPopupItem ("HotcuePopup");
# the popup's own content tree hangs under its "hotcuePopupContent<uid>"
# node. Every popup-internal objectName is suffixed with "<uid>" (deck
# group + hotcue number) because every HotcueButton instantiates its own
# popup with identical child names.
POPUP_POPUP_ITEM = "mainWindow/HotcuePopup"

POPUP_BUTTON_NAMES = {
    "delete": "hotcuePopupDeleteButton",
    "swap": ("waveform", "hotcuePopupSwapButton"),
    "previous type": "hotcuePopupTypePrev",
    "next type": "hotcuePopupTypeNext",
}

HOTCUE_TYPE_VALUES = {"CUE": 1, "LOOP": 4, "JUMP": 5}
HOTCUE_TYPE_NAMES = {value: name for name, value in HOTCUE_TYPE_VALUES.items()}
MAX_ZOOM = 10.0
MIN_ZOOM = 1.0


def _uid(context, hotcue=None, deck=None):
    hotcue = hotcue or getattr(context, "_popup_hotcue", 1)
    deck = deck or getattr(context, "_popup_deck", 1)
    return f"[Channel{deck}]-{hotcue}"


def _popup(context, name, hotcue=None, deck=None):
    """Path of a named element inside the opened hotcue popup.

    Only the content node carries the instance uid, so every child lookup
    must start from "HotcuePopup/hotcuePopupContent<uid>" and then use plain
    child objectNames (unique within the popup content subtree).
    """
    if name.startswith("hotcuePopupContent"):
        return f"{POPUP_POPUP_ITEM}/{name}{_uid(context, hotcue, deck)}"
    return f"{_popup(context, 'hotcuePopupContent', hotcue, deck)}/{name}"


def _waveform(context, name, hotcue=None, deck=None):
    """Path of a named element inside the popup waveform patch."""
    return f"{_popup(context, 'hotcuePopupWaveform', hotcue, deck)}/{name}"


def _rpc(context):
    return context.mixxx_rpc


def _click(context, path):
    _rpc(context).mouseClick(path)


def _wait_for_visible(context, path, timeout=5):
    wait_visible(_rpc(context), path, timeout)


def _get_property(context, path, prop):
    return _rpc(context).getStringProperty(path, prop)


def _get_bool(context, path, prop):
    value = _get_property(context, path, prop)
    return value in (True, "true", "1")


def _get_control_value(context, group, key):
    rpc = _rpc(context)
    rpc.command("getControlValue", f"{group},{key}")
    return float(rpc.getStringProperty("mainWindow", "lastControlValue"))


def _set_control_value(context, group, key, value):
    _rpc(context).command("setControlValue", f"{group},{key},{value}")


def _get_bb(context, path):
    value = _rpc(context).getBoundingBox(path)
    if isinstance(value, str):
        value = json.loads(value)
    keys = ("x", "y", "width", "height")
    return dict(zip(keys, (float(v) for v in value)))


def _is_open(context, hotcue=None, deck=None):
    # The Popup object itself is not reachable as an Item by spix, so "open"
    # is recognized through the visibility of the popup content tree
    return _get_bool(context, _popup(context, "hotcuePopupContent", hotcue, deck), "visible")


def _remember(context, key, value):
    context._remembered_hc = getattr(context, "_remembered_hc", {})
    context._remembered_hc[key] = value


# --- Given: popup state ---


@given("the hotcue popup is open for hotcue {hotcue:d} on deck {deck:d}")
def step_given_popup_open(context, hotcue, deck):
    context._popup_hotcue = hotcue
    context._popup_deck = deck
    _rpc(context).mouseClickWithButton(
        f"mainWindow/deck{deck}/hotcue_{hotcue}", QT_RIGHT_BUTTON, 0
    )
    _wait_for_visible(context, _popup(context, "hotcuePopupContent"))


@given("hotcue {hotcue:d} is set on deck {deck:d}")
def step_given_hotcue_set(context, hotcue, deck):
    context._popup_hotcue = hotcue
    context._popup_deck = deck
    group = f"[Channel{deck}]"
    status = _get_control_value(context, group, f"hotcue_{hotcue}_status")
    if status == 0:
        path = f"mainWindow/deck{deck}/hotcue_{hotcue}"
        _click(context, path)
        status = _get_control_value(context, group, f"hotcue_{hotcue}_status")
        if status == 0:
            # Last resort: mark the hotcue as set via its status control
            _set_control_value(context, group, f"hotcue_{hotcue}_status", 1)
            status = _get_control_value(context, group, f"hotcue_{hotcue}_status")
            assert status != 0, f"hotcue_{hotcue} could not be set (status={status})"


@given('the hotcue popup label shows "{text}" for hotcue {hotcue:d} on deck {deck:d}')
def step_given_popup_label(context, text, hotcue, deck):
    context._popup_hotcue = hotcue
    context._popup_deck = deck
    if not _is_open(context, hotcue, deck):
        _rpc(context).mouseClickWithButton(
            f"mainWindow/deck{deck}/hotcue_{hotcue}", QT_RIGHT_BUTTON, 0
        )
        _wait_for_visible(context, _popup(context, "hotcuePopupContent"))
    label = _popup(context, "hotcuePopupLabelField")
    _click(context, label)
    rpc = _rpc(context)
    rpc.inputText(label, text)
    rpc.enterKey(label, QT_KEY_ENTER, 0)
    wait_until_label_set(context, text)


@given("the playhead of deck {deck:d} is at {position:f}")
def step_given_playhead(context, deck, position):
    _set_control_value(context, f"[Channel{deck}]", "playposition", position)


# --- Given/When: remember helpers ---


@given("the hotcue color of hotcue {hotcue:d} on deck {deck:d} is remembered")
@when("I remember the hotcue color of hotcue {hotcue:d} on deck {deck:d}")
@when("the hotcue color of hotcue {hotcue:d} on deck {deck:d} is remembered")
def step_remember_hotcue_color(context, hotcue, deck):
    group = f"[Channel{deck}]"
    _remember(context, f"{deck}_color_{hotcue}", _get_control_value(
        context, group, f"hotcue_{hotcue}_color"
    ))


@given("the hotcue span of hotcue {hotcue:d} on deck {deck:d} is remembered")
@when("I remember the hotcue span of hotcue {hotcue:d} on deck {deck:d}")
@then("the hotcue span of hotcue {hotcue:d} on deck {deck:d} is remembered")
def step_remember_hotcue_span(context, hotcue, deck):
    group = f"[Channel{deck}]"
    _remember(context, f"{deck}_span_{hotcue}", (
        _get_control_value(context, group, f"hotcue_{hotcue}_position"),
        _get_control_value(context, group, f"hotcue_{hotcue}_endposition"),
    ))


@given("the beatloop size of deck {deck:d} is set to {beats:d}")
@given("the beatloop size is set to {beats:d}")
def step_given_beatloop_size(context, deck=1, beats=4):
    if deck is None:
        deck = 1
    _set_control_value(context, f"[Channel{deck}]", "beatloop_size", beats)


@given("quantize is disabled on deck {deck:d}")
def step_given_quantize_disabled(context, deck):
    _set_control_value(context, f"[Channel{deck}]", "quantize", 0)


@given('the hotcue type name of hotcue {hotcue:d} on deck {deck:d} is "{type_name}"')
@when('the hotcue type name of hotcue {hotcue:d} on deck {deck:d} is "{type_name}"')
def step_given_type_is(context, hotcue, deck, type_name):
    actual = HOTCUE_TYPE_NAMES.get(
        int(_get_control_value(context, f"[Channel{deck}]", f"hotcue_{hotcue}_type"))
    )
    if actual != type_name:
        raise AssertionError(f"hotcue type is {actual}, expected {type_name}")


# --- When: popup interactions ---


@when("I right-click hotcue {hotcue:d} on deck {deck:d}")
def step_right_click_hotcue(context, hotcue, deck):
    context._popup_hotcue = hotcue
    context._popup_deck = deck
    _rpc(context).mouseClickWithButton(
        f"mainWindow/deck{deck}/hotcue_{hotcue}", QT_RIGHT_BUTTON, 0
    )
    _wait_for_visible(context, _popup(context, "hotcuePopupContent"))


@when('I click the "{name}" button in the popup')
def step_click_popup_button(context, name):
    spec = POPUP_BUTTON_NAMES[name]
    path = _waveform(context, spec[1]) if isinstance(spec, tuple) else _popup(context, spec)
    _click(context, path)


@when('I click the "{name}" arrow in the popup')
def step_click_popup_arrow(context, name):
    _click(context, _popup(context, POPUP_BUTTON_NAMES[name]))


@when("I click hotcue color swatch {num:d} in the popup")
def step_click_swatch(context, num):
    _click(
        context,
        f"{_popup(context, 'hotcuePopupSwatch_')}{num - 1}",
    )


@when('I enter "{text}" in the hotcue popup label field')
def step_enter_label(context, text):
    label = _popup(context, "hotcuePopupLabelField")
    _click(context, label)
    _rpc(context).inputText(label, text)


@when('I press "{key}" in the hotcue popup label field')
@when("I press Enter in the hotcue popup label field")
def step_press_enter(context, key=None):
    keymap = {"Enter": QT_KEY_ENTER, "Escape": QT_KEY_ESCAPE}
    keycode = QT_KEY_ENTER if key is None else keymap[key]
    _rpc(context).enterKey(_popup(context, "hotcuePopupLabelField"), keycode, 0)


@when("I press Escape in the hotcue popup")
def step_press_escape_popup(context):
    # No item inside the popup is focused, so the Escape key event is
    # delivered to the popup item, which discards the popup
    _rpc(context).enterKey(_popup(context, "hotcuePopupContent"), QT_KEY_ESCAPE, 0)

def _read_zoom(context, zoom_path, prop="zoom"):
    value = _get_property(context, zoom_path, prop)
    try:
        return float(value)
    except ValueError:
        return None


@when("I zoom the hotcue popup waveform in by {steps:d} steps")
def step_zoom_in(context, steps):
    zoom_path = _popup(context, "hotcuePopupWaveform")
    zoom = _read_zoom(context, zoom_path)
    assert zoom is not None, f"could not read the {zoom_path!r} zoom property"
    value = max(MIN_ZOOM, zoom - steps)
    _rpc(context).setStringProperty(zoom_path, "zoom", str(value))
    # Let the zoom and splitView animations settle
    time.sleep(2)


@when("I zoom the hotcue popup waveform out by {steps:d} steps")
def step_zoom_out(context, steps):
    zoom_path = _popup(context, "hotcuePopupWaveform")
    zoom = _read_zoom(context, zoom_path)
    assert zoom is not None, f"could not read the {zoom_path!r} zoom property"
    value = min(MAX_ZOOM, zoom + steps)
    _rpc(context).setStringProperty(zoom_path, "zoom", str(value))
    # Let the zoom and splitView animations settle
    time.sleep(2)


@when("I zoom the hotcue popup waveform out to fit the span")
def step_zoom_out_fit(context):
    # Write the ideal zoom that the popup targeting the span would apply;
    # writing it directly breaks the binding the same way a wheel event would
    zoom_path = _popup(context, "hotcuePopupWaveform")
    ideal = _read_zoom(context, zoom_path, "idealZoom")
    assert ideal is not None, "could not read the ideal zoom"
    ideal = max(MIN_ZOOM, min(MAX_ZOOM, ideal))
    _rpc(context).setStringProperty(zoom_path, "zoom", str(ideal))
    time.sleep(2)


@when("I click the swap button in the popup")
def step_click_swap(context):
    _click(context, _waveform(context, "hotcuePopupSwapButton"))


# --- Then: popup assertions ---


@then("the hotcue popup should be open")
def step_popup_open(context):
    assert _is_open(context), "hotcue popup not open"


@then("the hotcue popup should be closed")
def step_popup_closed(context):
    assert not _is_open(context), "hotcue popup still open"


@then("the hotcue popup label field should be visible")
def step_label_visible(context):
    assert _get_bool(context, _popup(context, "hotcuePopupLabelField"), "visible")


@then("the hotcue popup delete button should be visible")
def step_delete_visible(context):
    assert _get_bool(context, _popup(context, "hotcuePopupDeleteButton"), "visible")


def _get_swatch_count(context):
    return int(float(_get_property(
        context, _popup(context, "hotcuePopupSwatches"), "count")))


@then("the hotcue popup color swatches should be visible")
def step_swatches_visible(context):
    count = _get_swatch_count(context)
    assert count >= 1, f"unexpected swatch count {count}"
    for i in range(count):
        assert _get_bool(
            context, f"{_popup(context, 'hotcuePopupSwatch_')}{i}", "visible"
        ), f"swatch {i} not visible"


def wait_until_label_set(context, text, timeout_s=2.0):
    import time
    hotcue = getattr(context, "_popup_hotcue", 1)
    deck = getattr(context, "_popup_deck", 1)
    deadline = time.time() + timeout_s
    value = ""
    while time.time() < deadline:
        value = _get_property(
            context, f"mainWindow/deck{deck}/hotcue_{hotcue}", "labelText")
        if value == text:
            return value
        time.sleep(0.1)
    return value

@then('the hotcue popup label should show "{text}"')
def step_label_shows(context, text):
    # The deck hotcue button label mirrors the committed cue label; allow
    # the model update to settle before reading
    import time
    hotcue = getattr(context, "_popup_hotcue", 1)
    deck = getattr(context, "_popup_deck", 1)
    value = wait_until_label_set(context, text)
    assert value == text, f"label shows {value!r}, expected {text!r}"


@then('the hotcue type name of hotcue {hotcue:d} on deck {deck:d} should be "{type_name}"')
def step_type_should_be(context, hotcue, deck, type_name):
    value = int(_get_control_value(context, f"[Channel{deck}]", f"hotcue_{hotcue}_type"))
    actual = HOTCUE_TYPE_NAMES.get(value)
    assert actual == type_name, f"hotcue type is {actual}, expected {type_name}"


@then("the hotcue color of hotcue {hotcue:d} on deck {deck:d} should have changed")
def step_color_changed(context, hotcue, deck):
    import time
    group = f"[Channel{deck}]"
    key = f"{deck}_color_{hotcue}"
    before = context._remembered_hc[key]
    after = _get_control_value(context, group, f"hotcue_{hotcue}_color")
    time.sleep(1.0)
    settled = _get_control_value(context, group, f"hotcue_{hotcue}_color")
    assert before != after or before != settled, (
        f"hotcue color unchanged (before={before}, after={after}, settled={settled})")


@then("the hotcue span length of hotcue {hotcue:d} on deck {deck:d} should be {beats:d} beats")
def step_span_length_beats(context, hotcue, deck, beats):
    group = f"[Channel{deck}]"
    start = _get_control_value(context, group, f"hotcue_{hotcue}_position")
    end = _get_control_value(context, group, f"hotcue_{hotcue}_endposition")
    bpm = _get_control_value(context, group, "bpm")
    sample_rate = _get_control_value(context, group, "track_samplerate")
    beat_frames_2 = beats * 60.0 / bpm * sample_rate * 2
    assert beat_frames_2 > 0, f"invalid beat size computation (bpm={bpm})"
    length = end - start
    assert abs(length - beat_frames_2) <= 0.015 * beat_frames_2, (
        f"loop span {length} != {beats} beats ({beat_frames_2})")


@then("the hotcue jump target of hotcue {hotcue:d} on deck {deck:d} should be at the playhead")
def step_jump_target_playhead(context, hotcue, deck):
    group = f"[Channel{deck}]"
    end = _get_control_value(context, group, f"hotcue_{hotcue}_endposition")
    playposition = _get_control_value(context, group, "playposition")
    track_samples = _get_control_value(context, group, "track_samples")
    expected = playposition * track_samples
    assert abs(end - expected) <= 0.005 * track_samples, (
        f"jump target {end} != playhead {expected}")


@then("the hotcue span of hotcue {hotcue:d} on deck {deck:d} should be swapped")
def step_span_swapped(context, hotcue, deck):
    group = f"[Channel{deck}]"
    start, end = context._remembered_hc[f"{deck}_span_{hotcue}"]
    new_start = _get_control_value(context, group, f"hotcue_{hotcue}_position")
    new_end = _get_control_value(context, group, f"hotcue_{hotcue}_endposition")
    assert abs(new_start - end) < 1e-3, f"start {new_start} != remembered end {end}"
    assert abs(new_end - start) < 1e-3, f"end {new_end} != remembered start {start}"


# --- Then: waveform assertions ---


@then("the hotcue popup waveform should be visible")
def step_waveform_visible(context):
    assert _get_bool(context, _waveform(context, "hotcuePopupWaveformFull"), "visible")


@then("the hotcue popup start notch should be visible")
def step_start_notch_visible(context):
    assert _get_bool(context, _waveform(context, "hotcuePopupStartNotch"), "visible")


@then("the hotcue popup start notch should not be visible")
def step_start_notch_hidden(context):
    assert not _get_bool(context, _waveform(context, "hotcuePopupStartNotch"), "visible")


@then("the hotcue popup end notch should be visible")
def step_end_notch_visible(context):
    assert _get_bool(context, _waveform(context, "hotcuePopupEndNotch"), "visible")


@then("the hotcue popup end notch should not be visible")
def step_end_notch_hidden(context):
    assert not _get_bool(context, _waveform(context, "hotcuePopupEndNotch"), "visible")


@then("the span filler should be visible")
def step_filler_visible(context):
    assert _get_bool(context, _waveform(context, "hotcuePopupSpanFiller"), "visible")


@then("the span filler should not be visible")
def step_filler_hidden(context):
    assert not _get_bool(context, _waveform(context, "hotcuePopupSpanFiller"), "visible")


@then("the hotcue popup should be in split view")
def step_split_view(context):
    assert _get_bool(
        context, _popup(context, "hotcuePopupWaveform"), "splitView"), "not in split view"
    assert _get_bool(
        context, _waveform(context, "hotcuePopupWaveformPartial"), "visible")


@then("the hotcue popup should not be in split view")
def step_no_split_view(context):
    assert not _get_bool(
        context, _popup(context, "hotcuePopupWaveform"), "splitView"), "in split view"


@then("the split view start half should be visible")
@then("the split view target half should be visible")
def step_split_halves_visible(context):
    assert _get_bool(context, _waveform(context, "hotcuePopupWaveformFull"), "visible")
    assert _get_bool(context, _waveform(context, "hotcuePopupWaveformPartial"), "visible")


@then("the split view target half should not be visible")
def step_split_target_hidden(context):
    assert not _get_bool(
        context, _waveform(context, "hotcuePopupWaveformPartial"), "visible")


@then("the loop warp seam should be visible")
def step_loop_seam_visible(context):
    assert _get_bool(context, _waveform(context, "hotcuePopupLoopSeam"), "visible")


@then("the jump warp divider should be visible")
def step_jump_divider_visible(context):
    assert _get_bool(context, _waveform(context, "hotcuePopupJumpDivider"), "visible")


@then("the skip shade above the split should be visible")
def step_shade_top_visible(context):
    assert _get_bool(context, _waveform(context, "hotcuePopupSkipShadeTop"), "visible")


@then("the skip shade below the split should be visible")
def step_shade_bottom_visible(context):
    assert _get_bool(context, _waveform(context, "hotcuePopupSkipShadeBottom"), "visible")


@then("the swap button should be visible")
def step_swap_visible(context):
    assert _get_bool(context, _waveform(context, "hotcuePopupSwapButton"), "visible")


def _assert_split_half_position(context, display_path, position):
    import time
    group = f"[Channel{getattr(context, '_popup_deck', 1)}]"
    track_samples = _get_control_value(context, group, "track_samples")
    expected = position / track_samples
    value = None
    deadline = time.time() + 2.0
    while time.time() < deadline:
        value = float(_get_property(context, display_path, "position"))
        if abs(value - expected) <= 0.005:
            return
        time.sleep(0.1)
    assert False, (
        f"{display_path} position {value!r} does not display the expected "
        f"track ratio {expected!r}")


@then("the split view start half should display the span start position")
def step_split_start_half_position(context):
    hotcue = getattr(context, "_popup_hotcue", 1)
    group = f"[Channel{getattr(context, '_popup_deck', 1)}]"
    _assert_split_half_position(
        context,
        _waveform(context, "hotcuePopupWaveformFull"),
        _get_control_value(context, group, f"hotcue_{hotcue}_position"))


@then("the split view target half should display the span end position")
def step_split_target_half_position(context):
    hotcue = getattr(context, "_popup_hotcue", 1)
    group = f"[Channel{getattr(context, '_popup_deck', 1)}]"
    _assert_split_half_position(
        context,
        _waveform(context, "hotcuePopupWaveformPartial"),
        _get_control_value(context, group, f"hotcue_{hotcue}_endposition"))


# --- Then: geometry assertions ---


@then("the hotcue popup start notch should be centered within the waveform")
def step_start_notch_centered(context):
    rect = _get_bb(context, _waveform(context, "hotcuePopupWaveformFull"))
    notch = _get_bb(context, _waveform(context, "hotcuePopupStartNotch"))
    center = notch["x"] + notch["width"] / 2
    expected = rect["x"] + rect["width"] / 2
    assert abs(center - expected) <= 3, f"start notch center {center} != {expected}"


@then("the span filler should cover about two thirds of the waveform")
def step_filler_two_thirds(context):
    rect = _get_bb(context, _waveform(context, "hotcuePopupWaveformFull"))
    filler = _get_bb(context, _waveform(context, "hotcuePopupSpanFiller"))
    ratio = filler["width"] / rect["width"]
    assert 0.58 <= ratio <= 0.74, f"span filler ratio {ratio} not ~2/3"


def _assert_centered_on_edge(context, edge):
    filler = _get_bb(context, _waveform(context, "hotcuePopupSpanFiller"))
    notch = _get_bb(context, _waveform(context, "hotcuePopupStartNotch" if edge == "start" else "hotcuePopupEndNotch"))
    center = notch["x"] + notch["width"] / 2
    expected = filler["x"] if edge == "start" else filler["x"] + filler["width"]
    assert abs(center - expected) <= 3, f"notch center {center} != filler {edge} {expected}"


@then("the hotcue popup start notch should be centered on the span filler start edge")
def step_start_notch_on_start_edge(context):
    _assert_centered_on_edge(context, "start")


@then("the hotcue popup end notch should be centered on the span filler end edge")
def step_end_notch_on_end_edge(context):
    _assert_centered_on_edge(context, "end")
