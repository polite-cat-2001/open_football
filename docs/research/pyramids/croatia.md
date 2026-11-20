# Croatia — football pyramid 2026-27

Scope: levels 1–2 as carried in our database (SuperSport HNL, Prva NL). No cups, no UEFA
competitions.
Research date: 2026-11-20. Season in progress (started 31 July / 22 August 2026).

## Pyramid at a glance

| id | League | Level | Clubs | Rounds per club | Shape |
|----|--------|-------|-------|-----------------|-------|
| KR1 | SuperSport HNL | 1 | 10 | 36 | one table, quadruple round-robin |
| KR2 | Prva nogometna liga (1. NL) | 2 | 16 | 30 | one table, double round-robin |

Both rows are correct for 2026-27: **10 / 16**.

## Formats

- **HNL**: ten clubs, every pair meets **four times**, 36 matches. No split, no carried points.
  The 2025-26 season had exactly 180 matches (36 × 5), which confirms the quadruple round-robin.
- **Prva NL**: 16 clubs, double round-robin, 30 matches. This is the first 16-club season — the
  league had 12 clubs from 2022-23 through 2025-26 and the HNS approved the expansion in March
  2026.

## Boundaries

| between | up | of which PO | down | of which PO | allocation | selection |
|---------|----|-------------|------|-------------|------------|-----------|
| 1–2 | 1 | 0 | 1 | 0 | free | bottom_n |

- Up: Prva NL champion, promoted directly (if eligible).
- Down: HNL 10th, relegated directly.
- **No play-off between the tiers.** Recent HNL seasons have not used a 9th-place play-off; the
  only play-off in this part of the pyramid is inside the Prva NL (15th v a 2. NL club).

## Reserve teams

Dinamo Zagreb II is in the 2026-27 Prva NL. Farm teams must play at least one level below the
senior side, so **Dinamo II cannot be promoted**. If it wins the league, the promotion place
passes to the next eligible club. This is the Croatian version of the reserve-team trap that also
exists in Portugal and Estonia.

## Oddities

- HNL relegation is one club, direct. Do not copy the 1997–2013 pattern of a 9th-place play-off;
  it has not been used in the current format.
- Prva NL relegation is asymmetric: 16th goes down directly, 15th plays a two-legged play-off
  (marked `Q` in the 2026-27 table) — presumably against a 2. NL club.
- The second tier's size jumped 12 → 16 in one season, which is a big intake of clubs (Vukovar
  from the HNL plus five promoted/returning sides).

## Sources

- https://en.wikipedia.org/wiki/Croatian_Football_League — 10 clubs; seasons of 180 matches;
  current champions; promotion/relegation with the Prva NL
- https://en.wikipedia.org/wiki/First_Football_League_(Croatia) — level 2; 12 clubs through
  2025-26; champion promoted; relegation to 2. NL
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Croatian_Football_League — 10 clubs, "Each team
  plays home-and-away against every other team ... twice, for a total of 36 matches each",
  `result10=REL`
- https://en.wikipedia.org/wiki/2026%E2%80%9327_First_Football_League_(Croatia) — "contested by 16
  teams and played in a double round robin format", Dinamo II in the field, `result15=Q`,
  `result16=REL`
- https://en.wikipedia.org/wiki/2025%E2%80%9326_Croatian_Football_League — completed season, 180
  matches, only 10th relegated

## Confidence

**High.** Counts, round numbers, the one-up/one-down rule and the absence of a tier play-off are
all stated explicitly in the 2025-26 and 2026-27 season articles, and the 36-round HNL is
confirmed by the 180-match season totals.
