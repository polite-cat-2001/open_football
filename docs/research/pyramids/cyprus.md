# Cyprus — football pyramid 2026-27

Scope: levels 1–2 as carried in our database (Cyprus League, 2. Division). No cups, no UEFA
competitions.
Research date: 2026-11-20. Season in progress.

## Pyramid at a glance

| id | League | Level | Clubs | Rounds per club | Shape |
|----|--------|-------|-------|-----------------|-------|
| ZYP1 | Cyprus League (First Division) | 1 | 14 | 26 + 10 or 7 | one table for 26 rounds, then top 6 / bottom 8 groups |
| CYP2 | 2. Division | 2 | 16 | 15 + 14 | one table for 15 rounds, then two groups of eight |

Both rows are correct: **14 / 16**.

## First Division: an asymmetric split

1. **First round**: 14 clubs, double round-robin, **26 matches**.
2. **Split** (points and goal difference carried):
   - **Group A**, top six: double round-robin, **10 more matches → 36**;
   - **Group B**, bottom eight: single round-robin, **7 more matches → 33**.
3. Group A 1st is champion. **Bottom three of Group B are relegated**, directly.

So there is no single "rounds" number for the division: 36 for the top six, 33 for the bottom
eight. The JSON keeps `rounds: 36` (the maximum) and records the 33 in the stage note.

## Second Division: single round-robin, then two groups of eight

1. **First phase**: 16 clubs, each plays every other club **once** (15 rounds).
2. **Promotion round**: top eight, double round-robin, **14 more → 29**; top three promoted.
3. **Relegation round**: bottom eight, double round-robin, **14 more → 29**; bottom three
   relegated.
4. Points and goals are **carried** into both groups (the 2025-26 tables show the first-phase
   points as the starting total).

## Boundaries

| between | up | of which PO | down | of which PO | allocation | selection |
|---------|----|-------------|------|-------------|------------|-----------|
| 1–2 | 3 | 0 | 3 | 0 | free | bottom_n |

Three up, three down, all direct and all decided after the split. No play-offs at this boundary
in either direction.

## Oddities

- The 14-club top flight splits 6 / 8, not 6 / 8 with equal games: the small championship group
  plays 10 more, the large relegation group only 7. Any fixture generator needs both numbers.
- The Second Division is effectively a 29-game season, not the 15- or 22-game shape its name
  suggests; the split doubles the length of the second phase.
- There is no relegation play-off in the top flight — 12th is not given a second chance.

## Sources

- https://en.wikipedia.org/wiki/Cypriot_First_Division — 14 clubs; 26-round first round; Group A
  6 clubs double round-robin (10 games), Group B 8 clubs single round-robin (7 games); points
  retained; bottom three relegated; "three lowest-placed teams ... replaced by the top three"
- https://en.wikipedia.org/wiki/Cypriot_Second_Division — 16 clubs; current format since 2022-23:
  "facing each other at least once", split into top/bottom eight, champion + 2nd + 3rd promoted,
  bottom three relegated
- https://en.wikipedia.org/wiki/2025%E2%80%9326_Cypriot_Second_Division — 232 matches total (120
  first phase + 56 + 56), 16 teams, promotion and relegation rounds double round-robin, points
  carried (adjust_points equal to first-phase totals), three promoted and three relegated

## Confidence

**High.** Both formats, the split sizes, the carried points and the 3/3 movement are stated
explicitly, and the 2025-26 Second Division's 232 matches confirm the 15 + 14 structure.
