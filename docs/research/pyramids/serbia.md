# Serbia — football pyramid, 2026-27

Serbia is mid-shrink and this season is the strange one. The SuperLiga was **16 clubs in 2025-26**,
is **14 in 2026-27**, and becomes **12 from 2027-28**. The reduction is absorbed by relegating
**four clubs** at the end of 2026-27 (positions 11-14) while only **two** come up from the First
League. That is a 2-up / 4-down boundary — the opposite of the usual shape.

Both professional levels also use a **split**: a double round robin first, then a championship group
and a relegation group playing each other once with points carried. Because the groups have
different sizes, clubs do **not** play the same number of matches.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | SER1 | Super liga Srbije (Mozzart Bet) | 14 | split: 26, then 6 + 8 | 26 + 5 (top) / 26 + 7 (bottom) | — (closed) | 4 direct |
| 2 | SER2 | Prva liga Srbije | 16 | split: 30, then 6 + 10 | 30 + 5 (top) / 30 + 9 (bottom) | 2 direct | 6 direct |
| 99 | SB19 | Omladinska liga Srbije (U19) | 14 | youth championship | n/a | — (closed) | — (closed) |

Level 3 (Srpska liga, four groups) is not in our dataset, so the First League is closed downward
here although six clubs really do drop into it each season.

## Level 1 — Super liga Srbije

- 14 clubs, 26 rounds double round robin, then a split: **top 6** play a 5-match championship round,
  **bottom 8** a 7-match relegation round; points carry over. Total 31 matches for the top group, 33
  for the bottom group. The two groups produce separate final tables.
- **Four clubs are relegated directly** (11th-14th) and there is **no relegation play-off** in
  2026-27 — the play-off was abolished for the shrink.
- 2026-27 promoted: Zemun (after 7 seasons) and Mačva (after 5). Season started 17 July 2026.
- 2027-28 will be 12 clubs, which restores normal numbers.

## Level 2 — Prva liga Srbije

- 16 clubs, 30 rounds double round robin, then **top 6** (5 more matches) and **bottom 10** (9 more),
  points carried.
- **Top two are promoted** directly.
- **6th-from-bottom to bottom: positions 11-16 are relegated** to the Srpska liga (level 3, four
  geographic groups, not modelled). No relegation play-off.
- Reserve/farm sides exist in the Serbian system lower down but not at these two levels in 2026-27.

## Level 99 — Omladinska liga Srbije (U19)

- The national **under-19** championship, played by the youth sides of SuperLiga and First League
  clubs. It is a youth competition, not a tier of the senior pyramid: winning it gives no route into
  the SuperLiga, and a club cannot be "promoted" out of it. Closed in both directions.
- Our row records 14 clubs; that number could not be verified from Wikipedia (no article exists),
  so it is kept as-is and flagged rather than corrected. Format recorded as `other` with no round
  count for the same reason.

## Boundary 1-2

- **Up 2** (First League top two), **down 4** (SuperLiga 11th-14th). No play-off in either
  direction.
- The imbalance is temporary and tied to the 14→12 shrink; from 2027-28 the boundary should return
  to 2 up / 2 down (to be re-checked next season).

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| SER1 | Super liga Srbije | 1 | 1 | 14 | 14 | correct for 2026-27 (was 16 in 2025-26, 12 from 2027-28) |
| SER2 | Prva liga Srbije | 2 | 2 | 16 | 16 | correct |
| SB19 | Omladinska liga Srbije | 99 | youth (U19) | 14 | 14 (unverified) | level is right as a youth marker; size not verifiable |

The important correction is to the **rules**, not the rows: four relegations from the top flight
and six from the second tier are not normal and will look like bugs if hardcoded.

## Caveats

- A split with 6- and 8-club groups means unequal fixtures; any simulator that assumes "everyone
  plays the same number of games" will be wrong here.
- The First League's 6 relegations plus the SuperLiga's 4 make the level-3 intake unusually large in
  2027; the Srpska liga groups are not modelled.
- Youth league size is unverified (no public table found); do not treat 14 as confirmed.

## Sources

- https://en.wikipedia.org/wiki/2026%E2%80%9327_Serbian_SuperLiga
- https://en.wikipedia.org/wiki/Serbian_SuperLiga
- https://en.wikipedia.org/wiki/2025%E2%80%9326_Serbian_SuperLiga
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Serbian_First_League
