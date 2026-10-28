Feature: Waveform

#
# E2E coverage for the waveform settings — the "waveform" tab of the
# "Interface" preferences category (res/qml/Settings/Interface.qml).
#
# Migrated from the former features/settings/interface.feature; the rest of
# that file was split into preferences.feature (tab navigation, save/cancel,
# theme & color appearance), deck.feature (palettes, decks tab, sliders) and
# browse.feature (library rows).
#
# These scenarios only cover the settings widgets and their backend config
# effect: each change is persisted with the save button and its config key
# is read back through the [Waveform] group. The visual side effects on the
# live waveforms (preview and decks) are out of scope here except for the
# embedded type-combobox preview scenarios below.
#

  Background:
    Given a new library-ready profile
    And I have the following sound devices
      | name           | api  | outputChannels | inputChannels |
      | Built-in Audio | Mock | 4              | 4             |
    And Mixxx is open and ready to operate
    And the settings popup is open
    And the "Interface" category is selected

  # Defaults in this tab are read live from the config (Mixxx.Config), so a
  # value that equals its default (e.g. a reset gain of "100%") is stored as
  # the empty string and would read back flaky from [Waveform]. Scenarios
  # therefore save a non-default value and assert on it, like the decks tab
  # scenarios do.

  Scenario: Waveform tab has settings to display
    When I click the "waveform" tab
    Then the "waveform type" setting should be visible
    And the "end of track warning" setting should be visible
    And the "beat grid opacity" setting should be visible
    And the "default zoom level" setting should be visible
    And the "play marker position" setting should be visible
    And the "beats until next marker" setting should be visible
    And the "time until next marker" setting should be visible
    And the "marker hint placement" setting should be visible
    And the "marker hint font size" setting should be visible
    And the "global visual gain" setting should be visible
    And the "low visual gain" setting should be visible
    And the "medium visual gain" setting should be visible
    And the "high visual gain" setting should be visible

  Scenario: End of track warning can be reduced to zero
    # Zero disables the warning; a stored 0 is not the default (30), so the
    # config key round-trips.
    Given the "waveform" tab is selected
    When I set the "end of track warning" setting to "0" with the spinbox
    And I click the save button
    Then the "end of track warning" setting should be "0"
    And the "end of track warning" should be saved as "0"

  Scenario: End of track warning can be set to a marked value
    Given the "waveform" tab is selected
    When I set the "end of track warning" setting to "60" with the spinbox
    And I click the save button
    Then the "end of track warning" setting should be "60"
    And the "end of track warning" should be saved as "60"

  Scenario: Beat grid opacity can be changed
    Given the "waveform" tab is selected
    When I set the "beat grid opacity" setting to "50" with the spinbox
    And I click the save button
    Then the "beat grid opacity" setting should be "50"
    And the "beat grid opacity" should be saved as "50"
    When I set the "beat grid opacity" setting to "0" with the spinbox
    And I click the save button
    Then the "beat grid opacity" setting should be "0"
    And the "beat grid opacity" should be saved as "0"

  Scenario: Default zoom level can be changed
    # The slider displays zoom*10, so "50" is a zoom factor of 5.
    Given the "waveform" tab is selected
    When I set the "default zoom level" setting to "50" with the spinbox
    And I click the save button
    Then the "default zoom level" setting should be "50"
    And the "default zoom level" should be saved as "5"
    When I set the "default zoom level" setting to "10" with the spinbox
    And I click the save button
    Then the "default zoom level" setting should be "10"
    And the "default zoom level" should be saved as "1"

  Scenario: Zoom level is synchronised by default
    Given the "waveform" tab is selected
    Then the "synchronise zoom level across waveforms" setting should be "on"

  Scenario: Zoom synchronisation can be disabled
    Given the "waveform" tab is selected
    When I toggle the "synchronise zoom level across waveforms" setting to "off"
    And I click the save button
    Then the "synchronise zoom level across waveforms" setting should be "off"
    And the "synchronise zoom level across waveforms" should be saved as "off"

  Scenario: Overview normalisation can be disabled
    Given the "waveform" tab is selected
    When I toggle the "normalise waveform overview" setting to "off"
    And I click the save button
    Then the "normalise waveform overview" setting should be "off"
    And the "normalise waveform overview" should be saved as "off"

  Scenario: Play marker position can be changed
    Given the "waveform" tab is selected
    When I set the "play marker position" setting to "25" with the spinbox
    And I click the save button
    Then the "play marker position" setting should be "25"
    And the "play marker position" should be saved as "0.25"

  # --- Waveform type & options ----------------------------------------------------

  Scenario Outline: Waveform type can be selected
    # The ComboBox popup renders a preview of each type (more than six
    # entries would need the keyboard fallback), so all five stay clickable.
    Given the "waveform" tab is selected
    When I set the "waveform type" setting to "<type>"
    And I click the save button
    Then the "waveform type" setting should be "<type>"

    Examples:
      | type     |
      | Filtered |
      | HSV      |
      | RGB      |
      | Simple   |
      | Stacked  |

  Scenario: Waveform type selection is persisted
    # "should be saved as" reads back the [Waveform] WaveformType key and
    # translates the type name into its stored legacy WaveformWidgetType id
    # (translated in CONFIG_SAVE_MAP). The default RGB is removed from the
    # config (see the banner comment), so persistence is asserted with a
    # non-default type only.
    Given the "waveform" tab is selected
    When I set the "waveform type" setting to "Simple"
    And I click the save button
    Then the "waveform type" should be saved as "Simple"

  # The "Stereo split" and "High details" options shown under the preview
  # depend on the selected waveform type: they are only supported by some
  # renderers (RGB supports both, Filtered/Stacked support high details
  # only, HSV/Simple support none). The default type is RGB, so both are
  # visible out of the box.
  Scenario: The stereo split option is available on a supported waveform type
    Given the "waveform" tab is selected
    When I set the "waveform type" setting to "Simple"
    Then the "stereo split" setting should not be visible
    When I set the "waveform type" setting to "RGB"
    Then the "stereo split" setting should be visible

  Scenario: The high details option is available on a supported waveform type
    Given the "waveform" tab is selected
    When I set the "waveform type" setting to "HSV"
    Then the "high details" setting should not be visible
    When I set the "waveform type" setting to "RGB"
    Then the "high details" setting should be visible

  Scenario Outline: Waveform options can be toggled for the RGB type
    Given the "waveform" tab is selected
    When I set the "waveform type" setting to "RGB"
    And I toggle the "<option>" setting to "on"
    And I click the save button
    Then the "<option>" setting should be "on"
    And the "waveform options" should be saved as "<option>"
    When I toggle the "<option>" setting to "off"
    And I click the save button
    Then the "<option>" setting should be "off"
    And the "waveform options" should be saved as "none"

    Examples:
      | option        |
      | stereo split  |
      | high details  |

  Scenario: Beats until next marker can be shown
    Given the "waveform" tab is selected
    When I toggle the "beats until next marker" setting to "on"
    And I click the save button
    Then the "beats until next marker" setting should be "on"
    And the "beats until next marker" should be saved as "on"
    When I toggle the "beats until next marker" setting to "off"
    And I click the save button
    Then the "beats until next marker" setting should be "off"
    # "off" restores the default, so the config key is removed (see the
    # banner comment at the top of the section).
    And the "beats until next marker" config key should be unset

  Scenario: Time until next marker can be shown
    Given the "waveform" tab is selected
    When I toggle the "time until next marker" setting to "on"
    And I click the save button
    Then the "time until next marker" setting should be "on"
    And the "time until next marker" should be saved as "on"
    When I toggle the "time until next marker" setting to "off"
    And I click the save button
    Then the "time until next marker" setting should be "off"
    # "off" restores the default, so the config key is removed (see the
    # banner comment at the top of the section).
    And the "time until next marker" config key should be unset

  Scenario Outline: Marker hint placement can be changed
    Given the "waveform" tab is selected
    When I toggle the "marker hint placement" setting to "<placement>"
    And I click the save button
    Then the "marker hint placement" setting should be "<placement>"

    Examples:
      | placement |
      | top       |
      | center    |
      | bottom    |

  Scenario: Marker hint font size can be changed
    Given the "waveform" tab is selected
    When I set the "marker hint font size" setting to "32 pt"
    And I click the save button
    Then the "marker hint font size" setting should be "32 pt"
    And the "marker hint font size" should be saved as "32 pt"
    When I set the "marker hint font size" setting to "10 pt"
    And I click the save button
    Then the "marker hint font size" setting should be "10 pt"
    And the "marker hint font size" should be saved as "10 pt"

  Scenario Outline: Visual gain can be changed
    # Drags land within ~1-2px, so slider tolerance absorbs the drift and
    # the saved config (a gain factor = percent/100) is asserted exactly.
    # Defaults (100%) are excluded from the examples for the reason given
    # above.
    Given the "waveform" tab is selected
    When I set the "<gain>" setting to "<value>" with the spinbox
    And I click the save button
    Then the "<gain>" setting should be "<value>"
    And the "<gain>" should be saved as "<saved>"

    Examples:
      | gain               | value | saved |
      | global visual gain | 150   | 1.5   |
      | low visual gain    | 300   | 3     |
      | medium visual gain | 80    | 0.8   |
      | high visual gain   | 50    | 0.5   |

  # --- Waveform preview (embedded in the type combobox) ---------------------------
  #
  # The waveform type combobox embeds a live waveform preview whose renderers
  # are bound to the tab's controls, so every change made through a control
  # must show on the preview immediately (no save needed — the persistence of
  # the same settings is asserted by the scenarios above). The assertions read
  # back what the bound renderers actually consume (the preview's renderer
  # derived properties), not the inputs themselves.

  Scenario: The beat grid opacity reflects on the waveform preview
    Given the "waveform" tab is selected
    When I set the "beat grid opacity" setting to "30" with the spinbox
    Then the waveform preview beat grid should be 30% opaque
    When I set the "beat grid opacity" setting to "100" with the spinbox
    Then the waveform preview beat grid should be 100% opaque

  Scenario: The default zoom level reflects on the waveform preview
    Given the "waveform" tab is selected
    When I set the "default zoom level" setting to "50" with the spinbox
    Then the waveform preview should be at zoom 5
    When I set the "default zoom level" setting to "10" with the spinbox
    Then the waveform preview should be at zoom 1

  Scenario: The play marker position reflects on the waveform preview
    Given the "waveform" tab is selected
    When I set the "play marker position" setting to "25" with the spinbox
    Then the waveform preview play marker should sit at 25%
    When I set the "play marker position" setting to "75" with the spinbox
    Then the waveform preview play marker should sit at 75%

  Scenario: The until-marker hints reflect on the waveform preview
    Given the "waveform" tab is selected
    Then the waveform preview until-marker hint should not show beats
    And the waveform preview until-marker hint should not show the remaining time
    When I toggle the "beats until next marker" setting to "on"
    Then the waveform preview until-marker hint should show beats
    When I toggle the "time until next marker" setting to "on"
    Then the waveform preview until-marker hint should show the remaining time
    When I toggle the "time until next marker" setting to "off"
    Then the waveform preview until-marker hint should not show the remaining time

  Scenario Outline: The marker hint placement reflects on the waveform preview
    Given the "waveform" tab is selected
    When I toggle the "marker hint placement" setting to "<placement>"
    Then the waveform preview until-marker hint should be placed at the "<placement>"
    When I toggle the "marker hint placement" setting to "center"
    Then the waveform preview until-marker hint should be placed at the "center"

    Examples:
      | placement |
      | top       |
      | bottom    |

  Scenario Outline: The marker hint font size reflects on the waveform preview
    Given the "waveform" tab is selected
    When I set the "marker hint font size" setting to "<size> pt"
    Then the waveform preview until-marker hint should use a <size>pt font

    Examples:
      | size |
      | 10   |
      | 32   |

  Scenario Outline: The visual gains reflect on the waveform preview
    Given the "waveform" tab is selected
    When I set the "<gain>" setting to "<value>" with the spinbox
    Then the waveform preview should have the "<band>" band gain set to "<target>"
    When I set the "<gain>" setting to "100" with the spinbox
    Then the waveform preview should have the "<band>" band gain set to "1"

    Examples:
      | gain               | value | band   | target |
      | global visual gain | 150   | global | 1.5    |
      | low visual gain    | 300   | low    | 3      |
      | medium visual gain | 80    | middle | 0.8    |
      | high visual gain   | 50    | high   | 0.5    |

  Scenario: The waveform options reflect on the waveform preview
    Given the "waveform" tab is selected
    When I set the "waveform type" setting to "RGB"
    Then the waveform preview should render with the selected options
    When I toggle the "stereo split" setting to "on"
    Then the waveform preview should render with the selected options
    When I toggle the "high details" setting to "on"
    Then the waveform preview should render with the selected options

  @xfail
  Scenario: Reset restores default waveform settings
    Given the "waveform" tab is selected
    When I set the "beat grid opacity" setting to "40"
    And I click the reset button
    Then the "beat grid opacity" setting should be "90"
    And the "waveform type" setting should be "RGB"
    And the "marker hint font size" setting should be "24 pt"

  # --- Waveform colors --------------------------------------------------------------
  #
  # The low/mid/high swatches of the preview open a native ColorDialog,
  # which the harness cannot drive. They are routed to an invisible test
  # stand-in through the same pattern as the library category's folder
  # picker: while test mode is on, open() is counted, the color the test
  # set beforehand is accepted, and the picked swatch binds the color into
  # the preview renderers immediately (colors are preview-only state:
  # save() does not persist them, so no config or deck feedback is
  # asserted here).
  Scenario Outline: Waveform colors can be picked
    Given the "waveform" tab is selected
    When I set the "waveform type" setting to "<type>"
    And I pick the color "<color>" for the "<band>" waveform color
    Then the "<band>" color swatch should be "<color>"
    And the waveform preview should render the "<band>" band with "<color>"

    Examples:
      | type     | band | color     |
      | Filtered | low  | #f6de27 |
      | Filtered | mid  | #f07581 |
      | Filtered | high | #f95429 |
      | HSV      | all  | #d3a7f3 |
      | RGB      | low  | #b86ff5 |
      | RGB      | mid  | #69dc02 |
      | RGB      | high | #623b73 |
      | Simple   | all  | #ba7197 |
      | Stacked  | low  | #d3bf7d |
      | Stacked  | mid  | #d44685 |
      | Stacked  | high | #52122b |

  Scenario: Search finds waveform settings
    When I search for "visual gain"
    Then the search results should be visible
