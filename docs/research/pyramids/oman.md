# Oman — football pyramid 2026-27

Research for the career simulation. Scope: level 1 only, the Oman Professional League.
Cups and AFC places are out of scope. Our list has a single Omani row, so the league is
closed in both directions in our data; in reality it relegates to the Oman First
Division League.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/Oman_Professional_League | infobox (14 clubs, level 1, relegation to the Oman First Division League), the 2025-26 champion, the club list |
| https://en.wikipedia.org/wiki/2024%E2%80%9325_Oman_Professional_League | confirming the competition exists with a season article and a 2024-25 calendar; no format detail |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_in_Asian_football_(AFC) | the 2026-27 Oman league is listed but its season article does not exist |

There is **no 2026-27 Oman Professional League article** on English Wikipedia (the link
is red at the time of writing). Nothing was found for a competition called the "Oman
Jindal League". Everything below about the 2026-27 shape therefore rests on the league
page plus arithmetic from the club count, not on a season source.

## League

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| OM1L | Oman Jindal League | 1 | 14 | 26 rounds (double round-robin) | — (top) | not verified |

- 14 clubs, level 1: confirmed by the league infobox, which also lists relegation to the
  Oman First Division League.
- 26 rounds is **derived**: 14 clubs playing each other home and away. No 2026-27 source
  states the round count or the calendar, and the 2024-25 season article is an empty
  shell (sections only, no table).
- The 2025-26 title went to Al-Seeb (5th title); Dhofar hold the record with 12.

## Name

Our row is called **Oman Jindal League**. No source read uses that name. The competition
is the **Oman Professional League**, branded the Omantel Professional League for
sponsorship, and known earlier as the Omantel Elite League / Oman Mobile League. The
name is therefore recorded as a conflict: either our database picked up a 2026-27 title
sponsor that is not documented anywhere readable, or the name is wrong. The id and level
are unaffected.

## Promotion and relegation

Not verified for 2026-27. The league page only states the direction (down to the Oman
First Division League), not how many clubs go or whether there is a play-off. Because
the First Division League is not in our list, this does not change `closed_down: true`,
and no boundary is encoded. A simulation should treat the 14 clubs as a closed pool
unless the First Division is added.

## Decisions

1. **`size: 14`, `level: 1`** from the league infobox.
2. **`format.kind: "single"`, `rounds: 26`** with a note that the round count is derived
   from the club count — the league is a plain double round-robin in every season where
   a table exists.
3. **`closed_up: true`, `closed_down: true`, no boundaries.**
4. **`playoff: null`** — no play-off structure is documented for this league.

## Oddities

- The league page's own "clubs (2024-25)" section lists only 12 clubs, two seasons after
  the infobox says 14; the list is stale (it still lists 2023-24 relegations). Trust the
  infobox figure for the current size, not the named list.
- The 2026-27 competition is listed in the AFC season navigation template, so it is
  being played; only its article is missing.

## Confidence

**Low-medium.** The size (14) and level are solid; the round count is arithmetic; the
name in our row is unverified and the relegation mechanics are unknown. Re-check when a
2026-27 season article or the OFA site becomes readable.
