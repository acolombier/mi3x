# AGENTS.md — Mixxx Behave E2E UI Tests

> **New to BDD or this test suite?** See [README.md](README.md) for a
> human-friendly introduction to Gherkin, Behave, the step DSL, test tags, and
> the overall setup. This file is the detailed technical reference.

## Architecture Overview

```text
mixxx_test_runner.py   ← CTest entry point (CMake add_test target "mixxx-behave-*")
  │
  ├─ profile.py        ← Profile creation, track download, MixxxProcess lifecycle
  ├─ environment.py    ← behave before_all/after_all/scenario hooks + autoretry
  ├─ steps/
  │   └─ mixxx_steps.py  ← Gherkin step definitions (Given/When/Then)
  ├─ features/
  │   ├─ deck.feature
  │   └─ library.feature
  └─ test_tracks.json   ← Static track metadata (url, title, artist, bpm, etc.)
```

## How to Run Tests (Iterating)

### Single feature, headed (local dev — uses your display)

```bash
src/test/behave/.venv/bin/python \
  src/test/behave/mixxx_test_runner.py \
  --binary build/mixxx-test \
  src/test/behave/features/library.feature
```

### Single feature, offscreen (no display needed)

```bash
# Using --headless flag (preferred — picks a headless display backend automatically)
src/test/behave/.venv/bin/python \
  src/test/behave/mixxx_test_runner.py \
  --binary build/mixxx-test \
  --headless \
  src/test/behave/features/library.feature

# Force a specific backend: --display-backend {auto,xvfb,xwayland}
#   xvfb     -> Xvfb + ffmpeg x11grab recorder
#   xwayland -> cage (Xwayland-capable nested wlroots compositor) + wf-recorder
#   auto     -> xwayland if cage+wf-recorder are installed, else xvfb, else offscreen
src/test/behave/.venv/bin/python \
  src/test/behave/mixxx_test_runner.py \
  --binary build/mixxx-test \
  --headless --display-backend=xwayland \
  src/test/behave/features/library.feature

# Or via QPA env var (equivalent, but no video recording)
QT_QPA_PLATFORM=offscreen src/test/behave/.venv/bin/python \
  src/test/behave/mixxx_test_runner.py \
  --binary build/mixxx-test \
  src/test/behave/features/library.feature
```

### Single feature, named scenario only (fastest iteration)

behave forwards extra args after the feature file. Use `-n` (a.k.a. `--name`) to
run just one scenario:

```bash
src/test/behave/.venv/bin/python \
  src/test/behave/mixxx_test_runner.py \
  --binary build/mixxx-test \
  --headless \
  src/test/behave/features/library.feature \
  -n "Maximize library with toggle"
```

### Custom retry count

By default, each scenario is retried up to 3 times on failure. Override with
`--retry N`:

```bash
src/test/behave/.venv/bin/python \
  src/test/behave/mixxx_test_runner.py \
  --binary build/mixxx-test \
  --headless \
  --retry 5 \
  src/test/behave/features/library.feature
```

### All features via CTest

```bash
# Headed (local dev, uses existing display)
ctest -R mixxx-behave- --output-on-failure

# Headless (CI — uses the xwayland backend via cage+wf-recorder by default)
MIXXX_TEST_HEADLESS=1 MIXXX_TEST_DISPLAY_BACKEND=xwayland ctest -R mixxx-behave- --output-on-failure

# Falling back to Xvfb (only when cage / wf-recorder are unavailable)
MIXXX_TEST_HEADLESS=1 MIXXX_TEST_DISPLAY_BACKEND=xvfb ctest -R mixxx-behave- --output-on-failure

# Custom retry count (default: 3)
MIXXX_BEHAVE_RETRY=5 ctest -R mixxx-behave- --output-on-failure
```

### Tips for iterating

- **Real-time logs**: `MixxxProcess` streams mixxx-test stdout/stderr to the
  terminal in real-time via a daemon thread. All `qDebug()` output from the
  custom command handlers (e.g. `getControlValue`) appears inline.
- **Video recording**: When `--record` is passed (or `MIXXX_TEST_RECORD=1`),
  the active display backend's recorder captures the screen: ffmpeg `x11grab`
  for the `xvfb` backend, `wf-recorder` (libavcodec) for the `xwayland` backend
  (cage). Chapter metadata is embedded into the video from behave's scenario
  lifecycle hooks (ffmpeg is still used for chapter muxing on both backends).
