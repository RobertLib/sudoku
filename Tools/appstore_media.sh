#!/bin/bash
#
# appstore_media.sh — regenerates every App Store screenshot and App Preview in AppStore/.
#
#     Tools/appstore_media.sh                    # screenshots + preview, every device
#     Tools/appstore_media.sh screenshots        # screenshots only
#     Tools/appstore_media.sh video              # App Preview only
#     Tools/appstore_media.sh screenshots duo    # one device only: iphone, ipad or duo
#
# Needs Xcode, the simulators named below and ImageMagick (`brew install
# imagemagick`). Every pose is driven by the `#if DEBUG` launch arguments in
# sudoku/Support/DebugScenarios.swift (plus two small hooks in HomeView and
# CustomPuzzleView), so this builds Debug, and none of it exists in the build
# that goes to the App Store.
#
# The iPhone Duo needs a hand: nothing on the command line unfolds it, so the
# screenshots start with it, and the run waits until you unfold it in DeviceHub
# (see wait_unfolded). Everything after that runs on its own, and a run for the
# iPhone or the iPad alone needs nobody.
#
# Output goes to AppStore/screenshots/<locale>/<device>/ and
# AppStore/preview/<locale>/<device>.mp4, where <device> is iphone-6.3,
# iphone-duo or ipad-13 — one folder and one file per slot in App Store Connect.
# Override the root with OUT_ROOT=… to try things out without touching the set
# you are about to upload. Tools/appstore_compose.sh then turns these plain
# shots into the captioned ones that are uploaded.
#
set -euo pipefail

MODE="${1:-all}"
ONLY="${2:-}"
# A typo would otherwise build, shoot nothing and still reset the simulators.
usage() { echo "usage: $0 [all|screenshots|video] [iphone|ipad|duo]" >&2; exit 2; }
case "$MODE" in all | screenshots | video) ;; *) usage ;; esac
case "$ONLY" in "" | iphone | ipad | duo) ;; *) usage ;; esac
if [ "$MODE" = video ] && [ "$ONLY" = duo ]; then
    echo "the iPhone Duo has no take of its own: its preview is the iPhone's (see IPHONE_VIDEO_SIZE)" >&2
    exit 2
