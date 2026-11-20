# China — football pyramid, 2026 season

China runs a **calendar-year** season (March → November), so this is "2026", not "2026-27". Three fully professional tiers, then the semi-pro/amateur Chinese Champions League.

| Level | Competition | Clubs | Shape | Rounds |
|---|---|---|---|---|
| 1 | Chinese Super League (CSL) | 16 | double round-robin | 30 |
| 2 | China League One | 16 | double round-robin | 30 |
| 3 | China League Two | 24 | 2 zones of 12 → 8 / 8 / 8 | 22 + 8 = 30 |

All four of our rows are correct on size: 16 / 16 / 12 + 12 (24) / levels 1-3. The one misreading is that League Two A and B are **not** two separate leagues.

## Level 1 and 2 — plain double round-robins

- **CSL, 16 clubs, 30 rounds.** Bottom two relegated directly. Champion 2026: Dalian Yingbo.
- **China League One, 16 clubs, 30 rounds.** 2026 is the first season of the **"2 up / 2.5 down"** rule: champion and runner-up go up, 15th and 16th go down, and **14th plays a two-leg promotion/relegation play-off** against the third-placed club of the League Two promotion group. (Before 2026 this boundary was a clean 2 up / 2 down; the previous play-off was in 2021.)

So the 1↔2 boundary is 2 up / 2 down with no play-off, and the 2↔3 boundary is nominally 3 up / 3 down but **one of those three in each direction is the same two-legged tie** — the League One club can survive it.

## Level 3 — how League Two really works

24 clubs, one division, two stages. This is the answer to "two groups that may merge": they do not merge into one league, they are **re-pooled by rank across both zones**.

**Stage 1 — zones (22 rounds, 264 matches)**

Two geographic zones of 12: **North** and **South**. Double round-robin inside the zone.

**Stage 2 — three pools (8 rounds each)**

- **Promotion group (冲甲组), 8 clubs** — top 4 of each zone.
- **Relegation A group, 8 clubs** — South 5th, 7th, 9th, 11th + North 6th, 8th, 10th, 12th.
- **Relegation B group, 8 clubs** — South 6th, 8th, 10th, 12th + North 5th, 7th, 9th, 11th.

Each pool plays **home and away only against the clubs it has not yet met** (i.e. the four from the other zone), which is exactly 8 rounds. **All points from stage 1 carry over in full**, so the second stage is a re-ranking of all 24 clubs, not a fresh competition and not a knockout.

Total: **30 rounds, 360 matches** (2026 ran 21 March → 8 November).

**Promotion to League One**

- 1st and 2nd of the promotion group → promoted directly to the next season's League One.
- 3rd of the promotion group → two-legged play-off against the **14th-placed club of League One** (the League One side hosts the second leg; foreign players and naturalised players are not allowed in the tie).

**Relegation**

- Bottom two of relegation A **and** bottom two of relegation B → 4 clubs down to the Chinese Champions League (level 4, outside our model).

**B teams (new in 2026)**

Reserve sides may now be promoted. Shandong Taishan B finished 2nd in 2026 and went up to League One. The cap: at most **one** professional-club B team per season may take a direct promotion or a play-off place — if two or more finish in the top three, the surplus places pass to the best-placed non-B club. A B team may never play in the same tier as its A team, and a relegated B team drops to the U-20 youth league rather than the CMCL.

## 2026 as it actually resolved

- CSL: Dalian Yingbo champion on head-to-head after finishing level on 52 points with Chengdu Rongcheng, who had led for 29 rounds.
- League One: Liaoning Tieren and Chongqing Tonglianglong promoted to the CSL.
- League Two: Dalian Kewei champion, Shandong Taishan B runner-up (both up), Guizhou Guiyang Jingji 3rd → play-off. Relegated: Wenzhou, Shanghai Saigengda, Chengdu Rongcheng B, Beijing Ligong.
- Nine CSL clubs and four League One clubs started 2026 with point deductions from the 2022-24 corruption case (e.g. Meizhou Hakka −9, Changchun Yatai −4). A career sim that carries over sanctions needs this hook.

## Data problems in our rows

1. `CHL3` / `CL3S` — the 12-club sizes are right, but they are the **first-stage zones** of one 24-club division. Generating a 12-team double round-robin in isolation, with its own promotion, would be wrong: after round 22 the zones are re-pooled by rank, and points carry over.
2. The zone names are **North / South**, not A / B.
3. `CLO` — nothing wrong with 16 clubs / 30 rounds, but the 2↔3 boundary now carries a play-off ("2.5 down"), which is new for 2026.

## Confidence

High. The Chinese Wikipedia season articles for 2026 exist for all three tiers and state the rules explicitly (the League Two article spells out the pools, the carry-over and the 8 extra rounds); the English 2026 League Two page's stage headings (North, South, Promotion stage, Relegation stage A/B) match that structure.

## Sources

- https://zh.wikipedia.org/wiki/2026年中国足球乙级联赛 (赛制: 24 clubs, zones of 12, 22+8 rounds, pool composition, promotion and relegation, B-team rule)
- https://zh.wikipedia.org/wiki/2026年中国足球甲级联赛 (16 clubs, "升2降2.5", 14th vs League Two 3rd, point deductions)
- https://zh.wikipedia.org/wiki/2026年中国足球超级联赛 (16 clubs, last two relegated, 2026 outcome, point deductions)
- https://en.wikipedia.org/wiki/Chinese_Super_League (16 clubs, 30 matches, 2 down / 2 up, calendar-year season)
- https://en.wikipedia.org/wiki/China_League_One (16 teams, top two up, bottom two down)
- https://en.wikipedia.org/wiki/China_League_Two (two groups North/South, top four of each into the promotion play-off — older, less detailed than the Chinese pages)
- https://en.wikipedia.org/wiki/2026_China_League_Two (2026 stage structure: North Group, South Group, Promotion stage, Relegation stage A/B)
