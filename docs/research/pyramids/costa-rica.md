# Costa Rica — football pyramid 2026-27

Scope: only the top flight is in our database (CRPD). No cups, no CONCACAF competitions.
Research date: 2026-11-20. The Apertura 2026 is in progress.

## Pyramid at a glance

| id | League | Level | Clubs | Rounds per club | Shape |
|----|--------|-------|-------|-----------------|-------|
| CRPD | Primera Division (Liga FPD / Liga Promerica) | 1 | 10 | 18 + 3 (+2) | Apertura and Clausura, each: double round-robin, then a four-team knockout, then a possible grand final |

Our row is right: **10 clubs, level 1**.

## Format — two tournaments, four-team knockout

Each tournament (Apertura July–December, Clausura January–May):

1. **Regular phase**: double round-robin, **18 matches** (ten clubs).
2. **Play-offs**: the top four play two-legged semi-finals and a two-legged final.
3. **Grand final**: if the play-off winner is not the regular-phase winner, the two meet over two
   legs for the title. If the same club wins both, it is champion outright — which is what
   happened in both 2025-26 tournaments.

Two champions per season; the row is one competition in our data, so a sim has to decide whether
it models one tournament or the whole season.

## Relegation

One club is relegated on the **combined Apertura + Clausura table**. It goes to the Liga de
Ascenso (Segunda Division), which is not in our list, so the report marks the downward direction
closed, per the task rule for single-row countries. There is no promotion into CRPD in our data.

## Boundaries

None inside our data — CRPD is both the top and the bottom of the modelled pyramid.

## Oddities

- The league article's format prose is out of date: it says 22 matchdays and a quadrangular,
  which was the 12-club shape. The 2025-26 season article describes the current ten-club,
  18-round, four-team-knockout format.
- Ten clubs is new (2025-26). Two clubs, Guanacasteca and Santos de Guapiles, lost their licences,
  which is why the league shrank from 12; a sim built on older data will show 12 clubs and
  22 rounds.
- There is no relegation play-off: bottom of the aggregate table goes down directly.

## Sources

- https://en.wikipedia.org/wiki/Liga_FPD — ten clubs; Apertura/Clausura; "top-four clubs ...
  qualifying to the second stage"; one relegation "based on the aggregate performance in both
  Apertura and Clausura tournaments"; stale 22-matchday prose
- https://en.wikipedia.org/wiki/2025%E2%80%9326_Liga_FPD — ten clubs, "regular phase consisted of
  18 matchdays", top four to a four-team knockout, grand final rule, aggregate table, one
  relegation place

## Confidence

**High** on size, level, the 18-round regular phase and the knockout shape (three independent
sources agree: the 2025-26 article, the league infobox, and the completed 2025-26 tables). Medium
only on how much of the two-tournament season our single row is meant to represent.
