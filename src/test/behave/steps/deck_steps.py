"""Feature-specific step definitions for deck.

Split out of the former monolithic step modules; shared machinery
lives in mixxx_steps.py / settings_steps.py / helpers.py.
All imports are module-level: behave discovers steps/*.py
alphabetically, and the common modules must not be pulled in ahead
of this file's own (more specific) step registrations."""

from helpers import (
    DECK_PATH_MAP,
    DECK_PROPERTY_MAP,
    LOOP_BUTTONS,
    QT_CONTROL_MODIFIER,
    QT_KEY_A,
    QT_KEY_BACKSPACE,
    QT_KEY_ENTER,
    QT_KEY_ESCAPE,
    QT_LEFT_BUTTON,
    QT_RIGHT_BUTTON,
    REMEMBERED_CO_KEYS,
    _click,
    _deck_button_path,
    _deck_group,
    _deck_hotcue_path,
    _get_bb,
    _get_control_value,
    _get_property,
    _is_visible,
    _long_press,
    _remember,
    _remembered_value,
    _set_control_value,
    _set_hotcue,
    _wait_for_hidden,
    _wait_for_visible,
)
from behave import given, when, then

import time


@when('I click the "{button}" button on deck {deck:d}')
def step_click_deck_button(context, button, deck):
    _click(context, _deck_button_path(deck, button))
    time.sleep(1)

@when('I long-press the "{button}" button on deck {deck:d}')
def step_long_press_deck_button(context, button, deck):
    path = _deck_button_path(deck, button)
    if button == "sync":
        context.rpc.invokeMethod(path, "toggleLeader", [])
    else:
        _long_press(context, path)
    time.sleep(0.5)

@when('I {direction} the "{component}" size on deck {deck:d}')
def step_direction_component_size(context, direction, component, deck):
    button = LOOP_BUTTONS.get((direction, component))
    if not button:
        raise ValueError(f"Unknown {direction} for {component}")
    _click(context, _deck_button_path(deck, button))
    time.sleep(0.3)

@when("I seek to {position:f} in deck {deck:d}")
def step_seek_in_deck(context, position, deck):
    context.rpc.mouseClickWithProportion(_deck_button_path(deck, "overview"), position, 0.5)
    time.sleep(0.5)

@when("I set the rate of deck {deck:d} to {value:d}%")
def step_set_rate(context, deck, value):
    path = f'{_deck_button_path(deck, "rate")}/handle'
    bb = context.rpc.getBoundingBox(_deck_button_path(deck, "rate"))
    context.rpc.mouseDrag(path, 0, 0, 0, bb[3] / 4 * -(value / 100), 1000)

@when("I set hotcue {hotcue:d} on deck {deck:d}")
@when("I clear hotcue {hotcue:d} on deck {deck:d}")
def step_toggle_hotcue(context, hotcue, deck):
    _click(context, _deck_hotcue_path(deck, hotcue))
    time.sleep(0.3)

@when('I remember the "{prop}" of deck {deck:d}')
def step_remember(context, prop, deck):
    _remember(
        context, prop,
        _get_control_value(context, _deck_group(deck), REMEMBERED_CO_KEYS[prop]))

@given("no track is loaded on deck {deck:d}")
def step_no_track_loaded_to_deck(context, deck):
    group = _deck_group(deck)
    if _get_control_value(context, group, "track_loaded"):
        _set_control_value(context, group, "eject", 1.0)
        time.sleep(0.01)
        _set_control_value(context, group, "eject", 0.0)
    time.sleep(0.3)
    assert not _get_control_value(context, group, "track_loaded"), f"Track is still loaded on {group}"

@given("the {prop} on deck {deck:d} is set to {value:f}")
def step_deck_set_rate(context, prop, deck, value):
    group = _deck_group(deck)
    key = DECK_PROPERTY_MAP.get(prop, prop)
    _set_control_value(context, group, key, value)
    time.sleep(0.3)

@given("the sync_on deck {deck:d} is {state}")
def step_deck_set_sync(context, deck, state):
    group = _deck_group(deck)
    _set_control_value(context, group, "sync_enabled", float(state != "disabled"))
    time.sleep(0.3)

