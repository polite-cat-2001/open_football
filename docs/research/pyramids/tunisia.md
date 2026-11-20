# Tunisia — football pyramid, 2026-27

Season runs August/September 2026 → May/June 2027.

| Level | Competition | Clubs | Shape | Rounds |
|---|---|---|---|---|
| 1 | Tunisian Ligue Professionnelle 1 (Ligue 1 Pro) | 16 | double round-robin | 30 |

Our row (16 clubs, level 1) is correct.

## Level 1 — a single 30-match table

For 2026-27 the competition is one table of sixteen clubs, each playing the others home and away
(30 matchdays). No split, no championship play-off: the champion is simply the club with the most
points after 30 rounds.

- Champion and runner-up → CAF Champions League; 3rd (and the cup winner) → CAF Confederation Cup.
- **Bottom three relegated** to Ligue Professionnelle 2, all three directly, no play-out.

The 2026-27 club list reconciles at 16 (three up from Ligue 2, three down from 2025-26), and it
includes promoted sides such as AS Marsa and JS El Omrane alongside the four big clubs.

## What sits below (not in our rows)

Ligue Professionnelle 2 is level 2 and is run by the same body (LNFP). It is **not** in our data,
so the model stops at Ligue 1: `closed_down` is true by the "no league below in our list" rule,
even though in reality three clubs leave downwards every season. A career sim that stops at level 1
should treat those three as "relegated out of the model" rather than as a transfer to another
simulated division.

## Data problems in our rows

None for size or level. Note only that Tunisian seasons have repeatedly changed shape (14 clubs,
then two groups with a play-off phase in some seasons); the 2026-27 shape is the plain 16-club
double round-robin described above, so a stored format from an older season would be stale.

## Confidence

High on size, rounds and relegation count: the league article's *Format* section states all three
for 2026-27 and the participating-club table lists exactly 16 clubs.

## Sources

- https://en.wikipedia.org/wiki/Tunisian_Ligue_Professionnelle_1 (16 clubs, 30 matchdays, bottom three relegated, 2026-27 club list)
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Tunisian_Ligue_Professionnelle_1 (current season)
