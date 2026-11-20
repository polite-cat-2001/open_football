# Andorra — football pyramid 2026-27

Scope: level 1 only (Primera Divisió). Segona Divisió is not in our rows. No cups, no European places.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/Primera_Divisi%C3%B3 | `teams = 10`, relegation to Segona Divisió, current season 2026-27, historical note that the size has changed |
| https://en.wikipedia.org/wiki/2025%E2%80%9326_Primera_Divisi%C3%B3 | 10 clubs, "play each other three times", `result9=RPO`, `result10=REL`, Pas de la Casa expulsion, promotion from Segona |

No `2026-27 Primera Divisió` article exists yet on the English or Catalan Wikipedia (several title
forms returned 404), and the federation site (faf.ad) was not read. The 2026-27 description below is
the 2025-26 shape, which the league's own article presents as current.

## League

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| AND1 | Primera Divisió | 1 | 10 | 27 rounds, triple round-robin | — (top) | 2 (1 direct + 1 play-off) |

Our row (AND1, level 1, 10 clubs) is correct. The infobox says 10; the prose still describes an older
eight-club split season (see conflicts).

## Format

- 10 clubs, every pair meets **three times**, 27 matches each. No split, no groups, no points carried.
- 10th is relegated to the Segona Divisió; 9th plays a **two-legged** play-off against the Segona
  Divisió runner-up. The Segona champion is promoted directly.
- A club can also lose its place off the pitch: in 2025-26 Pas de la Casa was expelled by the
  competition committee after three matchdays for fielding too few registered players, which cut the
  season to 24 matches per club. That is why the 2025-26 article says "twenty-four matches" for a
  10-club league.

## Boundary 1–2

Only one route exists in each direction and it is the same tie:

- Up: Segona champion direct; Segona runner-up enters the play-off.
- Down: 10th direct; 9th enters the play-off.
- The play-off winner takes the Primera Divisió place, so exactly one of {Primera 9th, Segona runner-up}
  is in the top flight next season and the league stays at 10.

Allocation is `free` — Andorra has no regional tiers below level 2 — and selection is `bottom_n`.

Since level 2 is not in our list, the league is marked `closed_down: true` even though the 10th club
really does go down; the movement is described here and in `notes`.

## Conflicts

The Primera Divisió overview article still says: "The eight clubs ... play each other three times ...
after the first 21 rounds, the league splits in half, into a top four and bottom four ... 27 games ...
the last placed of the relegation round is relegated, the penultimate plays a two-legged play-off."
That describes the pre-2020 eight-club format. The 2025-26 season article and the infobox both say
ten clubs and show a single 27-round table with the 9th/10th rule and no split. The ten-club version is
what is recorded.

## Oddities

- With 10 clubs and three meetings, one club in each pair hosts twice — home advantage is unbalanced
  by design, and the third-round venues are not drawn by position as in some other leagues.
- A club can be removed mid-season for licensing/registration reasons (Pas de la Casa), so a sim
  should not assume 10 clubs finish the season.

## Confidence

**Medium.** Ten clubs, three meetings, 10th down and 9th in a two-legged play-off against the Segona
runner-up are consistent between the league article and the 2025-26 season article; the 2026-27
season itself has no published article yet, and the league article's prose is stale.
