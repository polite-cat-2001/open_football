# Colombia — football pyramid 2026

Scope: levels 1–2 as carried in our database (Liga Dimayor, Torneo DIMAYOR). No cups, no
CONMEBOL competitions.
Research date: 2026-11-20. Calendar-year season (Apertura February–June, Finalizacion July–December),
so 2026 is nearly complete.

## Pyramid at a glance

| id | League | Level | Clubs | Rounds per club | Shape |
|----|--------|-------|-------|-----------------|-------|
| COL1 | Liga Dimayor | 1 | 20 | 19 + 6 (+2) | two independent tournaments, each: single round-robin, then two groups of four, then a two-legged final |
| CO22 | Torneo DIMAYOR (Primera B) | 2 | 16 | 15 + 6 (+2) | same two-tournament shape, plus a conditional promotion finale |

Sizes and levels in our rows are correct: **20 / 16**.

## The top flight is two championships, not one

Since 2002 the Apertura and the Finalizacion are independent title-awarding tournaments. Each is:

1. single round-robin, **19 matches** (a regional-derby round is added in most seasons, making 20);
2. top eight into **two groups of four**, double round-robin, **6 matches**, points starting at 0;
3. the two group winners meet in a **two-legged final**.

So "the league table" only ever means the current tournament's first stage. The row name
`Liga Dimayor Finalización` describes only the second tournament; a career sim that treats COL1 as
one 38-round season will produce the wrong fixture list and two missing title decisions.

## Relegation is a three-season average

The bottom two of the **promedio** table go down: average of first-stage points over the previous
three seasons (a promoted club averages only the seasons it has played). This is the key modelling
difference from a normal bottom-two rule — a club can finish last in one tournament and survive,
and a club can be relegated while sitting mid-table in the current season. `selection: "promedio"`
in the JSON.

## Primera B promotion is conditional

Two clubs go up every year, but the route depends on the two short-tournament winners:

- one club wins both Torneos → it is promoted; the next two in the aggregate table play off for
  the second place;
- both winners are top two in the aggregate table → both are promoted, nothing else is played;
- only one winner is top two → that club is promoted, the other winner plays the best-placed
  aggregate club that won nothing;
- neither winner is top two → grand final between the winners (winner promoted), then the loser
  plays the aggregate table's top club for the second place.

The JSON keeps `up: 2`, `up_playoff: 1` (at most one of the two places is a play-off) and spells
the scenarios out in `note`. Primera B has **no relegation** — `closed_down: true`.

## Boundaries

| between | up | of which PO | down | of which PO | allocation | selection |
|---------|----|-------------|------|-------------|------------|-----------|
| 1–2 | 2 | 1 | 2 | 0 | free | promedio |

## Oddities

- Neither league is a single table: both are two tournaments of 19 (or 15) rounds plus groups plus
  a final. A "rounds: 19" field is the first-stage length, not the season length.
- The Apertura/Finalizacion semi-final groups start from zero (no points carried), so the first
  stage is effectively a qualifying competition.
- Filial (B) teams have appeared in Primera B in the past; none is in the 2026 field, and the
  published promotion rules do not mention ineligibility.

## Sources

- https://en.wikipedia.org/wiki/Liga_DIMAYOR — 20 clubs; Apertura/Finalizacion; 19-match first
  stage; top 8 into two groups of four, double round-robin; two-legged final; relegation "by
  averaging the point totals ... over the previous three seasons", bottom two
- https://en.wikipedia.org/wiki/Categor%C3%ADa_Primera_B — 16 clubs; two tournaments with the same
  shape; the four 2025-onward promotion scenarios; grand final and promotion play-off; no relegation

## Confidence

**Medium.** Structure, sizes and the relegation rule are explicit and stable. The promotion
scenarios are recent (2025) and written in prose; the count (2) is certain but which route applies
depends on the season, so a sim must implement the conditions rather than a fixed play-off.
