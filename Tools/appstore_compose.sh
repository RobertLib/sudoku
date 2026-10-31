#!/bin/bash
#
# appstore_compose.sh — turns the plain screenshots into the ones that go up.
#
#     Tools/appstore_compose.sh
#
# Reads AppStore/screenshots/<locale>/<device>/*.png and writes
# AppStore/screenshots-composed/<locale>/<device>/*.png with the same names, so
# either set can be uploaded and the order is unchanged. Needs only ImageMagick
# — no simulator and no build.
#
# The layout is J-Notes' (github.com/RobertLib/j-notes), so the developer's
# listings read as one family: a flat saturated colour, a heading in white across
# the top, and the screenshot in a device frame below it, running off the bottom
# edge. Its proportions were measured off the J-Notes shots on the store and are
# kept as they are.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IN_ROOT="${IN_ROOT:-$ROOT/AppStore/screenshots}"
OUT_ROOT="${OUT_ROOT:-$ROOT/AppStore/screenshots-composed}"

command -v magick >/dev/null || { echo "needs ImageMagick (brew install imagemagick)"; exit 1; }
[ -d "$IN_ROOT" ] || { echo "no screenshots in $IN_ROOT — run Tools/appstore_media.sh first"; exit 1; }

# SF Pro Rounded, which is what the J-Notes headings are set in, echoing the
# app's own rounded number font, and the only rounded face on a stock macOS with complete Czech diacritics — Arial
# Rounded Bold has neither ť nor ě, and would drop them silently. Given as a
# path, not as a name: the Homebrew build has no fontconfig type map, so
# `-font SFNSRounded` fails and takes the heading with it while still exiting 0.
#
# ImageMagick instantiates a variable font at its default weight, so this comes
# out Regular however it is asked for. The weight is put back with a stroke of
# the fill colour, which is what STROKE below is for: 4% of the point size is
# about a Bold, measured against the live shots letter by letter.
FONT="${FONT:-/System/Library/Fonts/SFNSRounded.ttf}"
[ -f "$FONT" ] || { echo "no font at $FONT — set FONT=/path/to/font.ttf"; exit 1; }

TEXT='#FFFFFF'
BEZEL='#0B0B0D'   # the phone's body
RIM='#5C5C61'     # the hairline the titanium edge catches

# A colour per shot, in upload order: the app's own eight theme colours
# (ThemeColor in sudoku/Support/Theme.swift, light variants), every one of them,
# so the set looks like the app it shows. Ten shots and eight colours, so blue
# and orange come round twice — 10 is blue like 01, 09 orange like 03 — and no
# two neighbours share one, which is what keeps the row of thumbnails in search
# results reading as a set rather than as one long block. The first three, the
# ones search results show, are the three most unlike.
colour_for() {
    case "$1" in
        01-hint)         printf '#216BED' ;;  # blue, the default theme
        02-play)         printf '#5452D1' ;;  # indigo
        03-daily)        printf '#BF590D' ;;  # orange
        04-levels)       printf '#008291' ;;  # teal
        05-stats)        printf '#1F874D' ;;  # green
        06-custom)       printf '#8F45D1' ;;  # purple
        07-dark)         printf '#474F5C' ;;  # graphite, under the one dark shot
        08-achievements) printf '#D12E70' ;;  # pink
        09-win)          printf '#BF590D' ;;  # orange
        10-home)         printf '#216BED' ;;  # blue
        *)               printf '#216BED' ;;
    esac
}

# The captions. Two lines each, broken by hand: leaving one word alone on the
# last line looks like an accident. Order matches the shot order. The first
# three are what search results show, so they carry the three reasons to pick
# this sudoku over the others — hints that explain, nothing in the way, and a
# reason to come back tomorrow.
en_caption() {
    case "$1" in
        01-hint)         printf 'Hints that teach,\nnot just tell' ;;
        02-play)         printf 'No ads. No account.\nWorks offline.' ;;
        03-daily)        printf 'A new puzzle\nevery day' ;;
        04-levels)       printf 'Five levels, graded\nby real technique' ;;
        05-stats)        printf 'Watch yourself\nget faster' ;;
        06-custom)       printf 'Type in any puzzle\nfrom a newspaper' ;;
        07-dark)         printf 'Dark mode, 8 colors\nand 4 number fonts' ;;
        08-achievements) printf '22 achievements\nto unlock' ;;
        09-win)          printf 'Beat your\nbest time' ;;
        10-home)         printf 'Pure logic,\nbeautifully simple' ;;
        *)               echo "no caption for shot '$1'" >&2; exit 1 ;;
    esac
}

