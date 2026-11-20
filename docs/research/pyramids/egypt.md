# Egypt — football pyramid 2026-27

Scope: only the top flight is in our database (EGY1). No cups, no CAF competitions.
Research date: 2026-11-20. Season in progress (started 21 August 2026).

## Pyramid at a glance

| id | League | Level | Clubs | Rounds per club | Shape |
|----|--------|-------|-------|-----------------|-------|
| EGY1 | Egyptian Premier League | 1 | 20 | 19 + group phase | one single round-robin, then a six-club championship group and a fourteen-club relegation group |

Our row says 20, which is **right for 2026-27** — but the league had 18 clubs in 2024-25 and
2025-26, so the row is one season ahead of the older data.

## Format — new for 2026-27

1. **First phase**: 20 clubs, **single** round-robin, 19 matches (not the old 34-game double
   round-robin).
2. **Split**:
   - **championship group**, 1st–6th: the winner is champion and takes a Champions League place,
     the runner-up the second place, third the Confederation Cup;
   - **relegation group**, 7th–20th (14 clubs): **four** clubs are relegated.
3. The source does not state the number of matches in either group, nor whether first-phase
   points carry. Both are left null in the JSON rather than guessed.

## Boundaries

None inside our data — EGY1 is both the top and the bottom of the modelled pyramid. In reality
four clubs go down to the Egyptian Second Division A, which has three groups whose winners come
up (the old route); that is outside our list, so the report marks the direction closed.

## Oddities

- **The league page contradicts its own infobox.** The prose still says 18 clubs, 34 games,
  three relegated, "since 2015"; the 2026-27 season article (and the 20-club team list) describe
  the new two-phase format and four relegations. I follow the season article.
- **20 clubs is one season old.** 2024-25 was an 18-club double round-robin. If our data was
  seeded from that season, the row's size is already stale.
- **A single round-robin first phase is unusual** for a 20-club league: the first phase is a
  seeding competition, and half the season is the split.
- Because the format is brand new, there is no completed season to check the details against
  (points carry, group round counts).

## Sources

- https://en.wikipedia.org/wiki/Egyptian_Premier_League — infobox `teams = 20`, 20-club current
  team list; stale prose ("18 clubs ... 34 games ... three lowest-placed")
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Egyptian_Premier_League — "20 teams in a single
  group ... played in two phases"; first phase single-leg; championship group 1st–6th, relegation
  group 7th–20th; "Four of the teams in the relegation group get relegated"; three promoted clubs

## Confidence

**Medium.** The 2026-27 shape (20 clubs, 19 rounds, 6/14 split, four down) is stated explicitly in
the season article and matches its tables, but it is a first-year format, the index page still
describes the previous one, and the group round counts and points-carry rule are not documented.
