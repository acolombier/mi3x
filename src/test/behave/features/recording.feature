# WIP - Recording setting page is only a mock at the moment
Feature: Recording Settings

  The Recording page is a flat page: recording directory and file
  splitting, output file format with format-dependent quality controls
  (bitrate mode and quality slider for lossy formats, compression slider
  for FLAC), and static file tags.

  Background:
    Given a new empty profile
    And Mixxx is open and ready to operate

  Scenario: Recording category is reachable in the settings sidebar
    Given the settings popup is open
    When I select the "Recording" category
    Then the "Recording" category should be selected

  Scenario: Default settings
    # TODO(DSL): needs SETTING_MAP entries for the recording settings
    Given the settings popup is open
    # And the recording settings are set to default
    When I select the "Recording" category
    # Then the "recording directory" setting should be "/home/.../Recordings"
    # And the "recording format" setting should be "MP3"
    # And the "recordings split" setting should be "4 GB"
    # And the "quality" setting should be "128 kbit/s"

  Scenario: Save button enables on change and persists the setting
    # TODO(DSL): needs SETTING_MAP entries for the recording settings
    Given the settings popup is open
    # And the recording settings are set to default
    When I select the "Recording" category
    # And I set the "recording title tag" setting to "My title"
    # Then the save button should be enabled
    # When I click the save button
    # And the "recording title tag" should be saved as "My title"

  Scenario: Lossless formats hide the bitrate controls
    # TODO(DSL): needs SETTING_MAP entries for the recording settings
    Given the settings popup is open
    When I select the "Recording" category
    # When I set the "recording format" setting to "FLAC"
    # Then the "recording bitrate mode" setting should not be visible
    # And the "compression level" setting should be visible
    # When I set the "recording format" setting to "MP3"
    # Then the "recording bitrate mode" setting should be visible
    # And the "compression level" setting should not be visible