- **Session reuse**: scenarios sharing the same session key (profile directory +
  sound-device signature) reuse the same `mixxx-test` process — only the first
  scenario pays startup cost. `a fresh ... profile` opts out: it force-kills the
  running process and spawns a new genuinely empty (no config, no DB, no tracks)
  or library-ready profile every scenario. Because a reused instance keeps its
  QML state across scenarios (no `reloadQml`), a scenario that assumes the
  default window size or library columns must declare it with
  `the window size is default` / `the library columns are in their default state`
  (see the Given step table).
- After editing QML or `main.cpp`, rebuild:
  `cmake --build build --target mixxx-test -j$(nproc)`
- After editing Python (`steps/`, `environment.py`, `profile.py`, runner), no
  rebuild needed — just re-run the command.
- If spix patches fail to apply during build, delete
  `build/libspix-prefix` and `build/lib/libspix-install`, then reconfigure.

## How Tests Run

1. **CMake** finds `python3` + `behave`, globs `features/*.feature`, registers
   each as `mixxx-behave-<name>`.
2. `mixxx_test_runner.py` sets up a global tracks
   cache at `/tmp/mixxx-test-tracks/` (downloading if needed), optionally
   starts a headless display + recorder (Xvfb+ffmpeg, or cage+wf-recorder for
   the Xwayland backend) for CI, then invokes `behave` with the feature
   file.
3. behave invokes `environment.py` hooks, then matches step definitions in
   `steps/mixxx_steps.py`.
4. **Autoretry**: `before_feature` patches every scenario's `run()` method with
   a custom wrapper. If a scenario fails, it is retried up to `--retry N` times
   (default 3). Each attempt triggers `before_scenario`/`after_scenario` hooks
   normally. Only the final outcome is recorded in `context.results` (with a
   `retries` field summarizing previous attempts). `had_failure` / `fail_early`
   is only set when all retries are exhausted.

## mixxx-test --serve Mode

The `mixxx-test` binary built with `USE_TEST_UI=ON` supports `--serve` flag:

- Parses `--settings-path <dir>` via `CmdlineArgs::Instance()` (singleton — see
  `src/test/mixxxtest.cpp:29`). **Important**: `ApplicationScope` must call
  `CmdlineArgs::Instance().parse()` rather than constructing a local
  `CmdlineArgs`, otherwise `--settings-path` is lost.
- Creates `CoreServices` + `QmlApplication` to load the full Mixxx QML UI.
- Registers a **generic command handler** (see below) and starts an
  **AnyRpcServer** (spix) on **port 9000**.

## Custom spix Command: `getControlValue`

The `--serve` mode registers a custom handler via
`server.setGenericCommandHandler(...)` in `src/test/servemode.cpp`.

| Command           | Payload               | Result                                                                 | How to read result                                        |
|-------------------|-----------------------|------------------------------------------------------------------------|-----------------------------------------------------------|
| `getControlValue` | `"[Group],key"`       | `double` value stored in `mainWindow.lastControlValue` window property | `rpc.getStringProperty("mainWindow", "lastControlValue")` |
| `setControlValue` | `"[Group],key,value"` | Sets a ControlObject value                                             | None                                                      |
| `loadTrack`       | `"deck,filepath"`     | Loads a track file onto the specified deck                             | None                                                      |
| `library`         | JSON (see below)      | Adds/removes library directories, optionally triggers a scan           | None                                                      |
| `reloadQml`       | (empty)               | Tears down and rebuilds the QML engine                                 | None                                                      |

### `library` command

JSON payload:

```json
{
  "action": "addDirectory" | "removeDirectory",
  "path": "/absolute/path/to/directory",
  "scan": true | false
}
```

- `addDirectory`: calls `TrackCollectionManager::addDirectory()`. Silently
  skips if the directory is already watched (`AlreadyWatching`).
- `removeDirectory`: calls `TrackCollectionManager::removeDirectory()`.
- `scan`: when `true`, calls `startLibraryScan()` after the operation.

### `reloadQml` command

