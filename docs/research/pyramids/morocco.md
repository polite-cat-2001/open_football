# Morocco — football pyramid, 2026-27

Morocco runs an August–May season. Cups, CAF competitions and the Leagues Cup-style extras are out of
scope. We carry only the top flight, so the JSON has no boundary — but the real league is not closed.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | MAR1 | Botola Pro Inwi | 16 | double round robin | 30 | — (closed) | 2 direct + 2 play-off |
| 2 | — | Botola 2 (not modelled) | 16 | — | — | 2 direct + 2 play-off | — |

## Level 1 — Botola Pro

- 16 clubs, 30 rounds, no split.
- **15th and 16th are relegated directly.**
- **13th and 14th play two-legged ties** against the Botola 2 4th and 3rd respectively. Away goals
  decide a level aggregate (no extra time in 2026's ties).
- Botola 2's top two come up directly, so four places change each season, two of them contested.

2025-26: US Yacoub El Mansour and Olympic Safi went down direct; Olympique Dcheira lost its tie to
US Amal Tiznit and went down too; UTS Rabat beat JS Massira and stayed.

## Why the JSON says closed_down

Our list stops at level 1. By the README rule a league with nothing below it in our data is
`closed_down: true` even though real clubs move — the route exists, we just do not model Botola 2.

## Check against our database

| id | our name | our level | real level | our size | real size | verdict |
|---|---|---|---|---|---|---|
| MAR1 | Botola Pro Inwi | 1 | 1 | 16 | 16 | correct |

"Botola Pro Inwi" is the sponsored name and is what Moroccan media use; the plain name is Botola Pro.

## Caveats

- The 2025-26 calendar ran late (finished 5 July 2026, play-offs 17-21 July) because of fixture
  congestion around the World Cup. Do not assume a tidy August start for every season.
- Relegation play-off pairings are fixed by position, not drawn.

## Sources

- https://en.wikipedia.org/wiki/2025%E2%80%9326_Botola_Pro
