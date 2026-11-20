# Uganda — football pyramid, 2026-27

Season runs August 2026 → May 2027.

| Level | Competition | Clubs | Shape | Rounds |
|---|---|---|---|---|
| 1 | Uganda Premier League (UPL) | 18 | double round-robin | 34 |

Our row (18 clubs, level 1) is correct — but only since this season.

## The 2026-27 expansion

The league went from **16 to 18 clubs** for 2026-27: fourteen clubs stayed, two were relegated
(Buhimba Saints, Calvary) and four came up from the FUFA Big League (Blacks Power, Ntugasaze,
Kataka, Kigezi Homeboys). Every club plays 34 matches.

That means a stored "16" would be the 2025-26 shape, not this one; the article explicitly dates
18 clubs to 2026-27.

## Promotion and relegation

- **Bottom four relegated** to the FUFA Big League (level 2, not in our rows). The 2026-27 table
  marks 15th-18th as relegation places.
- Four come up from the Big League in exchange, so the size stays 18.
- Because the Big League is not one of our rows, `closed_down` is true by the "no league below in
  our list" rule: the four clubs leave the modelled pyramid.

A practical warning for a career sim: a 34-match season with a four-club relegation zone is a much
wider trap than the usual three, and Uganda's recent history includes clubs dropping out for
financial reasons mid-season, which changes the count.

## Data problems in our rows

Our size of 18 is right for 2026-27 but was 16 a season earlier — the row is only valid because it
was refreshed for the current season. Level 1 is correct.

## Confidence

High. The season article states the 16 → 18 expansion, the four promoted and two relegated clubs,
and marks 15th-18th as relegation; the league article dates 18 clubs to 2026-27.

## Sources

- https://en.wikipedia.org/wiki/Uganda_Premier_League (18 clubs since 2026-27, 34 matches, relegation to the FUFA Big League)
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Uganda_Premier_League (expansion 16 → 18, four promoted, four relegation places)
