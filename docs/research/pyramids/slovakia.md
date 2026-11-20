# Slovakia — football pyramid, 2026-27

Slovakia's top flight is a 12-club **split** league: 22 rounds double round robin, then the table
splits into a 6-club championship group and a 6-club relegation group, each playing home and away
again for 10 more matches (32 per club, points carried). The second tier is a plain 16-club double
round robin.

The boundary is a **2-up / 2-down** with one shared two-legged tie: the 11th-placed club of the
Niké liga plays the 2nd-placed club of the 2. Liga, and the winner plays in the top flight. The
champion of the 2. Liga goes up directly (subject to licensing), and the bottom club of the Niké
liga goes down directly.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | SLO1 | Niké liga | 12 | split 6+6 after 22 | 32 | — (closed) | 1 direct + 1 play-off |
| 2 | SK2 | II. Liga (MONACObet) | 16 | single table, double round robin | 30 | 1 direct + 1 play-off | 2 direct |
| 99 | SK19 | I. liga staršieho dorastu (U19) | 14 | youth championship | n/a | — (closed) | — (closed) |

Level 3 (3. Liga) is not in our dataset, so the II. Liga is closed downward here although its
bottom two really are relegated.

## Level 1 — Niké liga

- 12 clubs, 22 + 10 = **32 matches**. Points from the first phase are carried into the split groups,
  which produce the final ranking.
- The 12th-placed club is relegated directly; **11th plays the II. Liga runner-up over two legs**
  (baráž). This is one shared tie: if the second-tier club wins, it is promoted and the top-flight
  club goes down.
- 2026-27 started 25-26 July 2026, winter break 13 December 2026 to 7 February 2027, ends May 2027.
  Dukla Banská Bystrica came up as 2025-26 II. Liga champions, replacing Tatran Prešov.
- The split is not a "half the points" system — everything carries.

## Level 2 — II. Liga (MONACObet liga)

- 16 clubs, 30 rounds, double round robin (2017-18 format, after a spell at 12).
- Champion promoted **subject to meeting league requirements**; 2nd enters the two-legged play-off
  against the Niké liga 11th.
- Bottom two relegated to the 3. Liga.
- **Reserve sides are present** (Slovan Bratislava B, Žilina B) and cannot be promoted, so a
  notional top-two finish by a B team must not produce a promotion.

## Level 99 — I. liga staršieho dorastu (U19)

- The national **under-19** ("starší dorast") championship, played by the youth sides of the
  professional clubs in one national league. It is a youth competition, not a senior tier: no
  promotion into the Niké liga and nothing to be relegated into.
- Our row records 14 clubs. No public table could be found to confirm the 2026-27 size, so it is
  kept and flagged in `conflicts` rather than changed.

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| SLO1 | Niké Liga | 1 | 1 | 12 | 12 | correct |
| SK2 | II. Liga | 2 | 2 | 16 | 16 | correct |
| SK19 | I. Liga starsieho dorastu | 99 | youth (U19) | 14 | 14 (unverified) | t99 marker correct; size not verifiable |

Names: the ids SLO1/SK2 are inconsistent in style but the leagues are right; the II. Liga's sponsored
name is MONACObet liga.

## Caveats

- The split means 32 matches, not 30 — a plain double round robin gives the wrong fixture count.
- Licensing is a real gate on promotion (a champion without a licence is not promoted and the place
  can pass down), so promotion is not purely sporting.
- Reserve teams in the II. Liga are a live hazard for any "top two go up" rule.
- Youth size unverified.

## Sources

- https://en.wikipedia.org/wiki/2026%E2%80%9327_Slovak_First_Football_League
- https://en.wikipedia.org/wiki/Slovak_First_Football_League
- https://sk.wikipedia.org/wiki/Nik%C3%A9_liga
- https://en.wikipedia.org/wiki/2._Liga_(Slovakia)
- https://en.wikipedia.org/wiki/2026%E2%80%9327_2._Liga_(Slovakia)
