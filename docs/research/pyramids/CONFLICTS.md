# Pyramid research — conflicts and open questions

72 countries record at least one conflict. 97 notes touch sizes or promotion/relegation numbers; 111 are about names, formats or sources.

Each entry is written as: league · field — what we encoded; what the source says.

## Albania (low)

- **ALB1 · format** — ours: single table, 36 rounds; real: 36 rounds plus announced Championship/Relegation rounds (top 6 / bottom 4). Both the English and Albanian 2026-27 articles mark the split and link to sections that do not exist; neither gives a round count for it. Treated as an announcement, not a format.
- **ALB1 · relegation** — ours: 9th and 10th relegated, no play-out; real: 10th relegated directly, 9th plays the Kategoria e Pare play-off final loser. The Albanian league overview still states the old rule (bottom two down, no play-out); the 2026-27 Kategoria e Pare article describes the play-off for 9th.
- **ALB1-ALB2 · promotion_relegation** — ours: 3 promoted, 2 relegated; real: 3 promoted (2 direct + 1 play-off) against 2 documented relegation places. The two directions cannot both be true for a 10-club league; the missing place is not documented in any source read.

## Andorra (medium)

- **AND1 · format** — ours: 10 clubs, 27 rounds, no split; real: the league overview text describes 8 clubs, 21 rounds, a top-four/bottom-four split and 27 games. That prose describes the pre-2020 eight-club format. The infobox (teams = 10) and the 2025-26 season article (ten clubs, three meetings, no split) are current and are what is recorded.

## Argentina (high)

- ARGC is a phase, not a competition: the 2026 top division is Apertura + Clausura + aggregate table. The Apertura row (same 30 clubs) is missing, so the 'Campeon de Liga' title and one of the two relegation slots cannot be computed from the database.
- Level-1 relegation is not resolvable from the ARGC row at all: it needs the season aggregate table (both tournaments) and a 2024-2026 promedio table, and 2024/2025 data is absent.
- AR3F (18) and AR3R (19) are two paths of one 37-club competition (Torneo Federal A 2026), not two competitions. 18+19=37 is only the entry split after the first phase; clubs eliminated from the championship path are re-fed into the Revalida, so one club can appear in both rows within a season and the Revalida's final field exceeds 19.
- Level 3 is two parallel branches, not one league: Torneo Federal A (37 clubs, indirectly affiliated) and Primera B Metropolitana (22 clubs, directly affiliated). The three level-3 rows sum to 59, which is the correct total, but treating those 59 as one league is wrong - clubs only cross branches through Primera Nacional relegation, by affiliation.
- The level-3 downward edge is missing entirely (Federal A: 4 down; Primera B: 2 down). Without those rows, clubs relegated from level 3 have nowhere to go and level-3 sizes cannot be maintained.
- Missing rows: Torneo Apertura 2026 (level 1, 30 clubs), Primera C Metropolitana (level 4, directly affiliated), Torneo Argentino del Interior 2027 / Torneo Regional Federal Amateur (level 4, indirectly affiliated).
- Source conflict: the English Torneo Federal A page says 20 clubs entered the Revalida first phase; the Spanish page and arithmetic (37 - 18) give 19, which matches our row. The English page also says Federal A relegation goes to the Torneo Regional Federal Amateur, while the Spanish page (newer) says the Torneo Argentino del Interior, which replaces the TRFA as 4th tier from 2027.
- Primera Nacional totals are stable but the branch split is not: 2026 relegated 3 to Primera B Metropolitana and 1 to Torneo Federal A. Any model that assigns a fixed 2/2 will break the branch sizes.

## Armenia (low)

- **ARM2 · size** — ours: 15; real: 16 (as of 2025-26). The First League article gives teams = 16 but its current-season link points at 2025-26; no 2026-27 source exists yet. 15 is kept as our row, 16 as the last confirmed figure.

## Australia (high)

