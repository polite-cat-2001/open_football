# Uzbekistan — football pyramid, 2026

Calendar-year season: March → November 2026.

| Level | Competition | Clubs | Shape | Rounds |
|---|---|---|---|---|
| 1 | O'zbekiston Superligasi | 16 | double round-robin | 30 |
| 2 | O'zbekiston Pro Ligasi | 14 | double round-robin | 26 |

Our rows (16 and 14) are both right — but the Pro League's 14 is brand new, and its own article
still says 6.

## Level 1 — Super League

16 clubs, 30 rounds, March-November, no split. Champion and runner-up into the AFC Champions League
Elite/Two, third into the CAF-equivalent Silk Way Cup slot.

Relegation is **not a clean bottom-n**. The league article says "two or three teams can be
relegated depending on the number of sides", and that promotion can be voided when a reserve team
wins the Pro League (reserve clubs may not play in the top flight). For 2026 the season article
marks the 16th as directly relegated and 12th-15th as "relegation play-off" places — five slots in
all, which looks like a one-off reshape rather than the normal rule and is flagged as a conflict.

The documented normal rule, from the Pro League side: Pro League 1st and 2nd are promoted directly,
the Pro League 3rd plays the Super League 12th in a single play-off **at the Pro League club's
ground**, and the Super League's bottom club goes down. That is what a career sim should implement:
**3 up (1 play-off) / 3 down (1 play-off)**, with the caveat that the real count flexes between two
and three.

## Level 2 — Pro League

14 clubs in 2026, 26 rounds. This is the striking correction in our data: the Pro League shrank to
**6 clubs in 2024 and 2025** and expanded back to 14 for 2026 (its own article's infobox still says
6, and the 2026 season article's lead sentence still says "6 teams take part" while listing 14).
The 2026 fixture list is a straightforward double round-robin over 14 clubs.

- 1st and 2nd promoted; 3rd into the play-off against the Super League's 12th.
- Bottom club relegated to the First League (level 3, not in our rows). The 2026 table marks 13th
  and 14th as relegation too, which is one place more than the stated rule — another source wobble.

## Boundaries as numbers

| Boundary | Up | of which play-off | Down | of which play-off | Allocation |
|---|---|---|---|---|---|
| 1 ↔ 2 | 3 | 1 | 3 | 1 | free |

The play-off is a single match at the second-tier club's ground, which is unusual and worth keeping:
the lower-placed club gets the home advantage.

## Data problems in our rows

1. `UZ1` 16 — correct.
2. `UZ2L` 14 — correct for 2026, but it was 6 in 2024-25. A stale row from last season would have
   said 6, and a fixture generator using 14 must not also use a 6-club round count (26 rounds, not
   10).
3. Relegation counts below level 1 are not fixed and depend on reserve-team eligibility.

## Confidence

High on both sizes for 2026 (the 14-club Pro League roster and the 16-club Super League roster are
both explicit). Medium on the exact number of relegation places, where the league article (two or
three, flexing), the Pro League article (bottom one plus a play-off) and the 2026 season table
(12th-15th play-off, 16th down) do not agree.

## Sources

- https://en.wikipedia.org/wiki/Uzbekistan_Super_League (16 clubs, March-November, two or three relegated, reserve teams ineligible)
- https://en.wikipedia.org/wiki/2026_Uzbekistan_Super_League (16 clubs, 12th-15th and 16th markings)
- https://en.wikipedia.org/wiki/Uzbekistan_Pro_League (1st/2nd up, 3rd play-off at home vs Super League 12th, last down, 6 clubs in 2024-25)
- https://en.wikipedia.org/wiki/2026_Uzbekistan_Pro_League (14 clubs, 182 matches)
