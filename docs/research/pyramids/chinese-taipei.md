# Chinese Taipei — football pyramid 2026-27

Scope: the two leagues in our database (TFPL, TFL2). No cups, no AFC competitions.
Research date: 2026-11-20. The season is in progress (13 September 2026 – 2 May 2027), so club
lists are real but final standings do not exist.

## Pyramid at a glance

| id | League | Level | Clubs | Rounds per club | Shape |
|----|--------|-------|-------|-----------------|-------|
| TFPL | Taiwan Football Premier League | 1 | 8 | 21 | one table, triple round-robin |
| TFL2 | Taiwan Football League Div. 2 | 2 | 10 | 18 | one table, double round-robin |

Both of our rows are right for this season: **8** in the top flight and **10** in League 2.

## 2026-27 is an expansion season: nobody is relegated from the top flight

The TFPL normally relegates its 8th-placed club and sends 7th into a two-legged play-off against
the League 2 runner-up; the League 2 champion goes up directly. **For 2026-27 only** the CFA
decided there would be no relegations, because the league expands for 2027-28. In the same move
League 2 promotes **two** clubs (1st and 2nd are both marked as promotion places in the 2026-27
table) instead of one plus a play-off.

So this season the boundary moves **2 up, 0 down**. The standing rule (1 up + 1 play-off,
1 down + the same play-off) is what a career sim should use for any other season, and it is what
the JSON note says.

## Format details

- **TFPL** — three round-robin tournaments of seven games each, i.e. every club plays the other
  seven three times (21 matches). One table, no split, no carried points. Champion takes the AFC
  Challenge League berth.
- **TFL2** — double round-robin over ten clubs (18 matches). Below it there is no league
  relegation: clubs enter through pre-season qualifiers and can decline to enter (three did not
  for 2026-27), which is why the league had to be rebuilt to ten clubs.

## Boundaries

Only one boundary exists inside our data: 1–2.

| between | up | of which PO | down | of which PO | allocation | selection |
|---------|----|-------------|------|-------------|------------|-----------|
| 1–2 (2026-27) | 2 | 0 | 0 | 0 | free | other |

- Up: League 2 1st and 2nd (expansion season).
- Down: none (expansion season).
- Normal rule, for reference: League 2 champion up; League 2 runner-up v TFPL 7th over two legs
  for one shared place; TFPL 8th down. That is 2 up / 2 down in a normal year, one of each
  decided by the same tie.

## Oddities

- The League 2 article's "competition format" prose is stale: it describes eight clubs, 14 games
  and a July–November schedule. The 2026-27 season article and the team list (ten clubs,
  18 games, September–May) are the current facts.
- League 2 contains reserve teams (Kaohsiung Attackers Reserves, New Taipei Hang Yuan Reserves,
  Sunny Bank AC Taipei Reserves). Unlike most pyramids, they are not barred from promotion here.
- Taiwan switched from calendar-year to September–May for 2025-26, so "2026-27" is the second
  season of the new rhythm.

## Sources

- https://en.wikipedia.org/wiki/Taiwan_Football_Premier_League — 8 clubs, 21-game format, normal
  promotion/relegation rule (8th down, 7th in a play-off)
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Taiwan_Football_Premier_League — 8 clubs,
  triple round-robin ("each team plays a total of 21 games"), "no relegations for this season due
  to the upcoming league expansion"
- https://en.wikipedia.org/wiki/Taiwan_Second_Division_Football_League — level 2, promotion to
  TFPL, play-off description (stale prose: 8 clubs/14 games)
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Taiwan_Football_League_2 — ten clubs, "expanded to
  10 teams for this season", 18 games, top two marked as promotion

## Confidence

**Medium.** Sizes, levels and the one-off expansion rule are stated explicitly in the 2026-27
season articles. The normal-year boundary mechanics rest on the league articles' prose and are
not exercised this season, and the new top-flight size for 2027-28 is not stated anywhere I could
read.
