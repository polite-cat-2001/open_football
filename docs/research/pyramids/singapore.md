# Singapore — football pyramid, 2026-27

Singapore's top flight is a **closed invitation league**. There is no promotion and no relegation
anywhere in the country's senior game: clubs do not play their way into the Singapore Premier
League, they are admitted by the Football Association of Singapore, and nobody is relegated out of
it. The Singapore Football League (SFL, levels 2-3 by the official description) sits below, but it
is a separate competition with no sporting link upward.

What our database also has is **SPL2**, the reserve league launched in 2025-26. It is not a tier of
the pyramid: it is the reserve/development competition for the eight SPL clubs, one second team
each, and it exists to give U23 locals minutes.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | SIN1 | Singapore Premier League (AIA) | 8 | single table, four meetings | 28 | — (closed) | — (closed) |
| 99 | SIN2 | Singapore Premier League 2 (SPL2) | 8 | single table, three meetings | 21 | — (closed) | — (closed) |

No boundaries: neither league has a sporting route in or out.

## Level 1 — Singapore Premier League

- 8 clubs, all local since Albirex Niigata Singapore was localised as **FC Jurong** for 2026-27
  (DPMM left for Malaysia after 2024-25).
- 2026-27 runs 11 September 2026 to 16 May 2027 and each pair meets **four times** (28 matches per
  club, 112 in total).
- Champion takes the AFC Champions League Two place; Young Lions (the national U23 side) are
  ineligible for AFC competitions.
- **No relegation, no promotion.** Entry is by invitation and licensing.
- Note the format history: 2025-26 was played over **three** meetings (21 matches) to trim the
  calendar; 2026-27 is back to four.

## Level 99 — Singapore Premier League 2 (SPL2)

- 8 clubs — the reserve sides of the SPL clubs (Lion City Sailors II, Tampines Rovers II, etc.).
- 2026-27 runs 24 August 2026 to May 2027, 21 rounds (each pair meets three times).
- Development rules: squads are registered jointly for SPL and SPL2 (36-50 players, at least 25
  Singaporeans); at least six locals, four of them U23, must be on the pitch at all times.
- Closed in both directions: a reserve side cannot be promoted into the SPL, and there is nothing
  below to be relegated into. It replaced the SPL U21 league.

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| SIN1 | Singapore Premier League | 1 | 1 | 8 | 8 | correct |
| SIN2 | Singapore Premier League 2 | 99 | reserve league (not a tier) | 8 | 8 | correct as a t99 marker |

Rows are right. The thing to encode is the **absence** of promotion and relegation, not a size.

## Caveats

- The English SPL article's summary line ("four rounds ... 28 matches each") is right for 2026-27,
  but the 2025-26 season article and its format rules say three meetings — the two seasons genuinely
  differ. Recorded in `conflicts`.
- The real second tier, the Singapore Football League, is not in our dataset. Because SPL has no
  promotion route at all, this does not change any boundary — SIN1 is closed regardless.
- SPL2 clubs are reserve teams with the same names as their parents ("... II"); a simulator must not
  treat them as independent clubs that could be promoted.

## Sources

- https://en.wikipedia.org/wiki/Singapore_Premier_League
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Singapore_Premier_League
- https://en.wikipedia.org/wiki/2025%E2%80%9326_Singapore_Premier_League
- https://en.wikipedia.org/wiki/Singapore_Premier_League_2
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Singapore_Premier_League_2
- https://en.wikipedia.org/wiki/Singapore_football_league_system
