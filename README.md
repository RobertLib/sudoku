# Sudoku

A polished, fully offline Sudoku game for iPhone and iPad, written in Swift and SwiftUI.
The UI is in English with a complete Czech localization; the language follows the device
settings (Czech on Czech devices, English everywhere else) and, on a device with more than one
preferred language, can be changed per app in the iOS Settings app.

## Features

- **Endless puzzles in five difficulties** – Easy, Medium, Hard, Expert and Master, generated on
  the device. Every puzzle has exactly one solution and a symmetric layout. Difficulty is graded
  by the techniques a human needs to solve it, not just by the number of clues: every puzzle needs
  at least one technique of its own level (Medium, for example, always needs locked candidates).
- **Hints that teach** – a hint first nudges you towards the right area; "Show Me" explains the
  exact deduction with highlighted cells, colored candidates and chain lines. 24 techniques are
  supported, from Hidden Singles to X-Wings, Swordfish, coloring, Unique Rectangles and XY-Chains.
  Hints also point out wrong numbers and notes that no longer contain the correct digit.
- **Daily challenge** – one deterministic puzzle per day (the same on every device), difficulty
  rising through the week, a calendar archive of the last two years and streak tracking. Only
  challenges played on their own day count towards a streak; the archive is for catching up.
- **Notes** – pencil marks, automatic notes, automatic removal of notes when a digit is placed,
  and unlimited undo/redo.
- **Two input modes** – cell first or number first.
- **Mistake checking** – instant (with an optional 3-mistake limit and one "second chance"),
  rule conflicts only, or off. Wrong numbers count as mistakes in every mode, so a perfect game
  means the same everywhere; only instant checking reveals them right away. The limit only counts
  mistakes made while it was on, so switching modes mid-game never ends a game retroactively.
  A game over waits for the second chance even if the app is closed on it.
- **Custom puzzles** – type or paste a puzzle from a newspaper (81 characters, or a text grid with
  `---+---` lines as printed by many sites); it is checked for a unique solution and graded before
  you play it.
- **Statistics** – per-difficulty games, win rate, best/average times, perfect games, streaks,
  a solve-time chart and recent games. Best and average times and the chart only count games solved
  without hints, and custom puzzles count towards neither these times nor streaks. Hints stay with
  their puzzle: a restart keeps them, and a daily challenge played again starts with those of its
  earlier attempts, where showing the solution counts as a hint for every cell it filled.
- **22 achievements** with progress tracking. Custom puzzles only count towards their own
  achievement, since one can have almost every clue given, and speed achievements need a game
  without hints.
- **Themes** – 8 accent colors, light/dark/system appearance, 4 number fonts.
- **Feel** – synthesized sound effects (no audio files), haptics, completion waves and confetti.
- **iPad & keyboard** – adaptive portrait/landscape layouts and hardware keyboard shortcuts
  (arrows, 1–9, ⌫/0, N/Space, H, Esc, ⌘Z/U, ⇧⌘Z, ⌘P). On Czech and Slovak keyboards the number
  row enters digits without Shift. Return and Esc answer the pause, win and game over cards. A keyboard
  connected mid-game works straight away. The app uses a single window, because all navigation
  and the running game live in one shared model; it shows a pointer highlight on iPad.
- **Accessibility** – VoiceOver labels for every cell and control. VoiceOver reads a hint, a
  Check Board result, a wrong number under instant checking, a custom puzzle's check and the
  pause, win and game over cards as they appear, and keeps to those cards while they are up. A
  hint names the cells it highlights, and VoiceOver reads a cell as highlighted, with the
  candidates the hint works with and what to place or remove there; it also says what applying a
  hint, revealing a cell or the note tools changed. Times are read as durations.
  A wrong number sits in a tinted cell, and with Differentiate Without Color it is underlined too.
  Text on colored buttons and fills (notes and candidates on highlighted cells too), and the
  difficulty colors used as text, reach a contrast of 4.5:1 in light and dark mode, in every theme.
  Reduce Motion support and Dynamic Type: the other screens rearrange their tiles and cards for
  large text, while around the board, which doesn't grow with text size (the game and the custom
  puzzle screen), text stops at the first accessibility size; a long press on a tool button shows
  its label larger.
- **Private** – no network access, no accounts, no tracking. Games and statistics are stored as
  JSON in Application Support; pre-generated puzzles in Caches, which isn't backed up.

## Project layout

