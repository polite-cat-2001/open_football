# Saudi Arabia — football pyramid, 2026-27

Two modelled levels, both 18 clubs and both plain double round robins over 34 rounds. The link
between them is **3 up / 3 down**, with one of the three promotion places decided by a short
end-of-season play-off in the First Division. The Pro League sends its bottom three down
automatically; there is no relegation play-off in the top flight.

Note the shape of the play-off: the First Division's 3rd-6th play off as 5th v 4th and 6th v 3rd,
with a **single-leg final hosted by the higher-placed club** — not a two-legged tie as in most
second tiers.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | SA1 | Saudi Pro League (Roshn) | 18 | single table, double round robin | 34 | — (closed) | 3 direct |
| 2 | SA2L | Saudi First Division League (Yelo) | 18 | single table, double round robin | 34 | 2 direct + 1 play-off | 3 direct |

## Level 1 — Saudi Pro League

- 18 clubs, 34 rounds, August to May. 2026-27 runs 13 August 2026 to 29 May 2027, with a long
  winter break (24 December to 7 February) because Saudi Arabia hosts the 2027 AFC Asian Cup.
- Bottom three are relegated directly (2026: Al-Najma, Al-Okhdood, Damac).
- No title play-off and no relegation play-off.

## Level 2 — Saudi First Division League

- 18 clubs, 34 rounds.
- **Promotion:** top 2 direct (2026: Abha, Al-Faisaly). 3rd-6th enter the play-off: 5th hosts 4th,
  6th visits 3rd, both single matches; the final is one match at the higher-placed club's ground
  (2026: Al-Diriyah won it).
- **Relegation:** bottom three go down to the Saudi Second Division League (level 3, not in our
  dataset).

## Boundary 1-2

3 up / 3 down. One of the three up-places is the play-off, so the boundary is not a pure
bottom-three swap: the Pro League's 16th-18th always go down, while the First Division's 3rd-6th
have a second chance.

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| SA1 | Saudi Pro League | 1 | 1 | 18 | 18 | correct |
| SA2L | Saudi First Division League | 2 | 2 | 18 | 18 | correct |

Both names are the official ones; the sponsored names (Roshn, Yelo) are aliases. Nothing to fix.

## Caveats

- The Saudi Second Division (level 3) is not modelled, so the First Division is closed downward in
  our dataset even though clubs really do drop into it.
- Foreign-player quotas (10 registered, 8 available per match, at least 2 under-21) are squad rules,
  not pyramid shape — out of scope here but they affect squad data.
- The 2026-27 First Division article is a stub; the play-off format is taken from the league article
  and the 2026 outcome.

## Sources

- https://en.wikipedia.org/wiki/2026%E2%80%9327_Saudi_Pro_League
- https://en.wikipedia.org/wiki/Saudi_Pro_League
- https://en.wikipedia.org/wiki/Saudi_First_Division_League
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Saudi_First_Division_League