- Level 2 is only partly represented: the database holds 2 of the 9 member-federation NPLs (NSW 16 + Victoria 14 = 30 clubs) out of roughly 110. Missing at level 2: NPL Queensland (12), NPL South Australia (12), NPL Western Australia (12), NPL Northern NSW (12), NPL Capital Football/ACT (11), NPL Tasmania (10) and the Northern Territory's NorZone Premier League (8).
- A-League academy sides hold NPL slots that cannot climb: Sydney FC Youth and Western Sydney Wanderers Youth in NPL NSW (2 of 16), Melbourne City Youth in NPL Victoria (1 of 14). In NSW they are explicitly ineligible for the Australian Championship and finals. They can still go down (Central Coast Mariners Academy was relegated out of NPL NSW after 2025; Melbourne Victory Youth was relegated out of NPL Victoria after 2026), and Victoria even let Melbourne City Youth be promoted from VPL1 into NPL Victoria for 2026, so 'academy' blocks upward movement above NPL but not downward movement or intra-state promotion.
- Licence withdrawal, not sport: Western United had their A-League licence removed by Football Australia for financial reasons before 2025-26, cutting the league from 13 to 12, and Western United Youth then folded out of Victoria Premier League 1 during 2026. A simulation must model A-League exits as licence events, since there is no relegation.
- Expansion is pending but not for this season: Auckland FC entered in 2024-25 (making 13 before Western United's removal); the Canberra men's licence has slipped repeatedly and on 17 July 2026 was re-targeted at 2028-29, so 2026-27 stays at 12.
- Calendar mismatch inside one 'season' label: the A-League runs 16 Oct 2026 - 5/6 Jun 2027, while NPL competitions run February - September in the same calendar year. A '2026-27' snapshot therefore pairs A-League 2026-27 with NPL 2026 (already finished, 13 Sep 2026) rather than NPL 2027.
- Level-2 rows are parallel state leagues, not one national tier: there is no sporting movement between NPL NSW and NPL Victoria, and a club relocating states joins that state's pyramid through the annual declaration of leagues rather than by promotion or relegation, so a mover between A2SW and A2VI is not a pyramid move.
- New South Wales publishes a 1 + play-off relegation model (not a fixed 2), so treat the NSW boundary as one automatic place plus a 0-or-1 play-off place; Victoria publishes a fixed 3 down / 2 + 1 up. Sizes are therefore stable at 16 and 14 but the number of movers per season is not identical.

## Belgium (high)

- No level 4 in our rows: below BE3 sit Tweede afdeling / Division 2 Amateur (VV A, VV B, FFA). A club relegated from BE3A or BE3V has nowhere to land, so any simulation that runs a demotion must either stop at level 3 or add the level-4 rows.
- Naming: the rows call level 3 '1ste Nationale FFA/VV'. The competition is Eerste nationale (Dutch) / Nationale 1 (French) / Belgian Division 1 (English); FFA and VV are the wings (Football Francophone Amateur / Voetbal Vlaanderen), not the competition name. 'FFA' is also not ACFF's current label everywhere - sources alternate between FFA and ACFF.
- The two level-3 rows are parallel leagues at the same level, not a hierarchy: they must not be promoted/relegated into each other. The only cross-wing rule is that a level-3 club keeps the wing of its affiliation when it goes up or down.
- BE2's size of 15 is a transition artefact, not a design target. Anyone assuming 16 or 18 (the Feb 2025 announcement said '16-18 depending on U23 results', later dropped) will get league sizes wrong.
- BE1 in 2026-27 has no play-offs at all. Carrying over the 2023-24..2025-26 'split with rounds + play-offs' format (or phases such as PO1/PO2) would be wrong; the season is a plain 34-round table.
- BE3A's format is not 'single': it is a split after 22 rounds with points halved for both the promotion and the relegation play-offs. Modelling it as one table loses the reset and the play-off promotion slot.
- U23 reserve teams (Club NXT, Jong Genk, Jong KAA Gent, RSCA Futures in BE2; Jong Cercle, OH Leuven U23, Union SG U23, SL16 FC, Zebra Elites in level 3) are real members of the pyramid: always eligible for relegation, never for promotion. A promotion move onto a U23 club is invalid.
- Relegation counts at level 3 are conditional, not fixed: BE3V drops 2 plus 0-2 more depending on how many VV-affiliated clubs come down from BE2, BE3A drops 2 plus possibly 1. Hard-coding 'bottom 2 down' at level 3 breaks the 16/12 sizes in seasons with same-wing double relegations.

## Brazil (high)

- State championships run in parallel and are NOT a tier: the national pyramid (Série A-D) and the 27 state pyramids are two independent systems (en: 'Brazilian football league system'). Campeonato Paulista Série A1 2026 ran 10 Jan - 8 Mar while Série A ran 28 Jan - 2 Dec, so the same clubs are entered in both at once (e.g. Palmeiras, Corinthians, Santos, São Paulo, Red Bull Bragantino in both). A 'one club belongs to one league per season' model is therefore wrong for Brazil unless states are stored as a parallel competition, not a level.
- State championships have their own promotion/relegation inside their own pyramid (Paulista A1 relegated Velo Clube and Ponte Preta to A2 in 2026), and their only structural link upward is qualification: state-league/state-cup places feed Série D entry (and the Copa do Brasil). No state title ever promotes a club into Série C or above.
- A club cannot be in two national divisions in the same season: Série A, B, C and D are strictly disjoint (a Série A club is never also in B/C/D). The 'one league per season' invariant holds only within the national pyramid; across the state pyramid it does not.
- Promotion/relegation between Série A and Série B is NOT the only structural movement: B<->C and C<->D also move clubs every year, so a model that only wires BRA1<->BRA2 will drop real clubs. Série B's bottom four go to Série C; Série C's top four go to Série B.
- Série C and Série D exist below (20 and 96 clubs in 2026). 2026 is a transition year: Série C had only 2 relegated (Confiança, Itabaiana) instead of the usual 4, while 6 clubs came up from Série D (4 semi-finalists + 2 play-off winners among quarter-final losers), because Série C grows to 24 clubs in 2027 and 28 from 2028. So C->D = 2 and D->C = 6 in 2026, not the historical 4/4.
- Série D has no relegation at all (pt infobox 'rebaixa' is empty; no downward edge exists). Its field is set by qualification: clubs relegated from Série C, state-league/state-cup qualifiers, clubs that reached the previous Série D second stage, and CBF-ranking fill-ups. A generic pyramid model that assumes every league has both an up and a down edge breaks at Série D.
- Série B 2026 promotion is not a pure 'top N' rule: 2 of the 4 places are decided by a play-off among 3rd-6th, so a model that maps 'positions 1-4 promoted' produces the wrong set of clubs.
- The season is a calendar year (late Jan - early Dec), not Aug-May, and 2026 had a FIFA World Cup pause (11 Jun - 19 Jul) plus the state-to-national handover in Jan-Apr; season-boundary logic copied from European leagues will mis-date every transfer between these divisions.

## Bulgaria (medium)

- **BU2 · size** — ours: 18; real: 20. The 2026-27 Second League has 20 clubs in a transitional season; it returns to 16 in 2027-28.
- **BU2 · relegation** — ours: 6 direct (14th-20th); real: 5 direct (per the Bulgarian article). The English article says 14th-20th go down directly (six) and 13th plays off; the Bulgarian article says five direct relegations and 13th in a play-off. Six is used here because it matches the positions named.

## Chile (medium)

- CL2F and CL2Z are not leagues. Both are stages of the single level-3 competition (Liga de Segunda): CL2F is 'Fase 2', the split into the Liguilla de Ascenso and Liguilla de Descenso; CL2Z is a zonal stage/qualifier of the same competition, not a play-off group with its own 2 clubs. The database has turned one competition's phases into three level-? leagues.
- CL2F's size 12 matches no current level-3 format: 2026 has 14 clubs whose Fase 2 groups hold 7 each, and 2025 was a single 13-club table. The last 12-club second phase was 2016-17 (zonal phase, then a 12-club national phase), so the number is a stale historical format and is dropped here instead of copied into a league size.
- CL2Z's size 2 is not a club count at all; it is the number of zones (Norte/Sur) / a two-club zonal qualifier, so a 2-club 'league' would break any table generation.
- The three fragments (CL2F 12, CL2Z 2) leave the actual level 3 without a row of the right size (14), so promotion from level 2 (1 club) and relegation to level 4 (2 clubs) currently have no valid destination.
- Level 4 (Tercera División A, 14 clubs) is missing, so the 2 clubs relegated from level 3 have nowhere to go.
- The rows describe a flat single-table league; from 2026 level 3 resets into two 7-club liguillas mid-season, so its schedule and table structure cannot be modelled as one 14-team round robin.

## China (high)

- **CHL3/CL3S · membership** — ours: China League Two A and China League Two B, two leagues of 12; real: one 24-club China League Two whose first stage is two geographic zones (North 12, South 12). The two 12s are the correct first-stage group size, but they are not separate divisions: the zones are re-pooled after round 22 into an 8-club promotion group and two cross-zonal relegation groups. The zone labels should be North/South, not A/B.
- **CLO · rules** — ours: no play-off encoded at 2-3; real: 2 up / 2 direct down + 14th in a two-leg play-off. '2 up / 2.5 down' is new for 2026; a stored 2025 shape (2 down, no play-off) is stale.
- **level 3 · size** — ours: 12 + 12 = 24; real: 24. Total is right by construction; do not treat the two rows as independent 12-club leagues when generating fixtures.

## Chinese Taipei (medium)

- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .

## Colombia (medium)

- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .

## Costa Rica (high)

- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .

## Croatia (high)

- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .

## Cyprus (high)

- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .

## Czech Republic (high)

- **CZ3C · membership** — ours: one 32-team league; real: ČFL = 2 groups (A and B) of 16. The size is right; the shape is not. It is one division split into two 16-team groups whose winners meet in a two-leg baráž for a single promotion place.
- **TS1 · format** — ours: split 6 championship / 10 relegation; real: 6 championship / 4 placement play-off / 6 relegation. The split is three-way, not two-way. Places 7-10 play a two-legged placement bracket (7v10, 8v9, final), not a relegation group.
- **level 3 · structure** — ours: two parallel leagues: Bohemian and Moravian-Silesian; real: ČFL (Bohemia, groups A+B, 32) + MSFL (Moravia-Silesia, 18) = 3 groups. There are two level-3 competitions but three groups. Our CZ3C row bundles the two Bohemian groups; CZ3M is the single Moravian-Silesian league.
- **TS1 · playoff** — ours: none encoded; real: 13th safe, 14th/15th baráž, 16th direct. Any model that relegates a flat bottom 3 from the Chance Liga is wrong for this format.

## Denmark (high)

- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .

## Ecuador (high)

- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .

## Egypt (medium)

- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .

## Estonia (high)

- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .

## Ethiopia (medium)

- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .

## Faroe Islands (high)

- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .

## Finland (high)

- **KOG2 · structure** — ours: one level-5 league, 12 clubs; real: Kolmonen is 10 regional groups (110 clubs); KOG2 is the Uusimaa 'Etelä-Suomi lohko B' of 12. Size and level are right for that group, but the group is one of ten and its winner must win a promotion play-off to reach Kakkonen.
- **level 4 · membership** — ours: no row; real: Kakkonen (level 4): 30 clubs in three groups of 10, double round robin then a championship/relegation split. Our rows jump from Ykkönen (t3) to Kolmonen (t5). Kakkonen is the missing link: FIYK relegates into it and KOG2 promotes into it, so no boundary between our t3 and t5 rows can be encoded without it.

## France (high)

- **FR4C · size** — ours: 17; real: 16. National 1 is 48 clubs in 3 groups of 16 (30 rounds). Our 16/16/17 gives 49; group C is one club too large.
- **FR3 · name** — ours: Ligue 3; real: Ligue 3. Name is correct only from 2026-27: the former Championnat National was rebranded Ligue 3 (FFF competition rules 'Ligue 3 - règlement 2026-2027'). Older rows named 'Championnat National' would be wrong at level 3.
- **FR5 · membership** — ours: 3 groups (E, F, G); real: 8 groups (A-H) of 14 = 112 clubs. Our level 5 carries only groups E, F and G; five groups are missing. Sizes (14) are correct.

## Germany (high)

- **level 4 · membership** — ours: 3 Regionalligen (Bayern, Nordost, Südwest) = 55 clubs; real: 5 Regionalligen = 91 clubs. Regionalliga Nord (18) and Regionalliga West (18) are missing from our data. The three we carry have correct sizes: Bayern 19, Nordost 18, Südwest 18.
- **RLN4 · name** — ours: RLN4 = Regionalliga Northeast; real: Regionalliga Nordost. Id reads like 'Nord' but holds Nordost. The newly added Regionalliga Nord uses id RLN; if ids are regenerated, prefer RLNO for Nordost.
- **L3 · size** — ours: 20; real: 20. Correct, and it implies 38 rounds (380 matches).

## Gibraltar (high)

- **GIIL · name** — ours: Gibraltar Reserve League; real: Gibraltar Intermediate League (since 2018). The Gibraltar Reserves Division was replaced by the Intermediate League in June 2018. It is a development competition: squads of up to 18, at least 13 players eligible for Gibraltar, at most 5 over the age of 23, plus a salary cap. No promotion route.
- **GIIL · size** — ours: 9; real: None. Our 9 could not be confirmed from the sources used; the Intermediate League's entry varies with which GFL clubs field a side. Left at our value rather than guessed.

## Greece (medium)

- **GRS2 · structure** — ours: one league of 16; real: one group of 16 in 2026-27, but two groups (North/South) in 2025-26. The single group is new: the 2025-26 edition was split into a north and a south group, each with its own champion (Iraklis and Kalamata both went up). The reduction to 16 clubs in one group also removed the promotion play-offs and relegation play-outs.

## Hong Kong (medium)

- **HK3L · format** — ours: 16 clubs; real: 16 clubs in 2026-27, split 8/8; the competition-format text describes an 8+7 split because it was written for a 15-club season. The single-round-robin-then-split shape is right; the group sizes follow the entry list, so they change with promotions and withdrawals.
- **HK22 · identity** — ours: Hong Kong U22 League, 11 clubs; real: None. No HKFA U22 league article could be found; the HKFA runs age-group competitions alongside the senior pyramid (the U22-minute quota used to be enforced through the Sapling Cup, discontinued after 2025-26). Treat the row as an age-group competition with no promotion route; size 11 is our value, unverified.

## Hungary (high)

- **UN2 · playoff** — ours: not encoded; real: champion up, runner-up into a one-legged play-off against the NB I 11th (new for 2026-27). The NB II article still describes the previous rule - top two promoted, NB I 11th and 12th relegated. The 2026-27 NB I page and the Hungarian season page both confirm the new single-match play-off, so that is what is recorded here.

## India (medium)

- **IND2 · format** — ours: 8 clubs; real: 8 clubs, but the season article does not state the round structure. Rounds left null rather than assumed. The 2025-26 edition was a single table; whether 2026-27 is one or two round robins is not documented yet.
- **level 4 · membership** — ours: no row; real: I-League 3 is the fourth national tier; state leagues are the fifth. India now has four national divisions plus state leagues. Our rows stop at I-League 2, so its two relegation places have no destination in the dataset.

## Indonesia (medium)

- **IN3L · format** — ours: 24 clubs; real: 24 clubs, group structure for 2026-27 not yet published. 2024-25 used two groups of eight with a championship round and relegation play-offs; with 24 clubs the shape must differ. Recorded with null group count rather than a guess.
- **IN1L · playoff** — ours: none encoded; real: no title play-off section in the 2026-27 season article; 2024-25 had a Championship Series. The 2026-27 Super League appears to be a straight 34-round table, but the format has changed twice in three seasons, so treat 'no title play-off' as season-specific.

## Iran (medium)

- **IRN1 · relegation** — ours: not encoded; real: the 2026-27 table legend marks 15th-18th as relegation (four places), but only three clubs came up from the Azadegan League. Recorded as three down (two direct plus the 14th in a play-off), which fits the three-club Azadegan intake. The four-place legend cannot be reconciled with a stable 18-club league, and the 2025-26 season is no guide because the league was expanding then: only Mes Rafsanjan went down, through the play-off, while three clubs came up.
- **IRN3 · promotion** — ours: not encoded; real: the general League 2 article says the top two of each group go up (four clubs); the current Azadegan intake shows three. The four-club rule is older. The 2026-27 Azadegan article names exactly three promoted clubs - the League 2 champion, the runner-up and the play-off winner - so the three-place model is recorded.

## Israel (high)

- Liga Leumit's own article still says points are halved and the split is played as a single round-robin, which is the pre-2013 description; the 2025-26 season tables show full points carried (37 matches, e.g. 18W-13D-6L = 67 pts) and both eight-team groups playing once. The season tables are used here.
- The Israeli Premier League all-time table lists one '13th place' relegation play-off, and older seasons did use one; the 2023-24, 2024-25 and 2025-26 seasons all relegated exactly the bottom two with no play-off, so the 2026-27 model uses 2 down / 0 play-off.

## Italy (high)

- **IT3A-IT3C · membership** — ours: 3 separate level-3 leagues of 20; real: one 60-club Serie C with 3 geographical groups of 20. Sizes and levels are correct, but the three rows share one promotion play-off, one relegation play-out and a yearly geographical re-draw of clubs between groups. Do not treat them as closed leagues with a fixed 1-up-1-down each.

## Jamaica (medium)

- The 2026-27 season infobox says 247 matches, which cannot be right for 14 clubs playing 39 matches each (273 in total); the round count and the 39-match statement are used.

## Kazakhstan (medium)

- The English 2026 Premier League article is tagged AI-generated and its attendance figure is meaningless, but its 16-team, 30-round, 240-match, 2-relegated shape matches the Russian Wikipedia article exactly, so the numbers are used.
- Kazakhstan's second tier is variously called First League / First Division / Pervaya Liga; the Wikipedia article title is 'Kazakhstan First Division' while the league is 'Pervaya Liga'. Same competition.

## Latvia (medium)

- The 2026 Virsliga infobox says 170 matches, but 10 clubs playing four rounds is 180; the round count (four rounds, 36 per club) is stated in prose and matches the LFF regulations cited there, so 36 is used.
- Our row's name 'Futbola Pirmā līga' is the pre-2021 name: the second tier has been branded Nakotnes liga / Future League since 2021 and LVBET League for sponsorship in 2026. Same competition, id unchanged.

## Lebanon (medium)

- The 2026-27 season article says both that the league is 'divided into two groups of six' and that 'the top four teams enter the championship group, while the bottom four enter the relegation group'. The two sentences cannot both be true for 12 clubs. The 'groups of six' reading is used because the same paragraph says each club plays 'the other five clubs in its group twice, for a further 10 matches', which only works with two groups of six, and because 2024-25 and 2025-26 both used a 6/6 split.
- Points: the 2026-27 article says each club carries over half its points (rounded up); 2024-25 and 2025-26 say the same, so half-carry is used. This is why points_carry is true but the values are halved, not carried in full.

## Libya (medium)

- The Wikipedia league article still describes 36 clubs in 4 groups (its infobox and lead), which was the shape in earlier seasons. The LFF approved a 28-club, 2-group format for 2026-27 (Libya Observer, 21 September 2026), and Transfermarkt's 2026-27 tables show exactly two groups of 14. Our row's size 28 is right for 2026-27 and the 36/4 figure is stale.

## Lithuania (medium)

- **LTU2 · size** — ours: 16; real: 18. The I Lyga infobox still says 16 clubs, but the approved 2026 participant list on the same page has 18 (including six B teams). Used 18 for the season.
- **LI1 · name** — ours: Toplyga; real: TOPLYGA. Correct: the A Lyga was renamed TOPLYGA from 2026. Only the capitalisation differs.

## Malaysia (medium)

- **MYS1-MAY2 · season** — ours: calendar year 2026; real: 2026-27, August/September 2026 - May 2027. Malaysia no longer runs a calendar-year league: 2025-26 ran 8 Aug 2025 - 17 May 2026 and 2026-27 runs 28 Aug 2026 - 23 May 2027. The Super League also had 13 clubs in 2025-26 and 12 in 2026-27, so our size 12 is right for the coming season only.

## Malta (high)

- **MT1N · name** — ours: Premier League Opening Round; real: Maltese Premier League (Opening Round is one half of its season). The league is a single competition of 12 clubs split into an Opening Round and a Closing Round, each with its own table and its own champion; points reset to zero between them. 'Opening Round' is not the league's name.
- **MAL3 · size** — ours: 12; real: 14 in 2025-26, 12 in 2026-27. The Amateur League I had 14 clubs in 2025-26 (26 rounds) and drops to 12 for 2026-27 (22 rounds) after four relegations. Our 12 matches the coming season.

## Mexico (high)

- **MEXA-MEX2 · promotion/relegation** — ours: none in the top division; real: none in practice, but legally contested. The CAS ordered relegation back for 2026-27; Liga MX ignored it and made itself a closed league in July 2026, and the FMF's August 2026 model keeps Liga MX closed while restoring promotion between Liga de Expansión and Liga Premier. A Mexican Senate bill (Sep 2026) would force promotion back. Treat as closed for now, with political risk.
- **MEX2 · size** — ours: 16; real: 16 (prose says 15). The Liga de Expansión MX article's format paragraph says '15 clubs' while its own 2026-27 participant list and infobox say 16. Used 16.
- **MEXA/MEX2/M191/M21A · name** — ours: Liga MX Apertura / Liga de Expansión MX Clausura / U19 Apertura / U21 Apertura; real: Liga MX, Liga de Expansión MX, Liga MX Sub-19, Liga MX Sub-21. All four are year-round competitions split into Apertura and Clausura; the row names carry one tournament, not the competition.

## Moldova (high)

- **MDL2 · size** — ours: 11; real: 11 (infobox says 12). The Liga 1 infobox says 12 clubs, but the 2026-27 participant list and Phase I groups (6 + 5) have 11. Used 11 for the season.

## Myanmar (medium)

- **MYA1 · season** — ours: calendar year 2026; real: 2026-27, August 2026 - May 2027. The M League now runs August to May with 22 matches per club; the 2026-27 season is the current one. The old calendar-year habit dates from the Myanmar National League era.
- **MYA1 · name** — ours: M League; real: M League (formerly Myanmar National League). Correct: the MNL was rebranded as M League in August 2026, with a new logo and trophy. Sponsor name Grand Royal M League.

## Netherlands (high)

- **NL2-NTD · closed** — ours: open pyramid; real: closed for first teams. The Eerste Divisie has had no sporting relegation since 2022 (KNVB suspension for 5-10 seasons). A Tweede Divisie amateur champion is not promoted; 2025-26 champions Quick Boys stayed put.
- **510 · id** — ours: 510; real: Derde Divisie A (one of two level-4 divisions). The id is opaque but the mapping is right. Level 4 is two parallel divisions, A and B, 18 clubs each; we carry only A.

## New Zealand (high)

- All three rows are marked level 1. They are the level-2 regional stage: the pyramid has exactly one level-1 competition (the National League Championship) and three parallel level-2 leagues.
- The real level 1 (National League Championship, 11 clubs) is missing from the database entirely, so the top of this pyramid has no row.
- The three level-2 rows are parallel, not a hierarchy: their club pools are disjoint (north / centre / south of the country) and clubs never move between them. A simulation that treats them as 1st/1st/1st of one ladder, or that promotes between them, is wrong.
- The names hide the competition format: 'National League - North/Central/South' are the regional leagues that feed the National League, not national divisions of it.
- Nothing records the fixed 4/3/2 qualifying quota or the two automatic reserve entrants (Auckland FC Reserves, Wellington Phoenix Reserves), which are the reason level 1 has 11 clubs rather than 9.
- The 2027 restructure (12-club national double round robin, summer phase scrapped) is already announced; the rows describe the 2021-2026 format only.

## Nicaragua (medium)

- **NC2A · name** — ours: Liga de Ascenso de Nicaragua; real: Segunda División (branded Liga de Ascenso). The competition's official name is Segunda División de Nicaragua; the league and Transfermarkt both brand it 'Liga de Ascenso'. Our name is the branded one, and our id NC2A matches that branding.

## Nigeria (high)

- **NPFL · name** — ours: Nigeria Professional Football League; real: Nigeria Premier Football League (renamed 2023; the 2026-27 edition is branded Euromatch Premier Football League). Same competition and same 20-club format; only the name in our row is the pre-2023 one.

## North Macedonia (medium)

- **MAZ1 · playoff_opponent** — ours: 8th plays the 2. MFL play-off winner; real: the league article still says the opponent is the winner of a tie between the two Second League group runners-up. Outdated: the Second League has been a single division since 2021-22 and its 2026-27 table marks 3rd place as the play-off entrant. Use 1. MFL 8th v 2. MFL 3rd.

## Norway (high)

- **NO31-NO32 · name** — ours: PostNord-ligaen Avd. 1/2; real: 2. divisjon avdeling 1/2. The PostNord sponsorship ran 2016-2025 only; from 2026 the league has no title sponsor. Level, size (14+14) and id mapping are correct.

## Oman (low)

- **OM1L · name** — ours: Oman Jindal League; real: Oman Professional League (Omantel Professional League for sponsorship). No source read uses 'Jindal'. Probably a 2026-27 title sponsor that is not documented, or a bad name in our database.
- **OM1L · size/club_list** — ours: 14; real: the league page's own 2024-25 club list names only 12 clubs. The named list is stale (it still mentions 2023-24 relegations); the infobox says 14. 14 used.

## Philippines (medium)

- **PFL1 · format** — ours: single 20-round table; real: the 2026-27 league table labels places 1-5 'Championship round' and 6-10 'Classification round', implying a split that no text describes. Unresolved: the stated format is a double round-robin of 20 games and the 2025-26 title was decided on the single table. Recorded as single; re-check if a PFF regulation appears.

## Poland (high)

- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .

## Portugal (high)

- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .

## Puerto Rico (low)

- **PRA1 · size** — ours: 9; real: the season article says each tournament is 'contested by eight teams'. The participating-club list and the standings both show nine clubs; the 'eight' looks like a leftover from 2025-26. 9 used.

## Qatar (medium)

- **QU2L · size** — ours: 12; real: 8 clubs in 2026-27. Confirmed by the English 2026-27 club list and by the Spanish and Arabic league articles, both of which say eight. Our 12 looks like a copy of the QSL figure.
- **QU2L · promotion_rule** — ours: 1st direct + 2nd in the play-off; real: the English article says the champion plays the 10th-placed QSL club and the runner-up is not mentioned. Outdated 2022-23 rule. The 2026-27 QSL table marks 11th as the play-off place and the Arabic article describes runner-up v second-last. Current shape used.
- **QU2L · relegation** — ours: no relegation from the second tier; real: the English infobox lists relegation to a 'Qatar Stars League 3', while its own body text and the Spanish/Arabic articles say there is no relegation and no third tier. No QSL3 season or club list was found. Either way the destination is outside our data, so QU2L is closed_down.

## Romania (high)

- **RO2 · size** — ours: 23; real: 22. The 2026-27 Liga II article says 'twenty-two teams' twice and its league table's team list contains 22 clubs. Our 23 does not match any reading of the sources.

## Russia (high)

- 2DVB is one row for 4 parallel leagues: the 2026 Division B is 59 clubs in 4 geographic groups (Group 1: 16, Group 2: 15, Group 3: 16, Group 4: 12), each with its own champion, its own single promotion place and its own relegation quota (1 / 2 / 2 / 2). Group 4 additionally splits into subgroups 4A/4B after its summer stage. One row can only hold the aggregate.
- Season phase: Division B runs March-November on a calendar-year cycle (2026 season), while RU1/RU2/R3D1 run July-June (2026/27). There is no 2026-27 Division B season, so the row's season label points at the 2026 season, which overlaps but does not coincide.
- R3D1 'Phase 1' is not a phase of a league, it is one stage of a single competition: Division A is played as an autumn first stage (17 clubs: 10 gold + 7 silver, because Chernomorets, Chayka and Kuban failed licensing) and a spring second stage (20 clubs: 2x10, after 4 clubs come up from Division B and 1 goes down). The gold/silver split and the mid-season 4-in/1-out rotation cannot be expressed by one row.
- Promotion from Division B to Division A happens in the winter (November/March), not at the end of the season, so end-of-season-only rotation logic places the 4 promoted clubs half a season late.
- There is no relegation from Division A or promotion to it at the end of 2026-27; the FNL moved the A/B rotation to the winter window. A model that demotes the 2 bottom clubs in June 2027 would be wrong.
- The bottom edge of the pyramid is missing: Division B relegates to the amateur Third League (tier 5, no row in our DB) and entry is by licensing application, not automatic promotion - 7 clubs left Division B for tier 5 at the end of 2026 (Dynamo-2 Makhachkala, Iskra, Irkutsk, Arsenal-2, Kvant, Ural-2, Chelyabinsk-2).
- Naming: '1.Division' is the pre-2022 name of RU2; since 2022 it is the First League (Первая лига), just as the old '2. Division' became Second League Division A/B in 2023.

## San Marino (high)

- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .

## Serbia (high)

- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .

## Singapore (high)

- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .

## Slovakia (high)

- ** · ** — ours: ; real: .
- ** · ** — ours: ; real: .

## Spain (high)

- Segunda Federacion really has FIVE groups (I-V, 18 clubs each, 90 in total); our list holds only four (E4G2-E4G5), so Grupo I - the north-west group (Galicia, Asturias, Cantabria, Castilla y Leon) - is missing: 18 clubs, one fifth of level 4, with no row and no edges.
- Because SF-I is absent, one fifth of every level-4 flow has no edge: in 2026-27 SF-I sent 2 clubs up to Primera Federacion (champion Deportivo Fabril + a play-off winner) and took 1 of the 10 clubs relegated from Primera Federacion (Ourense CF). Level 4 upward total is 10, not 8; downward total is 10, not 7.
- Tier sizes differ by design: LaLiga 20, LaLiga2 22, Primera Federacion 2x20, Segunda Federacion 5x18. Any code assuming one uniform size per tier is wrong for ES2 (22).
- All eight rows are competitions, none is a phase: Primera Federacion's Grupo I/II and Segunda Federacion's groups are competition groups, not play-off stages, so E3G1/E3G2 and E4G2-E4G5 map 1:1 onto real groups by number.
- Naming only: 'LaLiga2' is officially Segunda Division (branded LaLiga Hypermotion); 'LaLiga' is Primera Division / LaLiga EA Sports. Same competitions, no structural mismatch.
- Out of our list but part of the pyramid: Segunda Federacion sends 27 clubs down to Tercera Federacion each season (25 direct - last five of each group - plus 2 from a play-off between the four worst 13th-placed teams); Tercera has no row here, so that outflow is unrepresentable.

## Thailand (high)

- **THA1/THA2 · season** — ours: calendar year 2026; real: August 2026 - May 2027. Thailand played spring-to-autumn until 2019; since 2020-21 the season is autumn/spring, so the current season is 2026-27.

## Türkiye (high)

- **T191 · level** — ours: 99 (youth/reserve sentinel); real: not on the pyramid at all. U19 Süper Lig is the Süper Lig clubs' youth competition: entry is compulsory for the 18 senior clubs, fixtures mirror the senior list, no promotion or relegation. Keep it at level 99 and closed both ways; the field changes only when a senior club goes up or down.

## Ukraine (medium)

- **UA2P · membership** — ours: Premier Liga 2, a 16-club senior-looking league; real: no senior competition of that name exists. The Ukrainian pyramid is UPL - Persha Liha - Druha Liha. 'Premier Liga 2' matches the UPL's youth/reserve championship (U-21, 16 clubs, one per UPL club). Keep level 99 and closed; it must never promote or relegate.
- **UA3L · size** — ours: 18; real: 18 in the 2026-27 group list (9 + 9); the league infobox says 22. The infobox figure is stale. 18 is the correct count for 2026-27; note that group sizes flex every season with withdrawals.
- **UA3L · relegation** — ours: not encoded; real: no relegation by rule. Druha Liha clubs that finish last lose professional status and return to regional football, or simply withdraw; the PFL does not relegate them. Model exits, not relegations.

## United States (high)

- **MNP3/USC3 · structure** — ours: both at level 3; real: two rival third-tier leagues in different organisations. MLS Next Pro belongs to MLS (reserve/development clubs), USL League One to the USL. They never exchange clubs and there is no sporting link between them or to MLS/USL Championship.

## Uruguay (high)

- UR2T is marked level 1; it is level 2 (Segunda División Profesional). This is the plain error the rows contain.
- UR2T's label 'Torneo Competencia' names the opening phase (two series of 7 plus a final) of the second division, not a competition: the row's size 14 is the whole second division, so keeping it as a separate 'league' invents a 14-club competition that lasts six matchdays.
- The two rows skip level 3. Segunda relegates 2 clubs per season into Primera Divisional C (28 clubs); with no level-3 row those clubs have nowhere to go and any move would shrink level 2.
- The level-1 row does not encode that the season is three tournaments plus a semi-final/final; a simulator using one 16-club table for the whole year cannot reproduce the Apertura/Intermedio/Clausura reset or the champion play-off.
- Relegation from level 1 depends on a two-season average table (Tabla de Descenso), not on the Clausura standings; nothing in the rows can hold that state.
- No row records that 3 of the 14 second-division clubs are promoted each year (2 direct + 1 play-off), which is the only reason a 16-club and a 14-club league can exchange clubs every season.

## Uzbekistan (medium)

- **UZ2L · size** — ours: 14; real: 14 in 2026, 6 in 2024 and 2025. 14 is correct for 2026 (the season article lists 14 clubs and 182 matches) but the league's own infobox and lead sentence still say 6. A row copied from last season would say 6 - and 14 clubs means 26 rounds, not 10.
- **UZ1 · relegation** — ours: 3 down (1 play-off); real: 2-3 depending on the season, plus a one-off 2026 reshape. The Pro League article describes bottom-club-down plus a 12th-v-3rd play-off; the 2026 Super League table instead marks 12th-15th as play-off places and 16th as direct relegation. Treat the 2026 markings as an unexplained one-off and implement the documented rule.
- **UZ2L · relegation** — ours: 1 down; real: last club down per the rule; the 2026 table marks 13th and 14th. The regulations text says the last-placed club is relegated to the First League; the 2026 standings mark two places. Level 3 (First League) is not in our rows either way.

## Venezuela (medium)

- **VZ1C · structure** — ours: one league named after the Clausura; real: one 14-club competition played as two tournaments (Apertura, Clausura), each with a top-8 group phase and a final. The Clausura is the second half of the same league, not a separate division. Model two 13-round tournaments inside VZ1C, with the table resetting at mid-year and an aggregate table only for relegation.
- **VZ1C · relegation** — ours: not encoded; real: one club in 2025 and 2026. The league article still says the two lowest are relegated; the last two seasons relegated exactly one (Yaracuyanos 2025, Anzoategui 2026). Use one.
- **VN2A · size** — ours: 17; real: 16 per the league infobox. No 2026 season page exists, so 17 could not be verified. Treated as our figure with a flag rather than corrected.

## Vietnam (high)

- **VIE1 · season** — ours: calendar year 2026; real: September/October 2026 - June/July 2027. Vietnam played spring-to-autumn until 2023; since 2023-24 the season is autumn/spring, so the current one is 2026-27.

