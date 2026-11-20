# Montenegro — football pyramid, 2026-27

Montenegro runs an August–May season. Cups and UEFA competitions are out of scope. Two levels, both
10 clubs, and the whole pyramid below with them is small — but the boundary between them is genuinely
open: three places, two of them decided over two legs.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | MNE1 | Meridianbet 1. CFL | 10 | four rounds | 36 | — (closed) | 1 direct + 2 play-off |
| 2 | MNE2 | 2. CFL | 10 | four rounds | 36 | 1 direct + 2 play-off | 2 direct (to level 3) |
| 3 | — | Third League (not modelled) | — | — | — | — | — |

## Level 1 — 1. CFL

- 10 clubs, each pair meets four times (36 matches).
- **10th is relegated directly.**
- **8th and 9th play two-legged ties**: 8th against the 2. CFL runner-up, 9th against the 2. CFL
  third-placed club.
- 2025-26 is a clean worked example: Jezero (8th) beat Iskra 8–1 and Bokelj (9th) beat Grbalj 2–0, so
  both stayed and only Jedinstvo (10th) went down.

## Level 2 — 2. CFL

- 10 clubs, 36 rounds. Champion promoted directly; 2nd and 3rd into the ties above.
- 9th and 10th relegated to the Third League.

## Boundary arithmetic

Three places each way with two contested. If both top-flight clubs win, only one club changes level —
so the model must allow "up 1-3 / down 1-3" rather than a fixed three.

## Check against our database

| id | our name | our level | real level | our size 2026-27 | verdict |
|---|---|---|---|---|---|
| MNE1 | Meridianbet 1. CFL | 1 | 1 | 10 | correct (sponsor name is official usage) |
| MNE2 | 2. CFL | 2 | 2 | 10 | correct |

Nothing to correct. `2. CFL` is the official short name, not an abbreviation of ours.

## Caveats

- 36 rounds for 10 clubs is heavy; the fixture list is four full round robins, not a split.
- The 2. CFL play-off pairings are fixed (8th v 2nd, 9th v 3rd) — there is no draw, so the model can
  pair them deterministically.

## Sources

- https://en.wikipedia.org/wiki/2026%E2%80%9327_Montenegrin_First_League
- https://en.wikipedia.org/wiki/2025%E2%80%9326_Montenegrin_First_League
- https://en.wikipedia.org/wiki/2025%E2%80%9326_Montenegrin_Second_League
