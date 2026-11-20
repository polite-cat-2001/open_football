# Algeria — football pyramid 2026-27

Scope: level 1 only (Ligue Professionnelle 1). Level 2 (League 2) is not in our rows, so this report
stops at the boundary; no cups, no CAF competitions.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Algerian_Ligue_Professionnelle_1 | 16 clubs, 2025-26 promoted trio (JS El Biar, US Biskra, CR Temouchent), `result14-16=REL`, season in progress |
| https://en.wikipedia.org/wiki/Algerian_Ligue_Professionnelle_1 | "contested by 16 clubs", "the three lowest-placed teams are relegated ... replaced by the top two teams in that division and the playoffs winner" |

## League

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| ALG1 | Ligue Professionnelle 1 | 1 | 16 | 30 rounds, double round-robin | — (top) | 3 direct |

Our row (ALG1, level 1, 16 clubs) is correct for 2026-27. The league has been 16 clubs since 2021-22;
the 2026-27 edition keeps that.

## Format

Plain double round-robin: 16 clubs, every pair home and away, 30 rounds, 240 matches, no split, no
groups, no apertura/clausura, no points carried. The 2026-27 season runs 3 September 2026 – 29 May 2027
and is in progress (72 matches played as of the article's last update in November).

Tiebreakers: points, head-to-head, head-to-head goal difference, first-half goal difference, first-half
goals, fair play, play-off. The "first half" tiebreaker is a curiosity of the Algerian regulations but
does not affect promotion or relegation.

## Boundary 1–2

- **Down: 3.** 14th, 15th and 16th are relegated directly (`result14-16=REL` in the 2026-27 table).
- **Up: 3.** Level 2 supplies the two best clubs plus the winner of its play-off, which is why three
  clubs came up for 2026-27 (JS El Biar, US Biskra, CR Temouchent — different parts of the country, so
  League 2 is regionalised).
- There is no promotion/relegation play-off at level 1 itself: the play-off that decides the third
  promotion is played inside League 2 and never involves a Ligue 1 club.

Because level 2 is not in our list, the league is marked `closed_down: true` even though real clubs
move to League 2 every season; the boundary is described here and in `notes`, not encoded.

## Oddities

- Three clubs promoted for 2026-27 and three relegated after 2025-26 means the size is stable at 16,
  but the third promotion comes from a play-off, not from a fixed league position. A sim that only
  models league tables will need that play-off invented or skipped.
- League 2 is regionalised (the promoted trio came from different regions), so the "top two plus
  play-off winner" route is not a single table. Sizes of the League 2 groups were not verified.

## Confidence

**High** for the league: 16 clubs, 30 rounds, 3 down, all three facts corroborated by the season
article and the league overview. **Medium** for the level-2 route, which is described from the
promoted-club list and the league overview only.
