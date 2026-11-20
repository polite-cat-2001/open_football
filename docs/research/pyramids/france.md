# France — football pyramid 2026-27

Data for the career sim. Season 2026-27, men's professional/National championships, Ligue 1 down to National 2 (levels 1-5). Cups and European competitions excluded.

## Sources

| What | URL |
|---|---|
| Ligue 1 2026-27 (rules, 34 rounds, relegation/barrage) | https://fr.wikipedia.org/wiki/Championnat_de_France_de_football_2026-2027 |
| Ligue 2 2026-27 (18 clubs, 34 rounds, both play-offs) | https://fr.wikipedia.org/wiki/Championnat_de_France_de_football_de_deuxi%C3%A8me_division_2026-2027 |
| Ligue 3 2026-27 (former National; 18 clubs, 34 rounds) | https://fr.wikipedia.org/wiki/Championnat_de_France_de_football_de_troisi%C3%A8me_division_2026-2027 |
| National 1 2026-27 (level 4, 3 groups of 16) | https://fr.wikipedia.org/wiki/Championnat_de_France_de_football_de_quatri%C3%A8me_division_2026-2027 |
| National 2 2026-27 (level 5, 8 groups of 14) | https://fr.wikipedia.org/wiki/Championnat_de_France_de_football_de_cinqui%C3%A8me_division_2026-2027 |
| English cross-check: Ligue 3 is the renamed National | https://en.wikipedia.org/wiki/2026%E2%80%9327_Ligue_2 |

FFFF competition rules for Ligue 3 (`reglement-ligue-3-betclic-2026-2027.pdf`) are cited by the French Ligue 3 article itself; I did not open the PDF.

## The pyramid

| Level | League | Clubs | Rounds | Up | Down |
|---|---|---|---|---|---|
| 1 | Ligue 1 | 18 | 34 | — (top) | 2 direct + 1 play-off |
| 2 | Ligue 2 | 18 | 34 | 2 direct + 1 play-off | 2 direct + 1 play-off |
| 3 | Ligue 3 | 18 | 34 | 2 direct + 1 play-off | 3 direct |
| 4 | National 1 — Groupes A, B, C | 3 × 16 = 48 | 30 | 1 per group (3) | 15th + 16th per group, plus the 2 worst 14th (8) |
| 5 | National 2 — Groupes A–H | 8 × 14 = 112 | 26 | 1 per group (8) | 12th–14th per group, plus the worst 11th (25) → Régional 1 |

**Naming change.** The third tier is officially **Ligue 3** in 2026-27 (sponsored "Ligue 3 Betclic"), run by the FFF; it was the Championnat National until 2025-26. Level 4 consequently became **National 1** (ex-National 2) and level 5 **National 2** (ex-National 3). Our ids FR4A/B/C and FR5E/F/G already use the new names — the naming is right, only the contents need fixing.

## Boundaries in detail

**1 ↔ 2.** Ligue 2's top two go up. Places 3-5 play a single-match bracket (5th at 4th, then the winner at 3rd); that winner meets Ligue 1's 16th in a two-leg tie. Ligue 1's 17th and 18th are relegated directly, so 2 up / 2 down plus one play-off place in each direction. Away goals are no longer used; level after 180 minutes goes to extra time then penalties.

**2 ↔ 3.** Mirror of the above with one extra rung: Ligue 3's 3rd-6th play a single-match bracket (6th at 3rd, 5th at 4th, final at the better seed) and the winner meets Ligue 2's 16th over two legs. Ligue 3's bottom three (16th-18th) go down with no play-off, which is exactly why National 1 promotes three.

**3 ↔ 4.** No play-off at all. National 1 is 48 clubs in three regional groups of 16; each group winner is promoted (3 up), matching Ligue 3's 3 direct relegations. National 1's own relegation is 8: 15th and 16th of every group (6) plus the two worst 14th-placed teams — the 14th is a "relegated under conditions" slot, so the sim cannot decide it inside one group alone.

**4 ↔ 5.** National 2 is 112 clubs in eight regional groups of 14; the eight group winners fill exactly National 1's eight relegation places. National 2's own relegation is 25 (bottom three of each group plus the worst 11th), feeding the regional leagues — outside the model.

## Decisions

- Level 5 is encoded with **all eight groups (A–H)**, not only the three we hold, so that the 8-up/8-down boundary with level 4 is closed. Groups keep our existing letters E, F, G.
- Group leagues use `format.kind = "groups"` with `groups` = 3 or 8 and the per-group `rounds`, because National 1/2 really are one championship split into regional groups (unlike Germany's five separate Regionalligen, which I encode as `"single"`).
- `allocation` is `by_geography` for 3↔4 and 4↔5: the promoted place is one per regional group, and the relegated club lands in the group of its region.
- `selection` is `bottom_n` where places are table positions, `other` where the rule is "group winner" rather than a rank band.
- Play-offs: two-leg ties between divisions are `legs: 2`; the internal single-match brackets are described in `entries`/`note` rather than inventing a second `legs` value.
- France has **no** level with a points-average (`promedio`) or split-season rule; every level is a plain double round-robin.

## Conflicts with our rows

| Ours | Real 2026-27 | Consequence |
|---|---|---|
| FR4A/B/C = 16/16/17 (49 clubs) | 16/16/16 (48) | Group C is one club too large; fix to 16 |
| FR5E/F/G only (3 × 14) | 8 groups of 14 (112) | Five groups missing; sizes correct |
| FR3 "Ligue 3", 18 clubs | correct | none |
| FR1/FR2 18 clubs each | correct | none |

## Confidence

**High** for levels 1-4: sizes, round counts and every promotion/relegation place are stated explicitly in the 2026-27 season articles, and the Ligue 3 rename is confirmed by English Wikipedia. **High** for the level-5 structure (8 × 14, winners up, 25 down). Medium only on *which* regions groups E/F/G cover — the season article gives no region labels for the individual groups, so the sim should treat group geography as cosmetic.

Open item: National 1 relegation depends on comparing 14th-placed teams across groups (two worst go down). That is a cross-group comparison the data model must support, or it has to be modelled as a fixed 8-slot rule with a tie-break.
