# Faroe Islands — football pyramid 2026

Scope: levels 1–2 as carried in our database (Meistaradeildin, 1. deild). No cups, no UEFA
competitions.
Research date: 2026-11-20. Calendar-year season, March–October; 2026 complete.

## Pyramid at a glance

| id | League | Level | Clubs | Rounds per club | Shape |
|----|--------|-------|-------|-----------------|-------|
| FARO | Meistaradeildin (Premier League) | 1 | 10 | 27 | one table, triple round-robin |
| FAR2 | 1. deild | 2 | 10 | 27 | one table, triple round-robin |

Both rows are correct: **10 / 10**, levels 1–2.

## Formats

Ten clubs at each level, every pair meeting **three times** (27 matches). Which club gets the extra
home game is drawn before the season, not set by the previous table. No split, no play-offs.

## Boundaries

| between | up | of which PO | down | of which PO | allocation | selection |
|---------|----|-------------|------|-------------|------------|-----------|
| 1–2 | 2 | 0 | 2 | 0 | free | bottom_n |

Two up, two down, direct. A promotion/relegation play-off existed from 1995 to 2005 but is not
part of the current format.

## The reserve-team trap (bigger here than anywhere else)

1. deild is largely a reserve league: the 2025 field included B36 II, HB II, KÍ II, Víkingur II,
NSÍ II, EB/Streymur II and 07 Vestur II. Three rules matter:

1. **A reserve team cannot be promoted.** Only non-reserve clubs may go up.
2. **There is only top-flight relegation if an eligible club is available.** The Premier League
   page states there "will only be relegation if at least one non-reserve team finishes in the
   1. deild top three" — so the bottom two of the top flight can both be reprieved.
3. **Cascading relegation.** If a relegated Premier League club already has a reserve side in
   1. deild, that reserve side is pushed down a division to make room, which saves another club.

A sim that always swaps the bottom two for the top two will be wrong most seasons.

## Oddities

- Triple round-robin at both levels (27 games), with home advantage allocated by draw.
- Because 1. deild is mostly B teams, "2nd place" often belongs to a reserve side; the promotion
  place slides down to the next eligible club.
- The top flight is fully national and has no reserve sides; the second tier mixes senior clubs
  (Skála, B71, ÍF, AB) with reserves.

## Sources

- https://en.wikipedia.org/wiki/Faroe_Islands_Premier_League — ten clubs, "play each other three
  times", two relegated / two promoted, reserve-team and cascading-relegation rules, play-off only
  in 1995-2005
- https://en.wikipedia.org/wiki/1._deild — ten clubs, two up / two down, reserve-team eligibility
  ("if the promoted team does not already have a team in 1. deild ... the team that finished third
  will be promoted instead")
- https://en.wikipedia.org/wiki/2025_1._deild — ten clubs, "Each team plays three times ... for a
  total of 27 matches each", reserve sides in the field, two promoted and two relegated

## Confidence

**High.** Sizes, the 27-match triple round-robin and the two-up/two-down rule are explicit, and
the reserve-team conditions are described in both the league and season articles.
