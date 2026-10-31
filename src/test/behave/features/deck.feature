Feature: Deck

  Rule: Deck controls (empty profile)

    Background:
      Given a new empty profile
      And Mixxx is open and ready to operate

  Scenario: Show or hide all 4 decks
    When I click the "4DECKS" button
    Then the deck for "[Channel3]" should be visible
    And the deck for "[Channel4]" should be visible
    When I click the "4DECKS" button
    Then the deck for "[Channel3]" should not be visible
    And the deck for "[Channel4]" should not be visible

  Scenario: Deck play button toggles playback
    Given a track is loaded on deck 1
    When I click the "play" button on deck 1
    Then the play button on deck 1 should be pressed
    And the deck 1 should be playing
    When I click the "play" button on deck 1
    Then the play button on deck 1 should be released
    And the deck 1 should be stopped

  # The test appears flaky, cue_point seems to occasionally be set to a very low value. It could be a genuine bug tho!
  @xpass
  Scenario: Deck cue button can be triggered
    Given a track is loaded on deck 1
    When I seek to 0.05 in deck 1
    And I click the "cue" button on deck 1
    Then the cue point should be set on deck 1

  @xfail
  @sub/hotcues
  Scenario: Deck hotcue can be set and cleared
    Given a track is loaded on deck 1
    When I set hotcue 1 on deck 1
    Then hotcue 1 should be set on deck 1
    When I clear hotcue 1 on deck 1
    Then hotcue 1 should not be set on deck 1

  Scenario: Beatjump moves playback position forward
    Given a track is loaded on deck 1
    When I click the "play" button on deck 1
    And I remember the "playback position" of deck 1
    When I click the "beatjump_forward" button on deck 1
    Then the "playback position" of deck 1 should have changed

  Scenario: Loop can be set and enabled
    Given a track is loaded on deck 1
    # This is needed because with quantize=1, if loop in and out end up on the same beat, no loop will be created
    # Alternatively, we could wait X to ensure more than one beat goes by between in and out
    And the quantize on deck 1 is set to 0.0
    When I click the "play" button on deck 1
    And I click the "loop_in" button on deck 1
    And I click the "loop_out" button on deck 1
    Then the loop should be enabled on deck 1

  @xfail
  Scenario: Loop size can be halved and doubled
    Given a track is loaded on deck 1
    When I remember the "beatloop size" of deck 1
    When I halve the "beatloop" size on deck 1
    Then the "beatloop size" of deck 1 should have changed
    When I double the "beatloop" size on deck 1
    Then the "beatloop size" of deck 1 should have changed

  Scenario: Loop can be recalled after exit
    Given a track is loaded on deck 1
    When I click the "play" button on deck 1
    And I click the "loop_in" button on deck 1
    # This is needed as if loop in and out end up on the same beat, no loop will be created
    # Alternatively, we could set quantize=0
    And I wait for 1 second
    And I click the "loop_out" button on deck 1
    Then the loop should be enabled on deck 1
    When I click the "reloop_toggle" button on deck 1
    Then the loop should not be enabled on deck 1
    When I click the "reloop_toggle" button on deck 1
    Then the loop should be enabled on deck 1

  @sub/sync
  Scenario: Sync can be toggled on a deck
    Given a track is loaded on deck 1
    When I click the "sync" button on deck 1
    Then sync should be enabled on deck 1
    When I click the "sync" button on deck 1
    Then sync should be disabled on deck 1

  @xfail
  @sub/sync
  Scenario: Other deck's BPM can be copied with long press
    Given a track is loaded on deck 1
    And a track is loaded on deck 2
    When I long-press the "sync" button on deck 1
    Then deck 1 BPM should be equal to deck 2

  @sub/sync
  Scenario: Range can be cycled on a deck
    Given a track is loaded on deck 1
    When I remember the "rate range" of deck 1
    When I click the "range" button on deck 1
    Then the "rate range" of deck 1 should have changed

  @sub/sync
  Scenario: Tempo fader changes playback rate
    Given a track is loaded on deck 1
    And the sync_on deck 1 is disabled
    And the tempo rate on deck 1 is set to 0.0
    When I set the rate of deck 1 to 5%
    Then the rate of deck 1 should be near 0.05
    And the rate ratio of deck 1 should be near 1.004

  Scenario: Edit mode can be toggled
    When I click the "EDIT" button
    Then edit mode should be enabled
    When I click the "EDIT" button
    Then edit mode should not be enabled

  Scenario: Edit mode overlays are visible on deck components
    When I click the "EDIT" button
    Then the edit overlay should be visible on the "play" component in deck 1
    When I click the "EDIT" button
    Then the edit overlay should not be visible on the "play" component in deck 1

  Scenario: Edit mode: single component can be repositioned
    When I click the "EDIT" button
    And I move the "play" component in deck 1 under the "cue" component
    And I click the "EDIT" button
    Then the "play" component should appear under the "cue" component in deck 1

  Scenario: Edit mode: component group can be moved
    When I click the "EDIT" button
    And I select the group containing "play" in deck 1 with a ctrl+click
    # Select the parent's parent
    And I select the group containing "play" in deck 1 with a long press
    # Select the parent's parent's parent
    And I select the group containing "play" in deck 1 with a ctrl+click
    And I move the selected group in deck 1 after the "rateSlider" component
    And I click the "EDIT" button
    Then the "play" component should appear after the "rateSlider" component in deck 1

  @category/responsiveness
  Scenario: The spinny is hidden when the deck gets too narrow
    When I resize the window's width to 1792px
    Then the "spinny" component should be visible in deck 1
    When I resize the window's width to 1500px
    Then the "spinny" component should not be visible in deck 1

  @category/responsiveness
  Scenario: The beatjump is hidden when the deck gets too narrow
    When I resize the window's width to 1792px
    Then the "beatjump" component should be visible in deck 1
    When I resize the window's width to 1400px
    Then the "beatjump" component should not be visible in deck 1

  @category/responsiveness
  Scenario: The hotcue is hidden when the deck gets too narrow
    When I resize the window's width to 1792px
    Then the "hotcue" component should be visible in deck 1
    When I resize the window's width to 1200px
    Then the "hotcue" component should not be visible in deck 1

  @category/responsiveness
  Scenario: The tempo is hidden when the deck gets too narrow
    When I resize the window's width to 1792px
    Then the "tempo" component should be visible in deck 1
    When I resize the window's width to 700px
    Then the "tempo" component should not be visible in deck 1
    And the "play" component should be visible in deck 1

  @category/responsiveness
  Scenario: 4 decks button hides when the window is too short
    When I resize the window's height to 500px
    Then the "4DECKS" button in the main toolbar should not be visible
    When I resize the window's height to 600px
    Then the "4DECKS" button in the main toolbar should be visible

  # --- Settings: palettes (former features/settings/interface.feature) ---------
  #
  # These scenarios exercise settings UI. The palettes live on the theme &
  # color tab, which is the category's default tab.

  Rule: Palette settings (Interface category)

    Background:
      Given a new empty profile
      And Mixxx is open and ready to operate
      And the settings popup is open
      And the "Interface" category is selected

  Scenario: Key color palette is disabled when key color is off
    # Component state: keyPaletteComboBox.enabled is bound to key color == "on"
    When I toggle the "key color" setting to "off"
    And I click the save button
    Then the "key color palette" setting should be disabled
    When I toggle the "key color" setting to "on"
    And I click the save button
    Then the "key color palette" setting should be enabled

  @sub/hotcues
  Scenario Outline: Hotcue palette can be changed
    When I set the "hotcue palette" setting to "<palette>"
    Then the "hotcue palette" setting should be "<palette>"

    Examples:
      | palette                |
      | Mixxx Hotcue Colors    |
      | Rekordbox COLD2 Hotcue Colors |

  @sub/hotcues
  Scenario: Hotcue default color can be changed
    When I set the "hotcue default color" setting to "3"
    Then the "hotcue default color" setting should be "3"

  Scenario Outline: Track palette can be changed
    # The second palette is beyond the popup's visible rows (popupMaxItem = 6)
    # and exercises the keyboard-selection fallback for off-screen options.
    # Persistence is asserted in the next scenario with a non-default palette:
    # Mixxx removes a config key that equals its default, so the default
    # palette ("Mixxx Track Colors") would read back as empty.
    When I set the "track palette" setting to "<palette>"
    And I click the save button
    Then the "track palette" setting should be "<palette>"

    Examples:
      | palette                |
      | Mixxx Track Colors     |
      | Rekordbox Track Colors |

  Scenario: Track palette selection is persisted
    When I set the "track palette" setting to "Rekordbox Track Colors"
    And I click the save button
    Then the "track palette" should be saved

  Scenario: Loop default color can be changed
    When I set the "loop default color" setting to "4"
    Then the "loop default color" setting should be "4"

  # --- Settings: decks tab (former features/settings/interface.feature) --------

  Rule: Decks tab settings (Interface category)

    Background:
      Given a new empty profile
      And Mixxx is open and ready to operate
      And the settings popup is open
      And the "Interface" category is selected
      And the "decks" tab is selected

  Scenario: Cue mode can be changed
    When I set the "cue mode" setting to "Pioneer"
    And I click the save button
    Then the "cue mode" setting should be "Pioneer"

  Scenario: Intro start can be set to the main cue when analyzing
    When I toggle the "set intro start to main cue" setting to "off"
    And I click the save button
    Then the "set intro start to main cue" setting should be "off"

  Scenario: Track time display can be changed
    When I toggle the "track time display" setting to "remaining"
    And I click the save button
    Then the "track time display" setting should be "remaining"

  Scenario: Time format can be changed
    When I set the "time format" setting to "Seconds"
    Then the "time format" setting should be "Seconds"

  Scenario: Double-press load to clone can be disabled
    When I toggle the "double-press load to clone" setting to "off"
    And I click the save button
    Then the "double-press load to clone" setting should be "off"

  Scenario: Track load point can be changed
    When I set the "track load point" setting to "First hotcue"
    Then the "track load point" setting should be "First hotcue"

  Scenario: Loading a track when playing can be allowed
    When I toggle the "loading a track when playing" setting to "allow"
    And I click the save button
    Then the "loading a track when playing" setting should be "allow"

  Scenario: Speed reset on track load can be changed
    When I toggle the "reset on track load" setting to "tempo"
    And I click the save button
    Then the "reset on track load" setting should be "tempo"

  @sub/sync
  Scenario: Sync mode can be changed
    When I toggle the "sync mode" setting to "use steady"
    And I click the save button
    Then the "sync mode" setting should be "use steady"

  Scenario: Keylock mode can be changed
    When I toggle the "keylock mode" setting to "current key"
    And I click the save button
    Then the "keylock mode" setting should be "current key"

  Scenario: Keyunlock mode can be changed
    When I toggle the "keyunlock mode" setting to "keep key"
    And I click the save button
    Then the "keyunlock mode" setting should be "keep key"

  Scenario: Pitch bend behaviour can be changed
    When I toggle the "pitch bend behaviour" setting to "smooth ramping"
    And I click the save button
    Then the "pitch bend behaviour" setting should be "smooth ramping"

  Scenario: Adjustment button ranges can be changed
    When I set the "temporary coarse adjustment" setting to "4.02"
    And I set the "permanent fine adjustment" setting to "0.06"
    Then the "temporary coarse adjustment" setting should be "4.02"
    And the "permanent fine adjustment" setting should be "0.06"

  Scenario: Ramping sensitivity can be changed
    When I set the "ramping sensitivity" setting to "500" with the spinbox
    Then the "ramping sensitivity" setting should be "500"

  # --- Settings: decks tab, ControlObject side-effects --------------------------
  # (former features/settings/interface.feature)

  @xfail(gh_issue=85)
  Scenario: Slider range is applied to the deck rate range control
    When I set the "slider range" setting to "24%"
    And I click the save button
    Then the "slider range" setting should be "24%"
    And the "slider range" should be saved as "24%"
    And the "slider range" on deck 1 should be "24%"
    When I set the "slider range" setting to "16%"
    And I click the save button
    Then the "slider range" setting should be "16%"
    And the "slider range" should be saved as "16%"
    And the "slider range" on deck 1 should be "16%"

  Scenario: Slider orientation is applied to the deck rate direction control
    When I toggle the "slider orientation" setting to "down"
    And I click the save button
    Then the "slider orientation" setting should be "down"
    And the "slider orientation" should be saved as "down"
    And the "slider orientation" on deck 1 should be "down"
    When I toggle the "slider orientation" setting to "up"
    And I click the save button
    Then the "slider orientation" setting should be "up"
    And the "slider orientation" should be saved as "up"
    And the "slider orientation" on deck 1 should be "up"

  # --- Settings: responsiveness ---------------------------------------------------
  # (former features/settings/interface.feature)
  #
  # On a short window the decks tab content overflows its ScrollView. A setting
  # below the fold must be reachable: scroll it into the on-screen area, then
  # prove it is interactable by changing its value.

  @category/responsiveness
  Scenario: Below-the-fold settings can be scrolled into view on a short window
    When I resize the window's height to 500px
    Then the "ramping sensitivity" setting should not be visible on screen
    When I scroll down in the settings
    Then the "ramping sensitivity" setting should be visible on screen
    When I set the "ramping sensitivity" setting to "600" with the spinbox
    Then the "ramping sensitivity" setting should be "600"
    When I resize the window's height to 1008px

  Rule: Hotcue popup
    Background:
      Given a new library-ready profile
      And Mixxx is open and ready to operate
      And a track is loaded on deck 1
      And hotcue 1 is set on deck 1
      And hotcue 1 on deck 1 is of type "CUE"

  @sub/hotcues
  Scenario: The popup opens on hotcue right-click
    When I right-click hotcue 1 on deck 1
    Then the hotcue popup should be open
    And the hotcue popup label field should be visible
    And the hotcue popup delete button should be visible
    And the hotcue popup color swatches should be visible
  @sub/hotcues
  Scenario: The popup closes on press outside and on Escape
    Given the hotcue popup is open for hotcue 1 on deck 1
    When I click the "spinny" button on deck 1
    Then the hotcue popup should be closed

  # spix cannot deliver keyboard events to the overlay popup reliably
  # (focus routing limitation), so this check is marked as flaky.
  @xpass
  @sub/hotcues
  Scenario: The popup closes with Escape
    Given the hotcue popup is open for hotcue 1 on deck 1
    When I press Escape in the hotcue popup
    Then the hotcue popup should be closed
  @sub/hotcues
  Scenario: Editing the label commits on Enter
    Given the hotcue popup is open for hotcue 1 on deck 1
    When I enter "Drop here" in the hotcue popup label field
    And I press Enter in the hotcue popup label field
    Then the hotcue popup label should show "Drop here"
  @sub/hotcues
  Scenario: The committed label is restored when the popup reopens
    Given the label of hotcue 1 on deck 1 is "Drop here"
    When I press Escape in the hotcue popup
    And I right-click hotcue 1 on deck 1
    Then the hotcue popup label should show "Drop here"
  @sub/hotcues
  Scenario: Choosing a color swatch changes the hotcue color
    Given the hotcue popup is open for hotcue 1 on deck 1
    And the hotcue color of hotcue 1 on deck 1 is remembered
    When I click hotcue color swatch 4 in the popup
    Then the hotcue color of hotcue 1 on deck 1 should have changed
  @sub/hotcues
  Scenario: Cycling the cue type with the arrows
    Given the hotcue popup is open for hotcue 1 on deck 1
    And hotcue 1 on deck 1 is of type "CUE"
    When I click the "next type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "LOOP"
    When I click the "previous type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "CUE"
  @sub/hotcues
  Scenario: The type cycler wraps around
    Given the playhead of deck 1 is at 0.5
    And the hotcue popup is open for hotcue 1 on deck 1
    When I click the "previous type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "JUMP"
    When I click the "next type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "CUE"
  @sub/hotcues
  Scenario: Deleting the hotcue from the popup
    Given the hotcue popup is open for hotcue 1 on deck 1
    When I click the "delete" button in the popup
    Then hotcue 1 should not be set on deck 1
  @sub/hotcues
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
  @sub/hotcues
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
  @sub/hotcues
  Scenario: The split view follows the zoom dynamically
    Given hotcue 1 on deck 1 is of type "CUE"
    And the hotcue popup is open for hotcue 1 on deck 1
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
  @sub/hotcues
  Scenario: The jump split view shades the skipped content and can swap ends
    Given the playhead of deck 1 is at 0.5
    And the hotcue popup is open for hotcue 1 on deck 1
    When I click the "previous type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "JUMP"
    Then the hotcue popup should be in split view
    And the skip shade above the split should be visible
    And the skip shade below the split should be visible
    And the jump warp divider should be visible
    And the span filler should not be visible
    And the swap button should be visible
    And the split view start half should display the span start position
    And the split view target half should display the span end position
    And the hotcue span of hotcue 1 on deck 1 is remembered
    When I click the "swap" button in the popup
    Then the hotcue span of hotcue 1 on deck 1 should be swapped
    And the split view start half should display the span start position
    And the split view target half should display the span end position

  # A hotcue set by clicking the button has no end position, so both
  # conversion defaults below apply to it (fresh cue or cleared end position).
  @sub/hotcues
  Scenario: A new cue becomes a loop of the deck's beatloop size
    Given the playhead of deck 1 is at 0.5
    And the beatloop size of deck 1 is set to 2
    And the hotcue popup is open for hotcue 1 on deck 1
    When I click the "next type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "LOOP"
    And the hotcue span length of hotcue 1 on deck 1 should be 2 beats
  @sub/hotcues
  Scenario: A new cue's jump target defaults to the playhead
    Given hotcue 1 on deck 1 is of type "CUE"
    And the playhead of deck 1 is at 0.5
    And quantize is disabled on deck 1
    And the hotcue popup is open for hotcue 1 on deck 1
    When I click the "previous type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "JUMP"
    And the hotcue jump target of hotcue 1 on deck 1 should be at the playhead

  # While the popup stays open, cycling back to CUE keeps the loop span;
  # closing the popup must discard it (parity with WCueMenuPopup::closeEvent),
  # so a later JUMP conversion falls back to the playhead instead of reusing
  # the stale span as its target.
  @sub/hotcues
  Scenario: A leftover loop span is discarded when the popup closes
    Given the playhead of deck 1 is at 0.5
    And quantize is disabled on deck 1
    And the beatloop size of deck 1 is set to 2
    And the hotcue popup is open for hotcue 1 on deck 1
    When I click the "next type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "LOOP"
    And the hotcue span length of hotcue 1 on deck 1 should be 2 beats
    When I click the "previous type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "CUE"
    And the hotcue span length of hotcue 1 on deck 1 should be 2 beats
    When I click the "spinny" button on deck 1
    Then the hotcue popup should be closed
    When I right-click hotcue 1 on deck 1
    And I click the "previous type" arrow in the popup
    Then the hotcue type name of hotcue 1 on deck 1 should be "JUMP"
    And the hotcue jump target of hotcue 1 on deck 1 should be at the playhead
  @sub/hotcues
  Scenario: The label can be cleared from the popup
    Given the label of hotcue 1 on deck 1 is "Drop here"
    And the hotcue popup is open for hotcue 1 on deck 1
    When I clear the hotcue popup label field
    And I press Enter in the hotcue popup label field
    Then the hotcue popup label should be empty

  Rule: Beatgrid popup
    Background:
      Given a new library-ready profile
      And Mixxx is open and ready to operate
      And a track is loaded on deck 1
      And the window size is default
      And quantize is disabled on deck 1

  @sub/sync
  Scenario: The quantize button toggles quantize
    When I click the "quantize" button on deck 1
    Then the quantize button on deck 1 should be pressed
    And quantize should be enabled on deck 1
    When I click the "quantize" button on deck 1
    Then the quantize button on deck 1 should be released
    And quantize should be disabled on deck 1

  @sub/sync
  Scenario: The popup opens on a Beatgrid toolbar click
    When I click the "beatgrid" button on deck 1
    Then the beatgrid popup should be open
    And the "shift grid slider" of the beatgrid popup should be visible
    And the "bar size spinbox" of the beatgrid popup should be visible
    And the "current BPM spinbox" of the beatgrid popup should be visible
    And the "snap to playhead button" of the beatgrid popup should be visible

  @sub/sync
  Scenario: The popup closes on press outside
    Given the beatgrid popup is open on deck 1
    When I click the "spinny" button on deck 1
    Then the beatgrid popup should be closed

  # spix cannot deliver keyboard events to the overlay popup reliably
  # (focus routing limitation), so this check is marked as flaky.
  @xpass
  @sub/sync
  Scenario: The popup closes with Escape
    Given the beatgrid popup is open on deck 1
    When I press Escape in the beatgrid popup
    Then the beatgrid popup should be closed

  @sub/sync
  Scenario: The current BPM spinbox shows the detected file BPM
    Given the beatgrid popup is open on deck 1
    Then the beatgrid current BPM spinbox should show the file BPM of deck 1

  # The shift grid slider fires one trigger per 1/100 slider unit (each
  # moving the grid by 0.01 s), so the resulting first-beat shift is
  # asserted against the magnitude derived from the slider's final value.
  @sub/sync
  Scenario: Dragging the shift grid slider right shifts the grid later
    Given the beatgrid popup is open on deck 1
    And the first beat position of deck 1 is remembered
    When I drag the shift grid slider of deck 1 to the right
    Then the first beat of deck 1 should have moved later

  @sub/sync
  Scenario: Dragging the shift grid slider left shifts the grid earlier
    Given the beatgrid popup is open on deck 1
    And the first beat position of deck 1 is remembered
    When I drag the shift grid slider of deck 1 to the left
    Then the first beat of deck 1 should have moved earlier

  @sub/sync
  Scenario: Snapping the grid to the current position moves the first beat
    Given the beatgrid popup is open on deck 1
    And the playhead of deck 1 is at 0.5
    And the first beat position of deck 1 is remembered
    When I click the "snap to playhead button" in the beatgrid popup
    Then the first beat of deck 1 should have changed

  @sub/sync
  Scenario: The halve BPM button halves the deck's BPM
    Given the beatgrid popup is open on deck 1
    And the BPM of deck 1 is remembered
    When I click the "halve BPM button" in the beatgrid popup
    Then the BPM of deck 1 should be half of the remembered BPM

  @sub/sync
  Scenario: The double BPM button doubles the deck's BPM
    Given the beatgrid popup is open on deck 1
    And the BPM of deck 1 is remembered
    When I click the "double BPM button" in the beatgrid popup
    Then the BPM of deck 1 should be double the remembered BPM

  @sub/sync
  Scenario: Locking the BPM disables the grid and BPM editing controls
    Given the beatgrid popup is open on deck 1
    And the playhead of deck 1 is at 0.5
    And the first beat position of deck 1 is remembered
    And the BPM of deck 1 is remembered
    When I click the "BPM lock button" in the beatgrid popup
    Then the BPM lock button of the beatgrid popup should be pressed
    And the BPM of deck 1 should be locked
    And the "shift grid slider" of the beatgrid popup should be disabled
    And the "snap to playhead button" of the beatgrid popup should be disabled
    And the "current BPM spinbox" of the beatgrid popup should be disabled
    When I click the "snap to playhead button" in the beatgrid popup
    And I drag the shift grid slider of deck 1 to the right
    Then the first beat of deck 1 should not have changed
    And the BPM of deck 1 should not have changed

  @sub/sync
  Scenario: Unlocking the BPM re-enables the grid and BPM editing controls
    Given the BPM of deck 1 is locked
    And the beatgrid popup is open on deck 1
    Then the BPM lock button of the beatgrid popup should be pressed
    And the BPM of deck 1 should be locked
    And the "shift grid slider" of the beatgrid popup should be disabled
    And the "snap to playhead button" of the beatgrid popup should be disabled
    And the "current BPM spinbox" of the beatgrid popup should be disabled
    When I click the "BPM lock button" in the beatgrid popup
    Then the BPM lock button of the beatgrid popup should be released
    And the "shift grid slider" of the beatgrid popup should be enabled
    And the "snap to playhead button" of the beatgrid popup should be enabled
    And the "current BPM spinbox" of the beatgrid popup should be enabled
