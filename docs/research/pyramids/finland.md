# Finland — football pyramid, 2026 (career year 2026-27)

Finland plays **calendar-year seasons**, so the season overlapping the 2026-27 career year is the
**2026 season** (4 April – 1 November 2026). The JSON uses `"season": "2026-27"` only as the
dataset label. Cups and UEFA competitions are out of scope.

Our four rows sit on levels 1, 2, 3 and 5. **Level 4 (Kakkonen) is missing from our database**,
which matters: it is the division Ykkönen relegates into and the one Kolmonen promotes into.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | FI1 | Veikkausliiga | 12 | double RR, then 6/6 split (top plays double, bottom single) | 22 + 10 / 22 + 5 | — (closed) | 1 direct + 1 play-off |
| 2 | FI2 | Ykkösliiga | 10 | triple round robin | 27 | 1 direct + 1 play-off | 1 direct + 1 play-off |
| 3 | FIYK | Ykkönen | 12 | double RR, then promotion/relegation rounds of 6 | 22 + 5 | 1 direct + 1 play-off | 2 direct |
| 4 | — | Kakkonen (not modelled) | 3 × 10 | double RR, then championship/relegation split | 22 | group winners may go up | 2 per group |
| 5 | KOG2 | Kolmonen, Etelä-Suomi lohko B | 12 | double round robin, one of 10 groups | 22 | play-off among the 10 group winners (6 places) | 2 (to Nelonen) |

## Level 1 — Veikkausliiga

- 12 clubs, 22-round double round robin (132 matches), then a split: the top six play the
  **mestaruussarja** (championship series) as a double round robin — 10 more games, 32 in total —
  and the bottom six play the **haastajasarja** (challenger series) as a single round robin, 5 more
  games, 27 in total. Points carry over in full, goals too.
- This asymmetry is deliberate and is the same system as 2025: the top half plays five more matches
  than the bottom half, so the two tables are not comparable game-for-game.
- **Relegation:** 12th goes down directly; 11th plays the Ykkösliiga runner-up over two legs.
- 2026 outcome: Inter Turku champions; IFK Mariehamn relegated; FF Jaro survived the play-off
  against PK-35 (2-1 on aggregate).

## Level 2 — Ykkösliiga

- 10 clubs, **triple** round robin, 27 matches — no split.
- **Promotion:** champion up directly (KTP in 2026). 2nd plays the Veikkausliiga 11th over two legs.
- **Relegation:** 10th down directly (SJK Akatemia). 9th plays the Ykkönen runner-up over two legs
  (KäPa lost on penalties to RoPS in 2026 and went down). So two clubs leave, one of them by play-off.

## Level 3 — Ykkönen

- 12 clubs: 22-round double round robin, then the top six play a **promotion round** and the bottom
  six a **relegation round**, each single round robin, points carried — 27 matches.
- Winner of the promotion round is promoted; its runner-up meets the Ykkösliiga 9th over two legs.
- The bottom two of the relegation round are relegated to Kakkonen (level 4, not in our rows).

## Level 5 — Kolmonen, Etelä-Suomi lohko B

- Kolmonen is the fifth tier since 2024: **110 clubs in 10 regional groups** of 8–12, run centrally
  by the FA (the districts lost the admin in 2020). For 2026 the groups are Etelä-Suomi A/B/C
  (12 each, all Uusimaa), Länsi-Suomi A/B/C (12 each), Itä- ja Keski-Suomi AC1/AC2 (8 each) and B
  (12), Pohjois-Suomi (10).
- KOG2 is **Etelä-Suomi lohko B**, 12 clubs, double round robin: Atlantis FC/2, FC Kontu, HPS/2,
  LPS, MPS/Atletico Malmi, PPJ/Lauttasaari, PPS, TiPS, Toukolan Teräs, Töölön Taisto, VJS/Akatemia,
  Valtti.
- **Promotion:** no group winner goes up automatically. The ten group winners contest the promotion
  places to Kakkonen and **six clubs are promoted** in a normal season — the binding constraint is
  Kakkonen's vacancies (three groups of ten, two relegated per group) and licensing.
- The bottom two in the group are normally relegated to Nelonen (level 6, district-run, not modelled).

## Check against our database

| id | our name | our level | real level | our size | real size 2026 | verdict |
|---|---|---|---|---|---|---|
| FI1 | Veikkausliiga | 1 | 1 | 12 | 12 | correct |
| FI2 | Ykkösliiga | 2 | 2 | 10 | 10 | correct |
| FIYK | Ykkönen | 3 | 3 | 12 | 12 | correct |
| KOG2 | Kolmonen Etelä Group B | 5 | 5 | 12 | 12 | size/level correct; the real group is "Etelä-Suomi lohko B", one of ten |

Only real problem is structural, not numeric: **no level-4 row**. With Kakkonen absent, the only
honest options are to accept that our t3→t5 step is not a boundary, or to add Kakkonen.

## Caveats

- The 2026 season finished on 1 November 2026, so 2027 compositions are already decided but the
  2027 season pages do not exist yet.
- Reserve/feeder sides are everywhere in the lower tiers (Klubi 04, SJK Akatemia, VJS/Akatemia,
  Atlantis FC/2 ...). Some are separate clubs, some are literal reserve teams that cannot play above
  their parent; a sim that treats them as ordinary clubs will produce impossible promotions.
- Kolmonen group shapes change every season with entries and withdrawals; the "10 groups, 110 clubs"
  figure is the 2026 shape, not a rule.

## Sources

- https://en.wikipedia.org/wiki/2026_Veikkausliiga
- https://fi.wikipedia.org/wiki/Veikkausliigan_kausi_2026
- https://en.wikipedia.org/wiki/2026_Ykk%C3%B6sliiga
- https://en.wikipedia.org/wiki/2026_Ykk%C3%B6nen
- https://en.wikipedia.org/wiki/Kolmonen
- https://fi.wikipedia.org/wiki/Kolmonen_(jalkapallo)
- https://en.wikipedia.org/wiki/Kakkonen
- https://en.wikipedia.org/wiki/Finnish_football_league_system
