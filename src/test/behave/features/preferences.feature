Feature: Preferences

  Background:
    Given a new empty profile
    And Mixxx is open and ready to operate

  # --- Settings popup chrome (former features/settings/main.feature) -----------

  Scenario: Settings popup opens from toolbar gear button
    When I click the "PREFERENCES" button
    Then the settings popup should be visible

  Scenario: Settings popup closes with close button
    Given the settings popup is open
    When I click the settings close button
    Then the settings popup should not be visible

  Scenario: Default category is Sound hardware
    When I click the "PREFERENCES" button
    Then the "Sound hardware" category should be selected

  Scenario: Selecting a category changes the active view
    Given the settings popup is open
    When I select the "Library" category
    Then the "Library" category should be selected

  Scenario: Search filters settings
    Given the settings popup is open
    When I search for "Sample Rate"
    Then the search results should be visible

  # --- Save / Cancel buttons (shared component behavior) ----------------------
  # The popup opens on the default "Sound hardware" category. Saving the sound
  # category touches the audio config, so mock devices are registered per
  # scenario where a save/cancel is involved (the Background stays device-free).

  Scenario: Save button is disabled when no changes
    Given the settings popup is open
    Then the save button should be disabled
    And the cancel button should not be visible

  Scenario: Save and cancel enable when a setting changes
    Given the settings popup is open
    And I have the following sound devices
      | name           | api  | outputChannels | inputChannels |
      | Built-in Audio | Mock | 4              | 4             |
    And the "Main Mix" setting is "on"
    When I toggle the "Main Mix" setting to "off"
    Then the save button should be enabled
    And the cancel button should be visible

  Scenario: Cancel reverts changes
    Given the settings popup is open
    And I have the following sound devices
      | name           | api  | outputChannels | inputChannels |
      | Built-in Audio | Mock | 4              | 4             |
    And the "Main Mix" setting is "on"
    When I toggle the "Main Mix" setting to "off"
    And I click the cancel button
    Then the "Main Mix" setting should be "on"
    And the save button should be disabled

  Scenario: Save applies changes
    Given the settings popup is open
    And I have the following sound devices
      | name           | api  | outputChannels | inputChannels |
      | Built-in Audio | Mock | 4              | 4             |
    When I toggle the "Main Mix" setting to "off"
    And I click the save button
    Then the save button should be disabled
    And the cancel button should not be visible

  # --- Responsiveness -----------------------------------------------------------
  #
  # The settings popup collapses its category sidebar below `smallScreenWidth`
  # (1200 px) and compacts ratio options (pills -> prev/next spinbox) when the
  # row has too little room. These scenarios exercise the responsive layouts and
  # prove the settings stay usable on narrow and short windows.

  @category/responsiveness
  Scenario: Settings categories collapse to a button on a narrow window
    Given the settings popup is open
    When I resize the window's width to 1250px
    Then the settings categories should be visible
    When I resize the window's width to 1150px
    Then the settings categories should not be visible
    And the button to reveal the categories should be visible
    When I resize the window's width to 1792px

  @category/responsiveness
  Scenario: Settings categories can be shown on demand on a narrow window
    Given the settings popup is open
    And the window's width is 1150px
    Then the settings categories should not be visible
    And the button to reveal the categories should be visible
    When I click the button to reveal the categories
    Then the settings categories should be visible
    When I resize the window's width to 1792px

  @category/responsiveness
  Scenario: Ratio options stay usable when the popup is narrow
    Given the settings popup is open
    And the window's width is 1792px
    And the "Interface" category is selected
    And the "decks" tab is selected
    Then the "track time display" setting should be expanded
    When I resize the window's width to 680px
    Then the "track time display" setting should be compacted
    When I toggle the "track time display" setting to "remaining"
    Then the "track time display" setting should be "remaining"
    When I resize the window's width to 1792px

  @category/responsiveness
  Scenario: The settings popup stays usable when the window is short
    Given the settings popup is open
    And the window's width is 1792px
    And the "Interface" category is selected
    And the "decks" tab is selected
    When I resize the window's height to 500px
    Then the settings popup should be visible
    And the "track time display" setting should be visible
    When I toggle the "track time display" setting to "both"
    Then the "track time display" setting should be "both"
    When I resize the window's height to 1008px

  # --- Interface category (former features/settings/interface.feature) ----------
  #
  # E2E coverage for the "Interface" preferences category
  # (res/qml/Settings/Interface.qml): tab navigation, the shared save, cancel
  # and reset button steps (shared with sound.feature, resolved for whichever
  # category is active) and the theme & color tab's appearance settings.
  #
  # The popup preconditions that used to be that file's Background are inlined
  # per scenario. The save/cancel scenarios are prefixed with "Interface" to
  # stay unique next to the popup-chrome scenarios above, which exercise the
  # same buttons through the Sound hardware category.
  #
  # The waveform tab scenarios of the former interface.feature live in
  # waveform.feature; the palettes and decks-tab settings live in deck.feature;
  # the library-related rows live in browse.feature.

  # --- Tab navigation ---------------------------------------------------------

  Scenario: Interface tabs are visible
    Given the settings popup is open
    And the "Interface" category is selected
    Then the "theme & color" tab should be visible
    And the "waveform" tab should be visible
    And the "decks" tab should be visible

  Scenario: The theme & color tab is selected by default
    Given the settings popup is open
    And the "Interface" category is selected
    Then the "theme & color" tab should be selected

  Scenario: Switching to the waveform tab
    Given the settings popup is open
    And the "Interface" category is selected
    When I click the "waveform" tab
    Then the "waveform" tab should be selected

  Scenario: Switching to the decks tab
    Given the settings popup is open
    And the "Interface" category is selected
    When I click the "decks" tab
    Then the "decks" tab should be selected

  Scenario: Switching back to the theme & color tab
    Given the settings popup is open
    And the "Interface" category is selected
    Given the "decks" tab is selected
    When I click the "theme & color" tab
    Then the "theme & color" tab should be selected

  # --- Save / Cancel / Reset buttons -------------------------------------------

  Scenario: Interface save button is disabled when no changes
    Given the settings popup is open
    And the "Interface" category is selected
    Then the save button should be disabled
    And the cancel button should be disabled

  Scenario: Save and cancel enable when setting changes
    Given the settings popup is open
    And the "Interface" category is selected
    Given the "tool tips" setting is "all"
    When I toggle the "tool tips" setting to "off"
    Then the save button should be enabled
    And the cancel button should be enabled

  Scenario: Interface cancel reverts changes
    Given the settings popup is open
    And the "Interface" category is selected
    Given the "tool tips" setting is "all"
    When I toggle the "tool tips" setting to "off"
    And I click the cancel button
    Then the "tool tips" setting should be "all"
    And the save button should be disabled

  Scenario: Interface save applies changes
    Given the settings popup is open
    And the "Interface" category is selected
    When I toggle the "tool tips" setting to "off"
    And I click the save button
    Then the "tool tips" setting should be "off"
    And the save button should be disabled

  @xfail
  Scenario: Reset restores default settings
    Given the settings popup is open
    And the "Interface" category is selected
    Given the "tool tips" setting is "all"
    When I click the reset button
    Then the "tool tips" setting should be "library"

  # --- Theme & color tab: appearance ------------------------------------------

  Scenario: Skin, Color and Layout choices are displayed
    # Save is stubbed (skinInput/colorInput/layoutInput are commented out in
    # loadInterface/saveInterface), so only the display is asserted.
    Given the settings popup is open
    And the "Interface" category is selected
    Then the "skin" setting should be "Unnamed"
    And the "color" setting should be "Dark"
    And the "layout" setting should be "Performance"

  Scenario: Tool tips can be switched between all levels
    Given the settings popup is open
    And the "Interface" category is selected
    When I toggle the "tool tips" setting to "off"
    And I click the save button
    Then the "tool tips" setting should be "off"
    When I toggle the "tool tips" setting to "library"
    And I click the save button
    Then the "tool tips" setting should be "library"
    When I toggle the "tool tips" setting to "all"
    And I click the save button
    Then the "tool tips" setting should be "all"

  Scenario: Screen saver can be disabled
    Given the settings popup is open
    And the "Interface" category is selected
    When I toggle the "disable screen saver" setting to "no"
    And I click the save button
    Then the "disable screen saver" setting should be "no"
    And the "disable screen saver" should be saved as "no"

  Scenario: Screen saver can be limited to playback
    Given the settings popup is open
    And the "Interface" category is selected
    When I toggle the "disable screen saver" setting to "while playing"
    And I click the save button
    Then the "disable screen saver" setting should be "while playing"

  Scenario: Start in full-screen mode can be enabled
    Given the settings popup is open
    And the "Interface" category is selected
    When I toggle the "start in full-screen mode" setting to "on"
    And I click the save button
    Then the "start in full-screen mode" setting should be "on"

  Scenario: Auto-hide the menu bar can be enabled
    Given the settings popup is open
    And the "Interface" category is selected
    When I toggle the "auto-hide the menu bar" setting to "on"
    And I click the save button
    Then the "auto-hide the menu bar" setting should be "on"

  # --- Theme & color tab: library ----------------------------------------------

  Scenario: BPM display precision can be changed
    Given the settings popup is open
    And the "Interface" category is selected
    When I set the "bpm display precision" setting to "3"
    Then the "bpm display precision" setting should be "3"

  Scenario: Search finds interface settings
    Given the settings popup is open
    And the "Interface" category is selected
    When I search for "Row Height"
    Then the search results should be visible