fi
wants() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; } # wants <iphone|ipad|duo>: does this run shoot it?
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_ROOT="${OUT_ROOT:-$ROOT/AppStore}"
# The build, the takes and the media on their way. A new folder in $TMPDIR on
# every run, which a run that succeeds deletes again (see on_exit); WORK=… names
# one of your own instead, and that one is never deleted as a whole. The run
# does clear folders of its own inside it, though — preview/ among them — and
# OUT_ROOT has a preview/ too, the last good set. So a WORK at or inside
# OUT_ROOT is refused rather than left to delete it.
if [ -n "${WORK:-}" ]; then
    OWN_WORK=no
    # Compared as real paths, so neither a relative WORK nor a symlink slips past.
    work_existed=no
    if [ -d "$WORK" ]; then work_existed=yes; fi
    mkdir -p "$WORK" "$OUT_ROOT"
    WORK="$(cd "$WORK" && pwd -P)"
    OUT_REAL="$(cd "$OUT_ROOT" && pwd -P)"
    case "$WORK/" in
        "$OUT_REAL"/*)
            echo "WORK=$WORK is inside OUT_ROOT ($OUT_REAL); give it a folder of its own" >&2
            if [ "$work_existed" = no ]; then rmdir "$WORK" 2>/dev/null || true; fi
            exit 2 ;;
    esac
else
    WORK="$(mktemp -d -t sudoku-appstore)"
    OWN_WORK=yes
fi
FINISHED=no
BID=cz.rob.sudoku

# Every device shoots its App Store slot size natively, so nothing is scaled
# or cropped:
#   iPhone 18 Pro     → 1206 × 2622, one of the two sizes Connect takes for 6.3"
#   iPad Pro 13" (M5) → 2064 × 2752, one of the two it takes for iPad 13"
#   iPhone Duo        → 2007 × 2853, one of the four it takes for iPhone Duo
#
# 6.3" is the iPhone slot this listing uses: "iPhone with Dynamic Island (medium
# display)", for 6.1" and 6.3" displays, and the one iPhone slot Connect
# requires. Until November 2026 the listing used the 6.5" slot (iPhone 11 Pro
# Max); that set is gone. If the 6.9" slot is ever wanted as well, shoot
# "iPhone 18 Pro Max" at its own size — `shoot` takes the device and the
# expected size as arguments.
IPHONE_NAME="iPhone 18 Pro"
IPAD_NAME="iPad Pro 13-inch (M5)"
IPHONE_SHOT_SIZE=(1206 2622)
IPAD_SHOT_SIZE=(2064 2752)

# The iPhone Duo slot takes either display, either way round: the outer one at
# 1398 × 2034, the inner one at 2007 × 2853. This shoots the inner one upright.
# It is the display the device is bought for, and upright it fits every pose
# whole: on the outer display the hint's explanation is cut short, and with the
# inner one on its side the statistics chart and the calendar run off the
# bottom. simctl calls the outer display `primary` and the inner one `primary-1`.
DUO_NAME="iPhone Duo"
DUO_SHOT_SIZE=(2007 2853)
DUO_DISPLAY=primary-1

# Xcode makes an iPhone 18 Pro and an iPhone Duo of its own; a Mac where either
# was deleted gets one back on demand.
IPHONE_TYPE=com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro
DUO_TYPE=com.apple.CoreSimulator.SimDeviceType.iPhone-Duo

# App Preview render sizes — the only two App Store Connect takes for these
# devices, and *not* the devices' own resolutions. The iPhone one is also the
# only size it takes for the iPhone Duo, and the Duo's displays are nowhere near
# that shape, so the Duo has no take of its own: its preview is the iPhone's,
# under its own name. See AppStore/screenshots.md.
IPHONE_VIDEO_SIZE=(886 1920)
IPAD_VIDEO_SIZE=(1200 1600)

# Previews must carry stereo AAC at 256 kbps and silence does not satisfy the
# check, so a bed is synthesised — the app itself ships no audio files.
PREVIEW_MUSIC="${PREVIEW_MUSIC-$WORK/bed.wav}"
PREVIEW_GAIN="${PREVIEW_GAIN:-0.5}"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

udid_for() {
    # Device lines are indented four spaces and read "<name> (<udid>) (<state>)".
    # Matched as a fixed string, because "iPad Pro 13-inch (M5)" carries brackets
    # of its own; the trailing " (" keeps "iPhone 18 Pro" from matching "iPhone 18 Pro Max".
    # The list goes from the oldest runtime to the newest, and the last match is taken: a
    # same-named simulator left on an older runtime may be too old for the app.
    xcrun simctl list devices available \
        | grep -F "    $1 (" \
        | grep -oE '[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}' \
        | tail -n 1 || true
}

ensure_device() { # ensure_device <name> <device-type-id> -> udid on stdout
    local udid; udid="$(udid_for "$1")"
    if [ -z "$udid" ]; then
        # Messages go to stderr, because the caller reads this function's stdout.
        # No runtime is named: simctl then takes the newest one that runs the
        # device type, and says which on stderr. Picking one here went wrong for
        # the iPhone Duo, which runs only on a runtime of its own
        # (`iOS-27-2-iPhone19-4`) that runs no other iPhone.
        echo "  creating simulator '$1'" >&2
        xcrun simctl create "$1" "$2" >/dev/null || return 1
        udid="$(udid_for "$1")"
    fi
    printf '%s' "$udid"
}

prefs_for() {
    printf '%s' "$HOME/Library/Developer/CoreSimulator/Devices/$1/data/Library/Preferences/.GlobalPreferences.plist"
}

# The status bar is the system's, not the app's, so `-AppleLanguages` never
# reaches it — and on the iPad it carries the date, which a Czech simulator
# prints in Czech over the English set. So the device itself is switched to the
# language being shot. That only takes after a reboot, so a device whose
# language changes is shut down here and boot_and_install brings it back up.
device_languages() { # device_languages <udid> -> the preferred languages, space-separated
    local prefs i=0 lang list=""; prefs="$(prefs_for "$1")"
    while lang="$(plutil -extract "AppleLanguages.$i" raw "$prefs" 2>/dev/null)"; do
        list="${list:+$list }$lang"
        i=$((i + 1))
    done
    printf '%s' "$list"
}

# The whole list, not just its first entry: a simulator set to Czech with
# English after it has to come back with both. Each key on its own: an empty
# region or no languages at all delete that key instead of writing it, which is
# how restore_devices puts back a device that never had it — writing the run's
# en_US there would leave it set for good.
set_device_language() { # set_device_language <udid> <region|""> [<language>...]
    local udid="$1" region="$2"; shift 2
    local prefs; prefs="$(prefs_for "$udid")"
    if [ "$(device_languages "$udid")" = "$*" ] \
        && [ "$(plutil -extract AppleLocale raw "$prefs" 2>/dev/null)" = "$region" ]; then
        return 0
    fi
    xcrun simctl boot "$udid" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
    if [ "$#" -gt 0 ]; then
        xcrun simctl spawn "$udid" defaults write -g AppleLanguages -array "$@"
    else
        xcrun simctl spawn "$udid" defaults delete -g AppleLanguages >/dev/null 2>&1 || true
    fi
    if [ -n "$region" ]; then
        xcrun simctl spawn "$udid" defaults write -g AppleLocale -string "$region"
    else
        xcrun simctl spawn "$udid" defaults delete -g AppleLocale >/dev/null 2>&1 || true
    fi
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
}

device_language() { # device_language <udid> <locale>
    case "$2" in
        cs)    set_device_language "$1" cs_CZ cs-CZ ;;
        en-US) set_device_language "$1" en_US en-US ;;
    esac
}

# A Sudoku already installed on these simulators — the developer's own, with its
# games and settings — would be lost to the clean installs below, so it is copied
# aside before the first of them and put back by restore_devices. A new folder on
# every run (SAVED, made next to the trap below): a copy from an earlier run is
# older than what is installed now, and must not be what gets put back. Nor is
# any copy ever deleted by the script: if a run died before putting the app back,
# its copy is the only one left.
#
# A copy counts only once it is whole. `complete` is written after both the app
# and its data are across, `none` when no Sudoku is installed, and
# restore_devices touches a device's app only after one of the two. A copy that
# failed or was cut short has neither: the run stops before the clean install, so
# the app on the device is still the one that was there, and it is left alone —
# rather than uninstalled, with its games, on the strength of half a copy.
save_install() { # save_install <udid> — on a booted device, once per run
    local dir="$SAVED/$1" apps app data
    if [ -e "$dir/complete" ] || [ -e "$dir/none" ]; then return 0; fi
    rm -rf "$dir"
    # "Not installed" has to be proven, never read off a lookup that failed:
    # `none` is leave for the clean install to delete whatever Sudoku is on the
    # device, games and all. `get_app_container` fails the same way for an app
    # that is missing and for a device that is still booting or a CoreSimulator
    # hiccup, so the answer comes from the list of installed apps instead — and
    # only from a list that is evidently whole, which on any iOS simulator that
    # is up includes Settings (com.apple.Preferences). Bundle ids are the list's
    # keys, quoted (`    "cz.rob.sudoku" =     {`); the closing quote keeps
    # `cz.rob.sudokuTests` apart. A device that is shut down cannot list its apps
    # at all, so that stops the run too.
    if ! apps="$(xcrun simctl listapps "$1" 2>/dev/null)"; then
        echo "  !! could not list the apps on $1; stopping, as a clean install could delete a Sudoku that is there" >&2
        return 1
    fi
    case "$apps" in
        *'"com.apple.Preferences" ='*) ;;
        *) echo "  !! the app list from $1 looks incomplete; stopping, as a clean install could delete a Sudoku that is there" >&2
           return 1 ;;
    esac
    case "$apps" in
        *"\"$BID\" ="*) ;;
        *) mkdir -p "$dir" && : > "$dir/none" || return 1
           return 0 ;;
    esac
    mkdir -p "$dir" \
        && app="$(xcrun simctl get_app_container "$1" "$BID" app 2>/dev/null)" \
        && data="$(xcrun simctl get_app_container "$1" "$BID" data 2>/dev/null)" \
        && cp -R "$app" "$dir/" \
        && rsync -a "$data/" "$dir/data/" \
        && : > "$dir/complete" \
        || { echo "  !! could not copy the installed Sudoku aside; stopping before a clean install loses it" >&2
             return 1; }
    echo "  kept the installed app and its data aside in $dir"
}

restore_install() { # restore_install <udid> — on a booted device; leaves it shut down
    local dir="$SAVED/$1" app data
    [ -e "$dir/complete" ] || return 0
    app="$(find "$dir" -maxdepth 1 -name '*.app' 2>/dev/null | head -n 1)"
    [ -n "$app" ] || return 0
    xcrun simctl install "$1" "$app" || return 1
    data="$(xcrun simctl get_app_container "$1" "$BID" data)" || return 1
    # Shut down first, so no running process holds the app's preferences in memory.
    xcrun simctl shutdown "$1" >/dev/null 2>&1
    # The container's own metadata belongs to the new install.
    rsync -a --delete --exclude .com.apple.mobile_container_manager.metadata.plist "$dir/data/" "$data/"
}

boot_and_install() { # boot_and_install <udid> <locale>
    local udid="$1"
    device_language "$udid" "$2"
    # `boot` fails on a device that is already up, which is fine; `bootstatus`
    # waits until the device has finished booting, and if it never does, nothing
    # after it can be trusted — save_install least of all.
    xcrun simctl boot "$udid" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 \
        || { echo "  !! $udid did not finish booting" >&2; exit 1; }
    save_install "$udid" || exit 1
    # Each locale starts from a clean install: settings the last run left in
    # UserDefaults must not leak into the next set. The poses themselves don't
    # need it — `-debugHistory` replaces the game data on every launch.
    xcrun simctl uninstall "$udid" "$BID" >/dev/null 2>&1 || true
    xcrun simctl install "$udid" "$APP"
    # 9:41 is the time Apple puts on its own. The battery is `discharging` at
    # 100 %, not `charged`: charged is the plugged-in glyph with a bolt through it,
    # which reads as a phone on charge rather than as a phone.
    xcrun simctl status_bar "$udid" override --time "9:41" \
        --batteryState discharging --batteryLevel 100 \
        --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 >/dev/null 2>&1 || true
    # The first launch after a boot and an install is the slow one; take that
    # cost before anything is shot.
    launch "$udid" "$2" -debugScenario home
    sleep 6
    xcrun simctl terminate "$udid" "$BID" >/dev/null 2>&1 || true
}

locale_args() {
    case "$1" in
        cs)    printf '%s\0%s\0%s\0%s\0' -AppleLanguages "(cs)" -AppleLocale cs_CZ ;;
        en-US) printf '%s\0%s\0%s\0%s\0' -AppleLanguages "(en-US)" -AppleLocale en_US ;;
    esac
}

# Arguments every pose gets. `-hasSeenWelcome` keeps the welcome sheet from
# starting to present before the scenario can cancel it; `-debugHistory` gives
# the statistics, the calendar and the achievements six weeks of play to show,
# the same on every launch (DebugScenarios.seedHistory). Sounds are off so a
# run doesn't play forty placement clicks through the Mac's speakers.
COMMON_ARGS=(-hasSeenWelcome 1 -debugHistory 1 -soundEnabled 0)

launch() { # launch <udid> <locale> <args...>
    local udid="$1" loc="$2"; shift 2
    local largs=()
    while IFS= read -r -d '' a; do largs+=("$a"); done < <(locale_args "$loc")
    xcrun simctl terminate "$udid" "$BID" >/dev/null 2>&1 || true
    clear_ready "$udid" || exit 1
    xcrun simctl launch "$udid" "$BID" "${largs[@]}" "${COMMON_ARGS[@]}" "$@" >/dev/null
}

# Every pose drops a marker when it is set up (DebugScenarios.markReady): a new
# game has to be generated first, and the hint pose plays a whole puzzle by
# hints until it reaches an Expert technique, which takes a few seconds in a
# Debug build and longer on a slower Mac. Waiting for the file rather than for a
# number keeps the fast poses fast and the slow ones correct.
#
# The marker sits in the app's data container. A lookup that fails stops here,
# naming the device: an empty path would point at /Documents/shot-ready instead,
# and the wait would sit out its whole timeout for a file that cannot appear.
ready_marker() { # ready_marker <udid> -> the marker's path on stdout
    local data
    data="$(xcrun simctl get_app_container "$1" "$BID" data)" && [ -n "$data" ] \
        || { echo "  !! no data container for $BID on $1" >&2; return 1; }
    printf '%s' "$data/Documents/shot-ready"
}

clear_ready() { # clear_ready <udid>
    local marker; marker="$(ready_marker "$1")" || return 1
    rm -f "$marker"
}

wait_ready() { # wait_ready <udid> <timeout-seconds> -> seconds waited on stdout
    local marker; marker="$(ready_marker "$1")" || return 1
    local ticks=0 limit=$(( $2 * 5 ))
    while [ ! -f "$marker" ] && [ "$ticks" -lt "$limit" ]; do
        sleep 0.2
        ticks=$((ticks + 1))
    done
    # stderr, because the caller reads this function's stdout.
    [ -f "$marker" ] || { echo "  !! the pose never became ready (${2}s)" >&2; return 1; }
    printf '%s' "$(( ticks / 5 ))"
}

# The iPhone Duo boots folded, on its outer display, and nothing on the command
# line unfolds it: simctl has no hinge, and toggling its displays' power only
# blanks them (and once took SpringBoard down with it). DeviceHub does it with a
# click, so the run asks for that and watches the inner display until it is lit
# and upright. Folded, that display is pure black; on its side, it comes out
# 2853 × 2007. A language switch is a reboot and folds it again, which is why
# the Duo is shot before anything else, in both languages.
wait_unfolded() { # wait_unfolded <udid>
    local probe="$WORK/unfolded.png" want="${DUO_SHOT_SIZE[0]}x${DUO_SHOT_SIZE[1]}"
    local lit size asked=no ticks=0
    while :; do
        lit=0 size=""
        if xcrun simctl io "$1" screenshot --display="$DUO_DISPLAY" "$probe" >/dev/null 2>&1; then
            read -r lit size < <(magick "$probe" -alpha off \
                -format '%[fx:maxima > 0.1] %wx%h\n' info: 2>/dev/null) || true
        fi
        if [ "$lit" = 1 ] && [ "$size" = "$want" ]; then
            break
        fi
        if [ "$asked" = no ]; then
            printf '\a  → Unfold the iPhone Duo in DeviceHub and turn it upright; the run then goes on by itself.\n'
            asked=yes
        fi
        ticks=$((ticks + 1))
        # Ten minutes, so a run nobody is watching ends instead of waiting for ever.
        [ "$ticks" -lt 300 ] \
            || { echo "  !! the iPhone Duo was not unfolded upright within 10 minutes" >&2; exit 1; }
        sleep 2
    done
    # Unfolding resizes whatever is on screen; give it a moment to settle.
    if [ "$asked" = yes ]; then sleep 3; fi
}

# ---------------------------------------------------------------- build

say "Building Debug for the simulator"
# Into a log, because a build says a great deal — and when it fails, its errors
# and the end of the log come out here, rather than the run just stopping.
BUILD_LOG="$WORK/build.log"
if ! xcodebuild -project "$ROOT/sudoku.xcodeproj" -scheme sudoku \
    -configuration Debug -sdk iphonesimulator \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$WORK/dd" build >"$BUILD_LOG" 2>&1; then
    echo "  !! the build failed. Its errors:" >&2
    grep -E '(^|: )(fatal )?error: ' "$BUILD_LOG" | awk '!seen[$0]++' | head -n 20 >&2 || true
    echo "  and the end of $BUILD_LOG:" >&2
    tail -n 25 "$BUILD_LOG" >&2
    exit 1
fi
APP="$WORK/dd/Build/Products/Debug-iphonesimulator/sudoku.app"

# Only the devices this run shoots, so a run for one device leaves the others
# alone and a `video` run does not need a Duo.
IPHONE_UDID="" IPAD_UDID="" DUO_UDID=""
DEVICES=()
if wants iphone; then
    IPHONE_UDID="$(ensure_device "$IPHONE_NAME" "$IPHONE_TYPE" || true)"
    [ -n "$IPHONE_UDID" ] \
        || { echo "no simulator named '$IPHONE_NAME', and creating one failed"; exit 1; }
    DEVICES+=("$IPHONE_UDID")
fi
if wants ipad; then
    IPAD_UDID="$(udid_for "$IPAD_NAME")"
    [ -n "$IPAD_UDID" ] || { echo "no simulator named '$IPAD_NAME'"; exit 1; }
    DEVICES+=("$IPAD_UDID")
fi
if wants duo && [ "$MODE" != video ]; then
    DUO_UDID="$(ensure_device "$DUO_NAME" "$DUO_TYPE" || true)"
    [ -n "$DUO_UDID" ] \
        || { echo "no simulator named '$DUO_NAME', and creating one failed (it needs Xcode 27.1 or later)"; exit 1; }
    DEVICES+=("$DUO_UDID")
fi

# The simulators are somebody's everyday ones, so they are put back the way they
# were when the run ends, however it ends: their languages, an installed Sudoku
# with its data (see save_install), and running or shut down. A device that has
# never been booted has no preferences file yet and no language to put back; on
# one that has, AppleLocale and AppleLanguages are each recorded as they were —
# set, or absent, which the run's own en_US must not outlive. The one thing not
# put back is a status bar override of your own: it is cleared.
ORIGINAL_DEVICES=()
for udid in "${DEVICES[@]}"; do
    booted=no
    # Not `grep -q`: quitting at the first match can leave simctl writing into
    # a closed pipe, and under pipefail that reads as no match.
    xcrun simctl list devices | grep -F "($udid) (Booted)" >/dev/null && booted=yes
    has_prefs=no
    [ -f "$(prefs_for "$udid")" ] && has_prefs=yes
    region="$(plutil -extract AppleLocale raw "$(prefs_for "$udid")" 2>/dev/null || true)"
    ORIGINAL_DEVICES+=("$udid|$booted|$has_prefs|$region|$(device_languages "$udid")")
done
restore_devices() {
    # Whatever fails here, the rest still has to be put back.
    set +e
    local entry udid booted has_prefs region languages dir
    for entry in "${ORIGINAL_DEVICES[@]}"; do
        IFS='|' read -r udid booted has_prefs region languages <<<"$entry"
        dir="$SAVED/$udid"
        # Only a device whose app save_install has accounted for: copied aside
        # whole, or found not installed. On any other the app is somebody's own —
        # never copied, or copied only in part — and the run never touched it.
        if [ -e "$dir/complete" ] || [ -e "$dir/none" ]; then
            # Booted first: a run that stopped mid-way can leave a device shut
            # down, and none of the next three commands works on one.
            xcrun simctl boot "$udid" >/dev/null 2>&1
            xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1
            xcrun simctl status_bar "$udid" clear >/dev/null 2>&1
            # The poses leave a Debug build with a made-up history behind; nobody
            # should open the simulator later and find it in their own data.
            xcrun simctl uninstall "$udid" "$BID" >/dev/null 2>&1
            restore_install "$udid" || echo "  !! could not put back the app kept in $dir" >&2
        elif [ -d "$dir" ]; then
            echo "  !! the Sudoku on $udid was not copied aside in full, so it is left as it was" >&2
            if [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
                echo "     (what did get copied is in $dir)" >&2
            fi
        fi
        if [ "$has_prefs" = yes ]; then
            # An empty region or language list deletes that key again.
            # shellcheck disable=SC2086
            set_device_language "$udid" "$region" $languages
        fi
        if [ "$booted" = yes ]; then
            xcrun simctl boot "$udid" >/dev/null 2>&1
        else
            xcrun simctl shutdown "$udid" >/dev/null 2>&1
        fi
    done
}

# Where the copies of an installed Sudoku go: Application Support, not WORK.
# WORK is in $TMPDIR, which macOS clears of files left unused for a few days, and
# the copy may be the only one left if putting it back failed; Caches is meant to
# be disposable and is what cleaning tools empty; the repository's .build/ goes
# with `swift package reset`. Application Support is for data that has to stay.
# The script never deletes a copy: its path is printed before the devices are
# put back, and removing it once the app is back is up to you.
SAVED_ROOT="$HOME/Library/Application Support/sudoku-appstore"
mkdir -p "$SAVED_ROOT"
SAVED="$(mktemp -d "$SAVED_ROOT/installed.XXXXXX")"

on_exit() {
    # Nothing may cut the restore short: a second Ctrl-C between uninstalling
    # the Debug build and putting the kept Sudoku back would leave the device
    # with neither. So from here on the signals that end a run are ignored, by
    # this shell and by the simctl calls it makes; the restore takes a minute.
    trap '' INT TERM HUP
    # Said first, so the copy can be found whatever happens below.
    if ls "$SAVED"/*/complete >/dev/null 2>&1; then
        echo "  the Sudoku that was installed is kept in $SAVED — delete it once it is back" >&2
    fi
    restore_devices
    if [ "$FINISHED" != yes ]; then
        echo "  the run's working files, the build log among them, are in $WORK" >&2
    elif [ "$OWN_WORK" = yes ]; then
        # The build and the takes, about 300 MB; nothing in WORK is needed now.
        rm -rf "$WORK"
    fi
    # A copy, whole or in part, is kept; a folder holding nothing but `none`
    # markers (no Sudoku was installed) is not worth leaving behind.
    if [ -z "$(find "$SAVED" -mindepth 2 ! -name none -print 2>/dev/null | head -n 1)" ]; then
        rm -rf "$SAVED"
    fi
}
trap on_exit EXIT

