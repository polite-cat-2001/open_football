# Gibraltar — football pyramid, 2026-27

Gibraltar is the clearest case of a **closed pyramid in both directions**: nothing goes up out of the
Gibraltar Football League, nothing is automatically promoted into it, and there is no sporting route
below it at all. Entry to the GFL is a **licensing decision**, not a result.

## At a glance

| Level | id | Competition | Clubs | Format | Games | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | GI1 | Gibraltar Football League | 11 | double RR, then 6/5 split | 20 + 5 / 20 + 4 | — (closed) | — (closed) |
| 99 | GIIL | Gibraltar Reserve League (= Intermediate League) | 9 | development competition | — | none | none |

## Level 1 — Gibraltar Football League

- 11 clubs for 2026-27 (12 in 2025-26: **Manchester 62 folded in May 2026** after failing to submit
  licence documentation).
- Format: everyone plays everyone twice (20 games), then the **top six** play a five-game
  Championship Group (25 games in total) and the **bottom five** a four-game Challenge Group (24).
  Points and goals carry over in full, so the two tables are not comparable game-for-game.
- The champion is the Championship Group winner. The Challenge Group winner goes into a play-off
  with the 3rd–6th placed clubs of the Championship Group for the last Conference League place —
  that is a European play-off, not a promotion play-off.
- **No relegation.** There is no bottom-placed club that goes down, and no promotion from the
  Intermediate League by right: Hound Dogs joining the GFL in 2025 after six years in the
  Intermediate League was a licensing/entry decision, not a sporting promotion.

## Level 99 — "Gibraltar Reserve League"

Our row is the reserve/development competition. Its real name since June 2018 is the **Gibraltar
Intermediate League**; it replaced the Gibraltar Reserves Division and the Under-18 Division.

- Development rules: squads of up to 18 players, at least 13 must be eligible for the Gibraltar
  national team and at most 5 may be over 23; a salary cap applies.
- It contains a mix of U23 sides (St Joseph's, Bruno's Magpies, College 1975 ...) and the occasional
  senior side given special dispensation (Hound Dogs before 2025).
- **No sporting route**: nothing in it promotes to the GFL and nothing in the GFL relegates into it.
- Our size (9) could not be confirmed from the sources used and is kept as-is rather than guessed.

## Check against our database

| id | our name | our level | real level | our size | real size | verdict |
|---|---|---|---|---|---|---|
| GI1 | Gibraltar Football League | 1 | 1 | 11 | 11 | correct (11 only because Manchester 62 folded; 12 in 2025-26) |
| GIIL | Gibraltar Reserve League | 99 | 99 (reserve) | 9 | unconfirmed | level and role right, **name outdated** (Intermediate League) |

## Caveats

- The 11-club size is a 2026-27 accident of licensing. Any model that hardcodes 11 will be wrong the
  moment a club is relicensed.
- Because entry is by licence, "promotion" and "relegation" should be modelled as no-ops for this
  country, otherwise the sim will invent a route that does not exist.
- The Challenge Group has been created and scrapped more than once (scrapped 2025-26, back 2026-27),
  so the split shape is not stable either.

## Sources

- https://en.wikipedia.org/wiki/Gibraltar_Football_League
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Gibraltar_Football_League
- https://en.wikipedia.org/wiki/2025%E2%80%9326_Gibraltar_Football_League
- https://en.wikipedia.org/wiki/Gibraltar_Intermediate_League
