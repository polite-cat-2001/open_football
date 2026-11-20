# Cambodia — football pyramid 2026-27

Scope: level 1 only (Cambodian Premier League). Cambodian League 2 is not in our rows. No cups, no AFC
competitions.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Cambodian_Premier_League | 11 clubs, "double round-robin ... before the top-six teams proceed to the champion round", `result1-6=CHA`, season 5 Sep 2026 – May 2027 |
| https://en.wikipedia.org/wiki/Cambodian_Premier_League | `teams = 11`, relegation to Cambodian League 2 |
| https://en.wikipedia.org/wiki/2025%E2%80%9326_Cambodian_Premier_League | the completed previous edition: 11 clubs, double round-robin, "Bottom-five round" section, no promotion or relegation because the 2024-25 League 2 was cancelled |

## League

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| KHM1 | Cambodian Premier League | 1 | 11 | 22 rounds + top-6 championship round (27 rounds for those six) | — (top) | not documented for 2026-27 |

Our row (KHM1, level 1, 11 clubs) is correct.

## Format

- 11 clubs, double round-robin = **22 rounds**, 110 matches.
- Then the table splits: **1st–6th** play a championship round, **7th–11th** play a bottom-five round.
  Both groups play a single round-robin inside themselves, so the top six reach **27** matches and the
  bottom five **26**. `format.rounds: 27` is the maximum.
- The table's qualification markers only cover the top six (`result1-6=CHA`); no relegation marker is
  set in the in-progress 2026-27 article, so what happens to the bottom of the bottom-five round is not
  documented for this season.
- Whether points carry into the second phase is not stated in either season article; it is likely
  (Cambodia has used a carry-over in previous editions) but is not recorded as fact here.

## Boundary 1–2 (not modelled)

- The Cambodian League 2 exists and the Premier League article names it as the relegation destination,
  but no 2026-27 relegation count is published.
- 2025-26 had **no** promotion or relegation at all because the 2024-25 League 2 was cancelled, and the
  same 11 clubs carried over. That is a one-off, not the rule.
- Because level 2 is not in our rows, the league is `closed_up: true` and `closed_down: true`; the real
  route is described here and in `notes`.

## Season label

The task described Cambodia as a calendar-year league using a 2026 season. The current edition is
labelled **2026-27** and runs from 5 September 2026 to May 2027, so a European-style season is used.
The Wikipedia infobox's closing date ("17 May 2026") is a typo for 2027 — the opening date and the
fixture list make the intended season obvious.

## Oddities

- An 11-club league playing a double round-robin has a bye every round; the split into 6 + 5 is the only
  way to give every club a full second phase, and it produces two different final match counts.
- The 2024-25 second-tier cancellation froze the top flight at 11 clubs for two seasons — a reminder
  that in this pyramid the level below can simply not run.

## Confidence

**Medium.** Size (11) and the double round-robin plus top-six championship round are stated in both the
2026-27 and 2025-26 articles. The bottom-five mechanics, the points-carry rule and the relegation count
are not documented for 2026-27 and are left unstated rather than guessed.