```
sudoku/
  Engine/        Pure Swift puzzle engine (no UI): grid geometry, backtracking solver,
                 generator, logical solver with all techniques, seeded RNG
  Model/         Game state, game session controller, settings, statistics,
                 achievements, daily challenges, persistence, puzzle cache
  Views/         SwiftUI screens (Home, Game, Daily, Statistics, Achievements,
                 Settings, Help, Custom puzzle, Welcome) and components
  Support/       Theme, sound & haptics, localized texts for model types, hint texts,
                 hardware keyboard input (game and custom puzzle), Debug-only launch
                 arguments for screenshots, the App Preview and manual testing
  Info.plist     Only the scene manifest (single window); everything else is generated
  Localizable.xcstrings   English source strings + Czech translations
sudokuTests/              Unit tests for the app logic (game session, statistics, persistence)
Tests/SudokuEngineTests/  Unit tests for the engine
Package.swift             Builds sudoku/Engine as a module for `swift test`
AppStore/                 App Store Connect texts (cs, en-US), privacy policy,
                          review notes and the reasoning behind them
Tools/                    Scripts that shoot the App Store screenshots and the App Preview
```

The app and test targets use Xcode's synchronized folders, so new files under `sudoku/` and
`sudokuTests/` are picked up automatically. The project builds in the Swift 6 language mode.

## Building and testing

- Open `sudoku.xcodeproj` in Xcode 27 and run the `sudoku` scheme (iOS 27+).
- Run the engine tests from the repository root:

  ```sh
  swift test            # debug
  swift test -c release # faster; also prints generation timings and technique usage
  ```

  The tests check, among other things, that every deduction of the logical solver agrees with
  the known solution across hundreds of random puzzles, that generated puzzles are unique and
  need a technique of their difficulty, and that generation is deterministic for a given seed.
- Run the app tests (⌘U in Xcode, or from the command line):

  ```sh
  xcodebuild test -project sudoku.xcodeproj -scheme sudoku \
    -destination 'platform=iOS Simulator,name=iPhone 17e'
  ```

  They cover hints, mistakes and the second chance, undo/redo, achievements, daily streaks,
  recording finished games exactly once and persistence (each unfinished game is its own file in
  `Games/`). They also pin a few daily puzzles: if an engine change alters them, every player
  would get different daily puzzles, so update the pinned strings only on purpose.

### Debug launch arguments

Debug builds accept launch arguments that jump straight to a screen, handy for screenshots:

```
-debugScenario game|notes|progress|hint|hintDetail|win|lost|paused
-debugScenario home|difficulty|daily|stats|achievements|help|custom|settings
-debugScenario advancedHint   # plays by hints until one needs an Expert/Master technique
-debugScenario demo           # plays a game like a person, takes a hint, wins (App Preview)
-debugScenario autoplay       # solves a puzzle using only Hint → Apply; prints AUTOPLAY lines
-debugScenario dailyPrint     # prints the last three daily puzzles and their generation times
-debugDifficulty easy|medium|hard|expert|master
-debugSeed 6                  # new games are generated from this seed (then 7, 8, …)
-debugHistory 1               # replaces all game data with six weeks of seeded play
-debugElapsed 754             # adds seconds to the clock of the scenario's game
-debugCustomPuzzle <81 cells> # the custom puzzle screen opens with this puzzle typed in
-debugDemoPace 0.4            # seconds per move in `demo`; -debugDemoLead 1.5 before the first
-debugAllDifficulties 1       # autoplay every difficulty in turn
-debugLandscape 1
-AppleLanguages "(cs)"    # force Czech
```

Every scenario drops `Documents/shot-ready` in the app's data container once it is set up, so a
script can wait for the screen instead of guessing. `autoplay` and the other game scenarios create
games and statistics in the app's data, and `-debugHistory` replaces them outright, so use a
simulator you don't mind resetting.

## App Store

Everything for the listing is in [AppStore/](AppStore/README.md): the texts to paste into App Store
Connect, the privacy policy, the notes for App Review, the competitive research and the reasoning
behind every word. Screenshots and the App Preview are generated, not drawn:

```sh
Tools/appstore_media.sh      # shoots the screenshots and records the preview in the simulators
Tools/appstore_compose.sh    # adds the captions and the device frame
```

See [AppStore/screenshots.md](AppStore/screenshots.md) for what they produce and how.

## Support

Questions, bug reports and ideas are welcome — open an issue on this repository or write to
**libsansky@iquest.cz**.

## Localization

All user-facing strings are English keys in `Localizable.xcstrings`; Czech translations include
proper plural forms (one/few/many/other). Hint explanations are written as separate sentences
for rows, columns and boxes so the Czech grammar (cases) is always correct.
