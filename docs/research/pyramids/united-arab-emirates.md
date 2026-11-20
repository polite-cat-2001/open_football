# United Arab Emirates — football pyramid, 2026-27

Season runs August 2026 → May 2027.

| Level | Competition | Clubs | Shape | Rounds |
|---|---|---|---|---|
| 1 | UAE Pro League (ADNOC Pro League) | 14 | double round-robin | 26 |
| 2 | UAE First Division League | 15 | double round-robin | 28 |

Our rows (14 and 15) are both correct.

## Level 1 — UAE Pro League

14 clubs, 26 matches. **Bottom two relegated** to the First Division, both directly, no play-out —
the 2026-27 season article marks 13th and 14th as relegation places and the 2025-26 movement
confirms it (Al Bataeh and Dibba went down, replaced by Hatta and United).

The league is a closed professional circuit in practice: clubs need a Pro League licence, and the
Pro League Committee (not the federation directly) runs it.

## Level 2 — UAE First Division League

15 clubs, 28 matches (each club plays every other home and away). **Top two promoted** directly to
the Pro League — again no play-off, confirmed by 2025-26 (Hatta champion, United runner-up, both
promoted).

The division has grown quickly: 15 in 2025-26 after a period at 14, 16 and 17, because privately
owned clubs and academies have been let in from the Second Division since 2021-22. That means the
size in our row is a snapshot, not a fixed number — the 2026-27 count should be re-checked each
season.

Below it sits the **UAE Second Division League** (level 3, founded 2019), not in our rows; First
Division clubs can be relegated there, so `closed_down` is true only because the model stops at
level 2.

## Boundary as numbers

| Boundary | Up | of which play-off | Down | of which play-off | Allocation |
|---|---|---|---|---|---|
| 1 ↔ 2 | 2 | 0 | 2 | 0 | free |

The cleanest boundary in this batch: two up, two down, both by table position, and a licence is the
only other filter.

## Data problems in our rows

None. One caveat: the First Division's size has changed in five of the last six seasons (14 → 17 →
15), so any stored fixture count is fragile.

## Confidence

High. Both sizes are confirmed by the 2025-26 club lists and the 2026-27 Pro League team-changes
table (12 retained + 2 promoted, 2 relegated).

## Sources

- https://en.wikipedia.org/wiki/UAE_Pro_League (14 clubs, promotion/relegation with the First Division)
- https://en.wikipedia.org/wiki/2026%E2%80%9327_UAE_Pro_League (14 teams, 13th/14th relegated, Hatta and United promoted)
- https://en.wikipedia.org/wiki/UAE_First_Division_League (15 sides, 28 games, top two promoted, Second Division below)
