# Screenshots and App Preview

The media is **not made by hand and is not in git** — the scripts below produce
it. Uploading is manual: in App Store Connect drag the files into the *App
Preview and Screenshots* section (language switch at the top, one locale at a
time).

```bash
Tools/appstore_media.sh                   # screenshots and previews (~17 min)
Tools/appstore_media.sh screenshots       # screenshots only (~11 min)
Tools/appstore_media.sh video             # previews only (~6 min)
Tools/appstore_media.sh screenshots duo   # one device only: iphone, ipad or duo
Tools/appstore_compose.sh                 # the colour, the heading and the device frame (~5 min)
```

Run them from the repository root. `appstore_media.sh` needs Xcode, the *iPhone
18 Pro*, *iPad Pro 13-inch (M5)* and *iPhone Duo* simulators and ImageMagick
(`brew install imagemagick`); `appstore_compose.sh` needs only ImageMagick. The
screenshots start with the iPhone Duo, and **the run waits for you to unfold
it** in DeviceHub, once per language — see [iPhone Duo](#iphone-duo) below. A
run for the iPhone or the iPad alone (`… iphone`, `… ipad`) needs nobody.
Python 3 for the preview's music
bed comes with macOS. `OUT_ROOT=…` (and `IN_ROOT=…` for compose) puts the output
somewhere else, which is how to try a change without touching the set you are
about to upload.

Nothing is replaced until its replacement is whole: the screenshots are shot
into a working folder and swapped in a device at a time, once all ten are
there, and the previews once every one has passed every check below. A run
that stops half-way leaves the last good set where it was. The working folder
is a new one in `$TMPDIR` on every run. A run that succeeds deletes it — the
build and the raw takes, about 300 MB; a run that fails keeps all of it and
says where, and a failed build prints its errors. `WORK=…` names a folder of
your own instead, which is never deleted as a whole; it may not be `OUT_ROOT`
or inside it, because the run clears a `preview/` of its own in it.

The `swift` tools print a page of AVFoundation deprecation warnings every run.
They are expected — the replacements landed in macOS 26 and the old API still
does exactly this job — and the line that matters is the last one, which reports
what the finished file actually holds.

## What the scripts produce

| What | Where | Resolution | Count |
|---|---|---|---|
| iPhone 6.3" screenshots | `screenshots/<locale>/iphone-6.3/` | 1206 × 2622 | 10 |
| iPhone Duo screenshots | `screenshots/<locale>/iphone-duo/` | 2007 × 2853 | 10 |
| iPad 13" screenshots | `screenshots/<locale>/ipad-13/` | 2064 × 2752 | 10 |
| The same, composed for the store | `screenshots-composed/<locale>/<device>/` | same | 10 + 10 + 10 |
| iPhone 6.3" App Preview | `preview/<locale>/iphone-6.3.mp4` | 886 × 1920, a constant 30 fps, AAC | 1 |
| iPhone Duo App Preview | `preview/<locale>/iphone-duo.mp4` | the same file as the 6.3" one | 1 |
| iPad 13" App Preview | `preview/<locale>/ipad-13.mp4` | 1200 × 1600, a constant 30 fps, AAC | 1 |

**One slot in App Store Connect, one folder and one preview file**, named after
it: `iphone-6.3` goes into *iPhone 6.1" or 6.3" displays*, `iphone-duo` into
*iPhone Duo*, `ipad-13` into *iPad 13" display*.

**Upload the composed set, not the plain one** — same file names, same order,
they differ only in the wrapper. The plain set is what the app actually looks
like and is worth keeping to diff against; the composed set is what a listing
needs, and it is where "no ads, no account, works offline" gets said out loud.

Every simulator shoots its slot size natively, so no screenshot is scaled or
cropped — `simctl io screenshot` writes the slot size straight out, and the
script fails rather than continuing if it does not.

**iPhone 6.3" is the slot this listing uses**: *iPhone with Dynamic Island
(medium display)*, for 6.1" and 6.3" displays. It is the one iPhone slot
Connect requires ("Required device sizes" in Apple's screenshot specifications,
November 2026), and it takes 1179 × 2556 or 1206 × 2622. The *iPhone 18 Pro*
simulator shoots 1206 × 2622 natively; Xcode makes one by default, and the
script creates one if it has gone. Until November 2026 the listing used the
6.5" slot (*iPhone with Face ID (large display)*, shot on an iPhone 11 Pro
Max); that set is gone. If the 6.9" slot is ever wanted as well, shoot *iPhone
18 Pro Max* at its own size; `shoot` already takes the device and its expected
size as arguments.

