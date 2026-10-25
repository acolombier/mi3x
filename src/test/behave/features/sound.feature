Feature: Sound

  Rule: Sound setting can be navigated
    Background:
      Given a new empty profile
      And Mixxx is open and ready to operate
      And the settings popup is open

  # --- Tab Navigation ---

  Scenario: Sound hardware tabs are visible
    Then the "engine" tab should be visible
    And the "delays" tab should be visible
    And the "stats" tab should be visible

  Scenario: Switching to delays tab
    When I click the "delays" tab
    Then the "delays" tab should be selected
    And the delays section should be visible

  Scenario: Switching to stats tab
    When I click the "stats" tab
    Then the "stats" tab should be selected

  Scenario: Switching back to engine tab
    And the "delays" tab is selected
    When I click the "engine" tab
    Then the "engine" tab should be selected
    And the engine section should be visible

  # --- Save / Cancel Buttons ---
  Scenario: Save button is disabled when no changes
    Then the save button should be disabled
    And the cancel button should not be visible

  Scenario: Save and cancel appear when setting changes
    Given the "Main Mix" setting is "on"
    When I toggle the "Main Mix" setting to "off"
    Then the save button should be enabled
    And the cancel button should be visible

  Scenario: Cancel reverts changes
    Given the "Main Mix" setting is "on"
    When I toggle the "Main Mix" setting to "off"
    And I click the cancel button
    Then the "Main Mix" setting should be "on"
    And the save button should be disabled

  Scenario: Save applies changes
    When I toggle the "Main Mix" setting to "off"
    And I click the save button
    Then the save button should be disabled
    And the cancel button should not be visible

  # Flaky: the committing overlay may flash too quickly if the save
  # completes instantly (no real audio device configured).
  @xpass
  Scenario: Save shows committing overlay while processing
    Given the "Main Mix" setting is "on"
    When I toggle the "Main Mix" setting to "off"
    And I click the save button
    Then the committing overlay should be visible
    And the committing overlay should not be visible after commit

  # --- Audio Router: Device Display ---

  Scenario: Router shows output devices in simple mode
    Then the router section should be visible
    And the router mode should be "simple"
    And the outputs column should be visible
    And the input column should not be visible

  Scenario: Router shows internal entities in simple mode
    Then the "Mixer" entity should be visible in the router
    And the "Deck 1" entity should be visible in the router
    And the "Record/Broadcast" entity should not be visible in the router

  Scenario: Switching to advanced mode shows inputs
    Given the router mode is "simple"
    When I set the router mode to "advanced"
    Then the inputs column should be visible
    And the "Record/Broadcast" entity should be visible in the router

  Rule: Engine allows connection inputs and output
    Background:
      Given a new empty profile
      And I have the following sound devices
        | name            | api  | outputChannels | inputChannels |
        | Built-in Audio  | Mock | 4              | 4             |
      And Mixxx is open and ready to operate
      And the settings popup is open
      And the "Sound hardware" category is selected
      And the "Sound API" setting is "Mock"

  Scenario: Switching to legacy mode hides router entities
    Given the router mode is "simple"
    When I set the router mode to "legacy"
    Then the "Mixer" entity should not be visible in the router
    And the "Deck 1" entity should not be visible in the router

  # FIXME: crash?
  @xfail
  Scenario: Indicators shows additional connections made in advanced mode when simple mode is used
    # FIXME: _find_first_output_edge is fragile (depends on system audio devices).
    # This scenario connects two internal entities (Deck 1 -> Mixer) so it avoids
    # the output device issue, but the edge-to-edge connect step still needs
    # verification that "Output" on Deck 1 and "Auxiliary" on Mixer are both
    # visible in advanced mode and that their types (source/sink) are compatible.
    Given the router mode is "advanced"
    When I connect the "Output" edge on "Deck 1" entity to a free output channel
    And I click the save button
    And I set the router mode to "simple"
    Then the "advanced (!)" option should be visible

  # --- Audio Router: Connection Edge States ---

  # FIXME: required edge not displaying
  Scenario: Required edge shows warning state when unconnected
    Given the router mode is "simple"
    Then the "Main" edge on "Mixer" entity should show warning state

  Scenario: Idle edge displays correctly when no connection
    Given the router mode is "advanced"
    Then the "PFL" edge on "Mixer" entity should show idle state

  Scenario: Edge shows setting state after new connection
    Given the router mode is "advanced"
    When I connect the "Main" edge on "Mixer" entity to a free output channel
    Then the "Main" edge on "Mixer" entity should show setting state

  Scenario: Edge shows existing state for saved connection
    Given the router mode is "advanced"
    And a saved connection exists from "Main" on "Mixer" to an output device
    Then the "Main" edge on "Mixer" entity should show existing state

  Scenario: Connection line shows correct state colors
    Given the router mode is "advanced"
    And a saved connection exists from "Main" on "Mixer" to an output device
    Then the connection from "Main" on "Mixer" should show existing state
    When I connect the "PFL" edge on "Mixer" entity to a free output channel
    Then the connection from "PFL" on "Mixer" should show set state

  # TODO: investigate
  @xfail
  Scenario: Disconnecting an existing connection marks it for deletion
    # FIXME: one blockers:
    #   2. spix has no mouseHover/mouseMoveTo API. The edge MouseArea uses
    #      onEntered to set AudioConnection.Flags.AboutToDelete, but spix
    #      only triggers onPressed (via mouseClick). Need spix hover support
    #      or a custom C++ command to set the flag directly.
    And the router mode is "advanced"
    And a saved connection exists from "Main" on "Mixer" to an output device
    When I hover over the "Main" edge on "Mixer" entity
    Then the connection from "Main" on "Mixer" should show warning state

  # --- Audio Router: Connect and Save ---

  Scenario: Creating a connection enables save button
    And the router mode is "advanced"
    When I connect the "Main" edge on "Mixer" entity to a free output channel
    Then the save button should be enabled

  Scenario: Saving persists the connection
    And the router mode is "advanced"
    When I connect the "Main" edge on "Mixer" entity to a free output channel
    And I click the save button
    And the committing overlay is not visible
    Then the "Main" edge on "Mixer" entity should show existing state

  Scenario: Cancel discards unsaved connection
    And the router mode is "advanced"
    When I connect the "Main" edge on "Mixer" entity to a free output channel
    And I click the cancel button
    Then the "Main" edge on "Mixer" entity should show warning state

  Scenario: Reset after connection restores original state
    And the router mode is "advanced"
    When I connect the "Main" edge on "Mixer" entity to a free output channel
    And I click the cancel button
    Then the router should match the saved configuration

  # --- Sound device setup notifications (@sub/notifications) --------------------
  #
  # Sound-setup failures are surfaced as sticky notifications at start-up
  # (QmlApplication) instead of modal dialogs. Both notifications are raised
  # before the Background steps run, so the settings popup above does not
  # interfere with the assertions below.

  Rule: Sound device setup notifications

    @sub/notifications
    Scenario: A startup without output devices is acknowledged in a sticky notification
      # The feature Background configures no outputs, so the "No Output
      # Devices" sticky notification is raised during start-up. The fresh
      # profile forces a deterministic start-up (the notification is only
      # raised once, while the QML UI loads).
      Given a fresh new empty profile
      And Mixxx is open and ready to operate
      Then the notification "No Output Devices" should be visible
      And the notification "No Output Devices" should be sticky

    # The <kind> dimension selects the seeded mock device's openStatus
    # (mixxx_profile.py): "busy" fails with ErrorDeviceCount and start-up
    # raises "Sound Device Busy"; "error" fails with Error and start-up
    # raises "Sound Device Error" (no Reconfigure CTA, only Retry/Exit).

    @sub/notifications
    Scenario Outline: A failing sound device at start-up is acknowledged in a sticky notification
      Given a profile with a <kind> sound device configured
      And Mixxx is open and ready to operate
      Then the notification "<title>" should be visible
      And the notification "<title>" should be sticky
      And the notification details should mention "Unopenable Sound Device"
      And the notification "<title>" should offer the actions "<actions>"

      Examples:
        | kind  | title              | actions                     |
        | busy  | Sound Device Busy  | Retry,Help,Reconfigure,Exit |
        | error | Sound Device Error | Retry,Exit                  |

    @sub/notifications
    Scenario Outline: The "Retry" action does not clear the notification while the device still fails
      Given a profile with a <kind> sound device configured
      And Mixxx is open and ready to operate
      When I click the "Retry" action of the "<title>" notification
      Then the notification "<title>" should be visible

      Examples:
        | kind  | title              |
        | busy  | Sound Device Busy  |
        | error | Sound Device Error |

    @sub/notifications
    Scenario: The "Reconfigure" action of the no-output notification focuses the sound engine section
      # The Background already leaves the engine section focused; the CTA
      # re-focuses it. The notification stays: it only clears once the sound
      # settings are saved with at least one output
      # (QmlSettingGroup::saved watcher, QmlApplication).
      Given a fresh new empty profile
      And Mixxx is open and ready to operate
      When I click the "Reconfigure" action of the "No Output Devices" notification
      Then the engine section should be visible
      And the notification "No Output Devices" should be visible

    @sub/notifications
    Scenario: The "Reconfigure" action of the no-output notification only clears it after a saved reconfiguration
      Given a fresh new empty profile
      And Mixxx is open and ready to operate
      When I click the "Reconfigure" action of the "No Output Devices" notification
      And the engine section should be visible
      And I click the save button
      And the committing overlay is not visible
      Then the notification "No Output Devices" should be visible

    @sub/notifications
    Scenario: The "Reconfigure" action of the busy notification closes it
      Given a profile with a busy sound device configured
      And Mixxx is open and ready to operate
      When I click the "Reconfigure" action of the "Sound Device Busy" notification
      Then the engine section should be visible
      And the connection from "Main" on "Mixer" should show existing state
      When I click the "Main" edge on "Mixer"
      And I connect the "Main" edge on "Mixer" entity to a free output channel on device "Working Sound Device"
      And I click the save button
      Then no notification should be visible

    @sub/notifications
    Scenario Outline: The "Exit" action of the failing-device notification stops the process
      # The Exit CTA is exit(0), shared by all startup notification kinds;
      # testing it on the failing-device cases keeps the no-output
      # scenarios process-alive.
      Given a profile with a <kind> sound device configured
      And Mixxx is open and ready to operate
      When I click the "Exit" action of the "<title>" notification
      Then Mixxx should have quit

      Examples:
        | kind  | title              |
        | busy  | Sound Device Busy  |
        | error | Sound Device Error |

  # --- Multi-Soundcard Synchronization ---
