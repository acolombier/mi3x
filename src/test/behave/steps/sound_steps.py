"""Feature-specific step definitions for sound.

Split out of the former monolithic step modules; shared machinery
lives in mixxx_steps.py / settings_steps.py / helpers.py.
All imports are module-level: behave discovers steps/*.py
alphabetically, and the common modules must not be pulled in ahead
of this file's own (more specific) step registrations."""

from helpers import (
    COMMITTING_OVERLAY,
    DELAYS_SECTION,
    ENGINE_SECTION,
    INPUT_COLUMN,
    OUTPUT_COLUMN,
    ROUTER_SECTION,
    _MULTI_SOUNDCARD_OPTION_INDEX,
    _ROUTER_MODE_OPTION_INDEX,
    _click,
    _click_active_button,
    _edge_path,
    _entity_path,
    _find_first_free_output_edge,
    _get_property,
    _get_router_mode,
    _is_visible,
    _set_router_mode,
    _wait_for_hidden,
)
from helpers import (
    wait_hidden,
    wait_visible,
)
from behave import given, when, then

import time


@given('the router mode is "{mode}"')
def step_router_mode_is(context, mode):
    current = _get_router_mode(context)
    if current != mode:
        _set_router_mode(context, mode)

@given('a saved connection exists from "{edge}" on "{entity}" to an output device')
def step_saved_connection_exists(context, edge, entity):
    source_path = _edge_path(entity, edge)
    assert wait_visible(context.rpc, source_path), f"Source edge {edge} on {entity} not visible"
    _click(context, source_path)
    time.sleep(0.5)
    sink_path = _find_first_free_output_edge(context)
    assert sink_path and wait_visible(context.rpc, sink_path), "No free output device edge found"
    _click(context, sink_path)
    time.sleep(0.3)
    _click_active_button(context, 'save')
    # Certain operation may take more than 5 second to apply, such as the ALSA API switch
    _wait_for_hidden(context, COMMITTING_OVERLAY, timeout=10)

@when('I set the router mode to "{mode}"')
def step_set_router_mode(context, mode):
    _set_router_mode(context, mode)

@when('I connect the "{edge}" edge on "{entity}" entity to a free output device with {mean}')
@when('I connect the "{edge}" edge on "{entity}" entity to a free output device')
def step_connect_edge_to_output_alt(context, edge, entity, mean="two clicks"):
    source_path = _edge_path(entity, edge)
    assert wait_visible(context.rpc, source_path), f"Source edge {edge} on {entity} not visible"
    if mean == "two clicks":
        _click(context, source_path)
        time.sleep(0.5)
        sink_path = _find_first_free_output_edge(context)
        assert sink_path and wait_visible(context.rpc, sink_path), "No free output device edge found"
        _click(context, sink_path)
        time.sleep(0.5)
    else:
        # FIXME not correctly working
        source_bb = context.rpc.getBoundingBox(source_path)
        sink_path = _find_first_free_output_edge(context)
        assert sink_path and wait_visible(context.rpc, sink_path), "No free output device edge found"
        sink_bb = context.rpc.getBoundingBox(sink_path)
        delta = sink_bb[0] - source_bb[0], sink_bb[1] - source_bb[1]
        context.rpc.mouseDrag(source_path, 0.5, 0.5, *delta, 1000)

@when('I hover over the "{edge}" edge on "{entity}" entity')
def step_hover_edge(context, edge, entity):
    # TODO: spix has no mouseHover/mouseMoveTo API. mouseClick triggers onPressed,
    # not onEntered. The AudioEntity edge MouseArea uses onEntered to set the
    # AboutToDelete flag (AudioConnection.Flags). Need either:
    #   1. A spix API for hover events (mouseHover / mouseMoveTo)
    #   2. A custom C++ command to directly set the AboutToDelete flag
    raise NotImplementedError(
        "spix has no hover API; mouseClick triggers onPressed not onEntered. "
        "Cannot simulate hover to set AudioConnection.Flags.AboutToDelete."
    )

