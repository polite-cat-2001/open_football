# England — football pyramid 2026-27

Research for the career simulation. Scope: levels 1-6 as carried in our database. Cups
(FA Cup, EFL Cup, EFL Trophy, FA Trophy) and European qualification are out of scope.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/English_football_league_system | level structure, sizes, promotion/relegation counts for levels 1-8, the 2026-27 Championship play-off change |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Premier_League | season is live: "twenty teams are competing", 33 weekend + 5 midweek rounds |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_EFL_Championship | 46 matchdays; "first season following the expansion of the post season play-offs from four teams to six"; quarter-final/semi-final table legend |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_EFL_League_One | 46 rounds (12 matches per round), play-off legend |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_EFL_League_Two | 46 rounds (12 matches per round), play-off legend |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_National_League | "Twenty-four teams are competing"; "The National League North consists of 24 teams"; "The National League South also consists of 24 teams" |
| https://en.wikipedia.org/wiki/National_League_System | promotion/relegation wording per step: "Champion and winner of 2nd-7th play-off", 4 down from each of steps 1 and 2 |
| https://en.wikipedia.org/wiki/National_League_(English_football) | 72 clubs = 24 + 24 + 24, each club plays the others twice, 2 up / 4 down, geography decides North vs South |

Cross-checks attempted on official sites: `efl.com/competitions/league-one/` and
`thenationalleague.org.uk` return JS shells with no tables, `premierleague.com` is the same. Sizes
were therefore confirmed arithmetically from the season articles (24 clubs x 46 rounds = 12 matches
per round in every fixture list) and from the structural statement on the pyramid page ("three
divisions of 24 clubs each").

## Leagues

| id | name | level | size | rounds | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| GB1 | Premier League | 1 | 20 | 38 | — (top) | 3 |
| GB2 | Championship | 2 | 24 | 46 | 3 (2 auto + 1 PO) | 4 |
| GB3 | League One | 3 | 24 | 46 | 3 (2 auto + 1 PO) | 4 |
| GB4 | League Two | 4 | 24 | 46 | 4 (3 auto + 1 PO) | 2 |
| CNAT | National League | 5 | 24 | 46 | 2 (1 auto + 1 PO) | 4 |
| NLN6 | National League North | 6 | 24 | 46 | 2 (1 auto + 1 PO) | 4 |
| NLS6 | National League South | 6 | 24 | 46 | 2 (1 auto + 1 PO) | 4 |

Every division is one table, double round-robin. All seven rows in our database are correct on
level and size — nothing needed changing.

Level 6 is not a floor: each of NLN/NLS sends its bottom four to level 7 (Northern Premier,
Southern League, Isthmian), which is outside our data, so `closed_down` is false everywhere.

## Boundaries

| between | up | of which PO | down | of which PO | allocation | selection |
| --- | --- | --- | --- | --- | --- | --- |
| 1-2 | 3 | 1 | 3 | 0 | free | bottom_n |
| 2-3 | 3 | 1 | 4 | 0 | free | bottom_n |
| 3-4 | 4 | 1 | 2 | 0 | free | bottom_n |
| 4-5 | 2 | 1 | 4 | 0 | free | bottom_n |
| 5-6 | 4 | 2 | 4 | 0 | by_geography | bottom_n |

- 1-2: Championship top two plus a play-off, **now 3rd-8th**. From 2026-27 the EFL expanded the
  Championship play-offs from four to six clubs: 5th hosts 8th and 6th hosts 7th in one-leg
  quarter-finals, 3rd and 4th go straight to two-leg semi-finals, final at Wembley. This is the only
  competition-format change affecting the 2026-27 pyramid.
- 2-3, 3-4: classic four-club play-offs (3rd-6th and 4th-7th), two-leg semis, one-leg final.
- 4-5: National League champion plus the 2nd-7th play-off winner; League Two's bottom two drop into
  the single national division, so the allocation is free.
- 5-6: the only geographic boundary. Each level-6 division contributes its champion and one
  play-off winner from 2nd-7th; the National League's bottom four are placed in North or South by
  the NLS Committee, mostly by geography, and clubs are moved sideways between the two divisions
  afterwards to even up the numbers. That balancing transfer is a real mechanic a career sim should
  reproduce, or at least tolerate.

Arithmetic closes: 20 - 3 + 3 = 20; 24 - 3 - 3 + 3 + 3 = 24; 24 - 3 - 4 + 3 + 4 = 24;
24 - 4 - 2 + 4 + 2 = 24; 24 - 2 - 4 + 2 + 4 = 24.

## Decisions

1. **`up`/`down` are per boundary, not per league.** `up` counts clubs leaving the lower division
   upward, `down` counts clubs leaving the upper division downward. They are equal wherever the
   pyramid is stable (all five boundaries here).
2. **`up_playoff` counts promotion places decided by a play-off**, not clubs entering one. So
   boundary 1-2 has `up_playoff: 1` even though six clubs play it.
3. **`selection` is always `bottom_n`** because relegation is purely positional at every boundary.
   Promotion is structural (champion / play-off) and is spelled out in `note` instead.
4. **`format.kind: "single"`** = one table, everyone plays everyone home and away. No splits, no
   groups anywhere in levels 1-6.
5. **Not modelled:** ground grading and financial criteria. Promotion from the National League and
   from step 2 upwards is conditional on those, and a club without the ground is replaced by the
   next eligible one. A career sim that ignores this will promote clubs that could not really go up.
6. **Excluded:** FA Cup, EFL Cup, EFL Trophy, FA Trophy, and European places (including the
   Premier League's fifth Champions League spot). They do not affect promotion or relegation.

## Oddities

- `2026–27 National League North` on Wikipedia is a redirect to a **rugby union** page
  (`2026–27 National League 2 North`). The football content for both level-6 divisions lives inside
  the parent `2026–27 National League` article, which is why that one page confirms all three
  division sizes.
- The pyramid page still says the Championship play-off is "the next six teams" while an older
  sentence above it says four; the six-team version is the current one and is confirmed by the
  2026-27 Championship article and its quarter-final/semi-final column legend.

## Confidence

**High.** Sizes and levels are confirmed twice each (structural statement + season article), the
round counts fall out of the fixture lists, and the one 2026-27 change is documented on two pages.
Residual risk is limited to the promotion-eligibility rules, which are deliberately not in the data.

## Added by the merge

- GB21 Premier League 2: level 99, 31 clubs, closed both ways — not covered by the research pass.
