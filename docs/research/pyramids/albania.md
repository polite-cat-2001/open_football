# Albania — football pyramid 2026-27

Scope: levels 1–2 only (Kategoria Superiore, Kategoria e Parë). No cups, no UEFA places.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Kategoria_Superiore | 10 clubs, season dates 21 Aug 2026 – 9 May 2027, "clubs will play each other four times for a total of 36 matches each", top-6/bottom-4 split markers |
| https://sq.wikipedia.org/wiki/Kategoria_Superiore_2026%E2%80%9327 | same facts in Albanian; confirms the split markers (Raundi i kampionatit / Raundi i rënies) and the 36-match statement |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Kategoria_e_Par%C3%AB | 12 clubs, rounds 1–22 then 23–33, promotion places, play-out places |
| https://en.wikipedia.org/wiki/Kategoria_e_Par%C3%AB | 12 clubs, "top two direct, 3rd–6th play off", bottom two down, 9th–10th play out |
| https://sq.wikipedia.org/wiki/Kategoria_Superiore | 10 clubs; "last two are relegated and there is no play-out" (statement predates the 2026-27 change) |
| https://en.wikipedia.org/wiki/2025%E2%80%9326_Kategoria_Superiore | previous shape: 36 rounds, 8th in a relegation play-off, 9th–10th relegated |

fshf.org (the federation's format-change announcement) timed out on every attempt, so the new top-flight format could not be read
from the primary source.

## Leagues

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| ALB1 | Kategoria Superiore | 1 | 10 | 36 rounds (four meetings) | — (top) | 2 (1 direct + 1 play-off) |
| ALB2 | Kategoria e Parë | 2 | 12 | 33 rounds (22 + 11) | 3 (2 direct + 1 play-off) | 2 direct + 2 play-out |

Both sizes in our database are correct: 10 and 12.

## ALB1 — what is actually known

- 10 clubs, four meetings each = 36 matches, 18 home and 18 away. Both the English and the Albanian
  season articles say this explicitly.
- The league table in both articles nevertheless marks **1st–6th as "Championship round"** and
  **7th–10th as "Relegation round"**, and both link to sections that do not exist in the article.
  No round count for a second phase is given anywhere, and 36 rounds + a group phase does not fit the
  21 Aug – 9 May calendar. The split markers are therefore recorded as announced-but-undocumented,
  not modelled.
- Relegation: the Albanian league article still says the bottom two go down with no play-out. The
  2026-27 Kategoria e Parë article says its own promotion play-off **final loser** then plays the
  **9th-placed** Superiore club for a place in 2027-28. That implies 10th down directly and 9th in a
  play-off — two places, not three, while three clubs come up from level 2.

## ALB2 — format

- 12 clubs. Rounds 1–22 (double round-robin), then rounds 23–33 (a third meeting), 33 rounds total.
- 1st and 2nd promoted directly; 3rd–6th enter a promotion play-off (semi-finals and final).
- 11th and 12th relegated to Kategoria e Dytë; 9th and 10th play a relegation play-out.
- Kategoria e Dytë (level 3) is outside our data.

## Boundaries

| between | up | of which PO | down | of which PO | allocation | selection |
| --- | --- | --- | --- | --- | --- | --- |
| 1–2 | 3 | 1 | 2 | 1 | free | bottom_n |

The counts do not balance (3 up against 2 down), and that is a property of the sources, not of the
model: the top flight is mid-reform, three clubs are documented as coming up, and only two are
documented as leaving. A career sim that keeps ALB1 at 10 clubs needs a third relegation place that
no source states.

## Decisions

1. `format.kind` for ALB1 is `"single", rounds: 36` — the only round count either Wikipedia gives.
   The split is described in `format.note` and in `conflicts`, not encoded as a group phase.
2. ALB2 is `"single", rounds: 33`: the 22 + 11 split is a third meeting, not a points-carrying group stage.
3. `closed_down: true` for ALB2 (Kategoria e Dytë is not in our list), `closed_up: true` for ALB1.
4. Every number above is from a season article for 2026-27; nothing is carried over from 2025-26.

## Oddities

- The 2025-26 season had **8th** in the relegation play-off (not 9th), with 9th and 10th down. If
  2026-27 really moved the play-out to 9th, the top flight's relegation shape changed twice in two
  seasons and a sim seeded with 2025-26 results will not match.
- Two clubs were relegated in 2025-26 (Bylis, Flamurtari) and two promoted (Laçi, Skënderbeu), so
  the 10-club size is stable in practice even though the 2026-27 rules as published do not add up.

## Confidence

**Low** for the top flight (format and relegation places), **high** for Kategoria e Parë (size, rounds,
promotion and relegation places all come from one detailed season article).