@when('I move the "{component}" component in deck {deck:d} {cardinality} the "{target}" component')
def step_move_component_after(context, component, deck, cardinality, target):
    component_path = _deck_button_path(deck, component)
    target_path = _deck_button_path(deck, target)

    component_bb = context.rpc.getBoundingBox(component_path)
    target_bb = context.rpc.getBoundingBox(target_path)
    delta = target_bb[0] - component_bb[0], target_bb[1] - component_bb[1]

    context.rpc.mouseDrag(component_path, 0.5, 0.5, *delta, 1000)
    time.sleep(2)

@when('I move the selected group in deck {deck:d} after the "{target}" component')
def step_move_group_after(context, deck, target):
    component_path = _deck_button_path(deck, "selectedGroupOverlay")
    target_path = _deck_button_path(deck, target)

    component_bb = context.rpc.getBoundingBox(component_path)
    target_bb = context.rpc.getBoundingBox(target_path)
    delta = target_bb[0] - component_bb[0] + target_bb[2]/2, target_bb[1] - component_bb[1]

    context.rpc.mouseDrag(component_path, 0, 0, *delta, 1000)
    time.sleep(2)

@when('I select the group containing "{component}" in deck {deck:d} with a {action}')
def step_select_component_group(context, component, deck, action):
    path = _deck_button_path(deck, component)
    if action == "long press":
        context.rpc.mouseClickAndHold(path, QT_LEFT_BUTTON, 0, 1000)
    elif action == "ctrl+click":
        context.rpc.mouseClickWithButton(path, QT_LEFT_BUTTON, QT_CONTROL_MODIFIER)
    else:
        raise NotImplementedError(f"Unsupported action '{action}'")
    time.sleep(0.3)

@then('the deck for "{group}" should {assertion} visible')
def step_deck_visible(context, group, assertion):
    if assertion == "be":
        _wait_for_visible(context, DECK_PATH_MAP[group])
    else:
        _wait_for_hidden(context, DECK_PATH_MAP[group])

@then('the "{component}" component should {assertion} visible in deck {deck:d}')
def step_deck_component_visible(context, component, assertion, deck):
    path = _deck_button_path(deck, component)
    if assertion == "be":
        _wait_for_visible(context, path)
    else:
        _wait_for_hidden(context, path)

@then("the deck {deck:d} should be {assertion}")
def step_deck_playing(context, deck, assertion):
    group = _deck_group(deck)
    expected = assertion == "playing"
    value = bool(_get_control_value(context, group, "play"))
    label = lambda x: 'playing' if x else 'stopped'
    assert value is expected, (
        f"Play button on deck {deck} ({group}) is {label(value)} but expected {label(expected)}"
    )

@then("deck {deck_a:d} {prop} should be equal to deck {deck_b:d}")
def step_deck_property_equal(context, deck_a, prop, deck_b):
    group_a = _deck_group(deck_a)
    group_b = _deck_group(deck_b)
    key = DECK_PROPERTY_MAP.get(prop, prop)
    current = _get_control_value(context, group_a, key)
    expected = _get_control_value(context, group_b, key)
    assert current == expected, (
        f"{prop} on deck {deck_a} ({group_a}) differs from {deck_b} ({group_b}): {current} != {expected}"
    )

@then("the play button on deck {deck:d} should be {assertion}")
def step_play_pressed(context, deck, assertion):
    group = _deck_group(deck)
    expected = assertion == "pressed"
    value = _get_property(context, _deck_button_path(deck, "play"), "highlight") == "true"
    label = lambda x: 'pressed' if x else 'released'
    assert value is expected, (
        f"Play button on deck {deck} ({group}) is {label(value)} but expected {label(expected)}"
    )

@then("the cue point should be set on deck {deck:d}")
def step_cue_set(context, deck):
    group = _deck_group(deck)
    value = _get_control_value(context, group, "cue_point")
    assert float(value) > 0, f"cue_point not set (value={value})"