cs_caption() {
    case "$1" in
        01-hint)         printf 'Nápovědy, které\nučí, ne jen radí' ;;
        02-play)         printf 'Bez reklam. Bez účtu.\nFunguje offline.' ;;
        03-daily)        printf 'Každý den\nnové sudoku' ;;
        04-levels)       printf 'Pět úrovní podle\nskutečných technik' ;;
        05-stats)        printf 'Sledujte, jak\nse zrychlujete' ;;
        06-custom)       printf 'Přepište si sudoku\nz novin nebo knihy' ;;
        07-dark)         printf 'Tmavý režim,\n8 barev a 4 písma' ;;
        08-achievements) printf '22 úspěchů\nk odemčení' ;;
        09-win)          printf 'Překonejte svůj\nnejlepší čas' ;;
        10-home)         printf 'Čistá logika,\nkrásně jednoduše' ;;
        *)               echo "no caption for shot '$1'" >&2; exit 1 ;;
    esac
}

caption_for() { # caption_for <locale> <name>
    case "$1" in
        cs) cs_caption "$2" ;;
        *)  en_caption "$2" ;;
    esac
}

# Proportions, measured off the J-Notes shots on the store and expressed against
# the canvas so an iPhone and an iPad shot are laid out the same way rather than
# the iPad getting a device a third of the size. The numbers are per mille,
# because bash has no fractions.
DEVICE_W_PM=793      # device body, as a fraction of the canvas width
DEVICE_TOP_PM=282    # top of the device, as a fraction of the canvas height
BEZEL_PM=30          # body around the screen, as a fraction of the canvas width
POINT_PM=113         # heading size, as a fraction of the canvas width
TEXT_WIDTH_PM=790    # the widest a heading line may be before it is shrunk
TEXT_HEIGHT_PM=780   # the tallest a heading block may be, against the band

