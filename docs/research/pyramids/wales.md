# Wales — football pyramid 2026-27

Research for the career simulation. Scope: levels 1-2 as carried in our database (the Ardal Leagues
at level 3 and below are outside it). Cups and European qualification are out of scope.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/Welsh_football_league_system | the 2026-27-onward structure table (16 / 16+16 / 4x16), tier-2 description and the licence caveat on promotion |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Cymru_Premier | "16 teams for the first time", who came up (3 from Cymru North, 3 from Cymru South), the three-way split, Survival Zone relegation and the promotion/relegation play-off |
| https://en.wikipedia.org/wiki/Cymru_Premier | the September 2024 FAW announcement of the format: 30 rounds, split 6/4/6, champions after matchday 35, 14th in the relegation play-off (cites BBC Sport) |
| https://en.wikipedia.org/wiki/Cymru_North | `teams = 16`, promotion to Cymru Premier, relegation to Ardal Leagues |
| https://en.wikipedia.org/wiki/Cymru_South | `teams = 16`, same structure |

Cross-check attempted on `faw.cymru/cymru-leagues/cymru-premier/table/`: the request timed out and
the site is JS-rendered, so no official table could be read. `2026–27 Cymru North` and
`2026–27 Cymru South` season articles do not exist yet, so the level-2 sizes rest on the league
infoboxes and the pyramid table (both 16).

## Leagues

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| WAL1 | Cymru Premier | 1 | 16 | 30 rounds + split 6/4/6 (35 rounds) | — (top) | 3 (2 auto + 1 PO) |
| WAL2 | Cymru North | 2 | 16 | 30 rounds | 2 (1 auto + 1 PO) | to Ardal Leagues (level 3, not modelled) |
| WA2S | Cymru South | 2 | 16 | 30 rounds | 2 (1 auto + 1 PO) | to Ardal Leagues (level 3, not modelled) |

Sizes and levels in our database are correct: 16/16/16 is exactly the new shape.

**Important:** WAL2 and WA2S are parallel regional divisions at the same level. They never play each
other, never exchange clubs with each other, and promotion from each goes straight to the Cymru
Premier. There is no balancing transfer between North and South (unlike England's National League
North/South): a club sits in the half of the country it belongs to. A career sim must keep the two
as separate competitions with a shared parent, not as one division of 32.

## The Cymru Premier format (new in 2026-27)

The league expanded from 12 to 16 clubs for this season, which is why six clubs came up from level 2
in 2026 (three from each region) and why our 16 is right where an older row saying 12 would be wrong.

- 30 rounds: everyone plays everyone home and away.
- Then the table splits: 1st-6th (Championship Race), 7th-10th (European Challenger), 11th-16th
  (Survival Zone). Points and results carry over.
- Each group plays once more: the top six and the bottom six reach **35 rounds**, the middle group of
  four stops at **33**. So there is no single round count for the division; `format.rounds: 35` is
  the maximum and the note in the JSON records the 33 for 7th-10th.
- Relegation: 15th and 16th go down automatically; **14th** plays a one-off against the winner of a
  one-off between the Cymru North and Cymru South runners-up, for the last place in next season's
  Cymru Premier.

## Boundaries

Only one boundary exists inside our data: 1-2.

| between | up | of which PO | down | of which PO | allocation | selection |
| --- | --- | --- | --- | --- | --- | --- |
| 1-2 | 3 | 1 | 3 | 1 | by_geography | bottom_n |

- Up: the champions of Cymru North and Cymru South (subject to a Tier 1 licence) plus the winner of
  the play-off described above.
- Down: 15th and 16th directly, plus 14th if it loses the play-off. The two directly relegated clubs
  are assigned to North or South by geography.
- The play-off is **shared**: one match decides both a relegation and a promotion place. Exactly one
  of {Cymru Premier 14th, tier-2 play-off winner} is in the top flight next season, which is why
  `up: 3` and `down: 3` still balance to 16.

## Decisions

1. **`allocation: "by_geography"`** because each region sends its own champion and relegated clubs
   are placed by region. Note that promotion also needs a licence; that gate is described in
   `note` rather than encoded, since `allocation` has to pick one story and the geographic split is
   the structural one.
2. **`selection: "bottom_n"`** — the bottom two are relegated on position; the 14th is the extra
   play-off entry.
3. **`format.kind: "split"`** rather than `"single"`, with `split_after: 30`, `groups: [6,4,6]` and
   `points_carry: true`. The uneven middle group is the reason for the extra note.
4. **Level 2 relegation is not modelled.** Both divisions relegate into the four Ardal Leagues
   (North West, North East, South West, South East, 16 each). The exact number of clubs per division
   was not verified, so it is `null` by omission rather than guessed.
5. **Excluded:** Welsh Cup, Welsh League Cup, and all European places. The Cymru Premier also runs a
   separate 2nd-7th Conference League play-off; it does not affect promotion or relegation and is
   left out.

## Oddities

- The 2025-26 season ended with **six** clubs promoted from level 2 (three per region) because of
  the expansion. That is a one-off, not the rule: the steady state from 2026-27 is one champion per
  region plus one play-off place. A sim seeded with 2025-26 history will look inconsistent with the
  2026-27 constitution unless this is handled.
- One club relegated in 2025-26 (Flint Mountain) went down voluntarily to tier 4 and reprieved
  Ruthin Town, which is a reminder that below level 1 Welsh membership is partly licence- and
  application-driven, not purely sporting.

## Confidence

**Medium.** Sizes (16/16/16), levels and the split structure are corroborated by three separate
pages, but the play-off mechanics and the split details come from essentially one encyclopaedic
source (citing BBC/FAW) and no FAW page could be read to confirm them. This is also the first season
of the format, so there is no completed season to check the description against.