@then("hotcue {hotcue:d} should {assertion} set on deck {deck:d}")
def step_hotcue_assertion(context, hotcue, assertion, deck):
    group = _deck_group(deck)
    expected = assertion == "be"
    value = float(_get_control_value(context, group, f"hotcue_{hotcue}_status"))
    assert (value > 0) == expected, (
        f"hotcue_{hotcue} {'not set' if expected else 'still set'} (value={value})"
    )

@then("the loop should {assertion} enabled on deck {deck:d}")
def step_loop_assertion(context, assertion, deck):
    group = _deck_group(deck)
    expected = assertion == "be"
    value = float(_get_control_value(context, group, "loop_enabled"))
    assert (value > 0) == expected, (
        f"Loop on deck {deck} ({group}) is {'not enabled' if expected else 'still enabled'} (loop_enabled={value})"
    )

@then('the "{prop}" of deck {deck:d} should have changed')
def step_value_changed(context, prop, deck):
    current = _get_control_value(
        context, _deck_group(deck), REMEMBERED_CO_KEYS[prop])
    saved = _remembered_value(context, prop)
    assert current != saved, (
        f"{prop} did not change on deck {deck} ({_deck_group(deck)}): "
        f"was {saved}, is {current}"
    )
    _remember(context, prop, current)

@then("sync should be {assertion} on deck {deck:d}")
def step_sync_assertion(context, assertion, deck):
    group = _deck_group(deck)
    value = float(_get_control_value(context, group, "sync_enabled"))
    expected = assertion == "enabled"
    assert (value > 0) == expected, (
        f"Sync on deck {deck} ({group}) is {'not ' if expected else ''}enabled (value={value})"
    )

@then("deck {deck:d} should be the sync leader")
def step_sync_leader(context, deck):
    group = _deck_group(deck)
    leader = _get_control_value(context, group, "sync_leader")
    assert float(leader) > 0, (
        f"Deck {deck} ({group}) is not the sync leader (sync_leader={leader})"
    )

@then("the rate of deck {deck:d} should be near {target}")
def step_rate_near(context, deck, target):
    group = _deck_group(deck)
    actual = float(_get_control_value(context, group, "rate"))
    tol = 0.01
    assert abs(actual - float(target)) < tol, (
        f"Rate on deck {deck} ({group}) is {actual}, expected ~{target}"
    )

@then("the rate ratio of deck {deck:d} should be near {target}")
def step_rate_ratio_near(context, deck, target):
    group = _deck_group(deck)
    actual = float(_get_control_value(context, group, "rate_ratio"))
    tol = 0.01
    assert abs(actual - float(target)) < tol, (
        f"Rate ratio on deck {deck} ({group}) is {actual}, expected ~{target}"
    )

@then("edit mode should {assertion} enabled")
def step_edit_mode_assertion(context, assertion):
    checked = _get_property(context, "mainWindow/editDeckButton", "checked")
    expected = assertion == "be"
    assert (checked == "true") == expected, (
        f"Edit mode {'not enabled' if expected else 'still enabled'} (checked={checked})"
    )

@then('the edit overlay should {action} visible on the "{component}" component in deck {deck:d}')
def step_edit_overlay_visible(context, action, component, deck):
    path = f"{_deck_button_path(deck, component)}Item/overlayItem"
    if action == "be":
        assert _is_visible(context, path), f"Component '{component}' is not visible"
    else:
        assert not _is_visible(context, path), f"Component '{component}' is visible"

@then('the "{component}" component should appear {cardinality} the "{target}" component in deck {deck:d}')
def step_component_order_after(context, component, cardinality, target, deck):
    cmp = lambda a, b: a[0] > b[0]
    if cardinality == "before":
        cmp = lambda a, b: a[0] < b[0]
    elif cardinality == "under":
        cmp = lambda a, b: a[1] > b[1]
    elif cardinality == "above":
        cmp = lambda a, b: a[1] < b[1]
    component_bb = context.rpc.getBoundingBox(_deck_button_path(deck, component))
    target_bb = context.rpc.getBoundingBox(_deck_button_path(deck, target))
    assert cmp(component_bb, target_bb), (
        f"Component {component} (x={component_bb[0]}) is not {cardinality} {target} (x={target_bb[0]})"
    )

