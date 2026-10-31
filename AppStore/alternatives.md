# ASO: the reasoning, the competition, and the alternatives

Numbers in brackets are character counts. The limits are 30 for the name, 30 for
the subtitle and 100 for keywords — and the keyword limit alone is counted in
UTF-8 bytes, so a Czech set carries its byte count as well.

Everything below was read off the store on 31 October 2026: ratings and prices
from the iTunes Search and Lookup APIs, subtitles, in-app purchase lists,
privacy labels and age ratings from the product pages, search suggestions from
the App Store's own search hints, and complaints from the last 500 reviews of
six apps (4 694 reviews in all).

## What we are up against

US storefront, by number of ratings:

| App | Subtitle | Developer | Ratings | Age | Money |
|---|---|---|---|---|---|
| Sudoku.com - Number Games | Logic puzzles and mind games | Easybrain | 1 869 075 | 13+ | ads, $14.99 to remove |
| ▻Sudoku - Classic Brain Game | Logic puzzles & Mind games | PeopleFun | 663 849 | 13+ | ads, $2.99 subscription to remove |
| Sudoku - Brain Puzzle Games | Sudoku - Math Puzzles | Oakever | 314 310 | 9+ | ads, subscriptions $1.99/week to $15.99/year |
| Killer Sudoku by Sudoku.com | Math crossword & number puzzle | Easybrain | 218 397 | 13+ | ads, $14.99 to remove |
| ⋆Sudoku | Classic Sudoku Logic Puzzles | Brainium | 161 178 | 13+ | ads, $11.99 to remove |
| Sudoku by Staple Games | by Staple Games | Staple Games | 104 566 | 4+ | free, tracks |
| Sudoku Puzzle - Brain Games | Classic Sudoku & Math Games | Guru Smart | 92 675 | 4+ | Pro $2.99/week, hints $0.99 |
| Sudoku :) | Sudoku Logic Puzzle Card Game | Maple Media | 59 171 | 18+ | ads, $24.99 to disable |
| Sudoku ′ | Sudoku free of distraction | Mind The Frog | 38 683 | 4+ | ads, $1.99 to remove |
| Sudoku ′ No ads | Classic number puzzle game | Mind The Frog | 29 196 | 4+ | **$1.99 to download** |
| Sudoku No Pop-up Ads | Number Games & Puzzles | Faraj Ebrahimi | 11 530 | 13+ | Premium $4.99 |
| Microsoft Sudoku | Microsoft Sudoku | Microsoft | 7 533 | 4+ | Premium $1.99/month |
| Sudoku - Daily Puzzles | Daily Sudoku Puzzles Game | Gamovation | 7 085 | 4+ | ads, $6.99 to remove, coins to $21.99 |
| Sudoku - No ads | sudoku solver & sudoku classic | Beijing Free Calculator | 4 324 | 4+ | $2.99/month, technique courses to **$59.99** |
| Good Sudoku by Zach Gage | Sudoku that loves you | STFJ | 1 332 | 4+ | $4.99 unlock |
| Not Evil Sudoku | Clean, Minimal and No Ads | Ashish Selvaraj | 1 104 | 4+ | Pro $4.99 |
| Sudoku - No Ads & Offline | Classic Logic Brain Puzzle | Nebi Sarigul | 722 | 4+ | $1.99/week to **$49.99** lifetime |
| Sudoku - Quiet | Calm, ad-free, offline Sudoku | Jingeun Kim | 12 | 4+ | free |

Every free app in the table with more than 7 000 ratings carries a *Data Used
to Track You* label. The only ones whose label reads *Data Not Collected* are
*Sudoku - No Ads & Offline* and *Sudoku - Quiet* — 722 and 12 ratings.

Five things follow from that table.

**We cannot win the head term.** Easybrain sits on "sudoku" with 1.87 million
ratings and the next four apps have six figures each. A new app with no ratings
does not rank on the bare word, whatever it puts in its name: the developer of
*Not Evil Sudoku* reported rank #138 for "sudoku" after 18 000 installs and a
front-page Reddit post. Chasing the word is how you end up with no traffic at
all; *sudoku* is in the name because it has to be, not because it will rank.

**The long tail is winnable, and the name decides it.** A US search run on the
same day:

