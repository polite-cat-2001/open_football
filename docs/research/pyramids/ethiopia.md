# Ethiopia — football pyramid 2026-27

Scope: only the top flight is in our database (ETP1). No cups, no CAF competitions.
Research date: 2026-11-20. Season in progress (November 2026 – May 2027).

## Pyramid at a glance

| id | League | Level | Clubs | Rounds per club | Shape |
|----|--------|-------|-------|-----------------|-------|
| ETP1 | Ethiopian Premier League | 1 | 20 | 38 | one table, double round-robin |

**Our row says 18; the league has 20.** 2024-25 was an 18-club season, the league expanded to 20
for 2025-26, and the league's own infobox and format section now describe 20 clubs and 38 games.

## Format

The simplest shape in this batch: 20 clubs, double round-robin, 38 matches, one table, no split,
no play-offs. Three lowest-placed clubs are relegated to the Ethiopian Higher League and the top
three of that league come up.

## Boundaries

None inside our data — ETP1 is both top and bottom of the modelled pyramid. The Higher League is
level 2 in reality but not in our list, so `closed_down` is true per the single-row rule.

## Oddities

- **Size correction needed.** If our data came from 2024-25, the row (18) is a season stale. The
  20-club shape is confirmed for 2025-26 by the league page, but there is no 2026-27 season
  article yet, so the 2026-27 size is inferred rather than directly listed.
- Ethiopian seasons straddle the new year (September/November to May/July), so "2026-27" is the
  right label even though the league is often described as "2025-26" on the page.
- The league has had repeated format changes (14 → 16 → 18 → 20 clubs over the last decade), so
  treat the size as volatile.

## Sources

- https://en.wikipedia.org/wiki/Ethiopian_Premier_League — infobox `teams = 20`, champions list
  through 2025-26, competition section: "There are 20 clubs ... a total of 38 games ... three
  lowest placed teams are relegated into the Ethiopian Higher League"
- https://en.wikipedia.org/wiki/2024%E2%80%9325_Ethiopian_Premier_League — 18-club table
  (`team_order` has 18 clubs), two relegated, confirming that 18 was last season's size and 20 is
  the new one

## Confidence

**Medium.** The 20-club/38-game shape is stated plainly, but only for the 2025-26 season; 2026-27
has no article yet, and the 18 → 20 change is recent enough that a data seed may not have caught
up.
