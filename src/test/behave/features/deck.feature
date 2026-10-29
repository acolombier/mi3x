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