| Search | #1 | #2 | #3 |
|---|---|---|---|
| sudoku offline | Sudoku.com (1.87 M) | *Sudoku Offline - Puzzle Game* (**29**) | *Sudoku Classic -Offline Puzzle* (1 106) |
| sudoku no ads | *Sudoku No Pop-up Ads* (11 530) | *Sudoku - No Ads & Offline* (726) | *Sudoku ′ No ads* (29 196) |
| sudoku hints | *SUDOKU HINTS* (**0**) | *Sudoku Solver: Hint or Solve* (1 839) | Sudoku (No Limits) (8 449) |
| learn sudoku | *Sudoku Tutor* (151) | *Phidoku: Snap & Learn Sudoku* (**0**) | Sudoku.com |
| sudoku daily | *Sudoku a Day* (805) | *Sudoku - Daily Puzzles* (7 086) | Sudoku.com |
| sudoku techniques | *SUDOKU - TheSudoku.com* (110) | Sudoku Puzzle - Brain Games | ⋆Sudoku |

An app with 29 ratings sits second for *sudoku offline* and one with none tops
*sudoku hints*, both on the strength of having the words in the name. That is
the whole strategy here: the name and the subtitle buy the modifiers, and the
ratings come later.

**The modifiers people actually type are "no ads" and "offline".** Apple's own
search suggestions, which list completions in order of popularity, give for
*sudoku*: `free no ads`, `sudoku.com`, `no ads`, `offline`, `master`, `a day`,
`blast!`, `friends`, `solver`. For *sudoku n…*: `no ads`, `no pop-up ads`,
`no wifi`, `ny times`, `no ads offline`, `no timer`, `no mistakes`. For *sudoku
f…*: `free no ads`, `for kids`, `for beginners`, `free no ads offline`, `for
seniors`. *sudoku d…* starts with `dark mode`; *t…*, *c…* and *h…* bring
`tutor`, `trainer`, `coach`, `custom` and `hint`. *No ads* turns up in two of
the top three, *offline* in four of the first twenty — and this app is one of
the very few that can claim both honestly.

**The whole category is monetised, including the apps whose names promise it is
not.** *Sudoku - No Ads & Offline* sells a $49.99 lifetime subscription;
*Sudoku - No ads* sells technique courses at up to $59.99 and, according to its
reviews, makes free players wait three minutes between games; *Sudoku No Pop-up
Ads* only promises that its ads won't pop up, and sells a $4.99 Premium. Oakever's
description promises an "Ad-Free Game Environment", while ads come up in 82 % of
its negative reviews, some of them in so many words: "they lied". The honest version of the promise — no ads,
no purchases, no account, no tracking, and no networking code in the binary at
all — is the differentiator, and it is not a small one.