@then("a track {assertion} loaded on deck {deck:d}")
def step_track_is_loaded_on_deck(context, assertion, deck):
    group = _deck_group(deck)
    expected = assertion == "is"
    reverse = "is not" if expected else "is"
    assert bool(_get_control_value(context, group, "track_loaded")) is expected, f"Track {reverse} loaded on {group}"


# --- Hotcue popup (sub feature) ---

# The hotcue popup is re-parented to the window overlay when opened, where
# it is reachable through its generated QQuickPopupItem ("HotcuePopup");
# the popup's own content tree hangs under its "hotcuePopupContent<uid>"
# node. Every popup-internal objectName is suffixed with "<uid>" (deck
# group + hotcue number) because every HotcueButton instantiates its own
# popup with identical child names.
HOTCUE_POPUP_ITEM = "mainWindow/HotcuePopup"

# name -> (location, element objectName). "waveform" elements live in the
# popup's waveform patch, "popup" ones in the popup content tree.
HOTCUE_POPUP_BUTTONS = {
    "delete": ("popup", "hotcuePopupDeleteButton"),
    "swap": ("waveform", "hotcuePopupSwapButton"),
    "previous type": ("popup", "hotcuePopupTypePrev"),
    "next type": ("popup", "hotcuePopupTypeNext"),
}

HOTCUE_TYPE_VALUES = {"CUE": 1, "LOOP": 4, "JUMP": 5}
HOTCUE_TYPE_NAMES = {value: name for name, value in HOTCUE_TYPE_VALUES.items()}
MAX_ZOOM = 10.0
MIN_ZOOM = 1.0


def _hotcue_popup(context, name, hotcue=None, deck=None):
    """Path of a named element inside the opened hotcue popup.

    Only the content node carries the instance uid, so every child lookup
    must start from "HotcuePopup/hotcuePopupContent<uid>" and then use plain
    child objectNames (unique within the popup content subtree).
    """
    hotcue = hotcue or getattr(context, "_popup_hotcue", 1)
    deck = deck or getattr(context, "_popup_deck", 1)
    uid = f"Channel{deck}-{hotcue}"
    if name.startswith("hotcuePopupContent"):
        return f"{HOTCUE_POPUP_ITEM}/{name}{uid}"
    return f"{HOTCUE_POPUP_ITEM}/hotcuePopupContent{uid}/{name}"


def _hotcue_waveform(context, name, hotcue=None, deck=None):
    """Path of a named element inside the popup waveform patch."""
    return f"{_hotcue_popup(context, 'hotcuePopupWaveform', hotcue, deck)}/{name}"


def _is_open(context, hotcue=None, deck=None):
    # The Popup object itself is not reachable as an Item by spix, so "open"
    # is recognized through the visibility of the popup content tree
    return _is_visible(context, _hotcue_popup(context, "hotcuePopupContent", hotcue, deck))


def _open_hotcue_popup(context, deck, hotcue):
    context._popup_deck = deck
    context._popup_hotcue = hotcue
    path = _deck_hotcue_path(deck, hotcue)
    popup_path = _hotcue_popup(context, "hotcuePopupContent")
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


def _read_hotcue_waveform_zoom(context, prop="zoom"):
    try:
        return float(_get_property(
            context, _hotcue_popup(context, "hotcuePopupWaveform"), prop))
    except (TypeError, ValueError):
        return None


def _set_hotcue_waveform_zoom(context, value):
    zoom_path = _hotcue_popup(context, "hotcuePopupWaveform")
    context.rpc.setStringProperty(zoom_path, "zoom", str(value))
    deadline = time.time() + 5.0
    while time.time() < deadline:
        zoom = _read_hotcue_waveform_zoom(context)
        if zoom is not None and abs(value - zoom) <= 1e-3:
            break
        time.sleep(0.1)
    else:
        raise AssertionError(
            f"could not apply the {zoom_path!r} zoom value {value!r}")
    # Let the zoom and splitView animations settle
    time.sleep(2)