compose() { # compose <in.png> <out.png> <locale> <name> <island|duo|plain>
    local src="$1" dst="$2" loc="$3" name="$4" style="$5"
    local W H
    # The newline matters: `read` returns non-zero at EOF without one, and under
    # `set -e` that ends the run with no output at all.
    read -r W H < <(magick identify -format '%w %h\n' "$src")

    local bg;   bg="$(colour_for "$name")"
    local text; text="$(caption_for "$loc" "$name")"

    local dev_w=$((W * DEVICE_W_PM / 1000))
    local bezel=$((W * BEZEL_PM / 1000))
    local dev_x=$(((W - dev_w) / 2))
    local dev_y=$((H * DEVICE_TOP_PM / 1000))
    local screen_w=$((dev_w - 2 * bezel))

    # Screen corners follow the hardware, measured off each simulator's own
    # screen mask (`simctl io screenshot --mask=alpha`): the circle that fits a
    # corner best is 16.3% of the screen's width on the iPhone 18 Pro and 8.4% on
    # the iPhone Duo's inner display. The frame draws a tenth less, as it did for
    # the iPhone 11 Pro Max before them (8.8% against a measured 9.7%). An iPad's
    # are much softer. The body is the screen's radius plus the bezel, which is
    # what keeps the two curves concentric — a body radius chosen on its own is
    # the single thing that makes a drawn frame look drawn.
    local screen_r body_r
    case "$style" in
        island) screen_r=$((screen_w * 147 / 1000)) ;;
        duo)    screen_r=$((screen_w * 76 / 1000)) ;;
        *)      screen_r=$((screen_w * 45 / 1000)) ;;
    esac
    body_r=$((screen_r + bezel))

    # The device runs off the bottom of the canvas on purpose — it is what makes
    # the shot read as a phone in the hand rather than as a product photo. So the
    # body goes on past the edge by its whole corner radius, and its bottom
    # corners fall outside the picture. It used to go on by only a bezel, and
    # then those corners came up into the picture: the bezel tapered away to
    # nothing at the bottom edge while the screen ran on straight.
    local dev_h=$((H - dev_y + body_r))

    # The screenshot, scaled to the screen width and with its top corners
    # rounded. The bottom ones would fall just inside the canvas on the iPhone
    # and the Duo, so the mask carries them a radius further down, out of the
    # picture, and the screen meets the edge square, as the body does.
    # Scaled, never cropped sideways: the status bar at the top and the number
    # pad near the bottom both have to survive at their own proportions. What is
    # cut is only what falls past the bottom edge of the canvas — the home
    # indicator's strip, about the last 4 % — which is the same thing the device
    # body does.
    local screen_h=$((dev_h - 2 * bezel))
    local scaled_h=$((H * screen_w / W))
    # `-compose Over` is put back before the `-extent`, and it is not optional:
    # `-extent` composites the picture onto its new canvas using whatever compose
    # operator is current, so the CopyOpacity left over from the line above turns
    # the finished screen back into its own mask. Silently — a grey rounded
    # rectangle is a perfectly valid image, and the only symptom is a device with
    # nothing in it.
    magick "$src" -resize "${screen_w}x${scaled_h}!" \
        \( -size "${screen_w}x${scaled_h}" xc:black -fill white \
           -draw "roundrectangle 0,0 $((screen_w-1)),$((scaled_h-1+screen_r)) $screen_r,$screen_r" \) \
        -alpha off -compose CopyOpacity -composite +repage \
        -compose Over -background none -extent "${screen_w}x${screen_h}" \
        "$WORK/screen.png"

    # The body: a rounded black rectangle with a hairline rim, the screen laid
    # into it, and — on the iPhone — the Dynamic Island painted back on. The
    # simulator's screenshots have no island in them (nor has its screen mask);
    # the status bar simply leaves a gap where it would be, so without this the
    # shot reads as a phone that does not exist. Its screen recordings do draw
    # it, which is where the size comes from: on the iPhone 18 Pro it is 23.7%
    # of the screen's width wide, 9.2% tall and 3.2% down from the top edge,
    # about 95 × 37 points. That is narrower than the 126 points of the Pro
    # iPhones before it, and the status bar agrees: the time and the icons sit
    # in the middle of the space either side of the narrow one.
    # The Duo's inner display has nothing to paint: its mask has no cut-out.
    local island_w=$((screen_w * 237 / 1000))
    local island_h=$((screen_w * 92 / 1000))
    local island_x=$(((screen_w - island_w) / 2))
    local island_y=$((screen_w * 32 / 1000))

    magick -size "${dev_w}x${dev_h}" xc:none \
        -fill "$BEZEL" -stroke "$RIM" -strokewidth "$((bezel / 6 + 1))" \
        -draw "roundrectangle 0,0 $((dev_w-1)),$((dev_h-1)) $body_r,$body_r" \
        "$WORK/screen.png" -geometry "+${bezel}+${bezel}" -composite \
        "$WORK/body.png"

    if [ "$style" = island ]; then
        magick "$WORK/body.png" -fill "$BEZEL" -stroke none \
            -draw "roundrectangle $((bezel + island_x)),$((bezel + island_y)) $((bezel + island_x + island_w)),$((bezel + island_y + island_h)) $((island_h / 2)),$((island_h / 2))" \
            "$WORK/body.png"
    fi

    # The heading is centred in the space above the device, not pinned to the
    # top: a two-line caption and a three-line one then sit on the same optical
    # line instead of one of them clinging to the top edge.
    local point=$((W * POINT_PM / 1000))

    # Then shrunk until the widest line fits inside the margins. Measured rather
    # than guessed, and it is the Czech set that needs it — "Bez reklam. Bez účtu."
    # is two characters longer than "No ads. No account." and the captions are
    # broken by hand, so a size chosen to suit English quietly runs a Czech line
    # off both edges. A line that fits is left at full size.
    local widest=0 line_w
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        line_w="$(magick -font "$FONT" -pointsize "$point" \
                         -strokewidth "$((point * 4 / 100))" \
                         label:"$line" -format '%w' info:)"
        [ "$line_w" -gt "$widest" ] && widest=$line_w
    done < <(printf '%s\n' "$text")

    local max_w=$((W * TEXT_WIDTH_PM / 1000))
    if [ "$widest" -gt "$max_w" ] && [ "$widest" -gt 0 ]; then
        point=$((point * max_w / widest))
    fi

    # And again against the height of the band, which is what an iPad needs. Its
    # canvas is 3:4 where the iPhone's is closer to 1:2, so the same fraction of
    # the width is a far larger fraction of the space above the device: a
    # three-line heading sized for the phone came down over the top of the iPad's
    # own frame. A line of this face occupies about 1.25 x its point size, and
    # `-interline-spacing` adds a fifth of one between lines.
    local lines; lines="$(printf '%s\n' "$text" | awk 'END { print NR }')"
    local band=$dev_y
    local max_h=$((band * TEXT_HEIGHT_PM / 1000))
    local block=$((lines * point * 125 / 100 + (lines - 1) * point / 5))
    if [ "$block" -gt "$max_h" ] && [ "$block" -gt 0 ]; then
        point=$((point * max_h / block))
        block=$((lines * point * 125 / 100 + (lines - 1) * point / 5))
    fi

    local stroke=$((point * 4 / 100))
    local offset=$(((band - block) / 2))
    [ "$offset" -lt 0 ] && offset=0

    # `-shadow` pads its blur by twice sigma on every side and moves it by its own
    # offset, and the merge starts the layer at the shadow's top left corner — so
    # the body sits 2 x sigma in from the left and 2 x sigma less the drop from the
    # top. Taking only one sigma off put every device a sigma to the right of centre
    # (17 px on the iPhone, 29 on the iPad), right under a centred heading.
    local sigma=$((W / 70)) drop=$((W / 200))
    magick -size "${W}x${H}" "xc:$bg" \
        \( "$WORK/body.png" \
           \( +clone -background black -shadow "40x${sigma}+0+${drop}" \) \
           +swap -background none -layers merge +repage \) \
        -gravity northwest -geometry "+$((dev_x - 2 * sigma))+$((dev_y - 2 * sigma + drop))" -composite \
        -font "$FONT" -pointsize "$point" \
        -fill "$TEXT" -stroke "$TEXT" -strokewidth "$stroke" \
        -interline-spacing "$((point / 5))" \
        -gravity north -annotate "+0+${offset}" "$text" \
        -crop "${W}x${H}+0+0" +repage \
        -alpha off -depth 8 -strip \
        -define png:compression-level=9 "$dst"
}

