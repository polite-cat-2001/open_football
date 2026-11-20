# Hong Kong — football pyramid, 2026-27

Four senior levels, all run by the HKFA: Premier League (1), First Division (2), Second Division (3),
Third Division (4, not in our rows). Promotion into the top flight is **a licence, not a table
position**, and the third tier is the only one with a split.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | HGKG | Hong Kong Premier League | 11 | double round robin | 20 | — (closed) | 1 |
| 2 | HK2L | Hong Kong First Division | 14 | double round robin | 26 | 2 offered (licence) | 2 |
| 3 | HK3L | Hong Kong Second Division | 16 | single RR, then 8/8 split | 15 + 7 | 2 | 2 |
| 4 | — | Hong Kong Third Division (not modelled) | — | — | — | 2 | bottom club leaves the system |
| 99 | HK22 | Hong Kong U22 League | 11 | age-group competition | — | none | none |

## Level 1 — Hong Kong Premier League

- 11 clubs, double round robin, 20 matches. No split, no title play-off: the table winner is champion.
- **Relegation:** bottom club goes down (one place).
- **Promotion in:** the First Division's top two are *offered* promotion, but a Premier League place
  needs the HKFA club licence and a professional structure. Clubs decline or fail licensing often,
  so in most seasons fewer than two come up — 2026-27 runs with 11 clubs after Sha Tin alone went up.

## Level 2 — Hong Kong First Division

- 14 clubs, double round robin, 26 matches.
- Top two offered promotion (see above); bottom two relegated to the Second Division.
- 2026-27 intake: Kui Tan and Leaper up from the Second Division; Kwun Tong down.

## Level 3 — Hong Kong Second Division

- 16 clubs. Everyone plays everyone **once** (15 games), then the table splits into a
  **Championship Group** of the top eight and a **Challenging Group** of the bottom eight, each
  playing a further single round robin (7 games) — 22 in total, points carried.
- Top two of the Championship Group are promoted; bottom two of the Challenging Group are relegated
  to the Third Division.
- 2026-27 intake: Kwun Tong down from the First Division; Sun Hei, Double Flower and Tsun Tat up from
  the Third Division; Mutual relegated.

## Level 99 — Hong Kong U22 League

- An **age-group competition**, not a senior division. No promotion into the pyramid and nothing
  relegates into it; the closed flags are true in both directions by definition.
- Our row's size (11) could not be confirmed from a league source — treat it as our own value.
  Do not confuse it with the Sapling Cup (a first-team cup with a mandatory under-22 quota) which was
  discontinued after 2025-26.

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| HGKG | Hong Kong Premier League | 1 | 1 | 11 | 11 | correct |
| HK2L | Hong Kong First Division | 2 | 2 | 14 | 14 | correct |
| HK3L | Hong Kong Second Division | 3 | 3 | 16 | 16 | correct |
| HK22 | Hong Kong U22 League | 99 | 99 (age group) | 11 | unconfirmed | role right, size unverified |

## Caveats

- The Premier League's size is not a stable number: 9, 10, 11 and 12 have all happened since 2014,
  driven by licensing and self-relegation (South China dropped itself in 2017).
- Because promotion is licensed, a model that always promotes the First Division's top two will drift
  the top flight upward every season.
- The Second Division's group sizes follow the entry list (8+7 in a 15-club season), so the split
  shape is a consequence of the size, not a fixed rule.

## Sources

- https://en.wikipedia.org/wiki/2026%E2%80%9327_Hong_Kong_Premier_League
- https://en.wikipedia.org/wiki/Hong_Kong_Premier_League
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Hong_Kong_First_Division_League
- https://en.wikipedia.org/wiki/Hong_Kong_First_Division_League
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Hong_Kong_Second_Division_League
- https://en.wikipedia.org/wiki/Hong_Kong_Second_Division_League
- https://en.wikipedia.org/wiki/Football_in_Hong_Kong
