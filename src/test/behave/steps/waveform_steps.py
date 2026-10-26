"""Feature-specific step definitions for waveform.

Split out of the former monolithic step modules; shared machinery
lives in mixxx_steps.py / settings_steps.py / helpers.py.
All imports are module-level: behave discovers steps/*.py
alphabetically, and the common modules must not be pulled in ahead
of this file's own (more specific) step registrations."""

from helpers import (
    COLOR_BAND_MAP,
    COLOR_PICKER_TEST_PATH,
    GAIN_BAND_MAP,
    WAVEFORM_OPTION_BITS,
    WAVEFORM_PREVIEW_PATH,
    _assert_deck_until_mark,
    _click,
    _deck_waveform_path,
    _get_property,
    _read_float_property,
    _set_property,
    _setting_spec,
    _waveform_color_props,
)
from helpers import (
    wait_visible,
)
from behave import when, then

import time


@when('I pick the color "{color}" for the "{band}" waveform color')
def step_pick_waveform_color(context, color, band):
    assert band in COLOR_BAND_MAP, f"Unknown waveform color '{band}'"
    index = COLOR_BAND_MAP[band]
    swatch_path = f"mainWindow/waveformColorSwatch_{index}"
    assert wait_visible(context.rpc, swatch_path), (
        f"Color swatch '{swatch_path}' is not visible; the current waveform "
        f"type must support the '{band}' color"
    )
    before = int(_get_property(context, COLOR_PICKER_TEST_PATH, "openCount"))
    _set_property(context, COLOR_PICKER_TEST_PATH, "testMode", "true")
    _set_property(context, COLOR_PICKER_TEST_PATH, "selectedColor", color)
    _click(context, swatch_path)
    deadline = time.time() + 5
    after = before
    while time.time() < deadline:
        after = int(_get_property(context, COLOR_PICKER_TEST_PATH, "openCount"))
        if after > before:
            break
        time.sleep(0.1)
    assert after == before + 1, (
        f"The color picker for the '{band}' waveform color did not open "
        f"(open count {before} -> {after})"
    )

@then("the waveform preview should be at zoom {zoom:g}")
def step_preview_waveform_zoom(context, zoom):
    actual = _read_float_property(context, WAVEFORM_PREVIEW_PATH, "zoom")
    assert abs(actual - zoom) < 0.01, (
        f"The waveform preview should be at zoom {zoom} but is {actual}"
    )

@then("the waveform preview beat grid should be {pct:d}% opaque")
def step_preview_waveform_beat_grid(context, pct):
    actual = _read_float_property(context, WAVEFORM_PREVIEW_PATH, "beatGridOpacity")
    expected = pct / 100
    assert abs(actual - expected) < 0.01, (
        f"The waveform preview beat grid should be {pct}% opaque ({expected}) "
        f"but is {actual}"
    )

@then("the waveform preview play marker should sit at {pct:d}%")
def step_preview_waveform_play_marker(context, pct):
    actual = _read_float_property(context, WAVEFORM_PREVIEW_PATH, "playMarkerPosition")
    expected = pct / 100
    assert abs(actual - expected) < 0.01, (
        f"The waveform preview play marker should sit at {pct}% ({expected}) "
        f"but is at {actual}"
    )

@then('the waveform preview until-marker hint should show beats')
def step_preview_waveform_until_mark_beats(context):
    actual = _get_property(context, WAVEFORM_PREVIEW_PATH, "untilMarkShowBeats")
    assert actual == "true", (
        f"The waveform preview until-marker hint should show beats "
        f"but showBeats is '{actual}'"
    )

@then('the waveform preview until-marker hint should not show beats')
def step_preview_waveform_until_mark_beats_off(context):
    actual = _get_property(context, WAVEFORM_PREVIEW_PATH, "untilMarkShowBeats")
    assert actual == "false", (
        f"The waveform preview until-marker hint should not show beats "
        f"but showBeats is '{actual}'"
    )

@then('the waveform preview until-marker hint should show the remaining time')
def step_preview_waveform_until_mark_time(context):
    actual = _get_property(context, WAVEFORM_PREVIEW_PATH, "untilMarkShowTime")
    assert actual == "true", (
        f"The waveform preview until-marker hint should show the remaining "
        f"time but showTime is '{actual}'"
    )

@then('the waveform preview until-marker hint should not show the remaining time')
def step_preview_waveform_until_mark_time_off(context):
    actual = _get_property(context, WAVEFORM_PREVIEW_PATH, "untilMarkShowTime")
    assert actual == "false", (
        f"The waveform preview until-marker hint should not show the remaining "
        f"time but showTime is '{actual}'"
    )

@then('the waveform preview until-marker hint should be placed at the "{placement}"')
def step_preview_waveform_until_mark_placement(context, placement):
    actual = _get_property(context, WAVEFORM_PREVIEW_PATH, "untilMarkAlignName")
    assert actual == placement, (
        f"The waveform preview until-marker hint should be placed at the "
        f"'{placement}' but is '{actual}'"
    )

