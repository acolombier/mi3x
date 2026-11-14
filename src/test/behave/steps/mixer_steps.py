"""Feature-specific step definitions for the Mixer & Effects settings.

Covers the persistence assertions that the generic settings steps cannot
express: whether an EQ shelf value actually reached the engine ControlObjects,
and whether the effect-graph state (main EQ, per-deck EQ/QuickEffect) was
applied by the Save button — read back through the ``getEffectsState`` RPC
command rather than ``effects.xml`` (which is only written on shutdown).

Shared machinery lives in settings_steps.py / mixxx_steps.py / helpers.py.
All imports are module-level: behave discovers steps/*.py alphabetically,
and the common modules must not be pulled in ahead of this file's own (more
specific) step registrations.
"""

import time

from behave import then, when

from helpers import (
    QT_KEY_DOWN,
    QT_KEY_ENTER,
    QT_KEY_UP,
    _click,
    _get_control_value,
    _get_effects_state,
    _get_property,
    _set_property,
    wait_visible,
)


# Setting -> (ControlObject group, key) that the setting is expected to drive.
# For the EQ shelves these are the coarse controls the EQ effects actually read
# (see EffectsManager's m_hiEqFreq / m_loEqFreq and the builtin EQ effects).
MIXER_CONTROL_MAP = {
    "high EQ shelf": ("[Mixer Profile]", "HiEQFrequency"),
    "low EQ shelf": ("[Mixer Profile]", "LoEQFrequency"),
}

# Setting -> (config group, key) written by saveEqualizers() via QmlConfigProxy.
# These are the "*Precise" keys; the coarse ControlObjects above are a separate
# concern and are the reason a shelf can "show" saved while the engine ignores it.
MIXER_CONFIG_MAP = {
    "high EQ shelf": ("[Mixer Profile]", "HiEQFrequencyPrecise"),
    "low EQ shelf": ("[Mixer Profile]", "LoEQFrequencyPrecise"),
}

# Deck EQ combo (Skin.ComboBox, textRole "display") shows the effect's
# *display* name (shortName), while the effect chain reports the manifest
# uniqueId (see the getEffectsState RPC command). Map the human-readable full
# name to both.
DECK_EQ_EFFECTS = {
    "Biquad Full Kill Equalizer": {
        "display": "BQ EQ/ISO",
        "uniqueId": "org.mixxx.effects.biquadfullkilleq Built-In",
    },
    "Bessel4 LV-Mix Isolator": {
        "display": "Bessel4 ISO",
        "uniqueId": "org.mixxx.effects.bessel4lvmixeq Built-In",
    },
    "Bessel8 LV-Mix Isolator": {
        "display": "Bessel8 ISO",
        "uniqueId": "org.mixxx.effects.bessel8lvmixeq Built-In",
    },
    "LinkwitzRiley8 Isolator": {
        "display": "LR8 ISO",
        "uniqueId": "org.mixxx.effects.linkwitzrileyeq Built-In",
    },
}


def _get_config_value(context, group, key):
    context.rpc.command("getConfigValue", f"{group},{key}")
    return context.rpc.getStringProperty("mainWindow", "lastConfigValue")


def _deck_eq_combo_path(deck):
    return f"mainWindow/mixerEffectDeckEq_{deck}"


def _deck_quickfx_combo_path(deck):
    return f"mainWindow/mixerEffectDeckQuickEffect_{deck}"


def _combo_index_of_text(context, path, text):
    count = int(_get_property(context, path, "count"))
    available = []
    for index in range(count):
        actual = context.rpc.invokeMethod(path, "textAt", [index])
        available.append(str(actual))
        if str(actual) == text:
            return index
    raise AssertionError(
        f"No combo option '{text}' in '{path}' (count={count}); options: {available}"
    )


def _scroll_combo_option_into_view(context, path, index):
    """Scroll the combo popup's list so option ``index`` is clickable.

    Mirror of settings_steps._scroll_combo_option_into_view; duplicated here
    because the common step modules must not be imported ahead of this file's
    own (more specific) step registrations.
    """
    list_path = f"{path}_popupList"
    option_path = f"{list_path}/option_{index}"
    deadline = time.time() + 8
    while time.time() < deadline:
        try:
            content_y = float(_get_property(context, list_path, "contentY") or 0)
            content_height = float(_get_property(context, list_path, "contentHeight") or 0)
            lx, ly, lw, lh = context.rpc.getBoundingBox(list_path)
        except Exception:
            return False
        max_y = max(0.0, content_height - lh)
        option_bb = None
        try:
            option_bb = context.rpc.getBoundingBox(option_path)
        except Exception:
            pass
        if option_bb is None or option_bb[2] <= 0 or option_bb[3] <= 0:
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
            shift = (oy + oh) - (ly + lh)
        else:
            shift = -(ly - oy)
        target_y = max(0.0, min(content_y + shift, max_y))
        if abs(target_y - content_y) < 1.0:
            center = oy + oh / 2
            return ly <= center <= ly + lh
        _set_property(context, list_path, "contentY", str(target_y))
        time.sleep(0.3)
    return False


