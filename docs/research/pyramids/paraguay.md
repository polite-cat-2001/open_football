# Paraguay — football pyramid 2026

Research for the career simulation. Scope: levels 1-2 as carried in our database (the
División de Honor and the División Intermedia). Our level-1 row is the **Clausura**, one
of the two annual championships. Cups, the Copa Libertadores places and the third tier
are out of scope.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026_Copa_de_Primera | the 2026 season: 12 clubs, Apertura 22 rounds, the aggregate table, relegation over three seasons (2 down) |
| https://en.wikipedia.org/wiki/2026_APF_Divisi%C3%B3n_Intermedia | 2026 Intermedia: 16 clubs, 30 rounds, champion and runner-up promoted, three relegated on a three-season average, geographic split of the relegations |

Both are complete seasons at the time of writing (the Clausura ends 29 November 2026).

## Leagues

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| PR1C | Primera División Clausura | 1 | 12 | 22 rounds (double round-robin) | — (top) | 2 |
| PAR2 | División Intermedia | 2 | 16 | 30 rounds (double round-robin) | 2 | 3 |

Sizes (12 and 16) and levels (1 and 2) in our database are correct.

## Level 1: two championships, no play-off

- 12 clubs. The season is two separate championships, **Apertura** (late January to May)
  and **Clausura** (July to late November), each a double round-robin of **22 rounds**.
- Each tournament crowns its own champion from its own table; there is no title play-off
  and no aggregate final. Olimpia won the 2026 Apertura. The 2026 Clausura was still
  running when this was written.
- Our row is the Clausura, so it is one 22-round competition inside a 44-match season.
- A separate aggregate table is published (Apertura + Clausura points) and is used for
  the relegation average and for Libertadores seeding, but it does not decide a title.

## Promotion and relegation

- **Level 1 down:** two clubs, decided by the **average of points per game over the last
  three seasons** (the "tabla de descenso"). In 2026 Rubio Ñu and San Lorenzo went down
  on 0.976 and 0.634 respectively, despite the table being close above them. No play-off.
- **Level 2 up:** champion and runner-up are promoted directly (Deportivo Santaní and
  General Caballero (JLM) in 2026). No promotion play-off.
- **Level 2 down:** three clubs, also on a three-season points-per-game average; the
  destination depends on geography — clubs from Asunción or within 50 km go to Primera
  B Metropolitana, the rest to Primera B Nacional. Tier 3 is not modelled.

## Boundary 1-2

| between | up | of which PO | down | of which PO | allocation | selection |
| --- | --- | --- | --- | --- | --- | --- |
| 1-2 | 2 | 0 | 2 | 0 | free | average_table |

- `average_table` (three-season points per game), not `bottom_n`: a club can finish 10th
  and still be relegated, and a promoted club starts with a clean average.
- `allocation: "free"` for this boundary — the geographic split only applies to level 2's
  own relegation into the two Primera B divisions, which is outside our data.

## Decisions

1. **`format.kind: "apertura_clausura"`, `rounds: 22`**, note that each tournament is a
   22-round double round-robin and the season is 44 matches per club.
2. **`playoff: null`** for both leagues: neither title nor promotion is decided by a
   play-off.
3. **`closed_down: true` for PAR2** — its relegation goes to tiers we do not carry.
4. **`selection: "average_table"`** on the boundary; `promedio` would also fit the
   concept, but the Paraguayan rule is literally a three-season average table.

## Oddities

- The 2026 level-1 relegation table makes the mechanism obvious: Rubio Ñu were 9th in
  the Apertura but had only one season of points, and their 40 points in 41 games were
  the second-worst average. Promoted clubs are not protected.
- Two clubs that were promoted for 2026 (Rubio Ñu, San Lorenzo) were relegated again in
  the same season — a one-season bounce that a sim seeded with a single table would not
  reproduce without the three-year average.
- Intermedia clubs are split by geography only when they go *down*, not when they go up:
  both promoted clubs enter the single national División de Honor.

## Confidence

**High.** Both 2026 seasons are complete on Wikipedia with tables, the promotion and
relegation sections spell out the three-season average, and sizes match our rows. The
only unverified detail is the exact tie-breaking inside the average tables.
