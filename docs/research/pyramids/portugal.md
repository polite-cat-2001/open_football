# Portugal — football pyramid 2026-27

Scope: levels 1–4 only. No cups, no UEFA competitions.
Research date: 2026-11-20. Season in progress (mid-November 2026), so team lists are real but final standings are not.

## Pyramid at a glance

| id | League | Level | Clubs | Rounds per club | Shape |
|----|--------|-------|-------|-----------------|-------|
| PO1 | Liga Portugal (Liga Portugal Betclic) | 1 | 18 | 34 | single table, double round-robin |
| PO2 | Liga Portugal 2 (Liga Portugal 2 Meu Super) | 2 | 18 | 34 | single table, double round-robin |
| PT3A | Liga 3 (Liga 3 Placard) | 3 | 20 | 18 + 14 or 18 + 10 | 2 geographic series, then split into promotion / relegation stages |
| CPSA–CPSD | Campeonato de Portugal, Série A–D | 4 | 14 each (56 total) | 26 (+6) | 4 geographic series, then promotion groups |

Levels 1 and 2 are plain: 18 clubs, 34 rounds, no split, no carried points.

**Our database rows are all correct for 2026-27**: 18 / 18 / 20 / 14×4. What the schema flattens is the shape of levels 3 and 4 — both are series-plus-phase competitions, not single tables.

## Level 2 contains reserve teams that cannot go up

Liga Portugal 2 2026-27 includes **Sporting B, Benfica B and Porto B**. Reserve teams may not be promoted to the Primeira Liga (they can be relegated normally, and are relegated automatically if the senior side drops into Liga Portugal 2). A career sim that simply promotes the top two of level 2 will promote an ineligible club whenever a B team finishes in the top two — the place passes to the next eligible club.

## Boundaries

### 1 ↔ 2 (Liga Portugal ↔ Liga Portugal 2)

- Up: Liga Portugal 2 1st and 2nd are promoted.
- Down: Primeira Liga 17th and 18th are relegated.
- One shared place: **16th of the Primeira Liga plays 3rd of Liga Portugal 2 over two legs**. The winner plays in the Primeira Liga next season. So 3 clubs can move in each direction, but only 1 of those 3 is decided on the pitch — and it is the *same* tie for both directions, not two independent slots.

### 2 ↔ 3 (Liga Portugal 2 ↔ Liga 3)

Mirror image:

- Up: Liga 3 1st and 2nd of the promotion stage go up; the **3rd of the promotion stage plays 16th of Liga Portugal 2 over two legs**.
- Down: Liga Portugal 2 17th and 18th are relegated directly; 16th is the club in that tie.

### 3 ↔ 4 (Liga 3 ↔ Campeonato de Portugal) — fixed 4 and 4

- Down: Liga 3 sends **4 clubs** down — the bottom two of each of the two relegation series.
- Up: Campeonato de Portugal sends **4 clubs** up — the top two of each of its two promotion groups.
- No play-off at this boundary, and no geography-driven exchange: the four CdP series are regional, but the four promotion places are won in the promotion groups, and a promoted club simply enters Liga 3, where it is then placed in the north (Série A) or south (Série B) series. Likewise a club relegated from Liga 3 is placed in whichever of the four CdP series covers its district association. So clubs do move between series every season, but the *number* of clubs crossing the boundary is fixed at 4/4.

## Liga 3 in detail — how it actually works

20 clubs, and it does **not** have a single table:

1. **First stage**: two geographic series of 10 (Série A = north, Série B = south), double round-robin, **18 rounds**.
2. **Promotion stage**: the top 4 of each series (8 clubs) form one series, double round-robin, **14 rounds**. **Points do not carry** — everyone starts at 0 (verified against the completed 2025-26 promotion table: each club played exactly 14 matches and no bonus column exists).
3. **Relegation stage**: positions 5–10 of each series (12 clubs) form two series of 6, double round-robin, **10 rounds**. Here points *do* carry, as bonus points ranked across both first-stage series: best 5th = 9, worst 5th / best 6th = 8, worst 6th = 7, 7th = 6, best 8th = 5, worst 8th = 4, best 9th = 3, worst 9th = 2, 10th = 1.
4. The bottom two of each relegation series (4) go down to the Campeonato de Portugal.

