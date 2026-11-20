# Germany — football pyramid 2026-27

Data for the career sim. Season 2026-27, men's Bundesliga down to Regionalliga (levels 1-4). Cups, the DFB-Pokal and European competitions excluded.

## Sources

| What | URL |
|---|---|
| Bundesliga 2026-27 (18 clubs, 306 matches, 16th play-off) | https://de.wikipedia.org/wiki/Fu%C3%9Fball-Bundesliga_2026/27 |
| 2. Bundesliga 2026-27 (18 clubs, two play-off ties) | https://de.wikipedia.org/wiki/2._Fu%C3%9Fball-Bundesliga_2026/27 |
| 3. Fußball-Liga 2026/27 (20 clubs, 380 matches, bottom 4 down) | https://de.wikipedia.org/wiki/3._Fu%C3%9Fball-Liga_2026/27 |
| Regionalliga 2026/27 overview (5 leagues, 4 × 18 + 1 × 19, promotion split) | https://de.wikipedia.org/wiki/Fu%C3%9Fball-Regionalliga_2026/27 |
| Regionalliga Bayern 2026/27 (19 clubs) | https://de.wikipedia.org/wiki/Fu%C3%9Fball-Regionalliga_Bayern_2026/27 |
| Regionalliga Nordost 2026/27 | https://de.wikipedia.org/wiki/Fu%C3%9Fball-Regionalliga_Nordost_2026/27 |
| Regionalliga Südwest 2026/27 | https://de.wikipedia.org/wiki/Fu%C3%9Fball-Regionalliga_S%C3%BCdwest_2026/27 |
| English cross-check: promotion rotation, Nord/Bayern play-off | https://en.wikipedia.org/wiki/2026%E2%80%9327_Regionalliga |

## The pyramid

| Level | League | Clubs | Rounds | Up | Down |
|---|---|---|---|---|---|
| 1 | Bundesliga | 18 | 34 | — (top) | 2 direct + 1 play-off |
| 2 | 2. Bundesliga | 18 | 34 | 2 direct + 1 play-off | 2 direct + 1 play-off |
| 3 | 3. Liga | 20 | 38 | 2 direct + 1 play-off | 4 direct |
| 4 | Regionalliga — 5 regional leagues | Bayern 19, Nord 18, Nordost 18, Südwest 18, West 18 = 91 | 36 / 34 / 34 / 34 / 34 | 4 places: 3 direct + 1 play-off | varies per league (to Oberliga) |

All levels are plain double round-robins; Germany has no split season and no points-average rule.

## Boundaries in detail

**1 ↔ 2.** 2. Bundesliga champion and runner-up go up; the 3rd meets the Bundesliga's 16th. Bundesliga's 17th and 18th go down. Two legs per tie, higher-division club at home in the second leg — this is the "Relegation" both leagues' infoboxes count as two (Bundesliga) and four (2. Bundesliga) play-off matches.

**2 ↔ 3.** Same shape: 3. Liga champion and runner-up up, 3rd vs the 2. Bundesliga's 16th; 2. Bundesliga's 17th and 18th down.

**3 ↔ 4.** This is the only genuinely asymmetric boundary, and it is **not** "champions of all five go up". The 3. Liga relegates its **bottom four**. Those four places are filled by:
- the champions of **Regionalliga Südwest** and **Regionalliga West** — direct;
- the champion of **Regionalliga Nordost** — direct, because the third direct spot **rotates annually** and belongs to Nordost in 2026-27;
- the winner of a **two-leg play-off between the champions of Regionalliga Bayern and Regionalliga Nord** — the fourth and last place.

So `up = 4`, of which `up_playoff = 1`. The relegated 3. Liga clubs drop into the Regionalliga of their own region, which is why `allocation = "by_geography"`.

**4 ↔ 5 (not encoded).** Each Regionalliga relegates into its Oberliga, but the count is not a fixed number and is not stated as one: Nordost sends one club down "plus one more depending on whether the single 3. Liga club from the NOFV area is relegated"; Südwest's count depends on 3. Liga relegations; Bayern's bottom clubs drop to the Bayernligen. Level 5 is outside our data, so the JSON stops at level 4 rather than invent a number — a sim that plays level 4 must not assume "bottom 3 down".

## Decisions

- Each Regionalliga is a separate league with its own single table, so `format.kind = "single"` with its own `rounds` (36 for Bayern's 19 clubs, 34 for the four 18-club leagues). The regional split is expressed by five rows at level 4 plus `allocation: "by_geography"`.
- Two ids are new: `RLN` (Regionalliga Nord) and `RLW` (Regionalliga West). Existing ids `RLB3`, `RLN4`, `RLSW` are kept unchanged so current rows still resolve.
- `playoff` is set only on the two leagues that actually contest it (Bayern, Nord). Nordost, Südwest and West have `playoff: null` because their champion goes up directly **this season**.
- `closed_up: true` only for the Bundesliga; `closed_down: false` everywhere, because even level 4 has a sporting route down to the Oberliga.

## Conflicts with our rows

| Ours | Real 2026-27 | Consequence |
|---|---|---|
| Level 4 = 3 leagues (Bayern 19, Nordost 18, Südwest 18) = 55 | 5 leagues = 91 | **Regionalliga Nord (18) and West (18) are missing**; the three we hold have correct sizes |
| L1/L2 18, L3 20 | correct | none |
| id `RLN4` for Nordost | Regionalliga Nordost | id reads like "Nord" but means Nordost; a new Nord id had to avoid collision |
| Level 4 promotion presumably "champions up" | 3 direct + 1 play-off, third spot rotating | If any code promotes all Regionalliga champions, it is wrong |

Also worth knowing: reserve teams (Bayern II, Schalke II, etc.) are in these leagues but are not eligible for promotion to the 2. Bundesliga, and 3. Liga reserve teams cannot be promoted either — the next eligible club moves up. The sim needs that filter if it models II-teams.

## Confidence

**High** for levels 1-3: club counts, match counts and all play-off/relegation places are stated explicitly in the 2026-27 articles. **High** for level 4 structure and the 2026-27 promotion split, which German and English Wikipedia agree on, including the rotation principle.

Two caveats a career sim must carry: the third direct level-4 promotion spot **rotates every year** (2026-27 = Nordost), so it cannot be hardcoded; and the level-4 relegation counts are conditional, so they are documented here rather than encoded as numbers.