No payload needed. Calls `QmlApplication::loadQml(mainFilePath())` to
destroy and recreate the entire QML engine. Use this to reset QML state
between scenarios instead of abusing the auto-reload feature.

### Why two-step?

spix's `command()` RPC method returns `void`. The handler runs on the main
thread, sets the result as a Qt property on the window. A subsequent
`getStringProperty()` call (also processed on the main thread, in order)
reads it back. Since spix processes commands sequentially, this is race-free.

### Python helpers

```python
def _get_control_value(rpc, group, key):
    rpc.command("getControlValue", f"{group},{key}")
    return float(rpc.getStringProperty("mainWindow", "lastControlValue"))

def _set_control_value(rpc, group, key, value):
    rpc.command("setControlValue", f"{group},{key},{value}")
```

### Adding new custom commands

To add a new C++ command, extend the lambda in `src/test/servemode.cpp`:

```cpp
if (command == "myCommand") {
    // parse payload, do work
    // store result: window->setProperty("myResult", value);
}
```

Then read from Python:

```python
rpc.command("myCommand", payload)
result = rpc.getStringProperty("mainWindow", "myResult")
```

## Profile Setup (`profile.py`)

### `create_empty_profile(settings_dir)`

- Creates the `settings_dir` directory (profile folder). Does **not** create a
  database — the `mixxx-test --serve` binary creates the database and applies
  schema migrations on startup.

### Profile types

- `empty`: schema-only database, no tracks (the only type currently implemented)

### `MixxxProcess` class

- `start()`: spawns `mixxx-test --serve --settings-path <dir> --developer
  --log-level warn`
- Stdout streamed via `subprocess.PIPE` + daemon thread writing with
  `sys.stdout.write()` for real-time logging
- Waits up to 60s for port 9000 to be reachable
- `stop()`: terminate with 15s grace, then kill

### Track downloads

- Manifest in `test_tracks.json` — each entry has `url`, `title`, `artist`,
  `tags`, `bpm`, `first_beat`, `samplerate`, and optionally `artwork` (URL to
  cover image)
- Downloaded on first run to `/tmp/mixxx-test-tracks/` (global cache, shared
  across all CTest invocations)

## Spix RPC API (`TestServer.h`)

Available via XML-RPC on `http://localhost:9000/`:

| Method | Signature | Purpose |
| --- | --- | --- |
| `mouseClick` | `(path)` | Left click at item center |
| `mouseClick` | `(path, proportion, offset?)` | Click at relative position |
| `mouseClickWithButton` | `(path, button, modifiers)` | button: 1=Left, 2=Right; modifiers: 0=None, 2=Ctrl |
| `mouseClickWithProportion` | `(path, x, y)` | Click at relative (x, y) position |
| `mouseClickAndHold` | `(path, button, modifiers, holdTime)` | Hold button for `holdTime` ms |
| `mouseBeginDrag` | `(startPath, startX, startY, endPath, endY, endY)` | Begin drag from one item to another |
| `mouseDrag` | `(path, startX, startY, deltaX, deltaY, time)` | Drag by pixel delta over `time` ms |
| `mouseEndDrag` | `(path)` | End drag at item center |
| `mouseDropUrls` | `(path, urls)` | Drag-drop URLs onto item |
| `command` | `(command, payload)` | Custom C++ handler (see `main.cpp`) |
| `enterKey` | `(path, key, modifiers)` | Send a keyboard key press |
| `inputText` | `(path, text)` | Type text into item |
| `getStringProperty` | `(path, propertyName)` | Read QML property as string |
| `setStringProperty` | `(path, propertyName, value)` | Write QML property |
| `invokeMethod` | `(path, method, args)` | Call Q_INVOKABLE method |
| `getBoundingBox` | `(path)` | Returns `[x, y, w, h]` |
| `existsAndVisible` | `(path)` | Check item exists and visible |
| `wait` | `(ms)` | Sleep on main thread |
| `takeScreenshot` | `(path, filePath)` | Capture screenshot |
| `quit` | `()` | Quit application |
| `getErrors` | `()` | Get collected errors |

## Path Resolution

Spix resolves items by their `objectName` in the QML object tree, using `/`
as separator. The path `mainWindow/libraryContent/trackList/columnHeader/Title`
means:

- Find the `ApplicationWindow` with `objectName: "mainWindow"`
- Find its child with `objectName: "libraryContent"` (Loader → Library.qml root)
- Find its descendant with `objectName: "trackList"` (TrackList.qml root
  Rectangle)
- Find child `HorizontalHeaderView` with `objectName: "columnHeader"`
- Find the column delegate whose `objectName == "Title"` (set to `display`
  property of the model)

### ObjectName Map

| QML File | objectName | Notes |
| --- | --- | --- |
| `main.qml` | `"mainWindow"` | Root `ApplicationWindow` |
| `main.qml` | `"splashScreen"` | Splash `Rectangle` (fades, then hides) |
| `MainWindow.qml` | `"library"` | Toolbar "Library" toggle button |
| `MainWindow.qml` | `"libraryContent"` | Loader that shows `Library.qml` |
| `Library/TrackList.qml` | `"trackList"` | Root Rectangle |
| `Library/TrackList.qml` | `"columnHeader"` | `HorizontalHeaderView` |
| `Library/TrackList.qml` | `"columnPickerMenu"` | Column visibility `Menu` |
| `Library/TrackList.qml` | `"trackTableView"` | `TableView` |
| `Library/TrackList.qml` | `<display value>` | Column header delegate: `objectName: display` |
| `Library/Track.qml` | `"trackContextMenu"` | Right-click context `Menu` |
| `Library/Cell.qml` | `"trackRow_" + row` | Row `Rectangle`, dynamic per-row |

### Path Constants (from `mixxx_steps.py`)

```python
BUTTON_PATHS = {
    "LIBRARY": "mainWindow/library",
    "4DECKS": "mainWindow/show4DecksButton",
    "EDIT": "mainWindow/editDeckButton",
}
LIBRARY_CONTENT = "mainWindow/libraryContent"
TRACKLIST_PATH = "mainWindow/libraryContent/trackList"
COLUMN_HEADER_PATH = "mainWindow/libraryContent/trackList/columnHeader"
COLUMN_PICKER_MENU_PATH = "mainWindow/columnPickerMenu"
TRACK_TABLE_PATH = "mainWindow/libraryContent/trackList/trackTableView"
TRACK_ROW_PATH = "mainWindow/libraryContent/trackList/trackTableView"
TRACK_CONTEXT_MENU_PATH = "mainWindow/trackContextMenu"
```

> **Note**: `COLUMN_PICKER_MENU_PATH` and `TRACK_CONTEXT_MENU_PATH` use
> `mainWindow/` (not `trackList/`) because Qt `Menu` popups render in the
> window's `Overlay`, not as children of their parent item.

### Lookup Maps

```python
DECK_PROPERTY_MAP = {
    "BPM": "bpm",
    "tempo rate": "rate",
}

REMEMBERED_CO_KEYS = {
    "beatloop size": "beatloop_size",
    "rate range": "rateRange",
    "playback position": "playposition",
}

TRACK_ACTIONS = {
    "click": _click,
    "double-click": _double_click,
    "right-click": _right_click,
    "long-press": _long_press,
}

LOOP_BUTTONS = {
    ("halve", "beatloop"): "loop_halve",
    ("double", "beatloop"): "loop_double",
}
```

- `DECK_PROPERTY_MAP` translates user-friendly property names to ControlObject
  keys. Used by `the {prop} on deck {deck:d} is set to {value:f}` and
  `deck {deck_a:d} {prop} should be equal to deck {deck_b:d}`.
- `REMEMBERED_CO_KEYS` maps prop names to CO keys for the remember/compare
  pattern (`I remember the "{prop}"` / `the "{prop}" should have changed`).
- `TRACK_ACTIONS` maps action verbs to helper functions for the generic
  `I {action} the track at row {row:d}` step.
- `LOOP_BUTTONS` maps `(direction, component)` tuples to button paths for the
  generic `I {direction} the "{component}" size on deck {deck:d}` step.

## Step DSL (`steps/mixxx_steps.py`)

### Constants

- `QT_LEFT_BUTTON = 1`, `QT_RIGHT_BUTTON = 2`, `QT_CONTROL_MODIFIER = 2`
- `QT_KEY_ENTER`, `QT_KEY_SPACE`, `QT_KEY_DOWN`, `QT_KEY_UP`, `QT_KEY_TAB` — Qt key codes
- `KNOWN_COLUMNS` — list of all possible library column display labels