@then("the engine section should be visible")
def step_engine_visible(context):
    assert _is_visible(context, ENGINE_SECTION), "Engine section is not visible"

@then("the delays section should be visible")
def step_delays_visible(context):
    assert _is_visible(context, DELAYS_SECTION), "Delays section is not visible"

@then("the committing overlay should be visible")
def step_committing_visible(context):
    assert _is_visible(context, COMMITTING_OVERLAY), "Committing overlay is not visible"

@then("the committing overlay should not be visible after commit")
@when("the committing overlay is not visible")
def step_committing_hidden(context):
    assert wait_hidden(context.rpc, COMMITTING_OVERLAY, timeout=15), "Committing overlay did not disappear"

@then("the router section should be visible")
def step_router_visible(context):
    assert _is_visible(context, ROUTER_SECTION), "Router section is not visible"

@then('the router mode should be "{mode}"')
def step_router_mode_should_be(context, mode):
    current = _get_router_mode(context)
    assert current == mode, f"Router mode should be '{mode}' but is '{current}'"

@then("the outputs column should be visible")
def step_outputs_visible(context):
    assert _is_visible(context, OUTPUT_COLUMN), "Outputs column is not visible"

@then("the inputs column should be visible")
def step_inputs_visible(context):
    assert _is_visible(context, INPUT_COLUMN), "Inputs column is not visible"

@then("the input column should not be visible")
def step_input_not_visible(context):
    assert not _is_visible(context, INPUT_COLUMN), "Input column should not be visible"

@then('the "{entity}" entity should be visible in the router')
def step_entity_visible(context, entity):
    path = _entity_path(entity)
    assert _is_visible(context, path), f"Entity '{entity}' is not visible in the router"

@then('the "{entity}" entity should not be visible in the router')
def step_entity_not_visible(context, entity):
    path = _entity_path(entity)
    assert not _is_visible(context, path), f"Entity '{entity}' should not be visible in the router"

@then('the "{edge}" edge on "{entity}" entity should show {state} state')
def step_edge_state(context, edge, entity, state):
    path = _edge_path(entity, edge)
    assert wait_visible(context.rpc, path), f"Edge {edge} on {entity} not visible"
    actual = _get_property(context, path, "state")
    assert actual == state, f"Edge {edge} on {entity} should show '{state}' state but shows '{actual}'"

@then('the connection from "{edge}" on "{entity}" should show {state} state')
def step_connection_state(context, edge, entity, state):
    path = _edge_path(entity, edge)
    assert wait_visible(context.rpc, path), f"Edge {edge} on {entity} not visible"
    connectionObjectName = context.rpc.invokeMethod(path, "connectionObjectName", [])
    actual = _get_property(context, f"mainWindow/{connectionObjectName}", "state")
    assert actual == state, f"Connection state is not '{state}', but '{actual}'"

@then("the router should match the saved configuration")
def step_router_matches_saved(context):
    assert _is_visible(context, ROUTER_SECTION), "Router section is not visible"
    has_changes = _get_property(context, ROUTER_SECTION, "hasChanges")
    # Require an exact "false": a missing/empty property ("" from spix when
    # the item or property is gone) must fail, not pass vacuously.
    assert has_changes == "false", (
        f"Router has unsaved changes (hasChanges={has_changes})"
    )

@then('the "{option}" option should be visible')
def step_option_visible(context, option):
    candidates = []
    idx = _ROUTER_MODE_OPTION_INDEX.get(option)
    if idx is not None:
        candidates.append(f"mainWindow/routerMode/option{idx}")
    idx = _MULTI_SOUNDCARD_OPTION_INDEX.get(option)
    if idx is not None:
        candidates.append(f"mainWindow/multiSoundcard/option{idx}")
    found = any(_is_visible(context, p) for p in candidates)
    assert found, f"Option '{option}' is not visible"
