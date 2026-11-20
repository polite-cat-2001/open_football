# Bulgaria — football pyramid 2026-27

Scope: levels 1–2 (First League / efbet Liga, Second League). No cups, no European places.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_First_Professional_Football_League_(Bulgaria) | 14 clubs ("reduced from 16"), 2025-26 promoted club and play-off winner, `result1-4` / `result9-14` split markers, season in progress |
| https://en.wikipedia.org/wiki/First_Professional_Football_League_(Bulgaria) | `teams = 14`, the history of the two-phase format, the 16-club 4/4/8 precedent |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Second_Professional_Football_League_(Bulgaria) | 20 clubs, "first wins direct promotion, 2nd and 3rd play off against the 12th and 13th of the First League", six direct relegations |
| https://bg.wikipedia.org/wiki/%D0%9F%D1%8A%D1%80%D0%B2%D0%B0_%D0%BF%D1%80%D0%BE%D1%84%D0%B5%D1%81%D0%B8%D0%BE%D0%BD%D0%B0%D0%BB%D0%BD%D0%B0_%D1%84%D1%83%D1%82%D0%B1%D0%BE%D0%BB%D0%BD%D0%B0_%D0%BB%D0%B8%D0%B3%D0%B0_2026/27 | the 2026-27 format in the federation's own language: groups 1–4, 5–8, 9–14, six and five rounds, 14th down, 12th/13th in play-offs |
| https://bg.wikipedia.org/wiki/%D0%92%D1%82%D0%BE%D1%80%D0%B0_%D0%BF%D1%80%D0%BE%D1%84%D0%B5%D1%81%D0%B8%D0%BE%D0%BD%D0%B0%D0%BB%D0%BD%D0%B0_%D1%84%D1%83%D1%82%D0%B1%D0%BE%D0%BB%D0%BD%D0%B0_%D0%BB%D0%B8%D0%B3%D0%B0_2026/27 | 20 clubs, transitional season, direct relegations reduced to 16 clubs for 2027-28 |

## Leagues

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| BU1 | efbet Liga (First League) | 1 | 14 | 26 rounds + groups 4/4/6 = 32 rounds (31 for the bottom group) | — (top) | 3 (1 direct + 2 play-off) |
| BU2 | Vtora Liga (Second League) | 2 | 20 | 38 rounds, double round-robin | 3 (1 direct + 2 play-off) | 6 direct + 1 play-off |

**BU1 size: our row 14 is right** — the league was cut from 16 to 14 for 2026-27.
**BU2 size: our row 18 is wrong** — the Second League has **20** clubs this season.

## BU1 format (2026-27)

- 14 clubs, double round-robin first phase: **26 rounds**.
- Then three groups:
  - **Group 1**: 1st–4th, double round-robin, 6 more rounds (32 total).
  - **Group 2**: 5th–8th, double round-robin, 6 more rounds (32 total).
  - **Group 3**: 9th–14th, **single** round-robin, 5 more rounds (31 total).
- Points and results carry over unchanged.
- In Groups 1 and 2 the 3rd or 4th of Group 1 plays the 1st of Group 2 for a Conference League place
  (out of scope).

## BU2 format (2026-27)

- 20 clubs, double round-robin = **38 rounds**.
- A transitional season: the Second League drops back to 16 clubs for 2027-28, so it sheds far more
  clubs than usual — **six direct relegations** (14th–20th) plus a play-off for 13th against the winner
  of the North-East/North-West Third League play-off.
- The Bulgarian source says five direct relegations instead of six; the English source says 14th–20th
  (six). The six is used here because it matches the positions it names.

## Boundaries

| between | up | of which PO | down | of which PO | allocation | selection |
| --- | --- | --- | --- | --- | --- | --- |
| 1–2 | 3 | 2 | 3 | 2 | free | bottom_n |

- **Down:** 14th relegated directly; **12th and 13th** play the Second League's 2nd and 3rd in
  single-match play-offs. Losing either tie means relegation.
- **Up:** Second League 1st goes up directly; 2nd and 3rd take the same two ties.
- So three clubs move each way, two of them through the same pair of play-offs. Both play-offs were
  single matches in 2025-26 (Septemvri beat Yantra 2:1 to stay up).

## Oddities

- The bottom group in BU1 has a 31st round while the top two groups have a 32nd, so the division has no
  single round count. `format.rounds: 32` is the maximum; the note records 31.
- 2026-27 is the first 14-club season since 2021-22. All published format descriptions on the league
  article still describe the 16-club 4/4/8 shape, which is why the Bulgarian season article is the
  source for the group sizes.
- BU2 is deliberately oversized (20) for one season only to shrink to 16; a sim that carries 20 forward
  will not match 2027-28.

## Confidence

**High** for BU1 (size, split, 32/31 rounds, 14th down, 12th/13th in play-offs) — it comes from the
Bulgarian season article and is consistent with the English markers. **Medium** for BU2 (size and
promotion route are clear; the number of direct relegations differs between the two language editions).