### Helper Functions

| Helper | Purpose |
| --- | --- |
| `_wait_for_visible(rpc, path, timeout=5)` | Poll `existsAndVisible` until true |
| `_wait_for_hidden(rpc, path, timeout=60)` | Poll `existsAndVisible` until false |
| `_click(rpc, path)` | `rpc.mouseClick(path)` |
| `_right_click(rpc, path)` | `rpc.mouseClickWithButton(path, QT_RIGHT_BUTTON, 0)` |
| `_long_press(rpc, path, button=QT_LEFT_BUTTON, hold_ms=1000)` | `rpc.mouseClickAndHold(path, button, 0, hold_ms)` |
| `_is_visible(rpc, path)` | `existsAndVisible` + bounding box area > 0 |
| `_is_column_visible(rpc, col)` | Resolves the model column index via `trackList.columnLabels` (see `_column_index`) + `columnWidth` via `invokeMethod` |
| `_column_index(rpc, col)` | Parses `trackList.columnLabels` (JSON array of labels in model order) and returns the index, or `-1`. Works for hidden columns whose header delegates do not exist |
| `_get_bb(rpc, path)` | `getBoundingBox` normalized to dict |
| `_get_control_value(rpc, group, key)` | Custom command: reads ControlObject via `command("getControlValue", ...)` + `getStringProperty("mainWindow", "lastControlValue")` |
| `_set_control_value(rpc, group, key, value)` | Custom command: writes ControlObject via `command("setControlValue", ...)` |
| `_load_track(rpc, deck, filepath)` | Custom command: loads track file via `command("loadTrack", ...)` |
| `_library_command(rpc, action, path, scan=False)` | Custom command: adds/removes library directories via `command("library", ...)` with JSON payload |
| `_get_property(rpc, path, prop)` | `rpc.getStringProperty(path, prop)` |
| `_set_property(rpc, path, prop, value)` | `rpc.setStringProperty(path, prop, str(value))` |
| `_ensure_profile(context, type)` | Manages profile lifecycle across scenarios (session reuse) |

### Given Steps

| Pattern | Implementation |
| --- | --- |
| `a new empty profile` | `_ensure_profile(context, "empty")` |
| `a [fresh] new empty profile` | `_ensure_profile(context, "empty", force=..)` — kills the running process and respawns a genuinely empty profile |
| `a [fresh] new library-ready profile` | `_ensure_profile(context, "library-ready", force=..)` — populated with the tracks dir (`addDirectory` runs at open/ready) |
| `Mixxx is open and ready to operate` | Starts Mixxx, waits for mainWindow, waits for splash to hide, caches `_column_idx` and `_default_props` |
| `the 4 decks view is enabled` | Sets `show4DecksButton.checked = true` |
| `a track is loaded on deck {deck:d}` | Picks random track from `MIXXX_TEST_TRACKS_DIR`, calls `loadTrack` C++ command |
| `no track is loaded on deck {deck:d}` | Ejects track via `eject` ControlObject if `track_loaded` is set |
| `the {prop} on deck {deck:d} is set to {value:f}` | `_set_control_value` to set a ControlObject (Given-only, not for When steps) |
| `the sync_on deck {deck:d} is {state}` | `_set_control_value` for `sync_enabled` (Given-only) |
| `the window's width is {width:d}px` | Sets `mainWindow.width` (impersonal Given form of `I resize the window's width to {width:d}px`) |
| `the window's height is {height:d}px` | Sets `mainWindow.height` (impersonal Given form of `I resize the window's height to {height:d}px`) |
| `the window size is default` | Sets `mainWindow.width=1792`, `mainWindow.height=1008`. Declares the default size a scenario relies on when reusing a session (no QML reload between scenarios) |
| `the library columns are in their default state` | `invokeMethod(trackList, "resetColumns")` — restores default column order, visibility and sort (see `Library/TrackList.qml`) |
| `I wait for {second:d} second` | `time.sleep(second)` (also available as @when and @then) |

### When Steps

