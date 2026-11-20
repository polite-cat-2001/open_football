# South Africa — football pyramid, 2026-27

Only the top flight is in our database, and it is a normal 16-club double round robin (30 rounds).
The South African twist is at the bottom: **one club is relegated directly and the club just above
it goes into a three-team mini-league** with the 2nd and 3rd clubs of the Motsepe Foundation
Championship (the National First Division). The mini-league winner plays in the Premiership next
season; it is a round robin, not a knockout and not a two-legged tie.

So the Premiership's 15th place is **not** an automatic relegation, and its 16th is.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | SFA1 | Betway Premiership (PSL) | 16 | single table, double round robin | 30 | — (closed) | 1 direct + 1 play-off |

The National First Division (level 2) and the ABC Motsepe League (level 3) are not in our dataset,
so the Premiership is closed downward here even though the relegation route is real.

## Level 1 — Betway Premiership

- 16 clubs, 30 rounds, August to May; three points for a win. 2026-27 is the 31st consecutive PSL
  season.
- Champion and runner-up enter the CAF Champions League; 3rd plus the Nedbank Cup winner enter the
  CAF Confederation Cup.
- **Relegation:** 16th goes down automatically and is replaced by the Championship winner;
  **15th enters the promotion/relegation play-off** with the Championship's 2nd and 3rd.
- 2026-27 changes: Kruger United and Milford promoted (both top-flight debutants), Orbit College and
  Magesi down — one direct, one through the play-off.
- Orlando Pirates are defending champions, ending Sundowns' eight-year run.

## The promotion/relegation play-off

- Three clubs: Premiership 15th, Championship 2nd, Championship 3rd.
- Single round robin (each plays the other two), usually staged after the league season; the winner
  takes the last Premiership place.
- Because it is a mini-league, "legs" is not meaningful: recorded as 1 with a note.

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| SFA1 | Betway Premiership | 1 | 1 | 16 | 16 | correct |

Nothing to correct. The row is a plain 16-club league; only the relegation rule needs care.

## Caveats

- The Championship (level 2) is not modelled, so the play-off's two second-tier entrants have no ids
  in our dataset. A simulation that only knows SFA1 cannot stage the mini-league; it can at best
  auto-relegate 16th and keep 15th.
- Ownership/feeder links (e.g. two clubs under one owner) are a real licensing issue in South Africa
  but do not change the pyramid shape.
- The play-off is a mini-league, not a two-legged final — a knockout implementation would be wrong.

## Sources

- https://en.wikipedia.org/wiki/South_African_Premiership
- https://en.wikipedia.org/wiki/2026%E2%80%9327_South_African_Premiership
