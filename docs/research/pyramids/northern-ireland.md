# Northern Ireland — football pyramid 2026-27

Research for the career simulation. Scope: levels 1-2 as carried in our database (the
new NCL Premier at level 3 is outside it). Cups and European places are out of scope.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_NIFL_Premiership | 2026-27: 12 clubs, 22 + 11 + 5 rounds, Section A/B split, one promotion from the Championship, one relegation |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_NIFL_Championship | 2026-27: 16 clubs, 30 + 7 rounds, top eight/bottom eight split, who goes up, the 15th-place play-off |
| https://www.nifootballleague.com/media/21084/nifl-championship-rules-2026-27.pdf | cited by the Championship article for the new 16-club format (not read directly) |

## Leagues

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| NIR1 | NIFL Premiership | 1 | 12 | 38 rounds, split 6/6 after 33 | — (top) | 1 direct + 1 play-off |
| NIR2 | NIFL Championship | 2 | 16 | 37 rounds, split 8/8 after 30 | 1 direct + 1 play-off | 1 direct + 1 play-off |

Both sizes and levels are correct, and 2026-27 is the **first** Championship season with
16 clubs (expanded from 12; four clubs came up from the Premier Intermediate League and
none went down). Treat anything seeded from 2025-26 history as a 12-club Championship.

## Premiership format

- 12 clubs: rounds 1-22 home and away, rounds 23-33 a third meeting with each opponent
  (home or away), then the table splits into **Section A** (1st-6th) and **Section B**
  (7th-12th). Each section plays its five rivals once more, so every club plays 38
  matches. Points and results carry over.
- The fixture list for rounds 34-38 is the reverse of rounds 23-33, so each club ends up
  with two home and two away meetings against every club in its own section.
- The champion is the Section A winner. No title play-off.

## Championship format

- 16 clubs, double round-robin for 30 rounds, then a split into **Section A** (1st-8th)
  and **Section B** (9th-16th) for seven more matches (37 rounds total). Points carry.
- Section A winner is the champion and is promoted; Section A runner-up goes to the
  two-legged play-off against the Premiership's second-bottom club.
- Section B bottom club is relegated; 15th plays the NCL Premier runner-up (level 3,
  not modelled).

## Boundary 1-2

| between | up | of which PO | down | of which PO | allocation | selection |
| --- | --- | --- | --- | --- | --- | --- |
| 1-2 | 2 | 1 | 2 | 1 | free | bottom_n |

The play-off is **shared**: the Championship runner-up plays the Premiership 11th over
two legs. Exactly one of {Premiership 11th, Championship runner-up} is in the top
flight next season, which is why 2 up and 2 down both keep the sizes at 12/16.

- Up: Championship champion directly, runner-up if it wins the play-off.
- Down: Premiership 12th directly, 11th if it loses the play-off.
- No licence or geography gate is described in these sources; entry is by league
  membership (the Premiership requires a licence, but that was not verified here and is
  not encoded).

## Decisions

1. **`format.kind: "split"` for both**, with `split_after` 33 / 30, `groups` [6,6] and
   [8,8], `points_carry: true`.
2. **`rounds` 38 and 37** — the maximum, reached by every club because both sections
   are even.
3. **`allocation: "free"`** — no regional split and no quota; a relegated or promoted
   club joins the other division as itself.
4. **NIR2 `closed_down: true`** — its relegation goes to the NCL Premier, which is not
   in our list. Its promotion place is real, hence `closed_up: false`.

## Oddities

- The Championship expanded to 16 for 2026-27 and **no club was relegated** in 2025-26
  because of that. A sim carrying 2025-26 outcomes forward will look wrong.
- Glenavon, relegated from the Premiership in 2026, is in the Championship this season;
  the same club can appear in both our rows across seasons, which is expected.
- Section labels ("Section A/B") replaced the older "Championship/Relegation split"
  wording; the mechanics are unchanged.

## Confidence

**High.** Both sizes, both round counts, both split points and the shared play-off are
stated explicitly in the 2026-27 season articles and match the league's own fixture
lists. Only the licensing side of promotion is unverified.
