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
    QT_LEFT_BUTTON,
    REMEMBERED_CO_KEYS,
    _click,
    _deck_button_path,
    _deck_group,
    _deck_hotcue_path,
    _get_control_value,
    _get_property,
    _is_visible,
    _long_press,
    _remember,
    _remembered_value,
    _set_control_value,
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