# Given: popup preconditions


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
    group = _deck_group(deck)
    _set_hotcue(context, group, hotcue, hotcue_type=hotcue_type)
    actual = _get_control_value(
        context, _deck_group(deck), f"hotcue_{hotcue}_type")
    assert actual == expected_type, f"Unable to set the hotcue type (is {actual})"


@given('the label of hotcue {hotcue:d} on deck {deck:d} is "{text}"')
def step_given_hotcue_label(context, text, hotcue, deck):
    context._popup_hotcue = hotcue
    context._popup_deck = deck
    group = _deck_group(deck)
    _set_hotcue(context, group, hotcue, text)
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


@given("the hotcue color of hotcue {hotcue:d} on deck {deck:d} is remembered")
def step_remember_hotcue_color(context, hotcue, deck):
    _remember(
        context,
        ("hotcue color", deck, hotcue),
        _get_control_value(
            context, _deck_group(deck), f"hotcue_{hotcue}_color"),
    )


# The "is remembered" step is also used after Then steps (Then-cascaded And),
# so it keeps its @then alias besides the impersonal @given form.
@then("the hotcue span of hotcue {hotcue:d} on deck {deck:d} is remembered")
@given("the hotcue span of hotcue {hotcue:d} on deck {deck:d} is remembered")
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


# When: popup interactions


@when("I right-click hotcue {hotcue:d} on deck {deck:d}")
def step_right_click_hotcue(context, hotcue, deck):
    _open_hotcue_popup(context, deck, hotcue)


@when('I click the "{name}" button in the popup')
@when('I click the "{name}" arrow in the popup')
def step_click_popup_button(context, name):
    try:
        location, element = HOTCUE_POPUP_BUTTONS[name]
    except KeyError:
        raise ValueError(f'Unknown popup button "{name}"')
    if location == "waveform":
        path = _hotcue_waveform(context, element)
    else:
        path = _hotcue_popup(context, element)
    _click(context, path)


@when("I click hotcue color swatch {num:d} in the popup")
def step_click_swatch(context, num):
    _click(context, f"{_hotcue_popup(context, 'hotcuePopupSwatch_')}{num - 1}")


@when('I enter "{text}" in the hotcue popup label field')
def step_enter_label(context, text):
    label = _hotcue_popup(context, "hotcuePopupLabelField")
    _wait_for_visible(context, label),
    _click(context, label)
    context.rpc.inputText(label, text)


@when("I clear the hotcue popup label field")
def step_clear_label_field(context):
    label = _hotcue_popup(context, "hotcuePopupLabelField")
    _click(context, label)
    time.sleep(0.3)
    context.rpc.enterKey("mainWindow", QT_KEY_A, QT_CONTROL_MODIFIER)
    time.sleep(0.3)
    context.rpc.enterKey("mainWindow", QT_KEY_BACKSPACE, 0)
    time.sleep(0.3)
    assert _get_property(context, label, "text") == "", (
        "could not clear the hotcue popup label field")


@when("I press Enter in the hotcue popup label field")
def step_press_label_enter(context):
    context.rpc.enterKey(_hotcue_popup(context, "hotcuePopupLabelField"), QT_KEY_ENTER, 0)


@when("I press Escape in the hotcue popup")
def step_press_escape_hotcue_popup(context):
    # No item inside the popup is focused, so the Escape key event is
    # delivered to the popup item, which discards the popup
    context.rpc.enterKey(_hotcue_popup(context, "hotcuePopupContent"), QT_KEY_ESCAPE, 0)


@when("I zoom the hotcue popup waveform in by {steps:d} steps")
def step_zoom_in(context, steps):
    zoom = _read_hotcue_waveform_zoom(context)
    assert zoom is not None, (
        "could not read the hotcue popup waveform zoom property")
    _set_hotcue_waveform_zoom(context, max(MIN_ZOOM, zoom - steps))


