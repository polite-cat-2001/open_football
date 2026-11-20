# Belarus — football pyramid 2026 (season 2026)

Scope: levels 1–2 (Vysheyshaya Liga, Pershaya Liga). Season 2026, calendar year — the season that
overlaps the 2026-27 career year. No cups, no European places (Belarusian clubs are currently banned
from UEFA competitions).

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026_Belarusian_Premier_League | 16 clubs, "30 matches each", `result14=RPO`, `result15-16=REL`, the two-legged play-off against the First League 3rd, the 2025-26 promoted/relegated trio |
| https://en.wikipedia.org/wiki/Football_in_Belarus | the league-system table: level 1 = 16 clubs, level 2 = 18 clubs |
| https://en.wikipedia.org/wiki/Belarusian_First_League | level 2 = 18 clubs, promotion to the Premier League, relegation to the Second League |

## Leagues

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| WER1 | Vysheyshaya Liga | 1 | 16 | 30 rounds, double round-robin | — (top) | 3 (2 direct + 1 play-off) |
| WER2 | Pershaya Liga | 2 | 18 | 34 rounds, double round-robin | 3 (2 direct + 1 play-off) | to Second League (not modelled) |

Both sizes in our rows are correct: 16 and 18.

## Format

- Premier League: 16 clubs, each plays every other home and away once = **30 matches**. No split, no
  groups, no carried points. Season 20 March – 29 November 2026.
- First League: 18 clubs, double round-robin = **34 matches** (the number follows from the size; the
  league article's "30 matchdays" describes the 16-club seasons).
- Both are plain tables; there is no championship/relegation round anywhere in the Belarusian pyramid.

## Boundary 1–2

| between | up | of which PO | down | of which PO | allocation | selection |
| --- | --- | --- | --- | --- | --- | --- |
| 1–2 | 3 | 1 | 3 | 1 | free | bottom_n |

- Down: 15th and 16th directly; **14th** plays a **two-legged** play-off against the First League's
  **3rd**.
- Up: First League champion and runner-up directly (Baranovichi and Dnepr Mogilev came up that way for
  2026); the 3rd-placed club (Belshina Bobruisk) won the play-off against the Premier League 14th
  (Smorgon) and went up too.
- So 3 up and 3 down every season, one of them decided by the same tie.

The First League's own relegation (to the Second League, level 3) is outside our data, which is why
WER2 is marked `closed_down: true`.

## Oddities

- The play-off is two-legged and pairs a specific position (14th) with a specific position (3rd), so
  the 14th-placed club is not "safe" and the 3rd-placed First League club is not "promoted" — both
  depend on one tie.
- The 2026 season began with three clubs replaced (two relegated directly, one after losing the
  play-off) and three arriving, which is the steady state of this boundary.

## Confidence

**High.** Sizes, 30 rounds, the 14th/15th/16th split, the two-legged play-off and the 3rd-place pairing
all come from the 2026 season article, and the 16/18 pyramid sizes are corroborated by the
Football in Belarus league-system table.
