# India — football pyramid, 2026-27

India now has **four national divisions** plus the state leagues: Indian Super League (1), Indian
Football League (2, the renamed I-League), I-League 2 (3), I-League 3 (4), state leagues (5). Our
rows cover the first three, so I-League 2's relegation has no destination in the dataset.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | IND1 | Indian Super League (MG) | 13 | double round robin + top-6 Cup play-offs | 24 | — (closed) | 1 |
| 2 | INIL | Indian Football League | 11 | double round robin | 20 | 1 (licence + fee) | 2 |
| 3 | IND2 | I-League 2 | 8 | one table (rounds not documented) | — | 2 | 2 |
| 4 | — | I-League 3 (not modelled) | — | — | — | 2 | — |
| 5 | — | State leagues (not modelled) | — | — | — | — | — |

## Level 1 — Indian Super League

- **13 clubs** in 2026-27, down from 14. Jamshedpur withdrew before the season (participation fee) and
  **Diamond Harbour** — the IFL champion — never took its promoted slot, so the AIFF ruled it would be
  deemed to finish bottom, earn no points, and play in the IFL in 2027-28.
- 24 rounds, double round robin, home and away — the league returned to a full home-and-away calendar
  under the new club-led commercial model.
- **Title:** the league table decides the league champion; the **ISL Cup** is a separate top-six
  knockout (3rd–6th single-leg, two-legged semis, single-leg final). It is not a promotion play-off.
- **Relegation:** one club (bottom) goes down; the AIFF confirmed relegation continues in 2026-27
  after briefly considering a one-season suspension.

## Level 2 — Indian Football League (ex-I-League)

- Rebranded in 2026: the I-League became the **Indian Football League**, with the clubs becoming the
  competition's organisers under an AIFF licence.
- **11 clubs**, double round robin (20 games).
- **Promotion:** champion up, but subject to paying the ISL participation fee and holding the licence.
  Diamond Harbour won the 2025-26 title, were promoted, could not pay, and lost the place — the
  cleanest illustration in this dataset that an Indian "promotion" is a commercial act.
- **Relegation:** bottom two down to I-League 2.
- Clubs joined the AIFF Academy Accreditation Programme for 2026-27 (minimum two stars by 2027-28).

## Level 3 — I-League 2

- 8 clubs; the season article does not state the round structure, so `rounds` is null rather than
  guessed.
- Two clubs promoted to the IFL each season, two relegated to I-League 3.
- 2025-26: Delhi FC champions; Delhi FC and Bengaluru United went up (Delhi's licence later moved to
  Samaleswari SC).

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| IND1 | Indian Super League | 1 | 1 | 13 | 13 | correct |
| INIL | Indian Football League | 2 | 2 | 11 | 11 | correct, and the name is the current rebrand |
| IND2 | I-League 2 | 3 | 3 | 8 | 8 | correct |

No numeric conflicts. The structural gap is I-League 3 (level 4) and the state leagues (level 5),
both absent from our rows.

## Caveats

- Indian club football is administratively unstable: relocations (Punjab, Delhi), licence transfers
  (Jamshedpur → Churchill Brothers; Delhi FC → Samaleswari) and fee-driven withdrawals change the
  entry list between seasons.
- Because promotion requires money, a model that always promotes the IFL champion will create clubs
  in the ISL that could never afford to be there.
- Reserve sides are excluded from I-League 3, so the development path runs through the IFL's own
  academy accreditation rather than a reserve league.

## Sources

- https://en.wikipedia.org/wiki/2026%E2%80%9327_Indian_Super_League
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Indian_Football_League
- https://en.wikipedia.org/wiki/2026%E2%80%9327_I-League_2
- https://en.wikipedia.org/wiki/Indian_football_league_system
- https://en.wikipedia.org/wiki/Indian_Football_League