So the split is asymmetric in a way that matters for a sim: **0 points carried into the promotion stage, 1–9 bonus points into the relegation stage.** A single `points_carry` flag cannot express both; the JSON keeps `points_carry: false` (the promotion stage, which is what decides promotions) and spells out the relegation-stage bonus in `stages`.

The champion is the winner of the promotion stage. Promotion stage 1st and 2nd go up, 3rd goes to the two-legged play-off against Liga Portugal 2's 16th.

## Campeonato de Portugal in detail

56 clubs, four geographically based series (A–D) of **14**, double round-robin, **26 rounds**:

1. **Series stage**: 1st and 2nd of each series (8 clubs) qualify for the promotion play-offs; 11th and 12th qualify for relegation play-offs; 13th and 14th are relegated directly to the district championships.
2. **Promotion play-offs**: the 8 qualifiers are split into **two groups of four**, each playing a double round-robin (**6 rounds**), points starting at 0. The **top two of each group are promoted** — 4 promotions, no knockout legs. The two group winners then play a single championship final at the Estádio Nacional.
3. Note the 2026-27 change below the promotion line: last season (2025-26) the bottom five of each series (10th–14th) went down directly, 20 clubs in total. In 2026-27 only 13th–14th are direct and 11th–12th go to relegation play-offs.

**How many go between Liga 3 and the Campeonato de Portugal: exactly 4 up and 4 down**, every season, no play-off.

## Sources

- https://pt.wikipedia.org/wiki/Primeira_Liga — 18 clubs; 17th–18th relegated; 16th plays 3rd of Liga Portugal 2 over two legs
- https://pt.wikipedia.org/wiki/Segunda_Liga — 18 clubs, 34 matches; top 2 promoted, 3rd plays 16th of the Primeira Liga; 17th–18th relegated, 16th plays 3rd of Liga 3; B teams cannot be promoted
- https://pt.wikipedia.org/wiki/Liga_3 — 20 clubs, two geographic series of 10, promotion/relegation stages, bonus points 1–6 described, third placed plays 16th of Liga Portugal 2
- https://pt.wikipedia.org/wiki/Campeonato_de_Portugal_(liga) — fourth tier, series + play-off structure, list of champions (format section there is stale, describing the old 63-club season)
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Primeira_Liga — 2026-27 table markers (`result16=RO`, `result17-18=LP2`)
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Liga_Portugal_2 — 2026-27 team list (Sporting B, Benfica B present), `result16=RO`, `result17-18=L3`
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Liga_3_(Portugal) — 20 clubs = 2 relegated from LP2 + 14 retained + 4 promoted from CdP; first-stage markers `1-4=PS`, `5-10=RS`
- https://en.wikipedia.org/wiki/2025%E2%80%9326_Liga_3_(Portugal) — completed promotion stage (8 clubs, 14 matches each, no carried points) and the exact relegation-stage bonus scale 9→1
- https://en.wikipedia.org/wiki/Liga_3_(Portugal) — format prose: 4 best of each series to promotion stage, bottom 6 to relegation stage
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Campeonato_de_Portugal — 56 clubs, four series, `result1-2=PPO`, `result11-12=RPO`, `result13-14=REL`
- https://en.wikipedia.org/wiki/2025%E2%80%9326_Campeonato_de_Portugal — 56 clubs (4 + 28 + 24), bottom five per series relegated, promotion play-offs as two groups of four with top two promoted

## Confidence

High on structure and counts. Items flagged rather than guessed:

- The English Wikipedia table for 2026-27 Liga Portugal 2 marks `result1=PL, result3=PL, result5=PO`, which contradicts the Portuguese prose (top 2 + 3rd to play-off). The prose is authoritative and is what the JSON uses.
- The 2026-27 Campeonato de Portugal relegation line (11th–12th play-offs, 13th–14th direct) differs from 2025-26 (10th–14th direct). This is below our modelled floor, so it is recorded as a note only.
- District-championship intake into the Campeonato de Portugal is not fixed year to year (24 in 2025-26, 20 in 2026-27) and is out of scope.

## Added by the merge

- PT23 Liga Next Gen U23: level 99, 20 clubs, closed both ways — not covered by the research pass.
