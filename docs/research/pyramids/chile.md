# Chile — pyramid research

Season: 2026  |  confidence: medium

## Sources

- https://es.wikipedia.org/wiki/Liga_de_Primera_2026
- https://es.wikipedia.org/wiki/Liga_de_Ascenso_de_Chile_2026
- https://es.wikipedia.org/wiki/Liga_de_Segunda
- https://es.wikipedia.org/wiki/Liga_de_Segunda_2026
- https://es.wikipedia.org/wiki/Segunda_División_Profesional_de_Chile_2025
- https://es.wikipedia.org/wiki/Segunda_División_Profesional_de_Chile_2016-17
- https://es.wikipedia.org/wiki/Tercera_División_A_de_Chile_2026
- https://en.wikipedia.org/wiki/Liga_de_Primera
- https://en.wikipedia.org/wiki/Campeonato_Nacional_Primera_B
- https://en.wikipedia.org/wiki/Segunda_División_Profesional_de_Chile

## Leagues

| id | name | level | size | up | down | format |
|---|---|---|---|---|---|---|
| CLPD | Liga de Primera | 1 | 16 | True | False | single |
| CL2B | Liga de Ascenso | 2 | 16 | False | False | single |
| CL2 | CL2 | 3 | 14 | False | False | single |
| CL3A | CL3A | 4 | 14 | False | False | single |

## Boundaries

| upper | lower | up | up playoff | down | down playoff | allocation | selection | note |
|---|---|---|---|---|---|---|---|---|
| 1 | 2 | 2 | 1 | 2 | 0 | free | bottom_n | up is the total and up_playoff the part decided by play-off: Liga de Ascenso champion direct, plus the winner of (runner-up vs 3rd-8th liguilla) over two legs. down=2, both direct from the Liga de Primera table. 16 - 2 + 2 = 16. |
| 2 | 3 | 1 | 0 | 1 | 0 | free | bottom_n | Only the Liga de Segunda champion goes up (the level-3 runner-up has no play-off), and only the last-placed Liga de Ascenso club comes down. 16 - 1 + 1 = 16 and 14 - 1 + 1 = 14. |
| 3 | 4 | 2 | 1 | 2 | 0 | free | bottom_n | Tercera División A (ANFA, semi-professional, 14 clubs, two zones) sends its champion up directly and a second club through a play-off among 2nd-5th. Liga de Segunda sends its bottom 2 down. 14 - 2 + 2 = 14. 2026 was exceptional: 3 went up (Atlético Colina, Colchagua, Lota Schwager) and 3 went down (Melipilla, San Antonio Unido, plus Barnechea's suspension) because of disciplinary expulsions, so do not hard-code the exceptional count. |

## Mismatches and open questions

- CL2F and CL2Z are not leagues. Both are stages of the single level-3 competition (Liga de Segunda): CL2F is 'Fase 2', the split into the Liguilla de Ascenso and Liguilla de Descenso; CL2Z is a zonal stage/qualifier of the same competition, not a play-off group with its own 2 clubs. The database has turned one competition's phases into three level-? leagues.
- CL2F's size 12 matches no current level-3 format: 2026 has 14 clubs whose Fase 2 groups hold 7 each, and 2025 was a single 13-club table. The last 12-club second phase was 2016-17 (zonal phase, then a 12-club national phase), so the number is a stale historical format and is dropped here instead of copied into a league size.
- CL2Z's size 2 is not a club count at all; it is the number of zones (Norte/Sur) / a two-club zonal qualifier, so a 2-club 'league' would break any table generation.
- The three fragments (CL2F 12, CL2Z 2) leave the actual level 3 without a row of the right size (14), so promotion from level 2 (1 club) and relegation to level 4 (2 clubs) currently have no valid destination.
- Level 4 (Tercera División A, 14 clubs) is missing, so the 2 clubs relegated from level 3 have nowhere to go.
- The rows describe a flat single-table league; from 2026 level 3 resets into two 7-club liguillas mid-season, so its schedule and table structure cannot be modelled as one 14-team round robin.

## Added by the merge

- CL2F Segunda División - Fase 2: level 3, 12 clubs, closed both ways — not covered by the research pass.
- CL2Z Segunda División - Liguilla zonal: level 3, 2 clubs, closed both ways — not covered by the research pass.
