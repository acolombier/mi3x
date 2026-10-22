import time

from behave import given, when, then
from mixxx_helpers import (
    _click,
    _deck_group,
    _deck_hotcue_path,
    _get_bb,
    _get_control_value,
    _get_property,
    _is_visible,
    _remember,
    _remembered_value,
    _wait_for_visible,
    _set_control_value,
    _set_hotcue_label,
)
from spix_helpers import (
    QT_KEY_ENTER,
    QT_KEY_ESCAPE,
    QT_RIGHT_BUTTON,
)

# The hotcue popup is re-parented to the window overlay when opened, where
# it is reachable through its generated QQuickPopupItem ("HotcuePopup");
# the popup's own content tree hangs under its "hotcuePopupContent<uid>"
# node. Every popup-internal objectName is suffixed with "<uid>" (deck
# group + hotcue number) because every HotcueButton instantiates its own
# popup with identical child names.
POPUP_POPUP_ITEM = "mainWindow/HotcuePopup"

# name -> (location, element objectName). "waveform" elements live in the
# popup's waveform patch, "popup" ones in the popup content tree.
POPUP_BUTTONS = {
    "delete": ("popup", "hotcuePopupDeleteButton"),
    "swap": ("waveform", "hotcuePopupSwapButton"),
    "previous type": ("popup", "hotcuePopupTypePrev"),
    "next type": ("popup", "hotcuePopupTypeNext"),
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


def _is_open(context, hotcue=None, deck=None):
    # The Popup object itself is not reachable as an Item by spix, so "open"
    # is recognized through the visibility of the popup content tree
    return _is_visible(context, _popup(context, "hotcuePopupContent", hotcue, deck))


def _open_hotcue_popup(context, deck, hotcue):
    context._popup_deck = deck
    context._popup_hotcue = hotcue
    path = _deck_hotcue_path(deck, hotcue)
    popup_path = _popup(context, "hotcuePopupContent")
    # AGENTS.md click-retry exception: the popup opens via tap on the
    # hotcue button's TapHandler, and spix synthetic taps can be dropped
    # under load; each retry is verified against the popup being visible.
    # The popup is modal while open, so further right-clicks on the button
    # cannot toggle it again.
    deadline = time.time() + 15.0
    while not _is_visible(context, popup_path):
        if time.time() >= deadline:
            break
        context.rpc.mouseClickWithButton(path, QT_RIGHT_BUTTON, 0)
        time.sleep(0.3)
    assert _is_visible(context, popup_path), (
        f"the hotcue popup for hotcue {hotcue} on deck {deck} did not open")


def _wait_until_label_set(context, text, timeout_s=2.0):
    hotcue = getattr(context, "_popup_hotcue", 1)
    deck = getattr(context, "_popup_deck", 1)
    deadline = time.time() + timeout_s
    while True:
        value = _get_property(
            context, _deck_hotcue_path(deck, hotcue), "labelText")
        if value == text or time.time() >= deadline:
            return value
        time.sleep(0.1)


def _read_zoom(context, prop="zoom"):
    try:
        return float(_get_property(
            context, _popup(context, "hotcuePopupWaveform"), prop))
    except (TypeError, ValueError):
        return None


def _set_zoom(context, value):
    zoom_path = _popup(context, "hotcuePopupWaveform")
    context.rpc.setStringProperty(zoom_path, "zoom", str(value))
    deadline = time.time() + 5.0
    while time.time() < deadline:
        zoom = _read_zoom(context)
        if zoom is not None and abs(value - zoom) <= 1e-3:
            break
        time.sleep(0.1)
    else:
        raise AssertionError(
            f"could not apply the {zoom_path!r} zoom value {value!r}")
    # Let the zoom and splitView animations settle
    time.sleep(2)


# --- Given: popup state ---


@given("the hotcue popup is open for hotcue {hotcue:d} on deck {deck:d}")
def step_given_popup_open(context, hotcue, deck):
    _open_hotcue_popup(context, deck, hotcue)


@given("hotcue {hotcue:d} is set on deck {deck:d}")
def step_given_hotcue_is_set(context, hotcue, deck):
    group = _deck_group(deck)

    def status_value():
        return _get_control_value(context, group, f"hotcue_{hotcue}_status")

    if status_value() == 0:
        _click(context, _deck_hotcue_path(deck, hotcue))
        deadline = time.time() + 1.0
        while status_value() == 0 and time.time() < deadline:
            time.sleep(0.1)
    if status_value() == 0:
        # Under load the click can be dropped (the hotcue button reacts to
        # a TapHandler); pulse the set control instead, the status control
        # is momentary and cannot create the cue.
        _set_control_value(context, group, f"hotcue_{hotcue}_set", 1)
        deadline = time.time() + 1.0
        while status_value() == 0 and time.time() < deadline:
            time.sleep(0.1)
        _set_control_value(context, group, f"hotcue_{hotcue}_set", 0)
    assert status_value() != 0, (
        f"hotcue_{hotcue} could not be set (status={status_value()})")
    context._popup_hotcue = hotcue
    context._popup_deck = deck


@given('hotcue {hotcue:d} on deck {deck:d} is of type "{hotcue_type}"')
def step_given_hotcue_type(context, hotcue, deck, hotcue_type):
    assert hotcue_type in HOTCUE_TYPE_VALUES, f"Unknown hotcue type {repr(hotcue_type)}"
    expected_type = HOTCUE_TYPE_VALUES[hotcue_type]
    _set_control_value(
        context, _deck_group(deck), f"hotcue_{hotcue}_type", expected_type)
    actual = _get_control_value(
        context, _deck_group(deck), f"hotcue_{hotcue}_type")
    assert actual == expected_type, f"Unable to set the hotcue type (is {actual})"


@given('the label of hotcue {hotcue:d} on deck {deck:d} is "{text}"')
def step_given_hotcue_label(context, text, hotcue, deck):
    context._popup_hotcue = hotcue
    context._popup_deck = deck
    group = _deck_group(deck)
    _set_hotcue_label(context, group, hotcue, text)
    value = _wait_until_label_set(context, text)
    assert value == text, (
        f"The committed label could not be set (shows {value!r}, expected {text!r})")


@given("the playhead of deck {deck:d} is at {position:f}")
def step_given_playhead(context, deck, position):
    group = _deck_group(deck)
    _set_control_value(context, group, "playposition", position)
    actual = _get_control_value(context, group, "playposition")
    assert actual == position, (
        f"Unable to set the deck {deck} playposition to {position}")


# --- Given/When: remember helpers ---


@given("the hotcue color of hotcue {hotcue:d} on deck {deck:d} is remembered")
@when("I remember the hotcue color of hotcue {hotcue:d} on deck {deck:d}")
@when("the hotcue color of hotcue {hotcue:d} on deck {deck:d} is remembered")
def step_remember_hotcue_color(context, hotcue, deck):
    _remember(
        context,
        ("hotcue color", deck, hotcue),
        _get_control_value(
            context, _deck_group(deck), f"hotcue_{hotcue}_color"),
    )


@given("the hotcue span of hotcue {hotcue:d} on deck {deck:d} is remembered")
@when("I remember the hotcue span of hotcue {hotcue:d} on deck {deck:d}")
@then("the hotcue span of hotcue {hotcue:d} on deck {deck:d} is remembered")
def step_remember_hotcue_span(context, hotcue, deck):
    group = _deck_group(deck)
    _remember(context, ("hotcue span", deck, hotcue), (
        _get_control_value(context, group, f"hotcue_{hotcue}_position"),
        _get_control_value(
            context, group, f"hotcue_{hotcue}_endposition"),
    ))


@given("the beatloop size of deck {deck:d} is set to {beats:d}")
@given("the beatloop size is set to {beats:d}")
def step_given_beatloop_size(context, beats, deck=1):
    _set_control_value(context, _deck_group(deck), "beatloop_size", beats)


@given("quantize is disabled on deck {deck:d}")
def step_given_quantize_disabled(context, deck):
    _set_control_value(context, _deck_group(deck), "quantize", 0)


# --- When: popup interactions ---


@when("I right-click hotcue {hotcue:d} on deck {deck:d}")
def step_right_click_hotcue(context, hotcue, deck):
    _open_hotcue_popup(context, deck, hotcue)


@when('I click the "{name}" button in the popup')
@when('I click the "{name}" arrow in the popup')
def step_click_popup_button(context, name):
    try:
        location, element = POPUP_BUTTONS[name]
    except KeyError:
        raise ValueError(f'Unknown popup button "{name}"')
    if location == "waveform":
        path = _waveform(context, element)
    else:
        path = _popup(context, element)
    _click(context, path)


@when("I click hotcue color swatch {num:d} in the popup")
def step_click_swatch(context, num):
    _click(context, f"{_popup(context, 'hotcuePopupSwatch_')}{num - 1}")


@when('I enter "{text}" in the hotcue popup label field')
def step_enter_label(context, text):
    label = _popup(context, "hotcuePopupLabelField")
    _wait_for_visible(context, label),
    _click(context, label)
    context.rpc.inputText(label, text)


@when('I press "{key}" in the hotcue popup label field')
@when("I press Enter in the hotcue popup label field")
def step_press_label_key(context, key=None):
    keymap = {"Enter": QT_KEY_ENTER, "Escape": QT_KEY_ESCAPE}
    keycode = QT_KEY_ENTER if key is None else keymap[key]
    context.rpc.enterKey(_popup(context, "hotcuePopupLabelField"), keycode, 0)


@when("I press Escape in the hotcue popup")
def step_press_escape_popup(context):
    # No item inside the popup is focused, so the Escape key event is
    # delivered to the popup item, which discards the popup
    context.rpc.enterKey(_popup(context, "hotcuePopupContent"), QT_KEY_ESCAPE, 0)


@when("I zoom the hotcue popup waveform in by {steps:d} steps")
def step_zoom_in(context, steps):
    zoom = _read_zoom(context)
    assert zoom is not None, (
        "could not read the hotcue popup waveform zoom property")
    _set_zoom(context, max(MIN_ZOOM, zoom - steps))


@when("I zoom the hotcue popup waveform out by {steps:d} steps")
def step_zoom_out(context, steps):
    zoom = _read_zoom(context)
    assert zoom is not None, (
        "could not read the hotcue popup waveform zoom property")
    _set_zoom(context, min(MAX_ZOOM, zoom + steps))


@when("I zoom the hotcue popup waveform out to fit the span")
def step_zoom_out_fit(context):
    # Write the ideal zoom that the popup targeting the span would apply;
    # writing it directly breaks the binding the same way a wheel event would
    ideal = _read_zoom(context, "idealZoom")
    assert ideal is not None, "could not read the ideal zoom"
    _set_zoom(context, max(MIN_ZOOM, min(MAX_ZOOM, ideal)))


# --- Then: popup assertions ---


@then("the hotcue popup should be open")
def step_popup_open(context):
    assert _is_open(context), "hotcue popup not open"


@then("the hotcue popup should be closed")
def step_popup_closed(context):
    assert not _is_open(context), "hotcue popup still open"


@then("the hotcue popup label field should be visible")
def step_label_is_visible(context):
    assert _is_visible(context, _popup(context, "hotcuePopupLabelField")), (
        "hotcue popup label field not visible")


@then("the hotcue popup delete button should be visible")
def step_delete_is_visible(context):
    assert _is_visible(context, _popup(context, "hotcuePopupDeleteButton")), (
        "hotcue popup delete button not visible")


def _swatch_count(context):
    return int(float(_get_property(
        context, _popup(context, "hotcuePopupSwatches"), "count")))


@then("the hotcue popup color swatches should be visible")
def step_swatches_is_visible(context):
    count = _swatch_count(context)
    assert count >= 1, f"unexpected swatch count {count}"
    for i in range(count):
        assert _is_visible(
            context, f"{_popup(context, 'hotcuePopupSwatch_')}{i}"), (
            f"swatch {i} not visible")


@then('the hotcue popup label should show "{text}"')
def step_label_shows(context, text):
    # The deck hotcue button label mirrors the committed cue label; allow
    # the model update to settle before reading
    value = _wait_until_label_set(context, text)
    assert value == text, f"label shows {value!r}, expected {text!r}"


@then('the hotcue type name of hotcue {hotcue:d} on deck {deck:d} should be "{type_name}"')
def step_type_should_be(context, hotcue, deck, type_name):
    value = int(_get_control_value(
        context, _deck_group(deck), f"hotcue_{hotcue}_type"))
    actual = HOTCUE_TYPE_NAMES.get(value)
    assert actual == type_name, f"hotcue type is {actual}, expected {type_name}"


@then("the hotcue color of hotcue {hotcue:d} on deck {deck:d} should have changed")
def step_color_changed(context, hotcue, deck):
    group = _deck_group(deck)
    before = _remembered_value(context, ("hotcue color", deck, hotcue))
    deadline = time.time() + 2.0
    while True:
        after = _get_control_value(context, group, f"hotcue_{hotcue}_color")
        if after != before or time.time() >= deadline:
            break
        time.sleep(0.1)
    assert after != before, f"hotcue color unchanged (stayed at {before})"


@then("the hotcue span length of hotcue {hotcue:d} on deck {deck:d} should be {beats:d} beats")
def step_span_length_beats(context, hotcue, deck, beats):
    group = _deck_group(deck)
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
    group = _deck_group(deck)
    end = _get_control_value(context, group, f"hotcue_{hotcue}_endposition")
    playposition = _get_control_value(context, group, "playposition")
    track_samples = _get_control_value(context, group, "track_samples")
    expected = playposition * track_samples
    assert abs(end - expected) <= 0.005 * track_samples, (
        f"jump target {end} != playhead {expected}")


@then("the hotcue span of hotcue {hotcue:d} on deck {deck:d} should be swapped")
def step_span_swapped(context, hotcue, deck):
    group = _deck_group(deck)
    start, end = _remembered_value(context, ("hotcue span", deck, hotcue))
    new_start = _get_control_value(
        context, group, f"hotcue_{hotcue}_position")
    new_end = _get_control_value(
        context, group, f"hotcue_{hotcue}_endposition")
    assert abs(new_start - end) < 1e-3, f"start {new_start} != remembered end {end}"
    assert abs(new_end - start) < 1e-3, f"end {new_end} != remembered start {start}"


# --- Then: waveform assertions ---


@then("the hotcue popup waveform should be visible")
def step_waveform_is_visible(context):
    assert _is_visible(
        context, _waveform(context, "hotcuePopupWaveformFull")), (
        "hotcue popup waveform not visible")


@then("the hotcue popup start notch should be visible")
def step_start_notch_is_visible(context):
    assert _is_visible(context, _waveform(context, "hotcuePopupStartNotch")), (
        "hotcue popup start notch not visible")


@then("the hotcue popup start notch should not be visible")
def step_start_notch_hidden(context):
    assert not _is_visible(context, _waveform(context, "hotcuePopupStartNotch")), (
        "hotcue popup start notch still visible")


@then("the hotcue popup end notch should be visible")
def step_end_notch_is_visible(context):
    assert _is_visible(context, _waveform(context, "hotcuePopupEndNotch")), (
        "hotcue popup end notch not visible")


@then("the hotcue popup end notch should not be visible")
def step_end_notch_hidden(context):
    assert not _is_visible(context, _waveform(context, "hotcuePopupEndNotch")), (
        "hotcue popup end notch still visible")


@then("the span filler should be visible")
def step_filler_is_visible(context):
    assert _is_visible(context, _waveform(context, "hotcuePopupSpanFiller")), (
        "span filler not visible")


@then("the span filler should not be visible")
def step_filler_hidden(context):
    assert not _is_visible(context, _waveform(context, "hotcuePopupSpanFiller")), (
        "span filler still visible")


@then("the hotcue popup should be in split view")
def step_split_view(context):
    assert _get_property(
        context, _popup(context, "hotcuePopupWaveform"), "splitView") == "true", (
        "not in split view")
    assert _is_visible(
        context, _waveform(context, "hotcuePopupWaveformPartial")), (
        "hotcue popup split view target half not visible")


@then("the hotcue popup should not be in split view")
def step_no_split_view(context):
    assert _get_property(
        context, _popup(context, "hotcuePopupWaveform"), "splitView") != "true", (
        "in split view")


@then("the split view start half should be visible")
@then("the split view target half should be visible")
def step_split_halves_is_visible(context):
    assert _is_visible(
        context, _waveform(context, "hotcuePopupWaveformFull")), (
        "split view start half not visible")
    assert _is_visible(
        context, _waveform(context, "hotcuePopupWaveformPartial")), (
        "split view target half not visible")


@then("the split view target half should not be visible")
def step_split_target_hidden(context):
    assert not _is_visible(
        context, _waveform(context, "hotcuePopupWaveformPartial")), (
        "split view target half still visible")


@then("the loop warp seam should be visible")
def step_loop_seam_is_visible(context):
    assert _is_visible(context, _waveform(context, "hotcuePopupLoopSeam")), (
        "loop warp seam not visible")


@then("the jump warp divider should be visible")
def step_jump_divider_is_visible(context):
    assert _is_visible(context, _waveform(context, "hotcuePopupJumpDivider")), (
        "jump warp divider not visible")


@then("the skip shade above the split should be visible")
def step_shade_top_is_visible(context):
    assert _is_visible(context, _waveform(context, "hotcuePopupSkipShadeTop")), (
        "skip shade above the split not visible")


@then("the skip shade below the split should be visible")
def step_shade_bottom_is_visible(context):
    assert _is_visible(context, _waveform(context, "hotcuePopupSkipShadeBottom")), (
        "skip shade below the split not visible")


@then("the swap button should be visible")
def step_swap_is_visible(context):
    assert _is_visible(context, _waveform(context, "hotcuePopupSwapButton")), (
        "swap button not visible")


def _assert_split_half_position(context, display_path, position):
    group = _deck_group(getattr(context, "_popup_deck", 1))
    track_samples = _get_control_value(context, group, "track_samples")
    expected = position / track_samples
    deadline = time.time() + 2.0
    while True:
        value = float(_get_property(context, display_path, "position"))
        if abs(value - expected) <= 0.005 or time.time() >= deadline:
            break
        time.sleep(0.1)
    assert abs(value - expected) <= 0.005, (
        f"{display_path} position {value!r} does not display the expected "
        f"track ratio {expected!r}")


@then("the split view start half should display the span start position")
def step_split_start_half_position(context):
    hotcue = getattr(context, "_popup_hotcue", 1)
    group = _deck_group(getattr(context, "_popup_deck", 1))
    _assert_split_half_position(
        context,
        _waveform(context, "hotcuePopupWaveformFull"),
        _get_control_value(
            context, group, f"hotcue_{hotcue}_position"))


@then("the split view target half should display the span end position")
def step_split_target_half_position(context):
    hotcue = getattr(context, "_popup_hotcue", 1)
    group = _deck_group(getattr(context, "_popup_deck", 1))
    _assert_split_half_position(
        context,
        _waveform(context, "hotcuePopupWaveformPartial"),
        _get_control_value(
            context, group, f"hotcue_{hotcue}_endposition"))


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
    notch_path = (
        "hotcuePopupStartNotch" if edge == "start" else "hotcuePopupEndNotch")
    notch = _get_bb(context, _waveform(context, notch_path))
    center = notch["x"] + notch["width"] / 2
    expected = filler["x"] if edge == "start" else filler["x"] + filler["width"]
    assert abs(center - expected) <= 3, f"notch center {center} != filler {edge} {expected}"


@then("the hotcue popup start notch should be centered on the span filler start edge")
def step_start_notch_on_start_edge(context):
    _assert_centered_on_edge(context, "start")


@then("the hotcue popup end notch should be centered on the span filler end edge")
def step_end_notch_on_end_edge(context):
    _assert_centered_on_edge(context, "end")
