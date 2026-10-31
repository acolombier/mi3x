Feature: Browse

  Rule: Library track list (library-ready profile)
    Background:
      Given a new library-ready profile
      And Mixxx is open and ready to operate
      And the window size is default
      And the library columns are in their default state

  # --- Track list & columns (@sub/library) -------------------------------------
  # (from the former features/library.feature)

  @sub/library
  Scenario: Library toggle button is visible
    When I check on the button "LIBRARY" in the main toolbar
    Then the library is shown for less than 75% of the Window's height

  @sub/library
  Scenario: Maximize library with toggle
    When I click the "LIBRARY" button
    Then the library is shown for more than 75% of the Window's height

  @sub/library
  Scenario: Library columns adapt to available width
    When I resize the window's width to 1500px
    Then only the column ",Preview,Title,Artist,Album,Year,BPM,Key,File Type,Bitrate" are shown
    When I resize the window's width to 1200px
    Then only the column ",Preview,Title,Artist,Album,Year,BPM,Key,File Type" are shown
    When I resize the window's width to 800px
    Then only the column "Title,Artist,BPM,Key" are shown

  @sub/library
  Scenario: Library columns can be re-ordered
    When I drag the column "Artist" before the column "Title"
    Then the column "Artist" should appear before the column "Title"

  @sub/library
  Scenario: Library columns can be shown when auto-hidden
    When I resize the window's width to 800px
    Then the column "Preview" should not be visible
    When I open the column picker menu
    And I toggle the column "Preview" in the column picker
    Then the column "Preview" should be visible

  @sub/library
  Scenario: Library columns can be hidden
    When I resize the window's width to 1200px
    Then the column "Artist" should be visible
    When I open the column picker menu
    And I toggle the column "Artist" in the column picker
    Then the column "Artist" should not be visible

  @sub/library
  Scenario: Library columns can be used to sort results
    When I click the column header "Title"
    Then the results should be sorted by "Title" in "ascending" order

  @sub/library
  Scenario: Track can be selected
    When I click the track at row 1
    Then the track at row 1 should be selected

  @sub/library
  Scenario: Track below the fold can be scrolled into view
    Given the library is maximized
    And the window's height is 500px
    When I click a track below the fold
    Then the track below the fold should be visible on screen

  @sub/library
  Scenario: Track context menu can be shown on right click
    When I right-click the track at row 1
    Then the track context menu should be visible

  @sub/library
  Scenario: Track context menu can be shown on long press
    When I long-press the track at row 1
    Then the track context menu should be visible

  # Flaky test on Xcb
  @xpass
  @sub/library
  Scenario: Track can be loaded via double click
    Given no track is loaded on deck 1
    When I double-click the track at row 1
    Then a track is loaded on deck 1

  @sub/library
  Scenario Outline: Track can be loaded via context menu
    Given no track is loaded on deck <deck>
    When I right-click the track at row <row>
    And I select "Load to" > "Deck" > "Deck <deck>" on the track menu
    Then a track is loaded on deck <deck>

    Examples:
      | deck | row |
      | 1    | 1   |
      | 2    | 18  |
      | 1    | 26  |

  @sub/library
  @category/responsiveness
  Scenario: Library collapses when the window is too short
    Given the library is not maximized
    When I resize the window's height to 650px
    Then the library should not be visible
    When I resize the window's height to 800px
    Then the library should be visible

  # --- Library search (@sub/search) ----------------------------------------------
  #
  # Requires item names on the search pane (res/qml/Library/SearchPane.qml;
  # resolved by QML id): searchPane, searchField, clearButton,
  # suggestionFieldList (field suggestions, e.g. "Artist:"), suggestionList
  #   (value suggestions), recentList, searchPlaceholder,
  #   collapsedPlaceholder, typingTip and the read-only properties
  #   activated, activeTokenIndex, criteriaCount, criteriaFields, activeQuery,
  #   suggestionTexts (value-suggestion texts, JSON list).
  # At the track list (res/qml/Library/TrackList.qml):
  #   trackTitleForRow(row), trackDataForRow(row)
  #
  # The rule Background resets leftover criteria/query with "no search is
  # currently active"; "the library search criteria include the field ..."
  # builds a deterministic token search.

  Rule: Library search

    Background:
      Given a new library-ready profile
      And Mixxx is open and ready to operate
      And no search is currently active

  @sub/search
  Scenario: Search bar opens and closes without filtering
    When I activate the library search
    Then the library search bar should be visible
    When I deactivate the library search
    Then all tracks in the library should be shown without a search filter

  @sub/search
  Scenario: Search filters the track results
    And a track available in the library with a unique title
    When I activate the library search
    And I type "title:" into the library search
    And I type the title of this track into the library search prefixed with "="
    And I wait for the search to settle
    Then this track should be visible in the results
    And not all tracks should be visible in the results

  @sub/search
  Scenario: Clearing the search shows all tracks again
    And a track available in the library
    When I activate the library search
    And I type the title of this track into the library search
    Then this track should be visible in the results
    When I clear the library search
    Then all tracks in the library should be shown again

  @sub/search
  Scenario: Search suggests matching field names
    When I activate the library search
    And I type "art" into the library search
    Then the library search suggestion "Artist:" should be visible

  @sub/search
  Scenario: A field suggestion creates a search token
    When I activate the library search
    And I type "art" into the library search
    And I press the "Down" key in the library search
    And I press the "Enter" key in the library search
    Then a search token "Artist" should be shown in the search bar

  @sub/search
  Scenario: A committed search appears in recent searches
    And a track available in the library
    When I activate the library search
    And I type the title of this track into the library search
    And I deactivate the library search
    And I clear the library search
    When I activate the library search
    Then the library recent search "<title of this track>" should be visible

  @sub/search
  Scenario: Search bar is present in the library pane
    Then the library search bar should be present
    And the search placeholder "Search..." should be visible

  @sub/search
  Scenario: Activating the search bar expands it
    When I activate the library search
    Then the library search bar should be visible
    And the library search bar should be expanded

  @sub/search
  Scenario: An activated search bar shows a suggestion placeholder
    When I activate the library search
    Then the search placeholder "Start typing to get suggestion" should be visible

  @sub/search
  Scenario: Typing a field name shows the matching field suggestion and the Tab hint
    When I activate the library search
    And I type "art" into the library search
    Then the library search suggestion "Artist:" should be visible
    And the search hint "Press "Tab" to search for an Artist" should be visible

  @sub/search
  Scenario: Typing filters the field suggestions
    When I activate the library search
    And I type "alb" into the library search
    Then the library search suggestion "Album:" should be visible
    And the library search suggestion "Artist:" should not be visible

  @sub/search
  Scenario: Typing an unknown field shows no field suggestion
    When I activate the library search
    And I type "zzz" into the library search
    Then the library search suggestion "zzz:" should not be visible

  @sub/search
  Scenario: Tab accepts the suggested field criterion and awaits its value
    When I activate the library search
    And I type "art" into the library search
    And I press the "Tab" key in the library search
    Then a search token "Artist" should be shown in the search bar
    And the search token "Artist" should be active
    And the search placeholder "Type "=" for an exact match" should be visible

  @sub/search
  Scenario: A typed field-and-value query becomes a criterion token
    When I activate the library search
    And I type "artist:Rockot" into the library search
    Then a search token "Artist" should be shown in the search bar
    And the library search query should be "artist:Rockot"
    And the search hint "Press "Tab" to add more criteria" should be visible

  @sub/search
  Scenario: Multiple criteria can coexist and preserve the insertion order
    When I activate the library search
    And I type "artist:Rockot" into the library search
    And I press the "Tab" key in the library search
    And I type "title:Drive" into the library search
    Then a search token "Artist" should be shown in the search bar
    And a search token "Title" should be shown in the search bar
    And the library search query should be "artist:Rockot title:Drive"

  @sub/search
  Scenario: A pasted multi-criteria query becomes exact-match criteria
    And a track available in the library with a unique title
    When I paste "artist:="<artist of this track>" title:"<title of this track>"" into the library search
    Then the library search criteria should be "Artist,Title"
    And the library search free text should be empty

  @sub/search
  Scenario: Pasting a query keeps its non-criteria words as free text
    And a track available in the library with a unique title
    When I paste "artist:"<artist of this track>" <title of this track>" into the library search
    Then the library search criteria should be "Artist"
    And the library search free text should be "<title of this track>"

  @sub/search
  Scenario: A pasted free-text search is preserved when no criteria are recognized
    And a track available in the library
    When I paste "<title of this track>" into the library search
    Then the library search query should be "<title of this track>"
    And this track should be visible in the results
    And not all tracks should be visible in the results

  # Known gap: the chip search dialect cannot represent the OR operator yet;
  # a query mixing criteria and a bare "Or" word drops all criteria instead
  # of keeping them (will be fixed by the advanced raw-query editor).
  @xfail
  @sub/search
  Scenario: A pasted query with an OR word keeps its criteria
    And a track available in the library with a unique title and with search operator in its metadata
    When I paste "artist:Rockot Baby Mandala | Nepalese Drill Music" into the library search
    Then the library search criteria should be "Artist"
    And the library search free text should be "Baby Mandala | Nepalese Drill Music"

  @sub/search
  Scenario: The equals prefix enables an exact match
    When I activate the library search
    And I type "artist:" into the library search
    And I type "=Rockot" into the library search
    Then the library search query should be "artist:=Rockot"

  @sub/search
  Scenario: Multi-word values are quoted so they stay a single criterion
    Given the library search criteria include the field "Artist" with the value "Please Calm My Mind"
    Then the library search query should be "artist:"Please Calm My Mind""

  @sub/search
  Scenario: Typing an artist value shows matching value suggestions
    Given a track available in the library with a unique title
    When I activate the library search
    And I type "artist:" into the library search
    And I type the artist of this track into the library search
    Then the library search suggestion showing the artist of this track should be visible

  @sub/search
  Scenario: Enter selects the highlighted value suggestion
    Given a track available in the library with a unique title
    When I activate the library search
    And I type "artist:" into the library search
    And I type the artist of this track into the library search
    And I press the "Down" key in the library search
    And I press the "Enter" key in the library search
    Then a search token "Artist" should be shown in the search bar
    And the library search query should contain the artist of this track

  @sub/search
  Scenario: A key suggestion is shown with its notation and applies as a key criterion
    When I activate the library search
    And I type "key:" into the library search
    And I type "10" into the library search
    Then the library search suggestion "10B" should be visible
    And the library search suggestion "10d" should be visible
    And I press the "Down" key in the library search
    And I press the "Enter" key in the library search
    Then a search token "Key" should be shown in the search bar

  # BPM value suggestions read the library table, whose analyzed BPM is
  # persisted lazily (on track eviction) and is therefore not deterministic
  # through UI actions in an E2E profile. The criterion application mechanism
  # is covered by "Enter selects the highlighted value suggestion", so BPM is
  # covered by the typed field:value path instead.
  @sub/search
  Scenario: A typed BPM value applies as a BPM criterion
    When I activate the library search
    And I type "bpm:1" into the library search
    Then a search token "BPM" should be shown in the search bar
    And the library search query should be "bpm:1"

  @sub/search
  Scenario: Clicking a recent search restores the query
    And a track available in the library
    When I activate the library search
    And I type the title of this track into the library search
    And I deactivate the library search
    And I clear the library search
    When I activate the library search
    And I click the recent library search "<title of this track>"
    Then the library search query should be "<title of this track>"

  @sub/search
  Scenario: A recent search can be applied with the keyboard
    And a track available in the library
    When I activate the library search
    And I type the title of this track into the library search
    And I deactivate the library search
    And I clear the library search
    When I activate the library search
    And I press the "Down" key in the library search
    And I press the "Enter" key in the library search
    Then the library search query should be "<title of this track>"

  @sub/search
  Scenario: A single criterion filters the library results
    And a track available in the library with a unique title
    When I activate the library search
    And I type the title of this track into the library search
    And I wait for the search to settle
    Then this track should be visible in the results
    And not all tracks should be visible in the results

  @sub/search
  Scenario: An artist criterion filters the library results
    And a track available in the library with a unique title
    When I activate the library search
    And I type "artist:" into the library search
    And I type the artist of this track into the library search
    And I wait for the search to settle
    Then this track should be visible in the results
    And not all tracks should be visible in the results

  @sub/search
  Scenario: Multiple criteria are combined with AND
    And a track available in the library with a unique title
    When I activate the library search
    And I type "artist:" into the library search
    And I type the artist of this track into the library search
    And I press the "Tab" key in the library search
    And I type the first word of the title of this track into the library search
    And I wait for the search to settle
    Then this track should be visible in the results
    And not all tracks should be visible in the results

  @sub/search
  Scenario: Ctrl+F activates the search bar
    When I press the "Ctrl+F" key in the library search
    Then the library search bar should be visible

  @sub/search
  Scenario: The Right arrow moves the focus between criteria tokens
    When I activate the library search
    And I type "artist:Rockot" into the library search
    And I press the "Tab" key in the library search
    And I type "key:74" into the library search
    And I press the "Left" key in the library search
    And I press the "Left" key in the library search
    And I press the "Left" key in the library search
    Then the search token "Artist" should be active
    When I press the "Right" key in the library search
    Then the search token "Key" should be active

  @sub/search
  Scenario: Backspace on an empty value removes the previous token
    When I activate the library search
    And I type "artist:" into the library search
    And I press the "Backspace" key in the library search
    Then the library search bar should be empty

  @sub/search
  Scenario: Delete removes the active criterion token
    When I activate the library search
    And I type "artist:Rockot" into the library search
    And I press the "Delete" key in the library search
    Then the library search bar should be empty

  @sub/search
  Scenario: The search bar is anchored to the bottom-right of the library pane
    Then the library search bar should be anchored to the bottom-right of the library pane

  # --- Library sidebar sources and tracklists ------------------------------------
  #
  # Covers new Playlist/Crate/Explorer sources, capability-driven create UI,
  # creation flows, activation and sync when items are created.
  Rule: Library sidebar sources and tracklists

    Background:
      Given a new library-ready profile
      And Mixxx is open and ready to operate
      And the window size is default
      And the library columns are in their default state

  Scenario: Sidebar shows all default sources at launch
    Then the library sidebar should show the source "All..."
    And the library sidebar should show the source "Playlists"
    And the library sidebar should show the source "Crates"
    And the library sidebar should show the source "Explorer"

  Scenario: Explorer source cannot create new items
    When I select the source "Explorer" in the library sidebar
    Then the option to create a new item should not be available for the selected library source

  Scenario: Creating a new playlist via sidebar
    When I select the source "Playlists" in the library sidebar
    And I initiate creating a new item in the selected library source
    Then a create popup for the library source should be visible
    When I enter "MyTestPlaylist" as the new item name
    And I confirm the create action
    Then a playlist named "MyTestPlaylist" should exist in the library
    When I expand the source "Playlists" in the library sidebar
    Then a playlist named "MyTestPlaylist" should appear in the library sidebar

  Scenario: Creating a new crate via sidebar
    When I select the source "Crates" in the library sidebar
    And I initiate creating a new item in the selected library source
    Then a create popup for the library source should be visible
    When I enter "MyTestCrate" as the new item name
    And I confirm the create action
    Then a crate named "MyTestCrate" should exist in the library
    When I expand the source "Crates" in the library sidebar
    Then a crate named "MyTestCrate" should appear in the library sidebar

  Scenario: Creating playlist via track context menu
    When I right-click the track at row 1
    And I select "Add to playlists" > "Create New Playlist" on the track menu
    When I enter "MyTestPlaylist" as the new playlist context-menu input and submit
    Then a playlist named "MyTestPlaylist" should exist in the library
    When I discard the track menu
    And I expand the source "Playlists" in the library sidebar
    Then a playlist named "MyTestPlaylist" should appear in the library sidebar

  Scenario: Creating crate via track context menu
    When I right-click the track at row 1
    And I select "Crates" > "Create New Crate" on the track menu
    When I enter "MyTestCrate" as the new crate context-menu input and submit
    Then a crate named "MyTestCrate" should exist in the library
    When I discard the track menu
    And I expand the source "Crates" in the library sidebar
    Then a crate named "MyTestCrate" should appear in the library sidebar

  Scenario: Playlist source create requires a valid name
    When I select the source "Playlists" in the library sidebar
    And I initiate creating a new item in the selected library source
    Then a create popup for the library source should be visible
    When I confirm the create action
    Then the create popup for the library source should remain visible
    And the create popup for the library source should show an error state
    When I cancel the create action
    Then a create popup for the library source should be hidden

  Scenario: Playlist source rejects duplicate names
    Given a playlist named "DupTest" already exists
    When I select the source "Playlists" in the library sidebar
    And I initiate creating a new item in the selected library source
    Then a create popup for the library source should be visible
    When I enter "DupTest" as the new item name
    And I confirm the create action
    Then the create popup for the library source should remain visible
    And the create popup for the library source should show an error state
    When I cancel the create action
    Then a create popup for the library source should be hidden

  Scenario: Crate source rejects duplicate names
    Given a crate named "DupTest" already exists
    When I select the source "Crates" in the library sidebar
    And I initiate creating a new item in the selected library source
    Then a create popup for the library source should be visible
    When I enter "DupTest" as the new item name
    And I confirm the create action
    Then the create popup for the library source should remain visible
    And the create popup for the library source should show an error state
    When I cancel the create action
    Then a create popup for the library source should be hidden

  Scenario: Switching between library sources activates them
    # Given the library sidebar shows the source "Crate"
    # Given the library sidebar shows the source "Explorer"
    Given a playlist named "A test playlist" already exists with 5 tracks
    And a crate named "A test crate" already exists with 5 tracks
    When I select the crate named "A test crate" in the library sidebar
    Then the crate named "A test crate" should be shown in tracklist
    When I select the playlist named "A test playlist" in the library sidebar
    Then the playlist named "A test playlist" should be shown in tracklist
    When I select the crate named "A test crate" in the library sidebar
    Then the crate named "A test crate" should be shown in tracklist
    When I select the source "All..." in the library sidebar
    Then all tracks should be shown in tracklist

  # --- Right side menu & split view (tracklist toolbar on the right edge) --------
  #
  # Requires objectNames on the tracklist right menu (res/qml/Library.qml):
  #   splitViewButton, rightTrackListLoader (the right-side Loader's TrackList)
  # and new steps:
  #   I click the split view button
  #   I click the track at row {row} on the right track list

  @sub/library
  Scenario: Split view opens a second track list
    When I click the split view button
    Then the track list on the right should be visible
    When I click the track at row 1 on the right track list
    Then the track at row 1 on the right track list should be selected
    When I click the split view button
    Then the track list on the right should not be visible

  # TODO: This scenario is invalid: we need to verify that search is independent per splits, and gets restored when the focus changes. Currently needs backend work so LibraryTableModel is specific to the view and not shared.
  @xfail
  @sub/library
  Scenario: A search applies to both track lists in split view
    Given a track available in the library
    When I click the split view button
    And I activate the library search
    And I type the title of this track into the library search
    Then this track should be visible in the left track list
    And this track should be visible in the right track list

  # --- Library scan & load-failure notifications (@sub/notifications) ------------
  #
  # Scan progress and summaries are surfaced as notifications (sticky while
  # scanning, transient summary, 10 s auto-timeout). The scan is triggered
  # through the logo context menu ("File > Library > Scan").

  Rule: Library scanner notifications

    Background:
      Given a new library-ready profile
      And Mixxx is open and ready to operate

    @sub/notifications
    Scenario: A library scan raised from the header menu is reported as a notification
      When I trigger a library scan from the header menu
      And the scanning overlay is hidden
      Then the notification "Library scan finished" should be visible
      And the notification bell should be enabled

    @sub/notifications
    @xpass
    Scenario: A transient scan summary auto-dismisses and closes the drawer
      When I trigger a library scan from the header menu
      And the scanning overlay is hidden
      And the notification "Library scan finished" is visible
      When I wait for 12 second
      Then the notification "Library scan finished" should not be visible
      And the notification drawer should not be visible

    @sub/notifications
    @test/missing-ui-interaction
    Scenario: Loading a missing track raises an error notification
      # loadTrack RPC with a nonexistent path (track-load failures produce a
      # notification, not a modal, deduped per track)
      When I attempt to load a missing track on deck 1
      Then the notification "Couldn't load track." should be visible
      And the notification details should mention the failure reason

  Rule: Library settings (fresh profile)

    Background:
      Given a fresh new empty profile
      And Mixxx is open and ready to operate
      And the settings popup is open
      And the "Library" category is selected

    # --- Library settings (former features/settings/library.feature) ----------------
    #
    # These scenarios configure the library through the settings popup.
    #
    # The "Search completion" / "Search history keyboard shortcuts" scenarios
    # from the former features/settings/interface.feature are not duplicated
    # here: both pages bind the same config keys ([Library]
    # EnableSearchCompletions / EnableSearchHistoryShortcuts), so the copies on
    # the Library page cover the setting once.

    @sub/library
    Scenario: Music library integrations are shown
      Then the "Rhythmbox integration" setting should be "off"
      And the "Banshee integration" setting should be "off"
      And the "iTunes integration" setting should be "off"
      And the "Traktor integration" setting should be "off"
      And the "Rekordbox integration" setting should be "off"
      And the "Serato integration" setting should be "off"

    @sub/library
    Scenario: An integration can be enabled and saved
      When I toggle the "Serato integration" setting to "on"
      And I click the save button
      Then the "Serato integration" setting should be "on"
      And the "Serato integration" should be saved as "on"

    @sub/library
    Scenario: Metadata synchronisation with files can be enabled
      When I toggle the "synchronise metadata with file" setting to "on"
      And I click the save button
      Then the "synchronise metadata with file" setting should be "on"
      And the "synchronise metadata with file" should be saved as "on"

    @sub/library
    Scenario: Metadata synchronisation with Serato can be enabled
      When I toggle the "synchronise metadata with Serato library" setting to "on"
      Then the "synchronise metadata with Serato library" setting should be "on"

    @sub/library
    Scenario: Relative path export can be preferred
      When I toggle the "prefer relative path on playlist export" setting to "on"
      And I click the save button
      Then the "prefer relative path on playlist export" setting should be "on"
      And the "prefer relative path on playlist export" should be saved as "on"

    @sub/library
    Scenario: Track duplicate distance can be changed
      When I set the "track duplicate distance" setting to "5"
      And I click the save button
      Then the "track duplicate distance" setting should be "5"
      And the "track duplicate distance" should be saved as "5"

    @sub/library
    @xfail(gh_issue=85)
    Scenario: History cleanup threshold can be changed
      When I set the "delete history playlist with less than" setting to "10"
      And I click the save button
      Then the "delete history playlist with less than" setting should be "10"
      And the "delete history playlist with less than" should be saved as "10"

    @sub/search
    Scenario: Search completion can be disabled
      When I toggle the "library search completion" setting to "off"
      And I click the save button
      Then the "library search completion" setting should be "off"

    @sub/search
    Scenario: Search history keyboard shortcuts can be disabled
      When I toggle the "library search history keyboard shortcuts" setting to "off"
      And I click the save button
      Then the "library search history keyboard shortcuts" setting should be "off"

    @sub/library
    Scenario: Search-as-you-type timeout can be changed
      When I set the "search-as-you-type timeout" setting to "5" with the spinbox
      And I click the save button
      Then the "search-as-you-type timeout" setting should be "5"
      And the "search-as-you-type timeout" should be saved as "5"

    @sub/library
    Scenario: Pitch slider fuzz BPM range can be changed
      # UI round-trip only: save() writes the raw 0-100 slider value to the
      # 0-100 "search_bpm_fuzzy_range" config key, which looks like a units bug
      # (config default is 0.06). Asserting persistence would enshrine it.
      When I set the "pitch slider for fuzz BPM search" setting to "50" with the spinbox
      Then the "pitch slider for fuzz BPM search" setting should be "50"

    # --- Music directories (sources) ---------------------------------------------
    #
    # Directories are seeded via the `library` RPC command; the last add runs a
    # blocking scan, whose completion refreshes the sources list in the already
    # open popup (scanner onRunningChanged -> loadSources()). Removal is driven
    # through the real UI (select row -> Remove -> keep/hide/purge -> Save).
    #
    # Adding directories is driven through the real UI too: the "Add" button is
    # routed to a test dialog mock (Library.qml testDialog) in test mode, which
    # emulates the native FolderDialog so the test can inject a folder path.

    @sub/notifications
    Scenario: The scan summary notification can be disabled
      When I toggle the "show scan summary" setting to "off"
      And I click the save button
      And I click the cancel button
      And I trigger a library scan from the header menu
      And the scanning overlay is hidden
      Then no notification should be visible

    Scenario: The music directory list is empty on a new profile
      Then the music directory list should be empty

    Scenario: Newly added directories appear in the music directory list
      Given the following music directories
        | id | tracks | permission | dir |
        | 0  | 0      | read       | M1  |
        | 1  | 0      | read       | M2  |
        | 2  | 0      | read       | M3  |
      When I add the test music directory 0
      Then the music directory list should contain 1 source
      And the save button should be enabled
      When I add the test music directory 1
      And I add the test music directory 2
      Then the music directory list should contain 3 sources
      When I click the save button
      Then the music directory list should contain 3 sources
      And the save button should be disabled
      And the library state should match the following
        | key     | value |
        | sources | 3     |

    Scenario: A single directory with tracks can be added and saved
      Given a music directory
      When I add the test music directory 0
      Then the music directory list should contain 1 source
      And the save button should be enabled
      When I click the save button
      Then the music directory list should contain 1 source
      And the save button should be disabled
      And the library state should match the following
        | key     | value |
        | sources | 1     |

    Scenario: An empty music directory can be removed
      Given the library contains 2 music directories
      When I select the music directory at row 0
      Then the remove button of the music directory at row 0 should be visible
      When I click the remove button for the music directory at row 0
      Then the music directory list should contain 2 sources
      And the save button should be enabled
      When I click the save button
      Then the music directory list should contain 1 source
      And the library state should match the following
        | key     | value |
        | sources | 1     |

    Scenario: Cancelling a removal keeps the music directory
      Given the library contains 2 music directories
      When I select the music directory at row 0
      And I click the remove button for the music directory at row 0
      And I click the cancel button
      Then the music directory list should contain 2 sources
      And the save button should be disabled

    Scenario Outline: A music directory with tracks can be removed and its tracks <action>
      Given the tracks directory is in the library
      When the scanning overlay is hidden
      And I select the music directory at row 0
      And I click the remove button for the music directory at row 0
      And I choose to <action> the tracks of the music directory at row 0
      And I click the save button
      And the scanning overlay is hidden
      Then the music directory list should contain 0 sources
      And the library state should match the following
        | key               | value |
        | visibleTrackCount | <visible> |
        | hiddenTrackCount  | <hidden>  |

      Examples:
        | action | visible | hidden |
        | keep   | >0      | =0     |
        | hide   | =0      | >0     |
        | purge  | =0      | =0     |

    Scenario: Relink is available for a selected music directory
      Given the tracks directory is in the library
      When I select the music directory at row 0
      Then the relink button of the music directory at row 0 should be visible
      And the remove button of the music directory at row 0 should be visible

    # --- Library row height (former features/settings/interface.feature) ------------

    @sub/library
    Scenario: Library row height can be changed
      Given the "Interface" category is selected
      When I set the "library row height" setting to "50" with a drag
      Then the "library row height" setting should be "50"

    # --- Responsiveness -------------------------------------------------------------
    #
    # The sources grid switches between 2 and 1 columns at 800px of content
    # width (integrations stack below the music directory pane), and the
    # metadata / history grids collapse their columns on narrow rows. On a
    # short window the category overflows its ScrollView and below-the-fold
    # settings must be reachable by scrolling.

    @category/responsiveness
    Scenario: Sources and integrations stack on a narrow window
      Given the window's width is 1792px
      Then the Library sources grid should be displayed in 2 columns
      When I resize the window's width to 700px
      Then the Library sources grid should be displayed in 1 column
      When I resize the window's width to 1792px

    @sub/library
    @category/responsiveness
    Scenario: Metadata and history settings rearrange on a narrow window
      Given the window's width is 1792px
      Then the Library metadata grid should be displayed in 2 columns
      And the Library history grid should be displayed in 2 columns
      When I resize the window's width to 700px
      Then the Library metadata grid should be displayed in 1 column
      And the Library history grid should be displayed in 1 column
      When I resize the window's width to 1792px

    @sub/library
    @category/responsiveness
    Scenario: Below-the-fold settings can be scrolled into view on a short window
      Given the window's width is 1792px
      When I resize the window's height to 500px
      Then the "pitch slider for fuzz BPM search" setting should not be visible on screen
      When I scroll down in the settings
      Then the "pitch slider for fuzz BPM search" setting should be visible on screen
      When I set the "pitch slider for fuzz BPM search" setting to "50" with the spinbox
      Then the "pitch slider for fuzz BPM search" setting should be "50"
      When I resize the window's height to 1008px

    @category/responsiveness
    Scenario: Integration options compact when the row is narrow
      Given the window's width is 1792px
      Then the Library integrations grid should be displayed in 1 column
      When I resize the window's width to 700px
      Then the Library integrations grid should be displayed in 2 columns
      And the integrations grid should be below the library source pane
      And the integrations grid should not overlap the library source pane
      When I resize the window's width to 1792px