@then('the waveform preview until-marker hint should use a {size:d}pt font')
def step_preview_waveform_until_mark_font(context, size):
    actual = _read_float_property(context, WAVEFORM_PREVIEW_PATH, "untilMarkTextSize")
    assert abs(actual - size) < 0.01, (
        f"The waveform preview until-marker hint should use a {size}pt font "
        f"but is {actual}pt"
    )

@then('the waveform preview should have the "{band}" band gain set to "{value}"')
def step_preview_waveform_band_gain(context, band, value):
    prop = GAIN_BAND_MAP[band]["preview"]
    actual = _read_float_property(context, WAVEFORM_PREVIEW_PATH, prop)
    assert abs(actual - float(value)) < 1e-3, (
        f"The waveform preview should have the '{band}' band gain set to "
        f"'{value}' ({prop}) but is {actual}"
    )

@then('the waveform preview should render with the selected options')
def step_preview_waveform_option(context):
    bits = 0
    for name, bit in WAVEFORM_OPTION_BITS.items():
        selected = _get_property(context, _setting_spec(name)["path"], "selected")
        if selected == "on":
            bits |= bit
    actual = int(_get_property(context, WAVEFORM_PREVIEW_PATH, "options"))
    assert actual == bits, (
        f"The waveform preview should render with option bits {bits} "
        f"but renders with bits {actual}"
    )

@then('the "{band}" color swatch should be "{color}"')
def step_waveform_color_swatch(context, band, color):
    _waveform_color_props(context, band, color)

@then('the waveform preview should render the "{band}" band with "{color}"')
def step_preview_waveform_color(context, band, color):
    _waveform_color_props(context, band, color)


# --- Deck waveforms (validation of the saved values) -----------------------
@then("the beat grid on deck {deck:d} should fade to {pct:d}% opacity")
def step_deck_waveform_beat_grid(context, deck, pct):
    actual = _read_float_property(context, _deck_waveform_path(deck), "beatGridAlpha")
    expected = pct / 100
    assert abs(actual - expected) < 0.01, (
        f"The beat grid on deck {deck} should fade to {pct}% opacity "
        f"({expected}) but is {actual}"
    )

@then("the play marker on deck {deck:d} should sit at {pct:d}%")
def step_deck_waveform_play_marker(context, deck, pct):
    actual = _read_float_property(
            context, _deck_waveform_path(deck), "playMarkerPosition")
    expected = pct / 100
    assert abs(actual - expected) < 0.01, (
        f"The play marker on deck {deck} should sit at {pct}% ({expected}) "
        f"but is at {actual}"
    )

@then("the until-marker hint on deck {deck:d} should show beats")
def step_deck_waveform_until_mark_beats_on(context, deck):
    _assert_deck_until_mark(context, "untilMarkShowBeats", deck, True, "beats")

@then("the until-marker hint on deck {deck:d} should not show beats")
def step_deck_waveform_until_mark_beats_off(context, deck):
    _assert_deck_until_mark(context, "untilMarkShowBeats", deck, False, "beats")

@then("the until-marker hint on deck {deck:d} should show the remaining time")
def step_deck_waveform_until_mark_time_on(context, deck):
    _assert_deck_until_mark(context, "untilMarkShowTime", deck, True, "remaining time")

@then("the until-marker hint on deck {deck:d} should not show the remaining time")
def step_deck_waveform_until_mark_time_off(context, deck):
    _assert_deck_until_mark(context, "untilMarkShowTime", deck, False, "remaining time")

@then('the until-marker hint on deck {deck:d} should be placed at the "{placement}"')
def step_deck_waveform_until_mark_placement(context, deck, placement):
    actual = _get_property(context, _deck_waveform_path(deck), "untilMarkAlignName")
    assert actual == placement, (
        f"The until-marker hint on deck {deck} should be placed at the "
        f"'{placement}' but is '{actual}'"
    )

@then('the until-marker hint on deck {deck:d} should use a {size:d}pt font')
def step_deck_waveform_until_mark_font(context, deck, size):
    actual = _read_float_property(context, _deck_waveform_path(deck), "untilMarkTextSize")
    assert abs(actual - size) < 0.01, (
        f"The until-marker hint on deck {deck} should use a {size}pt font "
        f"but is {actual}pt"
    )

@then('the waveform on deck {deck:d} should have the "{band}" band gain set to "{value}"')
def step_deck_waveform_band_gain(context, deck, band, value):
    prop = GAIN_BAND_MAP[band]["deck"]
    actual = _read_float_property(context, _deck_waveform_path(deck), prop)
    assert abs(actual - float(value)) < 1e-3, (
        f"The waveform on deck {deck} should have the '{band}' band gain set "
        f"to '{value}' ({prop}) but is {actual}"
    )

@then("the zoom of the waveform on deck {deck_a:d} should be equal to the zoom on deck {deck_b:d}")
def step_deck_waveform_zoom_equal(context, deck_a, deck_b):
    a = _read_float_property(context, _deck_waveform_path(deck_a), "waveformZoom")
    b = _read_float_property(context, _deck_waveform_path(deck_b), "waveformZoom")
    assert abs(a - b) < 1e-6, (
        f"The zoom of the waveform on deck {deck_a} ({a}) differs from the "
        f"zoom on deck {deck_b} ({b}); zoom synchronization did not couple them"
    )
