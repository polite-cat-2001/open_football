# United States — professional leagues, 2026

Calendar-year leagues (February/March → November/December). Three separate organisations, no
promotion or relegation anywhere yet.

| Level | Competition | Clubs | Shape | Games |
|---|---|---|---|---|
| 1 | Major League Soccer (MLS) | 30 | 2 conferences × 15, then conference play-offs | 34 |
| 2 | USL Championship | 25 | 2 conferences (13 + 12), then play-offs | 34 |
| 3 | MLS Next Pro | 30 | 2 conferences, then play-offs | 28 |
| 3 | USL League One | 17 | single table, then play-offs | 32 |

All four sizes match our rows.

## MLS is closed — and its conferences are one league

30 clubs (15 Eastern, 15 Western), 34 regular-season matches, six-week break for the 2026 World
Cup, then conference play-offs ending in MLS Cup on 18 December. 2026 is the last full
spring-autumn season: MLS moves to a summer-spring calendar from 2027-28, with a short 14-match
2027 season in between.

There is **no promotion and no relegation**: membership is by franchise award. The two conferences
are not separate leagues — they are one competition whose regular season is conference-weighted and
whose champion is decided by a conference play-off bracket. Nothing links MLS to the USL leagues;
they are rival organisations, and a USL club reaches MLS only by buying an expansion franchise
(Cincinnati, Nashville, San Diego and others did exactly that).

## USL Championship is its own structure

25 clubs in 2026 (13 Eastern, 12 Western), 34 matches, top eight per conference into the play-offs,
Players' Shield for the best overall record, USL Championship final for the title. It is sanctioned
as Division II and sits **outside** MLS: no promotion up, no relegation down.

The USL has voted to introduce promotion and relegation, but not yet: a new Division I league,
**USL Premier**, is planned for 2028, with the Championship between it and League One connected by
pro/rel from 2027-28. Until then every USL league is closed, and the 2026 season is played under the
old closed rules.

## MLS Next Pro is MLS's reserve league

30 clubs (2026), 28 matches in a mostly regionalised schedule, two conferences split into divisions
of seven or eight for scheduling. Top nine per conference reach the play-offs; new for 2026, 8th and
9th meet in a play-in round and the higher seeds then pick their opponents.

It is MLS's own second-tier development competition (Division III sanction), containing the reserve
sides of MLS clubs plus a few independent clubs (Chattanooga won the 2026 title, the first
independent winner). It is **not** below USL Championship in any sporting sense and has no
promotion or relegation of any kind — clubs enter and leave with their MLS parent.

## USL League One is the USL's third tier

17 clubs, 32 matches (double round-robin), top eight into the play-offs. It is the USL's own third
division, below the USL Championship but with **no automatic promotion** in 2026; the planned
Championship ↔ League One pro/rel starts with the 2027-28 reorganisation. Seven clubs in our four
rows is the whole US structure we model; the fourth USL tier (League Two, amateur) and the
independent NPSL are outside.

## What this means for a career sim

- Every one of these leagues is `closed_up` and `closed_down`. There are no boundary objects to
  generate, and no club can ever be promoted or relegated.
- The two "level 3" rows (MNP3, USC3) are **not** two divisions of one pyramid: they belong to
  different organisations (MLS and USL) and never exchange clubs.
- Sizes move constantly (expansion fees, folded clubs, clubs moving between USL and MLS). Treat all
  four numbers as 2026 snapshots.

## Data problems in our rows

1. The four sizes and the "closed" status are all correct.
2. `MNP3` and `USC3` share level 3 in our data, which is harmless as a label but implies a
   relationship that does not exist. They are parallel, rival third-tier leagues.
3. `MLS1` at level 1 is right, but nothing below it in our rows connects to it. Do not build a
   boundary from MLS to the USL Championship.

## Confidence

High on MLS (30 clubs, two conferences of 15, 34 matches, no pro/rel, calendar change from 2027-28),
on USL Championship (25 clubs, 8 per conference) and on USL League One (17 clubs, 32 games, top 8).
High on MLS Next Pro's 30 clubs and top-nine play-off. Medium only on MLS play-off field size, which
the season article does not spell out.

## Sources

- https://en.wikipedia.org/wiki/2026_Major_League_Soccer_season (30 clubs, 15 per conference, 34 matches, calendar change)
- https://en.wikipedia.org/wiki/USL_Championship (25 teams, two conferences, top eight per conference, planned USL Premier/pro-rel)
- https://en.wikipedia.org/wiki/2026_MLS_Next_Pro_season (30 clubs, 28 matches, top nine per conference, play-in and pick-your-opponent)
- https://en.wikipedia.org/wiki/2026_USL_League_One_season (17 teams, 32 games, top eight)