**The iPad set is not optional.** The app is universal, and a universal build
with no iPad screenshots is rejected.

**The iPhone Duo has a slot of its own**, and a set of its own: the inner
display, upright. See [iPhone Duo](#iphone-duo) below.

The iPhone App Preview has no per-size split: the one 886 × 1920 file is what
Apple lists for the 6.9", 6.5", 6.3" and 6.1" displays and for the iPhone Duo
alike. **So the Duo's preview is the iPhone's take**, copied to
`iphone-duo.mp4` so its slot has a file of its own. Apple's app preview
specifications (checked in the page source, November 2026) list 886 × 1920
portrait and 1920 × 886 landscape as the only sizes the Duo takes. Neither of
the Duo's displays has that shape: its inner display is about 0.7 wide to 1
tall. A take from the Duo itself could only go up with bars round it or with
the board cut off. Neither preview size is a device resolution —
886 × 1920 and 1200 × 1600 are the only two Connect takes for these devices,
and a preview at the device's own size comes out as H.264 Level 5.0 and is
refused.

The locales are `cs` and `en-US`, everything in portrait.

Each locale is shot in a simulator switched to that language, not just in an app
launched in it: the status bar belongs to the system, and on the iPad it carries
the date, which a Czech simulator prints in Czech over the English set.
Switching takes a reboot per device and locale, and when the script ends it puts
each simulator back as it found it: its languages, running or shut down, and a
Sudoku that was installed on it before, with its games and settings — copied
aside before the first clean install and put back at the end. "Not installed"
is taken only from the simulator's own list of installed apps, never from a
lookup that failed, and a simulator that does not finish booting stops the run.
Only a whole copy counts: if copying fails or is interrupted, the run stops
before the clean install and leaves that Sudoku exactly as it was. The copy
goes to `~/Library/Application Support/sudoku-appstore/`, not to the working
folder in `$TMPDIR`, which macOS clears out; its path is printed before the
simulators are put back, and the script never deletes it — remove it yourself
once the app is back. While the simulators are being put back, Ctrl-C and the
like are ignored, so a second one cannot leave a simulator with neither app.
The languages and the region are put back each on its own, and either one the
simulator did not have before is removed again. A simulator that
had never been booted (or one the script just created) has no language of its
own to go back to, so it stays in the last one shot, en-US. The Debug build
itself is uninstalled, so nobody opens the simulator later to find six weeks of
made-up games in it. The one thing not restored is a status bar override of
your own: the script clears the status bar.

The status bar reads 9:41, full Wi-Fi and signal, and a battery that is
`discharging` at 100 % rather than `charged`: charged is the plugged-in glyph,
a green cell with a bolt through it, which reads as a phone on charge rather
than as a phone. The date on the iPad's status bar is the real one. The Czech
set reads 09:41: the system formats the overridden time for the device's
language, and a Czech iPhone writes the hour with a leading zero.

## iPhone Duo

**The set goes into the *iPhone Duo* slot**, the composed files from
`screenshots-composed/<locale>/iphone-duo/`. It is optional until April 2027.
After that, every app built with the iOS 27.1 SDK or later needs it, and this
one is. A listing that has it also gets a *Made for iPhone Duo* badge on its
product page (Apple's screenshot specifications, November 2026).

**Why the inner display upright.** The slot takes either display, either way
round: the outer one at 1398 × 2034, the inner one at 2007 × 2853. The inner
display is the one the device is bought for, and upright it fits every pose
whole, which the others do not:

- On the outer display the hint's explanation is cut short mid-sentence.
- With the inner display on its side, the statistics chart, the calendar and
  the bottom of the home screen run off the bottom edge. The New Game sheet sits
  pinned to the left half, over a cut-off home screen.

Those three were shot and compared in November 2026; the outer display on its
side was not. The app needed no changes for the Duo. It lays itself out from the
space it has, never from the device, which is what Apple's checklist for the Duo
asks for.

**The run needs you once per language.** The Duo boots folded, on its outer
display, and nothing on the command line unfolds it:

- simctl has no hinge.
- Switching its displays' power off and on only blanks them, and once it took
  SpringBoard down too.

Unfolding is a click in DeviceHub. So the script asks (`→ Unfold the iPhone Duo
in DeviceHub and turn it upright`), watches the inner display until it is lit
and upright, and goes on by itself. Every language switch is a reboot, and a
reboot folds it again, so it asks twice. That is why the Duo is shot first, in
both languages: the asking is over in the first few minutes, and the rest of the
run needs nobody. A folded inner display still comes out at full size, pure
black, so a black frame stops the run rather than going into the set.

**The simulator.** The Duo runs only on a simulator runtime of its own
(`iOS-27-2-iPhone19-4`), which runs no other iPhone. Xcode 27.1 and later make
an *iPhone Duo* simulator by default. If it is gone, the script creates one and
lets simctl pick that runtime. simctl calls the outer display `primary` and the
inner one `primary-1`.

**The frame.** Its corners are measured off the simulator's own screen mask
(`simctl io screenshot --mask=alpha`), and there is no notch to paint: the
mask has no cut-out.

## How the poses work

Nothing here is mocked up. Every shot is the app reaching a screen through its
own code, driven by the `#if DEBUG` launch arguments in
[`DebugScenarios.swift`](../sudoku/Support/DebugScenarios.swift) — `-debugScenario`
picks the screen, `-debugDifficulty` the level — plus two small hooks for screens
the model cannot open on its own: the difficulty picker in
[`HomeView.swift`](../sudoku/Views/Home/HomeView.swift) and a typed-in puzzle in
[`CustomPuzzleView.swift`](../sudoku/Views/Screens/CustomPuzzleView.swift)
(`-debugCustomPuzzle`). None of it reaches an App Store build. Settings are set
per launch through the UserDefaults argument domain (`-appearance dark -theme
orange -digitStyle rounded`), so a pose never changes what the next one sees.

That is a deliberate trade. A mocked-up board would be quicker to write and
would quietly drift away from the game as the game changed; a board reached by
real moves either still plays or stops rendering. The XY-Wing on the first shot
is the hint engine's own, found by playing a real Expert puzzle by hints until
the engine needed an Expert technique, and the explanation under it is the
app's own text.

Three arguments make the set repeatable and believable:

- **`-debugSeed`** makes every new game the same puzzle on every run (and the
  next seed for each further game, which the hint pose needs). Without it each
  run would photograph a different board, and the first shot's XY-Wing would be
  whatever technique the next random puzzle happened to need.
- **`-debugHistory`** replaces the game data, before the model loads it, with
  six weeks of plausible play: 52 games across all five levels, 20 daily
  challenges ending in a 12-day streak, and the 16 achievements those games
  earned, each unlocked on the day it was earned. It is seeded, so every launch
  writes the same history, and because it replaces rather than adds, the order
  of the poses does not matter: the win in `09-win` cannot leak into the
  statistics of the next shot. On a clean install the statistics, the calendar
  and the achievements are empty pages, which is a true screen and the least
  useful one each of them has.
- **`-debugElapsed`** puts a believable time on the clock. A pose takes two
  seconds to set up; a Hard game showing 0:02 would read as a fake.

Every pose drops a marker file when it is set up (`Documents/shot-ready`), and the
script waits for the file rather than for a guessed number of seconds: a new
game has to be generated first, and the hint pose plays a whole puzzle by hints
before it gets to its XY-Wing — a few seconds in a Debug build, longer on a
slower Mac. What follows the marker is a short fixed settle per shot, for the
push animation, the sheet, the chart drawing in, or the win card's entrance.

The history moves with the calendar: it is written relative to the day the
script runs. The daily-challenge shot therefore looks fullest late in a month —
early in one, most of the 12-day streak sits on the previous month's page.

## The ten shots, in order

The order matters more than the count: search results show the first three, and
most people never scroll past them — so those three carry the three reasons to
pick this sudoku over the others: hints that explain, nothing in the way, and a
reason to come back tomorrow.

| # | Shot | Caption (EN / CS) | What it shows |
|---|---|---|---|
| 1 | `01-hint` | Hints that teach, not just tell / Nápovědy, které učí, ne jen radí | The hero. An Expert puzzle with an XY-Wing on the board: the pivot and both wings highlighted, the candidates coloured, the chain drawn, and the explanation in plain words. The one thing no free competitor has. |
| 2 | `02-play` | No ads. No account. Works offline. / Bez reklam. Bez účtu. Funguje offline. | A Hard game well under way — numbers placed all over the board, pencil marks in some cells, a cell selected with its row, column and box lit. And nothing else on the screen, which is the point of the caption. |
| 3 | `03-daily` | A new puzzle every day / Každý den nové sudoku | The daily challenge: today's puzzle, a 12-day streak and the month's calendar filled with solved days. |
| 4 | `04-levels` | Five levels, graded by real technique / Pět úrovní podle skutečných technik | The New Game sheet: five levels with what each one needs ("Advanced patterns like the X-Wing") and a best time on each. |
| 5 | `05-stats` | Watch yourself get faster / Sledujte, jak se zrychlujete | Statistics: games, win rate, best and average time, streaks and the solve-time chart. |
| 6 | `06-custom` | Type in any puzzle from a newspaper / Přepište si sudoku z novin nebo knihy | A Hard puzzle typed in and checked: "Valid puzzle · Hard — Exactly one solution". The puzzle is the app's own (generator seed 42), so it is nobody else's puzzle and no day's daily challenge. |
| 7 | `07-dark` | Dark mode, 8 colors and 4 number fonts / Tmavý režim, 8 barev a 4 písma | The same kind of game in dark mode, with the orange theme and the rounded number font — the one shot whose palette is not the default. |
| 8 | `08-achievements` | 22 achievements to unlock / 22 úspěchů k odemčení | The achievements: 16 of 22 unlocked, with dates, and progress bars on the ones still to go. |
| 9 | `09-win` | Beat your best time / Překonejte svůj nejlepší čas | A Hard game just won: "New Record!", the time against the old best, no mistakes, no hints, an achievement unlocked, and the confetti still falling. |
| 10 | `10-home` | Pure logic, beautifully simple / Čistá logika, krásně jednoduše | The home screen, with the app's own tagline: New Game, the daily challenge with its streak, and the four tiles. |

Poses that exist and are not in the set: `-debugScenario settings` (the full
settings sheet), `help` (How to Play, with the rules and every technique),
`hint` and `hintDetail` (a hint on an easier technique), `paused`, `lost`, and
`advancedHint` with other seeds and levels — Skyscrapers, X-Wings, W-Wings and
2-String Kites, all with their lines drawn. On the
iPad the home screen, the New Game sheet and the daily challenge sit in the
middle of a lot of space — the app's own layout at that size — which is why the
board shots lead the set there too.

## Composition

`Tools/appstore_compose.sh` builds the shot that actually goes up: a flat
saturated colour, a heading in white across the top, and the screenshot in a
device frame below it running off the bottom edge. The layout and every
proportion in it are J-Notes' (measured off that app's shots on the store), so
the developer's listings read as one family; the colours are this app's own
eight theme colours, all of them, one per shot in upload order. Ten shots and
eight colours, so blue and orange come round twice — `10-home` is blue like
`01-hint`, `09-win` orange like `03-daily` — and no two neighbours share one,
so the row of thumbnails reads as a set; the first three — blue, indigo,
orange — are the three most unlike.

Four things in there are less obvious than they look:

- **The device runs off the bottom by its whole corner radius.** Its rounded
  bottom corners have to fall outside the picture. Until November 2026 the body
  went past the edge by only a bezel, so on every set the corners came up into
  the shot, and the bezel tapered away to nothing at the bottom edge while the
  screen ran on straight.
- **The iPhone's Dynamic Island is painted on.** Neither the simulator's
  screenshots nor its screen mask has one; the status bar simply leaves a gap
  where the hardware would be. Without painting it the shot reads as a phone
  that does not exist. Its size is measured off the simulator's own screen
  recording, which does draw it: on the iPhone 18 Pro about 95 × 37 points,
  13 points below the top edge — narrower than the 126 points of the Pro
  iPhones before it. The corners of every frame are measured off the
  simulator's screen mask (`simctl io screenshot --mask=alpha`).
- **The heading is SF Pro Rounded, thickened with a stroke of its own colour.**
  ImageMagick instantiates a variable font at its default weight, so the face
  comes out Regular however it is asked for, and the alternative with a real bold
  — Arial Rounded Bold — has neither `ť` nor `ě` and drops them silently. Four per
  cent of the point size in stroke is about a Bold.
- **The heading shrinks itself to fit.** Measured, not guessed, and it is the
  Czech set that needs it: the captions are broken by hand, and a size chosen to
  suit English runs a long Czech line off both edges.

The captions live in `en_caption` and `cs_caption` in that script, two lines
each, and the per-shot colours in `colour_for` beside them.

## App Preview

**One continuous take of a game being played**, 18.8 seconds on each device
and in each language: an Easy puzzle half filled in, the rest played single by
single at a person's pace, a hint taken on the way — first its nudge ("Look at
box 1…"), then Show Me with the cell highlighted, then Apply — and the win: the
wave across the board, the confetti and the result card. The game is
`-debugScenario demo` ([`DebugScenarios.playDemo`](../sudoku/Support/DebugScenarios.swift)).

Easy, because every one of its moves is a single a viewer can follow at a
glance, and its hint is a sentence anyone understands. The player plays like a
person: the last cell of a row, column or box first, otherwise the single
nearest the last move, never a guess. It takes its hint at the first moment
after a few moves when no house is down to its last cell — a Full House hint
explains nothing — so the hint the preview shows is a real deduction (on seed 3,
a Hidden Single in box 1).

A preview plays in search results in place of the first screenshot, muted, so
the take is built to read without sound: the hint panel is on screen for five
seconds, long enough to read both stages.

How the timing works, because most of it does not fail loudly when it drifts:

- **The take is measured from the ready marker.** The app drops it the moment
  the half-filled board is up, and plays its first move `-debugDemoLead` (1.5)
  seconds later; the script starts recording as soon as it sees the marker. The
  seed is fixed, so the game is the same on every run, and so is its timeline
  as long as the simulator keeps up; how quickly the recorder comes up moves it
  by a fraction of a second.
- **A take can stall.** One en-US iPhone take stood still for 2.2 s at 14.4 s
  while the game went on behind it: everything after came late, the preview
  ran out before the result card, and every step reported success. So
  `assemble` first runs
  [`Tools/appstore_gaps.swift`](../Tools/appstore_gaps.swift) over the take,
  and the run stops, naming the clip and the stall, if anything inside the cut
  stands still for longer than 1.5 s. Nothing in the demo does by design: a
  number goes in every 0.4 s, the clock ticks every second while the hint is
  read, and the longest still moment in the four good takes measured was
  1.3 s, the pause before the result card. The fix is another take
  (`Tools/appstore_media.sh video`); `swift Tools/appstore_gaps.swift
  <clip.mp4>:1.0:19.8` checks one by hand.
- **The cut is 1.0 to 19.8 s into the recording.** The first move lands at about
  1.5 s, the hint is up from about 6 to 11 s, the last number goes in at about
  15.5 s and the result card stands from about 16.5 s, with the confetti
  falling over it.
- **A take can end before the cut does.** `simctl io recordVideo` writes a
  frame only when the screen changes, so a recording ends at its last change —
  the confetti settling, which varies from run to run (19.5 to 20.6 s so far).
  A cut past that used to be silently clamped: a cut ending at 20.2 once came
  out as four previews of four different lengths, and the 19.8 end later left
  the Czech iPhone preview at 18.5 s. `appstore_video.swift` now holds the
  take's last frame — the result card, by then standing still — for whatever
  the take lacks, and `assemble` fails if a finished preview is not as long as
  its cut. The gap check counts that held frame too: held for longer than
  1.5 s, it is a take that stopped rather than one that settled. Past about
  21 s a recording's tail is not reliably decodable (learned on the chess
  project), so the cut stays at 19.8.