@when("I zoom the hotcue popup waveform out by {steps:d} steps")
def step_zoom_out(context, steps):
    zoom = _read_hotcue_waveform_zoom(context)
    assert zoom is not None, (
        "could not read the hotcue popup waveform zoom property")
    _set_hotcue_waveform_zoom(context, min(MAX_ZOOM, zoom + steps))


@when("I zoom the hotcue popup waveform out to fit the span")
def step_zoom_out_fit(context):
    # Write the ideal zoom that the popup targeting the span would apply;
    # writing it directly breaks the binding the same way a wheel event would
    ideal = _read_hotcue_waveform_zoom(context, "idealZoom")
    assert ideal is not None, "could not read the ideal zoom"
    _set_hotcue_waveform_zoom(context, max(MIN_ZOOM, min(MAX_ZOOM, ideal)))


# Then: popup assertions


@then("the hotcue popup should be open")
def step_popup_open(context):
    assert _is_open(context), "hotcue popup not open"


@then("the hotcue popup should be closed")
def step_popup_closed(context):
    assert not _is_open(context), "hotcue popup still open"


@then("the hotcue popup label field should be visible")
def step_label_is_visible(context):
    assert _is_visible(context, _hotcue_popup(context, "hotcuePopupLabelField")), (
        "hotcue popup label field not visible")


@then("the hotcue popup delete button should be visible")
def step_delete_is_visible(context):
    assert _is_visible(context, _hotcue_popup(context, "hotcuePopupDeleteButton")), (
        "hotcue popup delete button not visible")


def _swatch_count(context):
    return int(float(_get_property(
        context, _hotcue_popup(context, "hotcuePopupSwatches"), "count")))


@then("the hotcue popup color swatches should be visible")
def step_swatches_is_visible(context):
    count = _swatch_count(context)
    assert count >= 1, f"unexpected swatch count {count}"
    for i in range(count):
        assert _is_visible(
            context, f"{_hotcue_popup(context, 'hotcuePopupSwatch_')}{i}"), (
            f"swatch {i} not visible")


@then('the hotcue popup label should show "{text}"')
def step_label_shows(context, text):
    # The deck hotcue button label mirrors the committed cue label; allow
    # the model update to settle before reading
    value = _wait_until_label_set(context, text)
    assert value == text, f"label shows {value!r}, expected {text!r}"


@then("the hotcue popup label should be empty")
def step_label_is_empty(context):
    value = _wait_until_label_set(context, "")
    assert value == "", f"label shows {value!r}, expected the empty string"


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


# Then: waveform assertions


@then("the hotcue popup waveform should be visible")
def step_waveform_is_visible(context):
    assert _is_visible(
        context, _hotcue_waveform(context, "hotcuePopupWaveformFull")), (
        "hotcue popup waveform not visible")


@then("the hotcue popup start notch should {assertion} visible")
def step_start_notch_visible(context, assertion):
    expected = assertion == "be"
    assert _is_visible(context, _hotcue_waveform(context, "hotcuePopupStartNotch")) is expected, (
        f"hotcue popup start notch {'not ' if expected else 'still '}visible")


@then("the hotcue popup end notch should {assertion} visible")
def step_end_notch_visible(context, assertion):
    expected = assertion == "be"
    assert _is_visible(context, _hotcue_waveform(context, "hotcuePopupEndNotch")) is expected, (
        f"hotcue popup end notch {'not ' if expected else 'still '}visible")


@then("the span filler should {assertion} visible")
def step_filler_visible(context, assertion):
    expected = assertion == "be"
    assert _is_visible(context, _hotcue_waveform(context, "hotcuePopupSpanFiller")) is expected, (
        f"span filler {'not ' if expected else 'still '}visible")


@then("the hotcue popup should {assertion} in split view")
def step_split_view(context, assertion):
    expected = assertion == "be"
    in_split = _get_property(
        context, _hotcue_popup(context, "hotcuePopupWaveform"), "splitView") == "true"
    assert in_split is expected, (
        "in split view" if expected else "in split view unexpectedly")
    if expected:
        assert _is_visible(
            context, _hotcue_waveform(context, "hotcuePopupWaveformPartial")), (
            "hotcue popup split view target half not visible")


