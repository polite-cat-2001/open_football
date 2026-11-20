# Austria — football pyramid 2026-27

Scope: level 1 only (Bundesliga). The 2. Liga is not in our rows. No cups, no European places (the
separate Conference League play-off is excluded).

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Austrian_Football_Bundesliga | 12 clubs, season 1 Aug 2026 – 17 May 2027, `result1-6=C` / `result7-12=R` split markers, Blau-Weiß Linz relegated and Austria Lustenau promoted after 2025-26 |
| https://en.wikipedia.org/wiki/Austrian_Football_Bundesliga | `teams = 12 (since 2018-19)`, the full split description, points halved and rounded down, 32 games, last in the Relegation Round demoted, 2. Liga champion promoted |

## League

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| A1 | Bundesliga | 1 | 12 | 22 rounds + split 6/6 = 32 rounds | — (top) | 1 direct |

Our row (A1, level 1, 12 clubs) is correct.

## Format

- 12 clubs, double round-robin: 22 rounds, 132 matches, every pair home and away.
- Then the table splits: **1st–6th** into the Championship Round, **7th–12th** into the Relegation Round.
- **Points are halved and rounded down** before the second phase — the only league in this batch that
  does not carry its table forward intact. This is why `points_carry` is false and a note is attached;
  a sim that just carries points will get the second half of the Austrian season wrong.
- Each group of six plays another double round-robin (10 more matches), so every club plays **32**
  games in the season.
- The winner of the Championship Round is champion. In the Relegation Round only the **last** club is
  demoted; the 2. Liga champion takes its place. There is no relegation play-off in this description
  (the 2. Liga promotion route is inside the 2. Liga).
- A Conference League play-off between the Championship Round clubs runs after the season; it decides a
  European place only and is out of scope.

## Boundary 1–2

- Down: 1 club, the bottom of the Relegation Round.
- Up: 1 club, the 2. Liga champion.
- Straight swap, no play-off at this boundary, so 12 clubs every season.

Because the 2. Liga is not in our list, the league is marked `closed_down: true` even though one club
really is relegated each year; the real movement is described here and in `notes`.

## Oddities

- The halving creates a permanent discontinuity: a club that ends the regular season 6 points clear
  starts the Championship Round 3 points clear, and rounding down can shrink a 1-point gap to 0. Any
  simulation of Austria needs this rule, not just the group split.
- The split is 6/6, so "relegation" is decided among six clubs over ten extra matches; the bottom club
  of the regular season is not automatically down.
- Austria's league is run by a separate association (the Bundesliga) that organises both of the top two
  divisions, so level 1 and level 2 are administered together — a structural detail our model flattens.

## Confidence

**High.** Size, split, halving, 32 rounds and the 1-up/1-down swap come from the league article and are
corroborated by the 2026-27 season article's table markers and its promotion/relegation note.