- **Frames went missing at both ends, too.** An H.264 cut hid its first two
  frames behind an edit list, and the encode in `appstore_conform.swift` ended
  the track at the last frame its reader handed over, two short of the end:
  0.07 s per preview, sometimes. The cut is now ProRes, encoded to H.264 once
  by conform, which closes the track at the cut's own end.
- **And the last frame came out long.** A video composition renders a frame
  only where its source has one, so when the take's last change inside the cut
  comes a few frames before the cut's end, the picture stops those few frames
  short, and its last frame is stretched over the rest rather than repeated.
  One en-US iPhone preview went up as 559 frames of 1/30 s and one of 1/6 s:
  18.8 s long, and not 30 fps. Conform now puts every
  frame on an exact 30 fps grid, repeating the one before wherever the source
  has none, and fails the run unless the written file holds exactly that —
  564 frames of 1/30 s for the 18.8 s cut.

Check it after any change to the pacing, the demo or the animations:

```bash
swift Tools/appstore_frames.swift AppStore/preview/en-US/iphone-6.3.mp4 \
    /tmp/frames 0.05 1.5 5.5 7.5 10 13 16 17.5 18.7
magick /tmp/frames/*.png -resize 260x +append /tmp/sheet.png
```

Those are the board before the first move, the first moves, the hint's nudge,
Show Me, the board filling up again, the last numbers, the wave, and the result
card under the confetti. A frame that repeats the one before it is a window
that has drifted past the action. Frames come out of the *finished* preview, not
the raw recording: the raw file is variable frame rate, and an exact seek into a
stretch where nothing changed comes back with whatever frame it could find.