# ---------------------------------------------------------------- screenshots

# A puzzle "from a newspaper" for the custom-puzzle pose: Hard, 26 clues, made by
# the app's own generator from seed 42 — so it is no day's daily challenge and
# nobody else's puzzle.
NEWSPAPER=.23........7.59....8...1..434..2...6.7.....3.6...1..787..3...1....56.2........38.

# name|extra settle seconds|launch arguments. The settle is what is left after
# the ready marker: the push or sheet animation, the win card's entrance, the
# chart drawing in. The order is the upload order and it matters more than the
# count: search results show the first three, and most people never scroll past
# them — so those three are the hint, the promise and the daily challenge.
#
# `-debugSeed` makes every new game the same puzzle on every run; seed 6 on
# Expert reaches an XY-Wing, the technique whose explanation reads most plainly
# ("the pivot is either 1 or 4 …"), with both wings and the pivot drawn on the
# board. `-debugElapsed` puts a believable time on the clock instead of the two
# seconds a pose takes to set up.
SHOTS=(
    "01-hint|1.5|-debugScenario advancedHint -debugDifficulty expert -debugSeed 6 -debugElapsed 754"
    "02-play|1.5|-debugScenario progress -debugDifficulty hard -debugSeed 11 -debugElapsed 466"
    "03-daily|1.5|-debugScenario daily"
    "04-levels|1.5|-debugScenario difficulty"
    "05-stats|2.5|-debugScenario stats"
    "06-custom|2.5|-debugScenario custom -debugCustomPuzzle $NEWSPAPER"
    "07-dark|1.5|-debugScenario progress -debugDifficulty medium -debugSeed 23 -debugElapsed 318 -appearance dark -theme orange -digitStyle rounded"
    "08-achievements|1.5|-debugScenario achievements"
    "09-win|3.5|-debugScenario win -debugDifficulty hard -debugSeed 11 -debugElapsed 597"
    "10-home|1.5|-debugScenario home"
)

