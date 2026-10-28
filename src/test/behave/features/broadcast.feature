# WIP - Broadcast setting page is only a mock at the moment
Feature: Broadcast Settings (connection profiles as tiles)

  The Broadcast page groups live-streaming server connection profiles as
  tiles. By default there is a single "Add profile" stand-in tile; clicking
  a profile tile (or its gear) focuses it and unfolds its full options in
  place, while other tiles dim — the same interaction as selecting a
  controller on the Controllers page.

  Rule: Broadcast connection profiles (popup open)

    Background:
      Given a new empty profile
      And Mixxx is open and ready to operate
      And the settings popup is open

  Scenario: Broadcast category is reachable in the settings sidebar
    When I select the "Broadcast" category
    Then the "Broadcast" category should be selected

  Scenario: Default layout shows one profile tile and the add tile
    # TODO(DSL): needs tile visibility steps
    When I select the "Broadcast" category
    # Then the "broadcastAddProfile" tile should be visible
    # And the "broadcastProfileName_Broadcast profile 1" tile should be visible
    # And the "broadcastProfileStatus_Broadcast profile 1" badge should read "DISCONNECTED"

  Scenario: Add profile creates and focuses a new profile tile
    # TODO(DSL): needs a click step resolving objectNames inside the popup
    When I select the "Broadcast" category
    # And I click the "broadcastAddProfile" tile
    # Then the "broadcastProfileSettings_Broadcast profile 2" settings should be visible
    # And the "broadcastSaveButton" button should be enabled

  Scenario: Focusing a profile unfolds its settings and dims the others
    # TODO(DSL): needs click + visibility steps
    When I select the "Broadcast" category
    # And I click the "broadcastProfileGear_Broadcast profile 1" button
    # Then the "broadcastServerType" combo should be visible
    # And the "broadcastEncodingFormat" combo should be visible
    # And the "broadcastStreamName" field should be visible
    # And the "broadcastAddProfile" tile should not be visible

  Scenario: Saving returns the page to the overview state
    # TODO(DSL): needs click + visibility steps
    When I select the "Broadcast" category
    # And I click the "broadcastProfileGear_Broadcast profile 1" button
    # And I click the "broadcastSaveButton" button
    # Then the "broadcastProfileSettings_Broadcast profile 1" settings should not be visible
    # And the "broadcastSaveButton" button should be disabled