| Pattern | Implementation |
| --- | --- |
| `I resize the window's width to {width:d}px` | `setStringProperty("mainWindow", "width", value)` |
| `I check on the button "{button}" in the main toolbar` | Asserts button visible via `_is_visible` |
| `I click the "{button}" button` | Looks up in `BUTTON_PATHS`, clicks |
| `I turn off "4 decks" mode` | Clicks `show4DecksButton` |
| `I click the "{button}" button on deck {deck:d}` | `_deck_button_path(deck, button)` + `_click` |
| `I long-press the "{button}" button on deck {deck:d}` | `_deck_button_path(deck, button)` + `_long_press` (or `invokeMethod` for sync) |
| `I {direction} the "{component}" size on deck {deck:d}` | Looks up in `LOOP_BUTTONS` dict, clicks button |
| `I remember the "{prop}" of deck {deck:d}` | Reads CO via `_get_control_value`, stores in `context._remembered` |
| `I seek to {position:f} in deck {deck:d}` | `mouseClickWithProportion` on the overview widget |
| `I set the rate of deck {deck:d} to {value:d}%` | `mouseDrag` on the tempo fader handle |
| `I set hotcue {hotcue:d} on deck {deck:d}` | Clicks on `hotcue_{hotcue}` button path |
| `I clear hotcue {hotcue:d} on deck {deck:d}` | Clicks on same hotcue button to toggle |
| `I click the column header "{column}"` | Clicks header at `COLUMN_HEADER_PATH/{column}` |
| `I drag the column "{column}" before the column "{target}"` | `invokeMethod(trackTableView, "moveColumn", [idx_column, idx_target])` |
| `I open the column picker menu` | Right-clicks on Title column header, waits for menu |
| `I toggle the column "{column}" in the column picker` | Use the keyboard to choose the nth item, based on column index |
| `I {action} the track at row {row:d}` | Looks up in `TRACK_ACTIONS` dict (`click`, `double-click`, `right-click`, `long-press`) |
| `I select {path} on the track menu` | Keyboard-navigates context menu using `enterKey` |
| `I move the "{component}" component in deck {deck:d} after the "{target}" component` | `mouseDrag` from component to target position |
| `I move the selected group in deck {deck:d} after the "{target}" component` | `mouseDrag` from selected group overlay to target position |
| `I select the group containing "{component}" in deck {deck:d} with a {action}` | Long press or ctrl+click for group selection |
| `I wait for {second:d} second` | `time.sleep(second)` |

### Then Steps

| Pattern | Implementation |
| --- | --- |
| `the library is shown for {operator} than {percent:d}% of the Window's height` | Compares `libraryContent` height ratio to `mainWindow` height |
| `only the column "{columns}" are shown` | Splits on `,`/`.`, checks each expected column visible, each unexpected column not visible |
| `the column "{column}" should {state} visible` | `_is_column_visible` check |
| `the column "{column}" should appear before the column "{other}"` | Compares `x` positions of headers |
| `the results should be sorted by "{column}" in "{order}" order` | Reads `sortingColumn`/`sortingOrder` from `columnHeader` |
| `the track at row {row:d} should be selected` | Reads `selected` property from Cell |
| `the track context menu should be visible` | `existsAndVisible` on `trackContextMenu` path |
| `the deck for "{group}" should {assertion} visible` | `_wait_for_visible`/`_wait_for_hidden` on `DECK_PATH_MAP` |
| `the deck {deck:d} should be {playing\|stopped}` | Reads `play` CO via `_get_control_value` |
| `the play button on deck {deck:d} should be {pressed\|released}` | Reads `highlight` property on play button |
| `deck {deck_a:d} {prop} should be equal to deck {deck_b:d}` | Compares CO values between two decks (uses `DECK_PROPERTY_MAP`) |
| `the cue point should be set on deck {deck:d}` | Asserts `cue_point > 0` |
| `hotcue {hotcue:d} should {assertion} set on deck {deck:d}` | Asserts `hotcue_{n}_status` CO |
| `the loop should {assertion} enabled on deck {deck:d}` | Asserts `loop_enabled` CO |
| `the "{prop}" of deck {deck:d} should have changed` | Compares current to saved value in `context._remembered` (uses `REMEMBERED_CO_KEYS`) |
| `sync should be {assertion} on deck {deck:d}` | Asserts `sync_enabled` CO |
| `deck {deck:d} should be the sync leader` | Asserts `sync_leader` CO |
| `the rate of deck {deck:d} should be near {target}` | Reads `rate` CO, asserts `abs(actual - target) < 0.01` |
| `the rate ratio of deck {deck:d} should be near {target}` | Reads `rate_ratio` CO |
| `edit mode should {assertion} enabled` | Reads `editDeckButton.checked` property |
| `the edit overlay should {action} visible on the "{component}" component in deck {deck:d}` | `_is_visible` on `componentItem/overlayItem` path |
| `the "{component}" component should appear after the "{target}" component in deck {deck:d}` | Compares `x` positions of component bounding boxes |
| `the "{group_name}" group should appear after the "{target}" component in deck {deck:d}` | Not yet implemented (`NotImplementedError`) |
| `a track {assertion} loaded on deck {deck:d}` | Reads `track_loaded` CO |
| `I wait for {second:d} second` | `time.sleep(second)` |

