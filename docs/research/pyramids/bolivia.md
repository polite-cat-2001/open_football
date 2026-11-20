# Bolivia — football pyramid 2026 (season 2026)

Scope: level 1 only (División Profesional). The Copa Simón Bolívar is the level-2 competition but it is
a cup-style route, not a league in our rows. No continental competitions.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026_FBF_Divisi%C3%B3n_Profesional | 16 clubs, "double round-robin ... 30 matchdays", `result15=RPO`, `result16=R`, the 23 March 2026 confirmation of the format |
| https://en.wikipedia.org/wiki/FBF_Divisi%C3%B3n_Profesional | `teams = 16`, the promedio relegation rule, the Copa Simón Bolívar route |

## League

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| BO1A | División Profesional | 1 | 16 | 30 rounds, double round-robin | — (top) | 2 (1 direct + 1 play-off) |

Our row (BO1A, level 1, 16 clubs) is correct.

## Format

- **2026 is a single tournament**: 16 clubs, double round-robin, 30 matchdays, 3 April – 13 December 2026. The
  clubs voted on 12 January 2026 to keep the double round-robin, and the format was confirmed on
  23 March 2026.
- This is a break from the recent past, when Bolivia played an Apertura and a Clausura (sometimes with
  groups and a play-off phase) inside one year. For 2026 there is **no apertura/clausura split**, so
  `format.kind` is `single`, not `apertura_clausura`.
- The top three qualify for the Copa Libertadores (champion and runner-up to the group stage), which is
  out of scope.

## Relegation

- Decided by **promedio** — average points over the last two seasons, not by the current table alone.
  The bottom club of that average is relegated directly (`result16=R`) and the second-from-bottom goes
  to a play-off (`result15=RPO`).
- The play-off is against the **runner-up of the Copa Simón Bolívar**, and the Copa Simón Bolívar
  champion is promoted directly. Real Potosí came up for 2026 by winning that cup (beating San Juan in
  the final) and one more club came through the play-off.
- The number of legs of that play-off was not documented in the sources read, so it is null in the JSON.

Because the second level is not a league in our rows, the league is marked `closed_down: true`; the
promedio rule and the cup route are described here and in `notes`.

## Oddities

- **Promedio relegation** is the one thing a naive sim gets wrong: a club can finish 14th this season
  and still go down on a two-season average, or finish last and survive because last season was worse
  for someone else. Bolivia is the only country in this batch using it.
- The second level is reached through a cup (Copa Simón Bolívar), with regional leagues feeding it, so
  "promotion" here is a tournament win rather than a league position.
- 2026 is a calendar-year season, like Belarus, not a 2026-27 split season.

## Confidence

**High** for size, format and the 15th/16th relegation split. **Medium** for the play-off mechanics
(opponent and legs), which come from the league overview rather than the 2026 season article.
