# Colombia and Argentina: promotion, reducido and relegation (2026)

Checked **2026-11-21**. Machine-readable findings with the full clause text are in
`colombia.json` (`CO22` `promotion`, `COL1` `relegation_detail`) and `argentina.json`
(`ARG2` `promotion` / `relegation_detail`, `ARGC` `relegation_detail`). League sizes and
`assets/data/league_pyramids.json` were not touched.

Primary sources: Spanish Wikipedia season pages (2026 and, where the 2026 page is silent,
2025) and the AFA tournament reglamentos (PDF, text extracted from the published files).
Dimayor's own reglamento was not reachable; every Dimayor rule below is from the season page.

## CO22 — Primera B: two promoted

The promotion table is the **reclasificación**, which sums **all matches of both tournaments**
— all-against-all, cuadrangulares and the two semester finals. That is not the Primera A
promedio, which counts the regular phase only.

| Case | Who goes up | Repechaje |
|---|---|---|
| Exactly one semester champion is in the top two | that champion, directly | the other champion vs the best-placed top-two club that won no tournament |
| The same club wins Apertura and Finalización | the double champion, directly | the next two best-placed clubs in the table |
| Both champions are in the top two | both, directly | cancelled |
| Neither champion is in the top two | **not stated in the 2026 article** | **not stated** |

The repechaje is a two-legged series (per the 2025 regulation of the same system). No 2026
dates are published; the Torneo II final is 25 and 28 November, so it would fall in December.

2026 state at 19 November: Torneo I champion Envigado is 3rd in the reclasificación (72),
Torneo II final is Boca Juniors de Cali vs Deportes Quindío with Quindío 1st (76). A Quindío
title is case 1 (Quindío up, Envigado v Real Cartagena); a Boca title is the unstated case 4.

## ARG2 — Primera Nacional: the Torneo reducido

- **Entrants (15):** 2nd to 8th of each zone (14) **plus the beaten finalist**, who is seed 1.
- **Primera fase:** 14 clubs, single match, better-placed at home; 2A-8B, 2B-8A, 3A-7B,
  3B-7A, 4A-6B, 4B-6A, 5A-5B; a draw sends the better-placed club through. 14–15 November.
- **Segunda fase:** the 7 winners + beaten finalist, seeded 1–8 by zone position, then points,
  goal difference, goals for, draw; 1v8, 2v7, 3v6, 4v5, two legs; the better seed hosts the
  return leg and advances if points and goal difference are level. First legs 21–22 November.
- **Semifinales:** two legs, re-seeded 1v4 and 2v3, same tie rule.
- **Final:** two legs, 12 and 19 December; level on points and goal difference → penalties.
- The winner takes the second promotion. The first is the single final of the two zone winners
  (Godoy Cruz 3–1 Tristán Suárez, 15 November), so Tristán Suárez is the reducido's seed 1.

Relegation is separate and simple: bottom two of each zone (4 clubs) go down to Primera B
Metropolitana or Torneo Federal A by affiliation; ties for those places are play-off matches.

## ARGC — Liga Profesional: two relegated

Not "last of the promedio plus the penultimate of the annual" as a standing rule. The rule is:

1. **Last of the 2024–2026 promedio** goes down.
2. **Last of the 2026 Tabla General de Posiciones** goes down.
3. If the same club is last in both, it goes down **by promedio** and the second place passes to
   the **anteúltimo (29th) of the annual table** — so there are always exactly two.

The annual table is the sum of the **Apertura and Clausura regular phases only** (32 matches);
the phase knockouts never move it. The promedio counts the regular phases of 2024, 2025 and 2026.
Promoted clubs count **only from their promotion season**, dividing by the matches they actually
played (2026: Gimnasia y Esgrima (M) 41/32, Estudiantes (RC) 14/32, Aldosivi 52/64). Ties in a
relegation place are settled by **play-off match(es)** under art. 111 of the AFA Reglamento
General (reglamento art. 26.2), not by goal difference.

2026 outcome: Estudiantes (RC) was last of the promedio (0.437) and last of the annual (14 pts),
so Aldosivi, 29th of the annual (19 pts), was the second relegated club.

## Promedio: exact calculation for the engine

| | COL1 | ARGC |
|---|---|---|
| Seasons | 2024-I … 2026-II (6 tournaments) | 2024, 2025, 2026 |
| Matches counted | all-against-all phase only; cuadrangulares and finals excluded | fase de zonas only; knockout excluded |
| Formula | Σ regular-phase points / Σ regular-phase matches | Σ regular-phase points / Σ regular-phase matches |
| Promoted club | starts from zero, no inherited average; divisor = matches actually played | counts only from promotion season; divisor = matches actually played |
| Clubs down | 2 (bottom of the table) | 2 (promedio last + annual last, overlap rule above) |
| Fallback when history is missing | current season's two regular phases, i.e. its own promedio component | 2026 annual table (identical to the promedio for a one-season club) |

So the "aggregate fallback" is exact for a club with only the current season, and the real
average only matters once older seasons exist. In both leagues the cup/playoff matches must be
kept out of the average.

## Remaining unknowns

- **CO22 case 4** (neither champion in the top two): not described in the 2026 article. The 2025
  regulation had a two-legged Gran Final between the champions, the loser then playing the
  best-placed non-champion in the repechaje; the English 2026 page still mentions a "grand final",
  but the Spanish 2026 text does not. Do not encode without Dimayor's reglamento.
- **CO22 repechaje dates and bracket** for 2026: unpublished (season in progress).
- **COL1 average tie-break**: the season article states no criterion for clubs level on average.
- **ARG2 dates**: second-leg and semi-final dates are not printed in the article; only the
  first-phase (14–15 Nov), second-phase first legs (21–22 Nov) and final (12 and 19 Dec) are sourced.
- **AFA art. 111 / Estatuto art. 93**: referenced by the reglamento for the play-off detail and the
  relegation formula; the referenced texts themselves were not read.