shoot() { # shoot <udid> <locale> <device-dir> <W> <H> [<display>]
    local udid="$1" loc="$2" dev="$3" w="$4" h="$5" display="${6:-}"
    local dir="$OUT_ROOT/screenshots/$loc/$dev"
    # Shot aside and swapped in once the set is complete: a run that stops half-way
    # leaves the last good set whole, and a shot dropped from the list must not
    # linger beside the new set and get uploaded with it.
    local staging="$WORK/shots/$loc/$dev"
    rm -rf "$staging"
    mkdir -p "$staging"
    for entry in "${SHOTS[@]}"; do
        IFS='|' read -r name settle args <<<"$entry"
        # shellcheck disable=SC2086
        launch "$udid" "$loc" $args
        local waited
        waited="$(wait_ready "$udid" 120)" || exit 1
        sleep "$settle"
        xcrun simctl io "$udid" screenshot ${display:+--display="$display"} \
            "$staging/$name.png" >/dev/null 2>&1
        local size
        size="$(magick identify -format '%wx%h' "$staging/$name.png")"
        printf '  %-16s %-10s ready in %ss\n' "$name" "$size" "$waited"
        # Every device shoots its slot size, so a mismatch means the simulator
        # is not the one this script expects rather than something to paper over.
        if [ "$size" != "${w}x${h}" ]; then
            echo "     !! expected ${w}x${h} — wrong simulator or a changed runtime (or a Duo turned on its side)"
            exit 1
        fi
        # A black frame is a display that was off: an iPhone Duo folded mid-run
        # still gives its inner display's full size.
        if [ "$(magick "$staging/$name.png" -alpha off -format '%[fx:maxima > 0.1]' info:)" != 1 ]; then
            echo "     !! the screen is black — was the iPhone Duo folded?"
            exit 1
        fi
    done
    xcrun simctl terminate "$udid" "$BID" >/dev/null 2>&1 || true
    mkdir -p "$dir"
    rm -f "$dir"/*.png
    mv "$staging"/*.png "$dir"/
}

if [ "$MODE" = all ] || [ "$MODE" = screenshots ]; then
    command -v magick >/dev/null \
        || { echo "needs ImageMagick (brew install imagemagick)"; exit 1; }
    # The Duo first, in both languages, because it is the one that needs a
    # hand (wait_unfolded): the run asks in its first few minutes, while you
    # are still there, and the rest runs on its own.
    if wants duo; then
        for loc in cs en-US; do
            say "Screenshots — iPhone Duo / $loc"
            boot_and_install "$DUO_UDID" "$loc"
            wait_unfolded "$DUO_UDID"
            shoot "$DUO_UDID" "$loc" iphone-duo "${DUO_SHOT_SIZE[@]}" "$DUO_DISPLAY"
        done
    fi
    for loc in cs en-US; do
        if wants iphone; then
            say "Screenshots — iPhone 6.3\" / $loc"
            boot_and_install "$IPHONE_UDID" "$loc"
            shoot "$IPHONE_UDID" "$loc" iphone-6.3 "${IPHONE_SHOT_SIZE[@]}"
        fi
        if wants ipad; then
            say "Screenshots — iPad 13\" / $loc"
            boot_and_install "$IPAD_UDID" "$loc"
            shoot "$IPAD_UDID" "$loc" ipad-13 "${IPAD_SHOT_SIZE[@]}"
        fi
    done

    # The simulator writes RGBA even though every pixel is opaque, and App Store
    # Connect wants screenshots without transparency. Dropping the channel leaves
    # the picture untouched and saves about a third of the size — verified rather
    # than assumed, and anything that is not identical is left alone.
    say "Squeezing PNGs (lossless)"
    while IFS= read -r f; do
        magick "$f" -alpha off -depth 8 -strip \
                    -define png:compression-level=9 \
                    -define png:compression-filter=5 "$f.opt"
        if [ "$(magick compare -metric AE "$f" "$f.opt" null: 2>&1 | awk '{print $1}')" = "0" ]; then
            mv "$f.opt" "$f"
        else
            rm -f "$f.opt"
            echo "  left as-is (not identical): $f"
        fi
    done < <(find "$OUT_ROOT/screenshots" -name '*.png')
    du -sh "$OUT_ROOT/screenshots"
fi

# ---------------------------------------------------------------- preview

# One continuous take of a game being played (DebugScenarios.playDemo): half
# of an Easy puzzle filled in, the rest played single by single at a person's
# pace, a hint taken through both of its stages on the way, and the win with its
# wave, confetti and result card. Easy, because every one of its moves is a
# single a viewer can follow, and its hint is a sentence anyone understands.
#
# The app drops the ready marker the moment the board is up and starts playing
# `-debugDemoLead` seconds later; recording starts as soon as the marker is
# seen, so the lead is what the recorder has to come up in, and the cut points
# below are measured from it. The seed is fixed, so the game — and with it the
# whole timeline — is the same on every run; only how quickly the recorder
# comes up moves, by a fraction of a second. Unless the simulator stalls: one
# en-US iPhone take stood still for 2.2 s at 14.4 s while the game went on, and
# its preview ran out before the result card. `assemble` checks every take for
# that (appstore_gaps.swift) before cutting it.
#
# `-debugElapsed` puts three and a half minutes on the clock, so the result
# card reads like a real Easy game rather than like the twenty seconds the take
# lasts.
DEMO_ARGS="-debugScenario demo -debugDifficulty easy -debugSeed 3 -debugElapsed 211"
RECORD_SECONDS=21

# Cut points, in seconds into the recording. Measured on both devices and in
# both languages: the first move lands at about 1.5 s, the hint is up from about
# 6 s to 11 s (its first stage, then Show Me), the last number goes in at about
# 15.5 s and the result card stands from about 16.5 s, with the confetti
# falling over it. So the cut opens on the board a moment before the first move
# and holds the card for about three seconds at the end.
#
# The end is bounded twice. `simctl io recordVideo` writes a frame only when
# the screen changes, so a take ends at its last change — the confetti settling,
# which varies from run to run (19.5 to 20.6 s so far) — and a range past that
# used to be clamped, which once left the Czech iPhone preview 0.3 s short. So
# appstore_video.swift now holds the last frame for whatever the take lacks, and
# `assemble` checks the length — and, through the gap check, that the frame held
# is a few frames of a settled result card rather than a take that stopped
# early. And nothing may reach past about 21 s into a
# recording anyway: the tail is not reliably decodable, and a range that crosses
# it comes out holding one frame while every step reports success (learned on
# the chess project). Apple wants 15 to 30 seconds; this is 18.8.
IPHONE_CUT=1.0:19.8
IPAD_CUT=1.0:19.8

record() { # record <udid> <locale> <out.mp4>
    local udid="$1" loc="$2" out="$3"
    mkdir -p "$(dirname "$out")"
    # shellcheck disable=SC2086
    launch "$udid" "$loc" $DEMO_ARGS
    local waited
    waited="$(wait_ready "$udid" 120)" || exit 1
    xcrun simctl io "$udid" recordVideo --codec h264 --force "$out" >/dev/null 2>&1 &
    local pid=$!
    sleep "$RECORD_SECONDS"
    kill -INT $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
    sleep 1
    printf '  %-10s %s (ready in %ss)\n' "$(basename "$out" .mp4)" \
        "$(avmediainfo "$out" | awk '/^Duration:/{print $2 "s"}')" "$waited"
    xcrun simctl terminate "$udid" "$BID" >/dev/null 2>&1 || true
}

assemble() { # assemble <clip.mp4> <out.mp4> <W> <H> <in:out>
    local clip="$1" out="$2" w="$3" h="$4" cut="$5"
    # First whether the take is worth cutting at all. A simulator that stalls
    # mid-take pushes everything after it late, and every step below would
    # still report success; the gap check names the clip and the stall instead.
    swift "$ROOT/Tools/appstore_gaps.swift" "$clip:$cut" || exit 1
    mkdir -p "$(dirname "$out")"
    # The cut is ProRes, so the picture is encoded to H.264 once, by conform, and
    # nothing hides frames behind an edit list on the way (see appstore_video.swift).
    local cut_file="$WORK/cut.mov"
    swift "$ROOT/Tools/appstore_video.swift" "$cut_file" "$w" "$h" "$clip:$cut"
    # What comes out of the cut is the right size and the wrong everything else
    # for App Store Connect — the wrong codec, too fast a bit rate and no audio at
    # all. This pins the lot to Apple's table, rewriting the file in place as the
    # finished MP4. The gain travels with the music: on its own it would land in
    # the music file's place.
    swift "$ROOT/Tools/appstore_conform.swift" "$cut_file" "$w" "$h" \
        ${PREVIEW_MUSIC:+"$PREVIEW_MUSIC" "$PREVIEW_GAIN"}
    mv -f "$cut_file" "$out"
    # Every step above reports success even when the result is short, so measure
    # it. (Conform has already checked its frames: exactly 30 a second, all alike.)
    local want got
    want="$(awk -v c="$cut" 'BEGIN { split(c, p, ":"); printf "%.2f", p[2] - p[1] }')"
    got="$(avmediainfo "$out" | awk '/^Duration:/ { printf "%.2f", $2; exit }')"
    if awk -v a="$want" -v b="$got" 'BEGIN { exit !(a - b > 0.05 || b - a > 0.05) }'; then
        echo "  !! $(basename "$out") is ${got}s, the cut asks for ${want}s" >&2
        exit 1
    fi
}

if { [ "$MODE" = all ] || [ "$MODE" = video ]; } && { wants iphone || wants ipad; }; then
    if [ -n "$PREVIEW_MUSIC" ] && [ ! -f "$PREVIEW_MUSIC" ]; then
        say "Synthesising the music bed"
        python3 "$ROOT/Tools/gen_preview_music.py" "$PREVIEW_MUSIC" 32
    fi
    # Made aside, like the screenshots, and swapped in only once every one has
    # passed every check: a run that stops on a stalled take leaves the last
    # good set whole, rather than new previews beside old ones, or a bad one in
    # their place.
    staging="$WORK/preview"
    rm -rf "$staging"
    for loc in cs en-US; do
        if wants iphone; then
            say "Preview — iPhone 6.3\" / $loc"
            boot_and_install "$IPHONE_UDID" "$loc"
            record "$IPHONE_UDID" "$loc" "$WORK/clips/iphone-$loc.mp4"
            assemble "$WORK/clips/iphone-$loc.mp4" "$staging/$loc/iphone-6.3.mp4" \
                "${IPHONE_VIDEO_SIZE[@]}" "$IPHONE_CUT"
            # The Duo's preview is this one (see IPHONE_VIDEO_SIZE), copied under
            # the Duo's name so that every slot in Connect has a file of its own.
            cp "$staging/$loc/iphone-6.3.mp4" "$staging/$loc/iphone-duo.mp4"
        fi
        if wants ipad; then
            say "Preview — iPad 13\" / $loc"
            boot_and_install "$IPAD_UDID" "$loc"
            record "$IPAD_UDID" "$loc" "$WORK/clips/ipad-$loc.mp4"
            assemble "$WORK/clips/ipad-$loc.mp4" "$staging/$loc/ipad-13.mp4" \
                "${IPAD_VIDEO_SIZE[@]}" "$IPAD_CUT"
        fi
    done
    for loc in cs en-US; do
        mkdir -p "$OUT_ROOT/preview/$loc"
        # A run for every device replaces the whole folder, so a preview for a
        # slot the listing no longer uses does not linger and get uploaded; a
        # run for one device replaces only its own.
        if [ -z "$ONLY" ]; then rm -f "$OUT_ROOT/preview/$loc"/*.mp4; fi
        mv -f "$staging/$loc"/*.mp4 "$OUT_ROOT/preview/$loc"/
    done
fi

# ---------------------------------------------------------------- tidy up

# The build and the takes come to about 300 MB a run, in a folder of its own
# every run, so on_exit deletes that folder once the devices are put back —
# after a run that got this far only. A failed run keeps everything, the build
# log and the takes being what tells you why, and a WORK=… of your own is never
# deleted. A Sudoku copied aside is not in WORK (see SAVED) and is never deleted.
FINISHED=yes
say "Done."