## Test Fixtures (`environment.py`)

- `before_all`: initiates `context._session` dict for cross-scenario state
- `before_feature`: patches every scenario with the custom autoretry wrapper
  (max attempts from `--retry`, default 3)
- `before_scenario`: restores `context.mixxx`, `context.mixxx_rpc`,
  `context.profile_dir`, `context.active_profile_type` from session; skips
  if `fail_early` is set and a previous scenario failed all retries
- `after_scenario`: computes outcome, records timing, stores pending result on
  `scenario._pending_result` for the autoretry wrapper to finalize
- `after_all`: writes `chapters.json` to artifacts directory, sends
  `rpc.quit()`, stops Mixxx process, cleans up temp profile dirs

### Autoretry wrapper (`patch_scenario_with_autoretry`)

Based on `behave.contrib.scenario_autoretry.patch_scenario_with_autoretry`.
Wraps `scenario.run()` so that failed scenarios are retried up to N times.
For each attempt: `before_scenario` → steps → `after_scenario` runs normally.
After the last attempt the wrapper:

1. Reads `scenario._pending_result` (set by `after_scenario`) to build the
   final result entry, adding a `retries` field when there were multiple
   attempts.
2. Appends the single result to `context.results`.
3. Sets `had_failure = True` **only** when all retries are exhausted and the
   scenario still failed (excluding `@xfail`/`@xpass`).

## How to Add a New Step

