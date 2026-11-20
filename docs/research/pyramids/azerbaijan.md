# Azerbaijan — football pyramid 2026-27

Scope: level 1 only (Premyer Liqa). The First League (level 2) is not in our rows. No cups, no
European places.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Azerbaijan_Premier_League | 12 clubs ("the top eleven from last season plus one promoted"), `result11=RPO`, `result12=REL`, season in progress |
| https://en.wikipedia.org/wiki/Azerbaijan_Premier_League | `teams = 12`, "33 matches each, playing each team three times, home venues for the third round determined by a draw", expansion to 12 for 2025-26 |

## League

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| AZ1 | Premyer Liqa | 1 | 12 | 33 rounds, triple round-robin | — (top) | 2 (1 direct + 1 play-off) |

Our row (AZ1, level 1, 12 clubs) is correct. The league went from 10 to 12 clubs for 2025-26 and keeps
12 for 2026-27.

## Format

- 12 clubs, every pair meets **three times** = 33 matches each, 198 in total.
- The third meeting's home team is decided by **draw**, not by the first two results — a small but real
  asymmetry a sim should reproduce (or deliberately ignore).
- Season August to May, no split, no groups, no carried points.
- Champion enters the Champions League first qualifying round; second and third go to the Conference
  League.

## Boundary 1–2

- **Down:** 12th relegated directly; **11th** enters a relegation play-off.
- **Up:** the First League sends its champion up directly and its runner-up into the play-off against
  11th, so the two directions are the same single tie.
- The play-off's number of legs and dates were not documented in the sources read (the article links to
  a "Relegation play-offs" section that is empty), so `legs` is null in the JSON.

Because the First League is not in our list, the league is marked `closed_down: true`; the real
movement is described here and in `notes`.

## Oddities

- A club can be saved from relegation by winning a play-off against the level-2 runner-up, which makes
  the 11th place genuinely different from 12th — the table's last two rows are not equivalent.
- The competition was 10 clubs for years and only reached 12 in 2025-26; any historical seed will show
  33-match seasons only from then on.

## Confidence

**High** for size, 33 rounds and the 11th/12th split. **Medium** for the play-off mechanics (opponent
and legs inferred from the play-off marker; no section text was readable).