**Teaching is what the best-loved apps win on, and nobody gives it away.**
*Good Sudoku* is the app every "best of" list names for teaching techniques —
and it costs $4.99, has not been updated since July 2025 and no longer starts
offline. *Sudoku - No ads* charges up to $59.99 for its courses. Reviewers who
praise any sudoku app praise the hints that name the technique ("Today I learned
about the Y-Wing!"); reviewers who pan Brainium's ask what "trial and error has
shown this box to be X" is supposed to teach them. A free app whose hints
explain 24 named techniques on the board, with no guessing ever needed, has the
field to itself.

## What players complain about, and what they ask for

Share of the 1–2★ reviews in each app's last 500:

| Complaint | Sudoku.com | Brainium | PeopleFun | Good Sudoku | "No ads" | Oakever |
|---|---|---|---|---|---|---|
| Ads | 87 % | 63 % | 74 % | 18 % | 19 % | 82 % |
| Ads in the middle of a game | 30 % | 6 % | 29 % | 5 % | 1 % | 17 % |
| Needs the internet / stuck loading | 1 % | 2 % | **28 %** | **23 %** | 0 % | 4 % |
| Subscriptions, waits, price | 7 % | 4 % | 3 % | 7 % | **40 %** | 7 % |
| Bugs, lost progress or streaks | 2 % | 14 % | 5 % | **33 %** | 5 % | 4 % |

PeopleFun made the internet mandatory in December 2025 ("I play sudoku mostly
when I'm on a plane, and guess what, no internet!"), which is why *offline*
belongs in the name rather than further down the description.

What reviewers wish for, in their own words, is almost a feature list of this
app: dark mode (28 of Sudoku.com's last 500 reviews), a number-first input
that locks a digit, switching mistake checking off, a calendar to go back to
missed daily puzzles, a harder top level, and "I can't put in my own game".
Each of those has its line in the description, and the screenshots show dark
mode, the calendar and the custom puzzle.

## The Czech storefront is small, and that is the opportunity

Searching *sudoku* in Czechia returns the international apps, mostly with
English names and untranslated interfaces. The ones with a Czech listing:

| CZ name | CZ subtitle | Developer | CZ ratings | App in Czech |
|---|---|---|---|---|
| Sudoku.com – Logická hra | Klasické číselné křížovky | Easybrain | 20 764 | no |
| Sudoku - klasické sudoku | Denní Sudoku Puzzle hry | Oakever | 4 260 | yes |
| Killer Sudoku od Sudoku.com | Řešte číselné hádanky! | Easybrain | 1 894 | no |
| Sudoku # | Sudoku (Soduko) | Jinyang Tang | 837 | yes |
| Sudoku ∙ Logické Myšlení Hra | Číslo Hry - #1 Trénink Sudoku | nerByte | 482 | yes |
| Sudoku - rébus na každý den | — | Gamovation | 325 | yes |
| Sudoku - Žádné reklamy Sudoku | Sudoku hry & Sudoku | Beijing Free Calculator | 144 | yes |
| Hintoku: Tvůj Sudoku trenér | Sudoku lekce + chytré nápovědy | hlm solutions | 7 | no |
| Sudoku offline bez reklam | Klasický logický hlavolam | Nebi Sarigul | 6 | yes |

Below Sudoku.com — which is not even translated — the whole Czech market tops
out at about 4 300 ratings, and past the third row in the hundreds. This is the
storefront where a good listing actually moves the ranking, and the translation
already exists.

Three findings shaped `cs/`:

- **The Czech suggestions are the English ones, translated.** Apple suggests
  `sudoku zdarma`, `sudoku offline` and `sudoku bez reklam` for *sudoku*, and
  `hry bez wifi`, `hry bez reklam`, `hry bez internetu` for *hry bez*, plus
  `hlavolamy` and `logické hry`. The name takes *offline* and *bez reklam*; the
  keyword field takes the rest, except *zdarma* (guideline 2.3.7 keeps prices
  out of every metadata field, see Keywords).
- **Machine-translated listings are the norm, and they read like it.** *Číslo
  Hry - #1 Trénink Sudoku*, *Sudoku - Žádné reklamy Sudoku*, *Denní Sudoku Puzzle
  hry*. A listing written in plain Czech stands out on that page by itself.
- **Apple's Czech stemming cannot be trusted.** *hra* and *hry*, *hlavolam* and
  *hlavolamy* are not reliably linked, so the form people type — the one Apple
  suggests — is the one that goes in, and *hra* and *hry* both earn their bytes.

The closest Czech competitor in spirit is *Hintoku* (a Czech developer, hints
and lessons), with seven ratings and no Czech interface yet. Its subtitle uses
*chytré nápovědy* too; the phrase is generic, and there is no better Czech
for "smart hints", but if it ever reads like an echo, *Výuka technik a denní
výzvy* (27) is the swap below.

## What is in use

```
en-US   Sudoku Offline: Hints, No Ads  (29)   Daily puzzle, learn techniques  (30)
cs      Sudoku bez reklam, offline     (26)   Denní výzvy a chytré nápovědy   (29)
```

Between the name and the subtitle, `en-US` indexes *sudoku, offline, hints, no,
ads, daily, puzzle, learn, techniques* — and because Apple combines terms within
a locale, across the name, subtitle and keyword field alike, that assembles
*sudoku offline*, *sudoku no ads*, *sudoku no ads offline*, *sudoku hints*,
*learn sudoku*, *sudoku daily*, *daily sudoku puzzle* and *sudoku techniques*
without spending a single keyword character on any of them; with the keyword
field, *sudoku no wifi*, *sudoku no timer*, *sudoku dark mode*, *sudoku for
beginners*, *sudoku for seniors* and *calm sudoku* join them.

Word order: `Hints, No Ads`, not `No Ads & Hints` — the second reads as "no ads
and no hints", which is the opposite of the app. And `Sudoku Offline`, not
`Offline Sudoku`: Apple matches the words in any order, but the name reads left
to right, and leading with the head term is worth more than matching the phrase
word for word.

## App name

| Czech | | English | |
|---|---|---|---|
| Sudoku bez reklam, offline | (26) | Sudoku Offline: Hints, No Ads | (29) |
| Sudoku bez reklam a offline | (27) | Sudoku Offline: Learn & Play | (28) |
| Sudoku offline s nápovědou | (26) | Sudoku No Ads: Daily & Hints | (28) |
| Sudoku: nápovědy bez reklam | (27) | Sudoku Offline – No Ads | (23) |
| Sudoku offline: denní výzvy | (27) | Sudoku: Hints That Teach | (24) |

Recommendation: keep *offline* and *no ads* in the name. They are the two
modifiers people type most, they are exactly what the competition fails at, and
the long-tail table above shows that the name is what ranks for them.

In Czech the words come in that order, `bez reklam, offline`, for a reason: Nebi
Sarigul's Czech listing is *Sudoku offline bez reklam* (see the table above), so
`Sudoku offline: bez reklam` would differ from it by a colon alone. App Store
Connect may refuse such a name as taken, and in search results it would read as a
copy of an app that sells a subscription. Apple matches the words in any order,
so the order costs nothing in search. `Sudoku bez reklam a offline` would repeat
the subtitle's *a*.

Deliberately **not** the choice:

- `Sudoku - Daily Puzzles` or anything close to it — that is Gamovation's app
  (7 085 ratings), and a near-identical name buys their leftovers while making
  the listing look like a clone. *daily* lives in the subtitle instead.
- `Sudoku - No Ads & Offline` — Nebi Sarigul's name, word for word, and the app
  behind it sells a $49.99 subscription. Standing next to it with the same name
  invites exactly the comparison this listing is trying to escape.
- `Sudoku Master …` — *Sudoku Master®* is a registered name (MALPA Games). The
  keyword field does carry *master*, and that is closer to the name than it
  looks: Apple combines terms across the name, the subtitle and the keyword
  field (see above), so the name's *sudoku* and the keyword's *master* make
  this listing match a search for *sudoku master* — which is also their app's
  name typed into the search field. It stays because the word is descriptive
  here: Master is one of this app's five levels, named in the app and in the
  description, and *master* is what players type when they want the hardest
  puzzles. Nothing visible pairs the two words, so nothing in the listing reads
  as theirs. The risk left is a reviewer seeing the keyword as leaning on a
  trademark (guideline 2.3.7) — low for a word that names a real level, and if
  it is ever raised, *master* is the keyword to drop.

There is no brand name here on purpose. The app is called Sudoku on the home
screen and plays sudoku, and in a category where the top names are all the
word plus a qualifier, a made-up brand would cost ranking and buy nothing. If a
brand is ever wanted anyway, put it *after* the head terms — never in front of
them.

## Subtitle

| Czech | | English | |
|---|---|---|---|
| Denní výzvy a chytré nápovědy | (29) | Daily puzzle, learn techniques | (30) |
| Výuka technik a denní výzvy | (27) | A daily puzzle that teaches | (27) |
| Nápovědy, které učí. Denně. | (27) | Learn techniques, no account | (28) |
| Bez účtu, bez wifi, s nápovědou | (31 ✗) | No wifi, no account, dark mode | (30) |
| Pět úrovní a denní výzvy | (24) | Hints that teach, not just tell | (31 ✗) |

The best line in the whole listing — *Hints that teach, not just tell* — is one
character too long for the subtitle, which is why it heads the first screenshot
instead.

There is no `en-GB` any more (dropped in November 2026): the UK, Ireland,
Australia and New Zealand read `en-US`. It used to duplicate `en-US`, trading
only *tutor* for *coach* in the keyword field — sudoku has no US/UK vocabulary
split to exploit.

**No price in the metadata, in any language.** Guideline 2.3.7 asks not to pack
*any* of it with pricing information — the name, the subtitle and the keyword
field alike — and *zdarma* / *free* is the wording that gets metadata rejected.
"No ads" / "bez reklam" is not a price and is fine. Free-to-download is already
stated by the price on the product page.

## Keywords

In use:

```
en-US  master,solver,beginner,classic,dark,mode,wifi,timer,senior,tutor,brain,logic,number,game,expert,calm  (100)
cs     hlavolamy,logické,hry,hra,wifi,internetu,česky,techniky,klasické,číselné,trénink,mozku,výuka          (92 / 100 bytes)
```

Why these, in English:

- Not *free*, although it is the single most common addition to "sudoku" in
  Apple's suggestions: guideline 2.3.7 keeps pricing information out of all
  metadata, the keyword field included. The name's *no ads* and *offline* still
  match the rest of *sudoku free no ads offline*.
- *master*, *expert* — two of the five levels, and what players type when they
  want a hard puzzle. *hard* and *easy* are the other three levels' words and
  were left out: they are too short a query to be anything but noise.
- *solver* — Apple's ninth suggestion. Honest here: type a puzzle in from the
  newspaper and the hints solve it with you step by step.
- *beginner*, *senior* — *for beginners* and *for seniors* are both top
  suggestions, and Apple pairs an English singular with its plural. (*kids* is
  left out on purpose: guideline 2.3.8 reserves "for kids" for the Kids
  category.)
- *dark*, *mode* — *sudoku dark mode* is the first suggestion under *d*, and the
  most requested missing feature in Sudoku.com's reviews.
- *wifi*, *timer* — with the name's *no*: *sudoku no wifi*, *sudoku no timer*.
  The timer can be hidden in Settings.
- *tutor* / *coach* — what the hints are; both are suggested.
- *classic*, *brain*, *logic*, *number*, *game* — the generic combinations:
  *classic sudoku*, *sudoku game*, *logic puzzle*, *number puzzle*, *brain game*.
- *calm* — *calm sudoku*, *calm puzzle game*: what an app without ads,
  pop-ups or a forced timer is, in the words people use for it.

In Czech, *techniky*, *výuka*, *trénink* and *mozku* (*trénink mozku*) carry the
learning side, *klasické* and *číselné* the generic phrases, *česky* the
`hlavolamy česky` suggestion, and *wifi* and *internetu* combine with the name's
*bez* into *bez wifi* and *bez internetu*.

Alternative sets, if you end up tuning by performance:

```
# EN, no-strings angle (leans hardest on the differentiator)
calm,wifi,internet,account,tracking,subscription,purchases,premium,timer,mistakes,classic,game,brain  (100)

# EN, learning angle (pairs with a "Learn every technique" subtitle)
tutor,coach,trainer,beginner,lessons,guide,xwing,swordfish,strategy,tips,tricks,logic,solver,game  (97)

# EN, daily-habit angle
streak,calendar,challenge,today,morning,routine,relax,calm,brain,training,classic,logic,game  (92)

# CZ, learning angle
techniky,naučit,začátečníky,výuka,trenér,nápověda,logické,hry,hlavolamy  (71 / 81 bytes)
```

Rules, so that editing does not break it:

- Separate with a comma and **no space after the comma** — a space counts towards
  the limit of 100.
- Do not repeat words from the name or the subtitle, Apple indexes those
  separately. **This applies between the name and the subtitle too.** That is why
  *sudoku*, *offline*, *hints*, *no*, *ads*, *daily*, *puzzle*, *learn* and
  *techniques* are absent from the English lists, and *sudoku*, *offline*, *bez*,
  *reklam*, *denní*, *výzvy*, *chytré* and *nápovědy* from the Czech one.
- Do not put a plural next to its singular ("beginner" and "beginners"), Apple
  pairs them itself. The Czech set does not get that service — see *hra*/*hry*
  above.
- **Do not name competing games or apps** — grounds for rejection, and the
  temptation is strong in a category this crowded. *sudoku.com*, *easybrain*,
  *brainium*, *killer* (Easybrain's *Killer Sudoku*, and a variant this app does
  not have), *nyt* and *good sudoku* are all other people's names or products.
- Do not reach for a word just because it fits. *killer*, *jigsaw*, *kids*,
  *multiplayer* and *friends* are all popular and all lies here.
- No *free* / *zdarma*, here or anywhere else: guideline 2.3.7 lists pricing
  information among the things not to pack metadata with.

## Shorter description, if you decide on a terser version

Each paragraph is one long line on purpose. App Store Connect keeps newlines
exactly as pasted, so a paragraph wrapped at 80 columns here comes out ragged on
the device while every other paragraph reflows — paste these as they are.

**EN**

```
Sudoku that teaches you how to solve it. Stuck? A hint first points you to the right row, column or box; Show Me then explains the exact step on the board, with the cells highlighted and the chains drawn — 24 techniques, from Hidden Singles to X-Wings and XY-Chains.

Five honest levels, graded by the techniques a puzzle really needs, not by how many numbers are given. Every puzzle has one solution and needs no guessing.

A new daily challenge every day, with streaks and a calendar of the last two years. Notes, auto notes and unlimited undo, statistics and 22 achievements, dark mode and 8 colors. Type in a puzzle from the newspaper and the hints work on it too, as long as it needs nothing beyond their 24 techniques.

No ads. No purchases. No account. No internet.
```

**CZ**

```
Sudoku, které vás naučí luštit. Zasekli jste se? Nápověda vás nejdřív navede na správný řádek, sloupec nebo čtverec; Ukázat pak přímo v mřížce vysvětlí přesný krok, se zvýrazněnými poli a nakreslenými řetězci – 24 technik, od jediného místa po X-Wing a XY-řetězce.

Pět poctivých úrovní podle technik, které sudoku opravdu vyžaduje, ne podle počtu zadaných čísel. Každé sudoku má jediné řešení a nevyžaduje hádání.

Každý den nová denní výzva se sériemi a kalendářem za dva roky. Poznámky, automatické poznámky a neomezené vracení tahů, statistiky a 22 úspěchů, tmavý režim a 8 barev. Přepište si sudoku z novin a nápovědy fungují i na něm, pokud nepotřebuje víc než jejich 24 technik.

Bez reklam. Bez nákupů. Bez účtu. Bez internetu.
```