1. **Follow step naming conventions** — Given/Then text must be
   behavior-oriented (what the user sees or expects). When text should favour
   language-oriented actions; implementation-specific details are acceptable
   when no clean alternative exists. See [README.md](README.md#writing-steps)
   for the full guide with examples.
2. Define Gherkin pattern in a `.feature` file
3. Add step implementation function in `steps/mixxx_steps.py` (or a new file
   in `steps/`)
4. Use `@given`, `@when`, or `@then` decorator from `behave`
5. Use helpers: `_rpc()` for spix proxy, `_wait_for_visible` for sync,
   `_get_control_value` for ControlObject reads

### Rules for `Given` steps

- **Always impersonal (state-oriented)** — a `Given` describes a precondition,
  not a user action. Write `the window's width is 1250px`, NOT
  `Given I resize the window's width to 1250px`. First-person action phrasing
  (`I ...`) is reserved for `When` steps.
- **Do not reuse action steps as `Given`** — if an action needs to be a
  precondition (e.g. a window already resized), add a separate impersonal
  `Given` step (`the window's width is {width:d}px`) rather than stacking a
  `@given` decorator onto the `I ...` action step.
- **`And` inherits the preceding keyword** — an `And` line is matched as a
  Given when it follows a `Given` step, so `And I resize the window's width to
  1250px` after a `Given` is a Given step and must use the impersonal form
  (`And the window's width is 1250px`).

### Rules for `When` steps

- **Favour language-oriented action text** — `I drag the volume fader of deck 1
  to 50%` is preferred over `I click on volume fader and drag to 0.05`.
  Implementation-specific text is acceptable when no clean behavior-oriented
  alternative exists (e.g. precise CO values like `I set the rate of deck 1 to
  0.05`).
- **`_set_control_value` is forbidden in `When` steps** — it bypasses the UI
  and does not test real user interaction. Use only in `Given` steps (context
  setup).
- **`_get_control_value` is allowed in `Then` steps** for assertions. It is a
  read-only operation that verifies state.
- **`When` steps must use real UI interactions** — spix `mouseClick`, drag,
  etc. If a step genuinely cannot use a UI interaction (e.g. seeking to an
  exact position on a slider), tag the scenario with `@test/missing-ui-interaction`
  and add a comment annotation explaining why.
- **Custom C++ commands** (e.g. `loadTrack`, `getControlValue`) that bypass
  UI are subject to the same tagging rule as `_set_control_value`.

### Rules for `Then` steps

- **Always behavior-oriented** — step text must describe what the user sees or
  expects, not internal state. `the loop should be enabled on deck 1` is
  correct; `the loop_enabled CO is 1` is not.
- **Never expose control object names** — use domain language (e.g. "the deck
  should be playing") rather than CO keys (e.g. "the play CO should be 1").
- **Implementation reads are fine internally** — `_get_control_value` in the
  step function body is allowed for assertions, but the Gherkin pattern itself
  must not leak it.

## How to Add a New Feature

1. Create `features/<name>.feature` with `Feature:` header and
   `Background:` / `Scenario:` blocks
2. Add objectNames in QML as needed (`objectName: "myElement"`)
3. CMake auto-discovers `*.feature` files — no registration needed

## How to Read a ControlObject from a Test

Use `_get_control_value(rpc, group, key)`:

```python
from steps.mixxx_steps import _get_control_value

@then('the play button should be pressed')
def step_play_pressed(context):
    value = _get_control_value(context.mixxx_rpc, "[Channel1]", "play")
    assert float(value) > 0, f"Play is not pressed (value={value})"
```

Or use `command("getControlValue", "[Group],key")` directly:

```python
context.mixxx_rpc.command("getControlValue", "[Channel1],play")
value = context.mixxx_rpc.getStringProperty("mainWindow", "lastControlValue")
```

## Tagging

- **`@xpass`** — Marks **flaky tests** (intermittent failures due to timing,
  platform quirks, etc.). The runner suppresses captured output for these and
  labels them `FLAKY` in video chapters. Use this when the test logic is
  correct but the environment is unreliable.

- **`@xfail(gh_issue=N)`** — Marks **known bugs**. Always include the
  `gh_issue=` annotation linking to the relevant GitHub issue so failures are
  traceable. The runner labels chapters `EXPECTED FAILURE` or `UNEXPECTED PASS`
  and prints the issue link on failure.

- **Autoretry applies to all scenarios**, including `@xpass` and `@xfail`.
  For `@xfail` scenarios that always fail, the retry attempts are harmless
  (just add time). `had_failure` is never set for `@xfail`/`@xpass` scenarios
  regardless of retry outcome.

## Known Limitations / Blockers

1. **spix mouseClick does not trigger Qt6 TapHandler** — `TapHandler` (used in
   TrackList.qml header delegates and Track.qml) doesn't respond to synthetic
   mouse events from spix. A patch (`spix.patch`) adds `globalPos` to Qt
   mouse events which helps, but the fix remains fragile.
2. **QML Menu popups (Overlay)** — `Menu` components like
   `columnPickerMenu` and `trackContextMenu` render outside the parent item in
   a window-level `Overlay`. spix cannot find them as children of the expected
   parent path. The alternative path `"mainWindow/columnPickerMenu"` works for
   visibility checks but click interaction may fail. Menu must override their
   `contentItem` with a custom `ListView` which explicitly set a `objectName` and
   allow interaction with the Menu's action (see `columnSelectionMenu` and
   `contextMenu` Menu for reference).
3. **spix drag-and-drop doesn't work with TableView column drag** —
   `mouseBeginDrag`/`mouseEndDrag` events don't trigger QML `TableView` column
   reorder mechanics. Current workaround: direct `invokeMethod("moveColumn",
   ...)` call.
4. **Window property `width` set via RPC doesn't trigger QML layout** —
   `setStringProperty("mainWindow", "width", "1200")` doesn't cause Column QML layout
   recalculation. Current workaround: direct `invokeMethod("columnWidth",...)` to detect if the column is now hidden.
5. **spix cannot seek to an exact playposition on a slider** — seeking to a
   precise position (e.g. 0.05) uses `_set_control_value` on the `playposition`
   CO. No spix API can target a fractional position on a `Slider` reliably.
   Tagged `@test/missing-ui-interaction`.
