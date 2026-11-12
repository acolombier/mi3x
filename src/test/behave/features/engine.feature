Feature: Engine

  Rule: Effects tab (popup open)

    Background:
      Given a new empty profile
      And Mixxx is open and ready to operate
      And the settings popup is open
      And the "Mixer & Effects" category is selected
      And the "effects" tab is selected

  Scenario: Adopt metaknob value is enabled by default
    Then the "adopt metaknob value" setting should be "on"

  Scenario: Adopt metaknob value can be disabled
    When I toggle the "adopt metaknob value" setting to "off"
    And I click the save button
    Then the "adopt metaknob value" setting should be "off"
    And the "adopt metaknob value" should be saved as "off"
    And the save button should be disabled

  Scenario: Cancel reverts effects changes
    Given the "adopt metaknob value" setting is "on"
    When I toggle the "adopt metaknob value" setting to "off"
    And I click the cancel button
    Then the "adopt metaknob value" setting should be "on"
    And the save button should be disabled

  Scenario: Reset restores effects defaults
    Given the "adopt metaknob value" setting is "off"
    When I click the reset button
    Then the "adopt metaknob value" setting should be "on"

  Rule: Mixer & Effects category (popup open)

    Background:
      Given a new empty profile
      And Mixxx is open and ready to operate
      And the settings popup is open
      And the "Mixer & Effects" category is selected

  Scenario: Mixer & Effects tabs are visible
    Then the "crossfader" tab should be visible
    And the "equalizers" tab should be visible
    And the "effects" tab should be visible

  Scenario: The crossfader tab is selected by default
    Then the "crossfader" tab should be selected

  Scenario: Switching to the equalizers tab
    When I click the "equalizers" tab
    Then the "equalizers" tab should be selected

  Scenario: Crossfader mode can be changed
    Given the "crossfader" tab is selected
    When I toggle the "crossfader mode" setting to "Constant Power"
    And I click the save button
    Then the "crossfader mode" setting should be "Constant Power"
    And the "crossfader mode" should be saved as "Constant Power"
    And the save button should be disabled

  Scenario: Crossfader reverse can be enabled
    Given the "crossfader" tab is selected
    When I toggle the "reverse crossfader" setting to "on"
    And I click the save button
    Then the "reverse crossfader" setting should be "on"
    And the "reverse crossfader" should be saved as "on"

  Scenario: Cancel reverts crossfader changes
    Given the "crossfader" tab is selected
    Given the "reverse crossfader" setting is "off"
    When I toggle the "reverse crossfader" setting to "on"
    And I click the cancel button
    Then the "reverse crossfader" setting should be "off"
    And the save button should be disabled

  Scenario: Reset restores crossfader defaults
    Given the "crossfader" tab is selected
    Given the "reverse crossfader" setting is "on"
    When I click the reset button
    Then the "reverse crossfader" setting should be "off"

  Scenario: EQ options can be changed
    Given the "equalizers" tab is selected
    And the "EQ effects only" setting is "on"
    When I toggle the "EQ effects only" setting to "off"
    And I click the save button
    Then the "EQ effects only" setting should be "off"
    And the "EQ effects only" should be saved as "off"

  Scenario: Bypass EQ is stored inverted
    Given the "equalizers" tab is selected
    When I toggle the "bypass EQ" setting to "on"
    And I click the save button
    Then the "bypass EQ" setting should be "on"
    And the "bypass EQ" should be saved as "on"

  Scenario: Single EQ effect can be disabled
    Given the "equalizers" tab is selected
    When I toggle the "single EQ effect" setting to "off"
    And I click the save button
    Then the "single EQ effect" setting should be "off"
    And the "single EQ effect" should be saved as "off"

  Scenario: EQ auto reset can be enabled
    Given the "equalizers" tab is selected
    When I toggle the "EQ auto reset" setting to "on"
    And I click the save button
    Then the "EQ auto reset" setting should be "on"
    And the "EQ auto reset" should be saved as "on"

  Scenario: Gain auto reset can be enabled
    Given the "equalizers" tab is selected
    When I toggle the "gain auto reset" setting to "on"
    And I click the save button
    Then the "gain auto reset" setting should be "on"
    And the "gain auto reset" should be saved as "on"

  Scenario: High EQ shelf reaches the engine
    Given the "equalizers" tab is selected
    When I set the "high EQ shelf" setting to "5000" with the spinbox
    And I click the save button
    Then the "high EQ shelf" setting should be "5000"
    And the "high EQ shelf" should be saved in the mixer config as "5000"
    And the "high EQ shelf" should be applied to the engine as "5000"

  Scenario: Low EQ shelf reaches the engine
    Given the "equalizers" tab is selected
    When I set the "low EQ shelf" setting to "1000" with the spinbox
    And I click the save button
    Then the "low EQ shelf" setting should be "1000"
    And the "low EQ shelf" should be saved in the mixer config as "1000"
    And the "low EQ shelf" should be applied to the engine as "1000"

  Scenario: Main EQ effect is persisted by Save
    Given the "equalizers" tab is selected
    When I set the "main EQ effect" setting to "Parametric Equalizer"
    And I click the save button
    Then the "main EQ effect" setting should be "Parametric Equalizer"
    And the main EQ effect should be saved as "org.mixxx.effects.parametriceq Built-In"

  @sub/mixer-deck-eq-quickfx
  Scenario Outline: Each deck EQ and QuickEffect is saved independently
    Given the "equalizers" tab is selected
    And the "single EQ effect" setting is "off"
    When I select "<eq>" as the EQ effect on deck <deck>
    And I select "<quickfx>" as the QuickEffect on deck <deck>
    And I click the save button
    Then the deck <deck> EQ effect should be "<eq>"
    And the deck <deck> QuickEffect should be "<quickfx>"
    And the deck <deck> EQ effect should be saved as "<eq>"
    And the deck <deck> QuickEffect should be saved as "<quickfx>"

    Examples:
      | deck | eq                         | quickfx       |
      | 1    | Biquad Full Kill Equalizer | Echoverb HP   |
      | 2    | Bessel4 LV-Mix Isolator    | Filter Echo   |
      | 3    | Bessel8 LV-Mix Isolator    | Mid/Side      |
      | 4    | LinkwitzRiley8 Isolator    | Side Reverb HP |

  Rule: Settings search (popup open)

    Background:
      Given a new empty profile
      And Mixxx is open and ready to operate
      And the settings popup is open
      And the "Mixer & Effects" category is selected
      And the "effects" tab is selected

  Scenario: Search finds effects settings
    When I search for "Metaknob"
    Then the search results should be visible
