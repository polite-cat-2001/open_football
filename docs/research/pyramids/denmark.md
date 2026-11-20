# Denmark — football pyramid 2026-27

Scope: levels 1–4 as carried in our database (Superliga, 1. Division, 2. Division, 3. Division).
No cups, no UEFA competitions.
Research date: 2026-11-20. Season in progress (started late July 2026).

## Pyramid at a glance

| id | League | Level | Clubs | Rounds per club | Shape |
|----|--------|-------|-------|-----------------|-------|
| DK1 | Superliga | 1 | 12 | 22 + 10 | regular season, then top 6 / bottom 6 |
| DK2 | 1. Division | 2 | 12 | 22 + 10 | regular season, then top 6 / bottom 6 |
| DK3O | 2. Division | 3 | 12 | 22 + 10 | regular season, then top 6 / bottom 6 |
| DK4L | 3. Division | 4 | 12 | 22 + 10 | regular season, then top 6 / bottom 6 |

All four rows are correct: **12 clubs each**, levels 1–4.

## One shape at every level

Each division is the same 12-club split competition:

1. **Regular season**: double round-robin, **22 matches**.
2. **Split** into a top six and a bottom six; points and goals carry over.
3. **Second phase**: each group plays a double round-robin, **10 more matches → 32**.

What differs is only what the groups decide:

- **Superliga** — championship group decides the title and Europe; the bottom two of the
  qualifying group are relegated.
- **1. Division** — top two of the promotion group are promoted; bottom two of the relegation
  group are relegated.
- **2. Division** — same: two up, two down.
- **3. Division** — top two of the promotion group are promoted; **the bottom four** of the
  relegation group are relegated to the Denmark Series.

## Boundaries

| between | up | of which PO | down | of which PO | allocation | selection |
|---------|----|-------------|------|-------------|------------|-----------|
| 1–2 | 2 | 0 | 2 | 0 | free | bottom_n |
| 2–3 | 2 | 0 | 2 | 0 | free | bottom_n |
| 3–4 | 2 | 0 | 2 | 0 | free | bottom_n |

Every boundary is a straight two-up/two-down swap decided after the split. No play-offs.

## Oddities

- **No relegation play-off in the Superliga.** The old 14-team format (2016-17 to 2018-19) had a
  multi-step play-off; since 2019-20 the bottom two of the qualifying group simply go down. The
  2025-26 relegation list (11th Fredericia, 12th Vejle) confirms it.
- **The 3. Division is brutal:** a six-club relegation group from which four go down. Relegation
  from level 4 is to the Denmark Series (level 5, not modelled), so our pyramid loses a lot of
  clubs at that boundary compared with levels 1–3.
- **Ids vs reality.** `DK3O` and `DK4L` look like regional groups, but every modelled Danish
  division is a single national league; the suffixes are just ids.
- Reserve teams are not in these four divisions (they play in the reserve league), so the
  reserve-team promotion problem does not apply here — unlike Estonia or Croatia.

## Sources

- https://en.wikipedia.org/wiki/Danish_Superliga — 12 clubs, 22 + 10 split format, points carried,
  bottom two of the qualifying playoff relegated, no play-off since 2019-20
- https://en.wikipedia.org/wiki/Danish_1st_Division — 12 clubs since 2012-13, promotion to
  Superliga, relegation to 2. Division; 2026-27 team list
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Danish_1st_Division — 12 clubs, 192 matches,
  regular season + promotion/relegation groups (6 + 6)
- https://en.wikipedia.org/wiki/Danish_2nd_Division — 12 clubs since 2021, two promotion and two
  relegation places
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Danish_2nd_Division — 12 clubs; "After 22 rounds
  the teams were split into a promotion group and a relegation group, with points and goals
  carried over in full"
- https://en.wikipedia.org/wiki/Danish_3rd_Division — 12 clubs; same 22-round split; "top two ...
  promoted ... bottom four in the relegation group are relegated"

## Confidence

**High.** The shared 22+10 shape is stated at every level, the 192-match totals in the 1. and
2. Division confirm 32 rounds per club, and the two-up/two-down (four-down at level 4) rules are
explicit.
