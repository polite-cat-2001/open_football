# Senegal — football pyramid, 2026-27

Two professional levels, both **16 clubs, one group, double round robin, 30 rounds**, and both
governed by the Ligue Sénégalaise de Football Professionnel (LSFP). Promotion and relegation are
simple **2 up / 2 down with no play-offs at either end**: the Ligue 1 bottom two drop, the Ligue 2
top two rise. A club relegated from Ligue 2 goes into the National 1 amateur level (level 3, not in
our dataset).

The Senegalese season is an autumn-to-spring one. 2026-27 was due to start on 3 October 2026 and
was pushed back to **17 October 2026**, finishing in June 2027.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | SEN1 | Ligue 1 (Lonase BET) | 16 | single table, double round robin | 30 | — (closed) | 2 direct |
| 2 | SEN2 | Ligue 2 | 16 | single table, double round robin | 30 | 2 direct | 2 direct |

There are no play-offs anywhere in the professional pyramid, so the `playoff` fields are `null` and
the boundary is a pure swap.

## Level 1 — Ligue 1

- 16 clubs, 30 rounds. Champion = most points after 30 rounds (2025-26: Teungueth FC, third title).
- Champion enters the CAF Champions League; the cup winner enters the CAF Confederation Cup.
- Bottom two are relegated (2026: AS Cambérène, ASC Sonacos).
- 2026-27 promoted pair: Diambars FC and Essamaye FC.
- This is the third edition at 16 clubs (2023-24, 2025-26, 2026-27) after a one-season cut to 14 for
  2024-25.

## Level 2 — Ligue 2

- 16 clubs, 30 rounds (expanded from 14 for 2024-25).
- Top two promoted directly; bottom two relegated to National 1.
- 2026-27 field: 12 survivors, 2 promoted from National 1 (ASFA Dakar, Dakar FC) and the two clubs
  relegated from Ligue 1.

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| SEN1 | Ligue 1 | 1 | 1 | 16 | 16 | correct |
| SEN2 | Ligue 2 | 2 | 2 | 16 | 16 | correct |

Both correct (16/16, levels 1/2). One cosmetic point: the top flight's sponsored name is "Ligue 1
Lonase BET".

## Caveats

- National 1 (level 3) and below are not modelled, so Ligue 2 is closed downward in our dataset
  although clubs really are relegated into it.
- The Ligue 2 field can contain reserve sides (academy B teams); the source pages do not spell out a
  promotion ban, so treat any reserve club as an ordinary entrant.
- Senegal has no league play-offs at all, so any "promotion play-off" logic must be disabled.

## Sources

- https://fr.wikipedia.org/wiki/Championnat_du_S%C3%A9n%C3%A9gal_de_football_2026-2027
- https://fr.wikipedia.org/wiki/Championnat_du_S%C3%A9n%C3%A9gal_de_football
- https://fr.wikipedia.org/wiki/Championnat_du_S%C3%A9n%C3%A9gal_de_football_de_deuxi%C3%A8me_division
- https://fr.wikipedia.org/wiki/Championnat_du_S%C3%A9n%C3%A9gal_de_football_de_deuxi%C3%A8me_division_2026-2027
- https://en.wikipedia.org/wiki/Ligue_1_(Senegal)