def _combo_select_keyboard(context, path, index):
    """Select a combo option via keyboard when its delegate is not rendered."""
    raw = _get_property(context, path, "highlightedIndex")
    highlighted = int(raw) if raw not in ("", None) else -1
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


def _select_combo_text(context, path, text):
    """Open a combo and select the option whose display text is ``text``.

    Mirrors the generic settings combo step: click the combo, click the option
    delegate when it is already rendered (options within ``popupMaxItem``), and
    fall back to keyboard navigation for options below the fold.
    """
    index = _combo_index_of_text(context, path, text)
    _click(context, path)
    option_path = f"{path}_popupList/option_{index}"
    in_view = bool(wait_visible(context.rpc, option_path)) and _scroll_combo_option_into_view(
        context, path, index
    )
    if in_view:
        _click(context, option_path)
    else:
        _combo_select_keyboard(context, path, index)
    time.sleep(0.3)


def _assert_combo_text(context, path, text):
    actual = _get_property(context, path, "currentText")
    assert actual == text, f"'{path}' should show '{text}' but is '{actual}'"


@then('the "{setting}" should be applied to the engine as "{value}"')
def step_setting_applied_to_engine(context, setting, value):
    """Assert a setting reached its live ControlObject (not just config).

    The EQ shelves currently write only the *Precise config keys, leaving the
    coarse ControlObjects at their defaults, so this step is expected to fail
    until saveEqualizers() also applies the values to the engine controls.
    """
    group, key = MIXER_CONTROL_MAP[setting]
    actual = _get_control_value(context, group, key)
    expected = float(value)
    assert abs(actual - expected) <= 1.0, (
        f"Setting '{setting}' should drive [{group}],{key} to {expected} "
        f"but the control value is {actual}"
    )


@then('the "{setting}" should be saved in the mixer config as "{value}"')
def step_setting_saved_in_mixer_config(context, setting, value):
    group, key = MIXER_CONFIG_MAP[setting]
    actual = _get_config_value(context, group, key)
    expected = float(value)
    assert abs(float(actual) - expected) <= 1e-6, (
        f"Setting '{setting}' should be saved to [{group}],{key} as {expected} "
        f"but the config value is '{actual}'"
    )


@then('the main EQ effect should be saved as "{unique_id}"')
def step_main_eq_saved(context, unique_id):
    """Assert the main EQ effect currently loaded on the output chain.

    Read back through the getEffectsState RPC command (the in-memory state
    that Save applies), not effects.xml, which is only flushed on shutdown.
    """
    state = _get_effects_state(context)
    actual = state.get("mainEq")
    assert actual == unique_id, (
        f"Main EQ effect should be saved as '{unique_id}' but is '{actual}'"
    )


@when('I select "{name}" as the EQ effect on deck {deck:d}')
def step_select_deck_eq(context, name, deck):
    info = DECK_EQ_EFFECTS[name]
    _select_combo_text(context, _deck_eq_combo_path(deck), info["display"])


@when('I select "{name}" as the QuickEffect on deck {deck:d}')
def step_select_deck_quickfx(context, name, deck):
    _select_combo_text(context, _deck_quickfx_combo_path(deck), name)


@then('the deck {deck:d} EQ effect should be "{name}"')
def step_deck_eq_should_be(context, deck, name):
    _assert_combo_text(context, _deck_eq_combo_path(deck), DECK_EQ_EFFECTS[name]["display"])


@then('the deck {deck:d} QuickEffect should be "{name}"')
def step_deck_quickfx_should_be(context, deck, name):
    _assert_combo_text(context, _deck_quickfx_combo_path(deck), name)


@then('the deck {deck:d} EQ effect should be saved as "{name}"')
def step_deck_eq_saved(context, deck, name):
    unique_id = DECK_EQ_EFFECTS[name]["uniqueId"]
    group = f"[Channel{deck}]"
    state = _get_effects_state(context)
    for deck_state in state.get("decks", []):
        if deck_state.get("group") == group:
            actual = deck_state.get("eq")
            assert actual == unique_id, (
                f"Deck {deck} EQ should be saved as '{unique_id}' but is '{actual}'"
            )
            return
    raise AssertionError(f"getEffectsState reported no EQ entry for {group}")


@then('the deck {deck:d} QuickEffect should be saved as "{name}"')
def step_deck_quickfx_saved(context, deck, name):
    group = f"[Channel{deck}]"
    state = _get_effects_state(context)
    for deck_state in state.get("decks", []):
        if deck_state.get("group") == group:
            actual = deck_state.get("quickEffect")
            assert actual == name, (
                f"Deck {deck} QuickEffect should be saved as '{name}' but is '{actual}'"
            )
            return
    raise AssertionError(f"getEffectsState reported no QuickEffect entry for {group}")
