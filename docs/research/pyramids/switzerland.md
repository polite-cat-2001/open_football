# Switzerland — football pyramid, 2026-27

Three levels: 12 / 10 / 18. The Super League is a **split** league (33 rounds of triple round robin,
then 6+6 for 5 more = 38, points carried). The Challenge League is a **10-club quadruple round
robin** (36 rounds). The Promotion League is an **18-club double round robin** (34 rounds).

Promotion and relegation are almost old-fashioned: **1 up / 1 down direct at each boundary, plus one
two-legged promotion/relegation tie between the Super League's 11th and the Challenge League's
runner-up**. The Challenge League's bottom club is relegated directly and replaced by the Promotion
League champion — there is no second-tier relegation play-off.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | C1 | Super League (Brack) | 12 | split 6+6 after 33 | 38 | — (closed) | 1 direct + 1 play-off |
| 2 | C2 | Challenge League (Dieci) | 10 | single table, 4 meetings | 36 | 1 direct + 1 play-off | 1 direct |
| 3 | CHPR | Promotion League (Hoval) | 18 | single table, double round robin | 34 | 1 direct | 2 direct |

The 1. Liga Classic (level 4) is not in our dataset, so the Promotion League is closed downward here.

## Level 1 — Super League

- 12 clubs. Phase 1: each plays the other 11 three times (33 rounds). Phase 2: split into a 6-club
  championship group and a 6-club relegation group, one match against each group rival (5 more) →
  **38 per club**, points carried.
- **Relegation:** 12th (last in the relegation group) goes down directly; **11th plays the Challenge
  League runner-up** over two legs (2026-27: 1 and 4 June 2027).
- 2026-27: Vaduz returned after five years as Challenge League champions; Winterthur was relegated.
  Thun defend the title.
- Season 24 July 2026 to 30 May 2027, winter break after matchday 19 (20 December) to 16 January.

## Level 2 — Challenge League

- 10 clubs, 36 rounds (four meetings each), the deepest round count in the country.
- Champion promoted; **runner-up plays the Super League 11th** over two legs.
- **Bottom club relegated directly** and replaced by the Promotion League champion — a simple
  1-up/1-down link, no bottom play-off.
- 2026-27: Winterthur and Kriens came in; Vaduz went up, Bellinzona went down.

## Level 3 — Promotion League

- 18 clubs, 34 rounds, the semi-professional bridge to amateur football.
- **Champion promoted subject to the professional licensing requirements**; if the champion is not
  licensed, no club goes up.
- **Bottom two relegated** to the 1. Liga Classic (level 4, three regional groups, not modelled).
- This is the highest Swiss league that allows reserve/U21 teams (unrestricted number), so a
  reserve side can win it but cannot be promoted to the Challenge League.

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| C1 | Super League | 1 | 1 | 12 | 12 | correct |
| C2 | Challenge League | 2 | 2 | 10 | 10 | correct |
| CHPR | Promotion League | 3 | 3 | 18 | 18 | correct |

Nothing to correct. As with Scotland, the Super League is not a plain double round robin.

## Caveats

- The Super League's split gives 38 matches, not 36 (12 clubs × 3) and not 33 — the triple round
  robin plus split is unusual and easy to mis-implement.
- Licensing decides both promotions (Promotion League → Challenge League, and Challenge League
  champion → Super League in principle), so a table-topping club can be held back.
- Reserve teams in the Promotion League are a hazard for "champion goes up" logic.
- Level 4 (1. Liga Classic) is regional (three groups), so nothing below should be hardcoded.

## Sources

- https://en.wikipedia.org/wiki/2026%E2%80%9327_Swiss_Super_League
- https://en.wikipedia.org/wiki/Swiss_Challenge_League
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Swiss_Challenge_League
- https://en.wikipedia.org/wiki/Promotion_League
