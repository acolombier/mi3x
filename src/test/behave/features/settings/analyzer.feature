Feature: Analyzer Settings
#
# E2E coverage for the "Analyzer" preferences category
# (res/qml/Settings/Analyzer.qml).
#
# Sections: BPM and Beat detection, Key detection, ReplayGain Loudness
# Normalization. No tabs: the category is a single scrollable column. The
# shared save/cancel/reset button behavior is covered in main.feature
# (component tests); this file covers Analyzer-specific settings and
# responsiveness.
#

  Background:
    Given a fresh new empty profile
    And Mixxx is open and ready to operate
    And the settings popup is open
    And the "Analyzer" category is selected

  # --- BPM and beat detection -------------------------------------------------

  Scenario: BPM settings are shown with their defaults
    Then the "BPM detection" setting should be "on"
    And the "BPM analyser" setting should be "queenmary"
    And the "assume constant tempo" setting should be "on"
    And the "BPM fast analysis" setting should be "off"
    And the "re-analysis when settings change" setting should be "off"
    And the "re-analysis of beatgrids imported from other DJ software" setting should be "off"
    And the "key detection" setting should be "on"
    And the "key analyser" setting should be "queenmary"
    And the "key fast analysis" setting should be "off"
    And the "key notation" setting should be "traditional"
    And the "ReplayGain normalization" setting should be "on"
    And the "ReplayGain analyser" setting should be "replaygain20"
    And the "ReplayGain re-analysis" setting should be "off"

  Scenario: BPM detection can be disabled and saved
    When I toggle the "BPM detection" setting to "off"
    And I click the save button
    Then the "BPM detection" setting should be "off"
    And the "BPM detection" should be saved as "off"

  Scenario: The beat analyser plugin can be switched and saved
    When I toggle the "BPM analyser" setting to "soundtouch"
    And I click the save button
    Then the "BPM analyser" setting should be "soundtouch"
    And the "BPM analyser" should be saved as "soundtouch"

  Scenario: The beat analyser plugin can be switched back
    Given the "BPM analyser" setting is "soundtouch"
    When I toggle the "BPM analyser" setting to "queenmary"
    And I click the save button
    Then the "BPM analyser" setting should be "queenmary"
    And the "BPM analyser" should be saved as "queenmary"

  Scenario: Assume constant tempo can be disabled and saved
    When I toggle the "assume constant tempo" setting to "off"
    And I click the save button
    Then the "assume constant tempo" setting should be "off"
    And the "assume constant tempo" should be saved as "off"

  Scenario: Fast analysis requires assuming constant tempo
    # Fast analysis cannot be combined with non-constant tempo beatgrids
    # (DlgPrefBeats::updateGui): disabling the constant tempo assumption
    # disables the fast analysis toggle and gates saving it.
    When I toggle the "BPM fast analysis" setting to "on"
    And I toggle the "assume constant tempo" setting to "off"
    And I click the save button
    Then the "assume constant tempo" should be saved as "off"
    And the "BPM fast analysis" setting should be disabled
    And the "BPM fast analysis" setting should be "off"

  Scenario: Re-analyse beats when settings change can be enabled and saved
    When I toggle the "re-analysis when settings change" setting to "on"
    And I click the save button
    Then the "re-analysis when settings change" setting should be "on"
    And the "re-analysis when settings change" should be saved as "on"

  Scenario: Re-analyse beatgrids imported from other DJ software can be enabled and saved
    When I toggle the "re-analysis of beatgrids imported from other DJ software" setting to "on"
    And I click the save button
    Then the "re-analysis of beatgrids imported from other DJ software" setting should be "on"
    And the "re-analysis of beatgrids imported from other DJ software" should be saved as "on"

  # --- Key detection ----------------------------------------------------------

  Scenario: Key detection can be disabled and saved
    When I toggle the "key detection" setting to "off"
    And I click the save button
    Then the "key detection" setting should be "off"
    And the "key detection" should be saved as "off"

  Scenario: The key analyser plugin can be switched and saved
    When I toggle the "key analyser" setting to "keyfinder"
    And I click the save button
    Then the "key analyser" setting should be "keyfinder"
    And the "key analyser" should be saved as "keyfinder"

  Scenario: Key fast analysis can be enabled and saved
    When I toggle the "key fast analysis" setting to "on"
    And I click the save button
    Then the "key fast analysis" setting should be "on"
    And the "key fast analysis" should be saved as "on"

  Scenario: Key notation can be changed and saved
    When I toggle the "key notation" setting to "lancelot"
    And I click the save button
    Then the "key notation" setting should be "lancelot"
    And the "key notation" should be saved as "lancelot"

  Scenario: Custom key notation can be selected and saved
    When I toggle the "key notation" setting to "custom"
    And I click the save button
    Then the "key notation" setting should be "custom"
    And the "key notation" should be saved as "custom"

  # --- ReplayGain -------------------------------------------------------------

  Scenario: ReplayGain analyser can be switched and saved
    When I toggle the "ReplayGain analyser" setting to "replaygain10"
    And I click the save button
    Then the "ReplayGain analyser" setting should be "replaygain10"
    And the "ReplayGain analyser" should be saved as "replaygain10"

  Scenario: ReplayGain normalization can be disabled and saved
    When I toggle the "ReplayGain normalization" setting to "off"
    And I click the save button
    Then the "ReplayGain normalization" setting should be "off"
    And the "ReplayGain normalization" should be saved as "off"

  Scenario: ReplayGain target loudness can be changed and saved
    # Legacy hint in the ReplayGain preferences: the target loudness slider
    # adjusts the ReplayGain reference loudness (-18 LUFS) by a dB offset.
    When I set the "ReplayGain target loudness" setting to "-10" with the spinbox
    And I click the save button
    Then the "ReplayGain target loudness" setting should be "-10"
    And the "ReplayGain target loudness" should be saved as "-10"

  Scenario: ReplayGain re-analysis can be enabled and saved
    When I toggle the "ReplayGain re-analysis" setting to "on"
    And I click the save button
    Then the "ReplayGain re-analysis" setting should be "on"
    And the "ReplayGain re-analysis" should be saved as "on"

  Scenario: Initial boost without ReplayGain can be changed and saved
    When I set the "ReplayGain default boost" setting to "0" with the spinbox
    And I click the save button
    Then the "ReplayGain default boost" setting should be "0"
    And the "ReplayGain default boost" should be saved as "0"

  # --- Shared popup behavior --------------------------------------------------

  Scenario: Save and cancel enable when an Analyzer setting changes
    When I toggle the "BPM fast analysis" setting to "on"
    Then the save button should be enabled
    And the cancel button should be visible

  Scenario: Cancel reverts Analyzer setting changes
    When I toggle the "key analyser" setting to "keyfinder"
    And I click the cancel button
    Then the "key analyser" setting should be "queenmary"
    And the save button should be disabled

  Scenario: Reset restores the Analyzer defaults
    Given the "key analyser" setting is "keyfinder"
    And the "key notation" setting is "custom"
    And the "BPM fast analysis" setting is "on"
    When I set the "ReplayGain target loudness" setting to "-10" with the spinbox
    And I set the "ReplayGain default boost" setting to "3" with the spinbox
    And I click the reset button
    Then the "key analyser" setting should be "queenmary"
    And the "key notation" setting should be "traditional"
    And the "BPM fast analysis" setting should be "off"
    And the "ReplayGain target loudness" setting should be "0"
    And the "ReplayGain default boost" setting should be "-6"

  Scenario: Search finds Analyzer settings
    When I search for "ReplayGain"
    Then the search results should be visible

  # --- Responsiveness ----------------------------------------------------------
  #
  # The section grids switch between 2 and 1 columns at 850px of content
  # width. On a short window the category overflows its ScrollView and
  # below-the-fold settings must be reachable by scrolling.

  @category/responsiveness
  Scenario: BPM and key grids collapse on a narrow window
    Given the window's width is 1792px
    Then the BPM analyzer grid should be displayed in 2 columns
    And the key analyzer grid should be displayed in 2 columns
    And the ReplayGain analyzer grid should be displayed in 2 columns
    When I resize the window's width to 700px
    Then the BPM analyzer grid should be displayed in 1 column
    And the key analyzer grid should be displayed in 1 column
    And the ReplayGain analyzer grid should be displayed in 1 column
    When I resize the window's width to 1792px

  @category/responsiveness
  Scenario: Below-the-fold settings can be scrolled into view on a short window
    Given the window's width is 1792px
    When I resize the window's height to 500px
    Then the "ReplayGain default boost" setting should not be visible on screen
    When I scroll down in the settings
    Then the "ReplayGain default boost" setting should be visible on screen
    When I set the "ReplayGain default boost" setting to "0" with the spinbox
    Then the "ReplayGain default boost" setting should be "0"
    When I resize the window's height to 1008px
