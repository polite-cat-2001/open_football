# North Macedonia — football pyramid 2026-27

Research for the career simulation. Scope: level 1 (1. MFL) only; the Second League
(tier 2) is described because it feeds the top flight, but it is not in our list, so
the top flight is closed downwards in our data. Cups and UEFA places are out of scope.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Macedonian_First_Football_League | 2026-27: 10 clubs, 13 rounds played by 8 November, promotion/relegation changes, the table's marks (8th play-off, 9th-10th relegation) |
| https://en.wikipedia.org/wiki/Macedonian_First_Football_League | infobox (10 clubs), the club-count history 10 clubs 2014-2020, 12 clubs 2020-2026, 10 from 2026; relegation to 2. MFL; the play-off description |
| https://en.wikipedia.org/wiki/2019%E2%80%9320_Macedonian_First_Football_League | the last 10-club season: "each team will play the other sides four times ... 36 matches" |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Macedonian_Second_Football_League | 2. MFL 2026-27: one 14-club division, 1st-2nd promotion, 3rd into the top-flight play-off |

## League

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| MAZ1 | Prva Makedonska Fudbalska Liga | 1 | 10 | 36 rounds (four meetings) | — (top) | 2 (9th, 10th) + 1 play-off (8th) |

Our 10 and level 1 are correct, and 2026-27 is the first 10-club season since 2019-20.
The league had 12 clubs and 33 rounds from 2020-21 to 2025-26; the shrink to 10 is why
five clubs were relegated in 2025-26 (8th lost the play-off, 9th-12th went down) and
three came up.

## Format

- 10 clubs, four meetings each: 36 rounds, 180 matches. The 2026-27 season page does
  not print a round count, but its match total (65 matches after 13 rounds) is
  consistent with five matches per round, and the last 10-club season (2019-20) played
  36 rounds. Treat the number as derived rather than quoted.
- No split, no play-off for the title: champion on points.

## Promotion and relegation

- 9th and 10th are relegated directly to the 2. MFL.
- 8th plays a play-off against the winner of the 2. MFL promotion tie; the loser goes
  down, the winner stays. For 2026-27 the 2. MFL is a single 14-club division whose
  top two go up directly and whose 3rd enters that play-off, so the play-off is
  "1. MFL 8th v 2. MFL 3rd".
- **Outdated text:** the league article still describes the play-off as "the eighth
  placed team ... against the winner of the tie between second placed teams of the two
  groups". That was the two-group Second League format, abandoned in 2021-22; the
  2026-27 2. MFL table marks its 3rd place as the play-off entrant instead. Use the
  current single-division reading.

## Decisions

1. **`format.rounds: 36`** with a note; the number is derived from 10 clubs playing
   four times each, not quoted from a 2026-27 source.
2. **`playoff: {"kind": "relegation", "entries": "8th"}`**, `legs: null` — the tie's
   two-leg/single-match format is not stated in any source read.
3. **`closed_up`/`closed_down` both true, no boundaries.** Only one Macedonian row.
4. **No split.** Points are not carried anywhere and the title is decided by the table.

## Oddities

- The 2026-27 table already shows Skopje on 4 points from 13 games (0 wins, 4 draws),
  and Struga top on 29; the season is unusually compressed at the bottom, but that is
  form, not structure.
- The 10-club shrink makes the 2026-27 division the smallest top flight in the
  league's post-1992 history apart from 2014-2020.

## Confidence

**Medium-high.** Size (10), level, the promotion/relegation marks and the 2. MFL
structure are explicit. The 36-round figure is inferred from the club count and the
previous 10-club season; the play-off's match format is unknown.