WORK="$(mktemp -d -t sudoku-compose)"
trap 'rm -rf "$WORK"' EXIT

sets=0
for loc_dir in "$IN_ROOT"/*; do
    [ -d "$loc_dir" ] || continue
    loc="$(basename "$loc_dir")"
    for dev_dir in "$loc_dir"/*; do
        [ -d "$dev_dir" ] || continue
        dev="$(basename "$dev_dir")"
        case "$dev" in
            iphone-duo) style=duo ;;
            iphone-*)   style=island ;;
            *)          style=plain ;;
        esac
        out="$OUT_ROOT/$loc/$dev"
        # A folder without shots would otherwise reach ImageMagick as the literal
        # pattern `*.png` and stop the run with an "unable to open image" error
        # that names neither the folder nor the cause.
        shots=("$dev_dir"/*.png)
        if [ ! -e "${shots[0]}" ]; then
            echo "no screenshots in $dev_dir — run Tools/appstore_media.sh screenshots, or remove the folder" >&2
            exit 1
        fi
        # Composed aside and swapped in once the whole set is done: a run that fails half-way
        # leaves the last good set whole, and a shot dropped or renamed since then must not
        # linger in the set that goes up.
        staging="$WORK/sets/$loc/$dev"
        mkdir -p "$staging"
        printf '\n\033[1m%s / %s\033[0m\n' "$loc" "$dev"
        for src in "${shots[@]}"; do
            name="$(basename "$src" .png)"
            compose "$src" "$staging/$name.png" "$loc" "$name" "$style"
            printf '  %-16s %s\n' "$name" "$(magick identify -format '%wx%h' "$staging/$name.png")"
        done
        mkdir -p "$out"
        rm -f "$out"/*.png
        mv "$staging"/*.png "$out"/
        sets=$((sets + 1))
    done
done

# An IN_ROOT with no <locale>/<device> folders in it composes nothing, and would
# otherwise end on `du` failing over an OUT_ROOT that was never made.
[ "$sets" -gt 0 ] \
    || { echo "no <locale>/<device> folders in $IN_ROOT — run Tools/appstore_media.sh screenshots first" >&2; exit 1; }
du -sh "$OUT_ROOT"
