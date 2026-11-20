# Vietnam — football pyramid, 2026-27

Season runs September/October 2026 → June/July 2027. **Not a calendar-year season** — Vietnam
switched to autumn/spring in 2023-24, and 2026-27 is the fourth season in that shape.

| Level | Competition | Clubs | Shape | Rounds |
|---|---|---|---|---|
| 1 | V.League 1 | 14 | double round-robin | 26 |

Our row (14 clubs, level 1) is correct.

## Level 1 — V.League 1

14 clubs, 26 matches, no split and no championship play-off: the champion is the top club after 26
rounds (tie-breakers: points, head-to-head, goal difference, goals scored).

- Champion → AFC Champions League Two group stage; runner-up → ACL Two play-offs.
- **Bottom two relegated** to V.League 2, both directly. 2025-26 confirms it: PVF-CAND (13th) and
  Becamex Ho Chi Minh City (14th) both went down, and both appear in the 2026-27 V.League 2 list.
- No relegation play-off at this boundary.

## What sits below (not in our rows)

V.League 2 (level 2) is 14 clubs, 26 rounds, runs the same autumn/spring calendar, and is an exact
mirror of the top tier: **top two promoted, bottom two relegated** (to the Vietnamese Second
Division, which is the third level and is not professional in the same way).

Because V.League 2 is not one of our rows, `closed_down` is true by the "no league below in our
list" rule — in reality two clubs leave downwards every season and two arrive from outside the
model. A career sim that stops at level 1 must treat those as exits/entries, not as a simulated
division.

One complication worth knowing: reserve sides. Hanoi FC B played in V.League 2 in 2026-27, so the
second tier's promotion places are not always taken by the top two eligible clubs.

## Data problems in our rows

1. `VIE1` 14 and level 1 — correct.
2. The task note calls Vietnam a calendar-year league. That was true up to 2023; the 2023-24,
   2024-25, 2025-26 and 2026-27 seasons are all autumn/spring.

## Confidence

High. The size, 26 rounds and the two-up/two-down boundary are stated in both league articles and
confirmed by the 2026-27 club list, which contains exactly the two clubs relegated from V.League 1.

## Sources

- https://en.wikipedia.org/wiki/V.League_1 (14 clubs, 26 games, August/September to June, format change in 2023)
- https://en.wikipedia.org/wiki/V.League_2 (14 clubs, 26 games, top two promoted, bottom two relegated, 2026-27 members including the two clubs relegated from V.League 1)
