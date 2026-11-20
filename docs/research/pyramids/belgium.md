# Belgium — pyramid research

Season: 2026-27  |  confidence: high

## Sources

- https://nl.wikipedia.org/wiki/Eerste_klasse_A_2026-27_(voetbal_Belgi%C3%AB)
- https://nl.wikipedia.org/wiki/Eerste_klasse_B_2026-27_(voetbal_Belgi%C3%AB)
- https://nl.wikipedia.org/wiki/Eerste_nationale_2026-27_(voetbal_Belgi%C3%AB)
- https://nl.wikipedia.org/wiki/Eerste_nationale_(voetbal_Belgi%C3%AB)
- https://fr.wikipedia.org/wiki/Championnat_de_Belgique_de_football_2026-2027
- https://fr.wikipedia.org/wiki/Championnat_de_Belgique_de_football_de_deuxi%C3%A8me_division_2026-2027
- https://fr.wikipedia.org/wiki/Championnat_de_Belgique_de_football_de_troisi%C3%A8me_division_2026-2027
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Belgian_Pro_League
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Challenger_Pro_League
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Belgian_Division_1

## Leagues

| id | name | level | size | up | down | format |
|---|---|---|---|---|---|---|
| BE1 | Jupiler Pro League | 1 | 18 | True | False | single |
| BE2 | Challenger Pro League | 2 | 15 | False | False | single |
| BE3A | 1ste Nationale FFA | 3 | 12 | False | False | split |
| BE3V | 1ste Nationale VV | 3 | 16 | False | False | single |

## Boundaries

| upper | lower | up | up playoff | down | down playoff | allocation | selection | note |
|---|---|---|---|---|---|---|---|---|
| 1 | 2 | 2 | 1 | 2 | 0 | free | bottom_n | BE2 1st promotes directly; the 2nd-5th knockout play-off winner promotes directly too, with no further barrage against a BE1 club (that barrage existed only in the 2025-26 transition, when Lommel beat Dender). BE1 17th and 18th are relegated directly, no relegation play-off. Promotion needs a Division 1A licence, and a U23 reserve side can never be promoted, so an ineligible top-5 finisher is skipped and the next eligible club takes the play-off place. Decided on sporting merit, not geography: 2 up / 2 down keeps BE1 at 18 and BE2 at 15. |
| 2 | 3 | 2 | 1 | 2 | 0 | by_affiliation | bottom_n | One promotion slot per wing: the BE3V (Voetbal Vlaanderen) champion goes up directly (up_playoff 0 for that wing), the BE3A (FFA / francophone) promotion-play-off winner goes up via play-off (up_playoff 1). BE2's bottom 2 are relegated directly into Eerste nationale, each into the wing it is affiliated to. Parallel-league sizes are fixed (16 VV, 12 FFA), so the wing split of the 2 relegated clubs is absorbed by conditional extra relegations from level 3: a VV-affiliated club coming down sends BE3V's 14th (and 13th if two come down) to Tweede afdeling, an FFA-affiliated club sends BE3A's 10th (relegation play-off 4th) down; BE3V always drops at least 2 (15th, 16th) and BE3A at least 2 (11th, 12th). Level 3 is therefore 28 clubs (16+12) and stays so; never move a club across wings to balance numbers. |

## Mismatches and open questions

- No level 4 in our rows: below BE3 sit Tweede afdeling / Division 2 Amateur (VV A, VV B, FFA). A club relegated from BE3A or BE3V has nowhere to land, so any simulation that runs a demotion must either stop at level 3 or add the level-4 rows.
- Naming: the rows call level 3 '1ste Nationale FFA/VV'. The competition is Eerste nationale (Dutch) / Nationale 1 (French) / Belgian Division 1 (English); FFA and VV are the wings (Football Francophone Amateur / Voetbal Vlaanderen), not the competition name. 'FFA' is also not ACFF's current label everywhere - sources alternate between FFA and ACFF.
- The two level-3 rows are parallel leagues at the same level, not a hierarchy: they must not be promoted/relegated into each other. The only cross-wing rule is that a level-3 club keeps the wing of its affiliation when it goes up or down.
- BE2's size of 15 is a transition artefact, not a design target. Anyone assuming 16 or 18 (the Feb 2025 announcement said '16-18 depending on U23 results', later dropped) will get league sizes wrong.
- BE1 in 2026-27 has no play-offs at all. Carrying over the 2023-24..2025-26 'split with rounds + play-offs' format (or phases such as PO1/PO2) would be wrong; the season is a plain 34-round table.
- BE3A's format is not 'single': it is a split after 22 rounds with points halved for both the promotion and the relegation play-offs. Modelling it as one table loses the reset and the play-off promotion slot.
- U23 reserve teams (Club NXT, Jong Genk, Jong KAA Gent, RSCA Futures in BE2; Jong Cercle, OH Leuven U23, Union SG U23, SL16 FC, Zebra Elites in level 3) are real members of the pyramid: always eligible for relegation, never for promotion. A promotion move onto a U23 club is invalid.
- Relegation counts at level 3 are conditional, not fixed: BE3V drops 2 plus 0-2 more depending on how many VV-affiliated clubs come down from BE2, BE3A drops 2 plus possibly 1. Hard-coding 'bottom 2 down' at level 3 breaks the 16/12 sizes in seasons with same-wing double relegations.

## Added by the merge

- BEY1 U18 Elite 1: level 99, 12 clubs, closed both ways — not covered by the research pass.
- BE21 U21 Pro League: level 99, 11 clubs, closed both ways — not covered by the research pass.