What the last run produced:

```
886×1920   18.80s  564 frames at 30 fps  H.264 High 4.0 11.5 Mbit/s  AAC 48 kHz stereo 254 kbit/s  26.3 MB  (music: bed.wav)
1200×1600  18.80s  564 frames at 30 fps  H.264 High 4.0 11.5 Mbit/s  AAC 48 kHz stereo 254 kbit/s  26.3 MB  (music: bed.wav)
```

**The music is synthesised, because it has to be.** App Store Connect *requires*
stereo AAC at 256 kbps on a preview, and silence does not satisfy it: AAC
compresses digital silence to about 2 kbps and Connect reports a file with no
usable audio as an unsupported audio configuration. The app ships no audio
files — its sounds are built at launch — so
[`Tools/gen_preview_music.py`](../Tools/gen_preview_music.py) writes the bed:
I-V-vi-IV in D major at 60 BPM, felt-piano notes over a held open fifth, no
percussion — the chess project's instrument in a calmer key.
`PREVIEW_GAIN=…` changes how loud it sits, `PREVIEW_MUSIC=path.wav` replaces it
with something else. The last line `appstore_conform.swift` prints is what the
finished file holds — check that the audio says about 255 kbit/s, because a
preview without usable audio is otherwise only reported a whole upload later.
