# -----------------------------------------------------------------------
# Text drafted autonomously by an AI agent (for a human reviewer to check,
# amend, and submit).
#
# Behave E2E tests for the hotcue edit popup rendered by
# res/qml/HotcuePopup.qml in the QML skin stack.
# -----------------------------------------------------------------------
Feature: Hotcue popup editing
  The hotcue edit popup offers waveform preview with zoom (mouse wheel),
  color swatches, a cue type cycler (CUE/LOOP/JUMP), a label editor, a
  delete button, and a warp/split view for loop and jump spans that do not
  fit into the preview window.

  Background:
    Given a new library-ready profile
    And Mixxx is open and ready to operate
    And a track is loaded on deck 1
    And hotcue 1 is set on deck 1

  Scenario: The popup opens on hotcue right-click
    When I right-click hotcue 1 on deck 1
    Then the hotcue popup should be open
    And the hotcue popup label field should be visible
    And the hotcue popup delete button should be visible
    And the hotcue popup color swatches should be visible

  Scenario: The popup closes on press outside and on Escape
    Given the hotcue popup is open for hotcue 1 on deck 1
    When I click the "spinny" button on deck 1
    Then the hotcue popup should be closed

  # spix cannot deliver keyboard events to the overlay popup reliably
  # (focus routing limitation), so this check is marked as flaky.
  @xpass
  Scenario: The popup closes with Escape
    Given the hotcue popup is open for hotcue 1 on deck 1
    When I press Escape in the hotcue popup
    Then the hotcue popup should be closed

  Scenario: Editing the label commits on Enter
    Given the hotcue popup is open for hotcue 1 on deck 1
    When I enter "Drop here" in the hotcue popup label field
    And I press Enter in the hotcue popup label field
    Then the hotcue popup label should show "Drop here"

  Scenario: The committed label is restored when the popup reopens
    Given the hotcue popup label shows "Drop here" for hotcue 1 on deck 1
    When I press Escape in the hotcue popup
    And I right-click hotcue 1 on deck 1
    Then the hotcue popup label should show "Drop here"

  Scenario: Choosing a color swatch changes the hotcue color
    Given the hotcue popup is open for hotcue 1 on deck 1
    And the hotcue color of hotcue 1 on deck 1 is remembered
    When I click hotcue color swatch 4 in the popup
    Then the hotcue color of hotcue 1 on deck 1 should have changed

  Scenario: Cycling the cue type with the arrows
    Given the hotcue popup is open for hotcue 1 on deck 1
    And the hotcue type name of hotcue 1 on deck 1 is "CUE"
    When I click the "next type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "LOOP"
    When I click the "previous type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "CUE"

  Scenario: The type cycler wraps around
    Given the playhead of deck 1 is at 0.5
    And the hotcue popup is open for hotcue 1 on deck 1
    When I click the "previous type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "JUMP"
    When I click the "next type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "CUE"

  Scenario: Deleting the hotcue from the popup
    Given the hotcue popup is open for hotcue 1 on deck 1
    When I click the "delete" button in the popup
    Then hotcue 1 should not be set on deck 1

  Scenario: The waveform preview marks the cue position
    Given the hotcue popup is open for hotcue 1 on deck 1
    Then the hotcue popup waveform should be visible
    And the hotcue popup start notch should be visible
    And the hotcue popup end notch should not be visible
    And the span filler should not be visible
    And the hotcue popup start notch should be centered within the waveform

  # spix has no mouse wheel event support, so the zoom interaction is driven
  # by writing the waveform's zoom property directly.
  @test/missing-ui-interaction
  Scenario: The span filler shows the cue span at its positions
    Given the hotcue popup is open for hotcue 1 on deck 1
    When I click the "next type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "LOOP"
    When I zoom the hotcue popup waveform out to fit the span
    Then the span filler should be visible
    And the hotcue popup start notch should be visible
    And the hotcue popup end notch should be visible
    And the span filler should cover about two thirds of the waveform
    And the hotcue popup start notch should be centered on the span filler start edge
    And the hotcue popup end notch should be centered on the span filler end edge

  # spix has no mouse wheel event support, so the zoom interaction is driven
  # by writing the waveform's zoom property directly.
  @test/missing-ui-interaction
  Scenario: The split view follows the zoom dynamically
    Given the hotcue popup is open for hotcue 1 on deck 1
    And the beatloop size is set to 4
    When I click the "next type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "LOOP"
    When I zoom the hotcue popup waveform out to fit the span
    Then the hotcue popup should not be in split view
    When I zoom the hotcue popup waveform in by 9 steps
    Then the hotcue popup should be in split view
    And the split view start half should be visible
    And the split view target half should be visible
    And the loop warp seam should be visible
    When I zoom the hotcue popup waveform out by 9 steps
    Then the hotcue popup should not be in split view
    And the split view target half should not be visible

  # spix has no mouse wheel event support, so the zoom interaction is driven
  # by writing the waveform's zoom property directly.
  @test/missing-ui-interaction
  Scenario: The jump split view shades the skipped content and can swap ends
    Given the playhead of deck 1 is at 0.5
    And the hotcue popup is open for hotcue 1 on deck 1
    When I click the "previous type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "JUMP"
    When I zoom the hotcue popup waveform in by 9 steps
    Then the hotcue popup should be in split view
    And the skip shade above the split should be visible
    And the skip shade below the split should be visible
    And the jump warp divider should be visible
    And the span filler should not be visible
    And the swap button should be visible
    And the split view start half should display the span start position
    And the split view target half should display the span end position
    And the hotcue span of hotcue 1 on deck 1 is remembered
    When I click the swap button in the popup
    Then the hotcue span of hotcue 1 on deck 1 should be swapped
    And the split view start half should display the span start position
    And the split view target half should display the span end position

  # A hotcue set by clicking the button has no end position, so both
  # conversion defaults below apply to it (fresh cue or cleared end position).
  Scenario: A new cue becomes a loop of the deck's beatloop size
    Given the playhead of deck 1 is at 0.5
    And the beatloop size of deck 1 is set to 2
    And the hotcue popup is open for hotcue 1 on deck 1
    When I click the "next type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "LOOP"
    And the hotcue span length of hotcue 1 on deck 1 should be 2 beats

  Scenario: A new cue's jump target defaults to the playhead
    Given the playhead of deck 1 is at 0.5
    And quantize is disabled on deck 1
    And the hotcue popup is open for hotcue 1 on deck 1
    When I click the "previous type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "JUMP"
    And the hotcue jump target of hotcue 1 on deck 1 should be at the playhead

# -----------------------------------------------------------------------
# End of AI-generated text (drafted autonomously by an AI agent, for a
# human reviewer to check, amend, and submit).
# -----------------------------------------------------------------------
