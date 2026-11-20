# Nigeria — football pyramid 2026-27

Research for the career simulation. Scope: level 1 only, the NPFL. Cups and CAF
competitions are out of scope. Our list has a single Nigerian row, so the league is
closed in both directions in our data even though four clubs go down in reality.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Nigeria_Premier_Football_League | the 2026-27 season: 20 clubs, 38 rounds, four promoted from the NNL, four relegated, the table's relegation marks on 17th-20th |
| https://en.wikipedia.org/wiki/Nigeria_Premier_Football_League | league infobox (20 clubs, 38 matches, August-May calendar), relegation to the Nigeria National League, the 2023 rename to "Premier" |

No official NPFL page was read: the season article is the only source for the 2026-27
constitution, and it cites npfl.com.ng for the table. Cross-check beyond that was not
possible (the league site is not readable in this environment).

## League

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| NPFL | Nigeria Professional Football League | 1 | 20 | 38 rounds (double round-robin) | — (top) | 4 |

Size and level in our database are correct. The league was renamed **Nigeria Premier
Football League** in 2023 and the 2026-27 edition is sponsored as the "Euromatch
Premier Football League"; our row still carries the 2014-2023 name. Same competition,
so no data change is needed, but anything that matches on the name will miss.

- 20 clubs, 38 matches each, August to May with a two-week break over Christmas.
- 2026-27 is the 56th season of the top flight. Four clubs came up from the Nigeria
  National League (Sporting Lagos, Inter Lagos, Doma United, Ranchers Bees) and four
  went down in 2025-26 (Remo Stars, El-Kanemi Warriors, Bayelsa United, Wikki Tourists).
- No title play-off, no split, no groups: one table, champion on points.

## Relegation

Four clubs are relegated: 17th to 20th, marked as such in the 2026-27 table. There is
no play-off place and no licence gate encoded in the table — the only non-sporting
twist seen this season is administrative, not structural: Warri Wolves and Inter Lagos
were docked three points and three goals for assault on match officials, which changes
who finishes in the bottom four but not how many go down.

The Nigeria National League (tier 2, run in regional groups) is not in our list, so
`closed_down` is `true` per the README rule. A career simulation that wants a real
Nigerian pyramid would need the NNL; with only NPFL modelled, the bottom four must
simply disappear or stay (no `boundaries` entry).

## Decisions

1. **`format.kind: "single"`, `rounds: 38`.** Confirmed twice (season article and
   league infobox).
2. **`closed_up: true`, `closed_down: true`, no boundaries.** Single row in our list.
   The real four-club relegation is described in `notes`, not encoded.
3. **`playoff: null`.** Nothing in the season structure is decided by a play-off.

## Oddities

- The 2026-27 season article's "Matches: 128" and "Goals: 299" are mid-season totals
  (13 rounds played), not season totals. Do not read them as a 380-match season.
- Barau and Ranchers Bees both play home games at the Muhammadu Dikko Stadium in
  Kaduna, and Barau's own ground was ruled unsuitable; ground-sharing is common and a
  stadium is not a reliable club identifier.

## Confidence

**High** for size (20), level, round count and the four-club relegation. **Medium** only
for the exact wording of the 2026-27 regulations: no NPFL rulebook or official table
could be read directly, and the season article is a single encyclopaedic source.
