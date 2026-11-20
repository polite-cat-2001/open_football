# Czech Republic — football pyramid, 2026-27

Season runs July 2026 → May/June 2027 (autumn/spring). Levels 1-2 are run by the Ligová fotbalová asociace, level 3 by the Řídící komise for Bohemia (ČFL) and for Moravia (MSFL).

| Level | Competition | Clubs | Shape | Rounds |
|---|---|---|---|---|
| 1 | Chance Liga | 16 | 30 rounds, then split 6 / 4 / 6 | 30 + 5 (35 max) |
| 2 | Chance Národní liga | 16 | double round-robin | 30 |
| 3 | Česká fotbalová liga (ČFL) | 32 | 2 groups (A, B) × 16 | 30 |
| 3 | Moravskoslezská fotbalová liga (MSFL) | 18 | double round-robin | 34 |

All four sizes match our database rows (16 / 16 / 32 / 18). Levels match too.

## Level 1 — the split is three-way, not two-way

After 30 rounds the table breaks into:

- **1-6, championship group** — single round-robin (5 matches). Points and goals carry over in full, so the title is decided on the 35-match total, not on the mini-table.
- **7-10, placement group** — a two-legged knockout: 7v10, 8v9, then a two-legged final. The winner gets CZK 3m and a favourable Czech Cup seeding. It has **no** bearing on promotion or Europe (the old "group for Europe" ended with 2022-23; from 2023-24 the five European places come straight from the championship group).
- **11-16, relegation group** — single round-robin (5 matches), again with full points carry-over.

Relegation out of it: 16th goes down directly; 15th and 14th play two-legged play-outs against the Národní liga's 2nd and 3rd. 13th is always safe. So it is **1 direct + 2 play-off places**, not "bottom 3".

The brief's example (`championship: 6, relegation: 10`) is wrong for this season: there is no 10-club relegation group.

## Level 2 — Chance Národní liga

16 clubs, 30 rounds. Champion promoted directly; 2nd and 3rd go to the play-outs. Bottom two relegated to ČFL or MSFL **by the club's regional affiliation** (so 0-2 can go to either league). From 2027-28 clubs will need a stadium with floodlights and under-soil heating.

## Level 3 — two competitions, three groups

This is the part our data flattens. The third level is not "Bohemian league + Moravian league" as two 16-ish leagues:

- **ČFL** — Bohemia, run by the Řídící komise pro Čechy. Since 2019-20 it is **two groups, A and B, of 16 each = 32 clubs** (2024-25 was an exception with 17 per group). In 2026-27 it is again 2 × 16.
- **MSFL** — Moravia-Silesia, run by the Řídící komise pro Moravu. **18 clubs, 34 rounds**, champion promoted directly.

**How many go up from each**

- ČFL: **one** place, and only after a baráž — the winners of groups A and B play each other over two legs for the single promotion spot (stated explicitly for 2026-27).
- MSFL: **one** place, direct to the champion.
- Total 2 up, matching the Národní liga's 2 down.

**Do ČFL and MSFL exchange clubs?** No. They are parallel divisions of the same level: clubs only move between level 2 and level 3, or down to the Divize (A/B/C for ČFL, D/E/F for MSFL). The only coupling between the two is that the Národní liga's two relegated clubs are assigned by geography, and the two leagues' own relegation counts flex to keep 32 + 18 filled — ČFL drops 4 / 3 / 2 and MSFL drops 0-2 depending on how many of the Národní liga's two relegated clubs are Czech vs Moravian.

## Boundaries as numbers

| Boundary | Up | of which play-off | Down | of which play-off | Allocation |
|---|---|---|---|---|---|
| 1 ↔ 2 | 1 | 2 | 1 | 2 | free |
| 2 ↔ 3 | 2 | 1 | 2 | 0 | by geography |

The 2↔3 "up" pair is asymmetric: MSFL direct, ČFL via the A/B baráž.

## 2026-27 as it actually resolved (sanity check on the rules)

- Down from the Chance Liga: Dukla Praha (16th, sporting). Karviná was moved down **administratively** by the FAČR Ethics Committee over the 2022-24 corruption case; the freed place was offered to Táborsko (declined, stadium) and then to Artis Brno, which accepted.
- Up from the Národní liga: Zbrojovka Brno (champion). Artis Brno arrived via that administrative vacancy, not via a play-out.
- Národní liga lost Sparta B, České Budějovice and Chrudim (the last two failed licensing), so **three** level-3 clubs came up: Kladno and Arsenal Česká Lípa (both ČFL — i.e. both group winners, which shows the baráž is a fallback, not an absolute cap) and Třinec (MSFL champion).
- Nobody came down from the Národní liga into the MSFL.

That season is an exception driven by licensing and discipline, not the steady-state rule; a career sim should implement 2 up / 2 down and handle vacancies as separate events.

## Data problems in our rows

1. `CZ3C` "Ceska fotbalova liga, 32" — size correct, **shape** wrong: it is one division in two groups of 16, and promotion runs through an A-vs-B baráž.
2. `CZ3M` "18" — correct, 34 rounds.
3. The brief's "Bohemian and Moravian-Silesian" pair hides the fact that the Bohemian side alone is two groups.
4. The 6/10 split in the brief's sample JSON does not exist in this format.

## Confidence

High on sizes, rounds and the shape of both splits: the Czech season articles for 2026-27 are already written and the transition lists reconcile 16 + 16 + 50 clubs exactly. The only genuinely variable numbers are the level-3 relegation counts (they are functions of licensing and geography, not fixed).

## Sources

- https://cs.wikipedia.org/wiki/1._česká_fotbalová_liga (Systém soutěže: split, play-out, relegation group)
- https://cs.wikipedia.org/wiki/Chance_Liga_2026/2027 (16 clubs, the two newcomers)
- https://cs.wikipedia.org/wiki/2._česká_fotbalová_liga (16 clubs, 30 rounds, promotion and relegation)
- https://cs.wikipedia.org/wiki/Chance_Národní_liga_2026/2027 (2026-27 team changes, baráž dates)
- https://cs.wikipedia.org/wiki/Česká_fotbalová_liga (groups A/B, 16 each, relegation flexibility)
- https://cs.wikipedia.org/wiki/Česká_fotbalová_liga_2026/2027 (2 × 16, group winners' baráž for one place)
- https://cs.wikipedia.org/wiki/Moravskoslezská_fotbalová_liga (18 clubs, 34 rounds, champion up)
- https://cs.wikipedia.org/wiki/Moravskoslezská_fotbalová_liga_2026/2027 (18 clubs confirmed for 2026-27)
- https://en.wikipedia.org/wiki/2025–26_Czech_First_League (English cross-check: championship / play-off / relegation groups, 14th-15th play-out, full points carry-over)