@then("the split view {half} half should {assertion} visible")
def step_split_half_visible(context, half, assertion):
    assert half in ("start", "target"), f"unknown split view half {half!r}"
    expected = assertion == "be"
    path = _hotcue_waveform(
        context,
        "hotcuePopupWaveformFull" if half == "start"
        else "hotcuePopupWaveformPartial")
    assert _is_visible(context, path) is expected, (
        f"split view {half} half {'not ' if expected else 'still '}visible")


@then("the loop warp seam should be visible")
def step_loop_seam_is_visible(context):
    assert _is_visible(context, _hotcue_waveform(context, "hotcuePopupLoopSeam")), (
        "loop warp seam not visible")


@then("the jump warp divider should be visible")
def step_jump_divider_is_visible(context):
    assert _is_visible(context, _hotcue_waveform(context, "hotcuePopupJumpDivider")), (
        "jump warp divider not visible")


@then("the skip shade above the split should be visible")
def step_shade_top_is_visible(context):
    assert _is_visible(context, _hotcue_waveform(context, "hotcuePopupSkipShadeTop")), (
        "skip shade above the split not visible")


@then("the skip shade below the split should be visible")
def step_shade_bottom_is_visible(context):
    assert _is_visible(context, _hotcue_waveform(context, "hotcuePopupSkipShadeBottom")), (
        "skip shade below the split not visible")


@then("the swap button should be visible")
def step_swap_is_visible(context):
    assert _is_visible(context, _hotcue_waveform(context, "hotcuePopupSwapButton")), (
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
        _hotcue_waveform(context, "hotcuePopupWaveformFull"),
        _get_control_value(
            context, group, f"hotcue_{hotcue}_position"))


@then("the split view target half should display the span end position")
def step_split_target_half_position(context):
    hotcue = getattr(context, "_popup_hotcue", 1)
    group = _deck_group(getattr(context, "_popup_deck", 1))
    _assert_split_half_position(
        context,
        _hotcue_waveform(context, "hotcuePopupWaveformPartial"),
        _get_control_value(
            context, group, f"hotcue_{hotcue}_endposition"))


# Then: geometry assertions


@then("the hotcue popup start notch should be centered within the waveform")
def step_start_notch_centered(context):
    rect = _get_bb(context, _hotcue_waveform(context, "hotcuePopupWaveformFull"))
    notch = _get_bb(context, _hotcue_waveform(context, "hotcuePopupStartNotch"))
    center = notch["x"] + notch["width"] / 2
    expected = rect["x"] + rect["width"] / 2
    assert abs(center - expected) <= 3, f"start notch center {center} != {expected}"


@then("the span filler should cover about two thirds of the waveform")
def step_filler_two_thirds(context):
    rect = _get_bb(context, _hotcue_waveform(context, "hotcuePopupWaveformFull"))
    filler = _get_bb(context, _hotcue_waveform(context, "hotcuePopupSpanFiller"))
    ratio = filler["width"] / rect["width"]
    assert 0.58 <= ratio <= 0.74, f"span filler ratio {ratio} not ~2/3"


def _assert_centered_on_edge(context, edge):
    filler = _get_bb(context, _hotcue_waveform(context, "hotcuePopupSpanFiller"))
    notch_path = (
        "hotcuePopupStartNotch" if edge == "start" else "hotcuePopupEndNotch")
    notch = _get_bb(context, _hotcue_waveform(context, notch_path))
    center = notch["x"] + notch["width"] / 2
    expected = filler["x"] if edge == "start" else filler["x"] + filler["width"]
    assert abs(center - expected) <= 3, f"notch center {center} != filler {edge} {expected}"


@then("the hotcue popup start notch should be centered on the span filler start edge")
def step_start_notch_on_start_edge(context):
    _assert_centered_on_edge(context, "start")


@then("the hotcue popup end notch should be centered on the span filler end edge")
def step_end_notch_on_end_edge(context):
    _assert_centered_on_edge(context, "end")
