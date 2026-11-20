# Luxembourg — football pyramid, 2026-27

Luxembourg runs one **August–May** season, so "2026-27" is literal. Cups and UEFA competitions
are out of scope.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | LUX1 | National Division (BGL Ligue) | 16 | double round robin | 30 | — (closed) | 2 direct + 2 play-off |
| 2 | LUX2 | Division of Honour (Ehrenpromotion) | 16 | double round robin | 30 | 2 direct + 2 play-off | 2 direct + 2 play-off (to level 3) |
| 3 | — | 1. Division, two series (not modelled) | — | two series | — | series runners-up | — |

Both of our levels are 16 clubs and 30 rounds — check.

## Level 1 — National Division

- 15th and 16th are relegated directly.
- **13th and 14th play one-off ties** against the Division of Honour's 4th and 3rd respectively.
  Each tie decides one place: the winner is in the National Division next season.
- 2025-26 as an example: 15th Pétange and 16th Rodange went down, Mamer (13th) lost its tie to
  Wiltz and Canach (14th) lost to Walferdange — four clubs left, four came in.

## Level 2 — Division of Honour (Ehrenpromotion)

- Top two promoted directly; 3rd and 4th into the ties described above.
- **Relegation:** 15th and 16th down to the 1. Division; 13th and 14th play the runners-up of the two
  1. Division series.
- Our name "Ehrenpromotion" is the German form. The Luxembourgish press writes *Éierepromotioun*, the
  French *Promotion d'Honneur*; all three are the same league.

## Boundary in numbers

4 places each way, 2 of them contested. If both National Division clubs win their ties, only two clubs
change level and the Division of Honour gains nothing — so the model should treat the four places as
"up to 4", not a fixed 4.

## Check against our database

| id | our name | our level | real level | our size | real size | verdict |
|---|---|---|---|---|---|---|
| LUX1 | BGL Ligue | 1 | 1 | 16 | 16 | correct |
| LUX2 | Ehrenpromotion | 2 | 2 | 16 | 16 | correct (German name) |

## Sources

- https://en.wikipedia.org/wiki/2025%E2%80%9326_Luxembourg_National_Division
- https://en.wikipedia.org/wiki/Luxembourg_Division_of_Honour
- https://en.wikipedia.org/wiki/2025%E2%80%9326_Luxembourg_Division_of_Honour
