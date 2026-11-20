# Australia — pyramid research

Season: 2026-27  |  confidence: high

## Sources

- https://en.wikipedia.org/wiki/Australian_soccer_league_system
- https://en.wikipedia.org/wiki/A-League_Men
- https://en.wikipedia.org/wiki/2026%E2%80%9327_A-League_Men
- https://en.wikipedia.org/wiki/National_Premier_Leagues_NSW_Men%27s
- https://en.wikipedia.org/wiki/2026_National_Premier_Leagues_NSW_Men%27s
- https://en.wikipedia.org/wiki/2025_National_Premier_Leagues_NSW_Men%27s
- https://en.wikipedia.org/wiki/National_Premier_Leagues_Victoria_Men%27s
- https://en.wikipedia.org/wiki/2026_National_Premier_Leagues_Victoria_Men%27s
- https://en.wikipedia.org/wiki/2026_Victoria_Premier_League_1
- https://en.wikipedia.org/wiki/Football_NSW_League_Men%27s

## Leagues

| id | name | level | size | up | down | format |
|---|---|---|---|---|---|---|
| AUS1 | A-League Men | 1 | 12 | True | True | single |
| A2SW | National Premier League - New South Wales | 2 | 16 | True | False | single |
| A2VI | National Premier League - Victoria | 2 | 14 | True | False | single |

## Boundaries

| upper | lower | up | up playoff | down | down playoff | allocation | selection | note |
|---|---|---|---|---|---|---|---|---|
| 1 | 2 | 0 | 0 | 0 | 0 | none | bottom_n | No sporting boundary exists. A-League Men is a closed, licence-based league (10 Australian + 2 New Zealand clubs) with no promotion to or relegation from it; entry is by APL licence, so NPL NSW and NPL Victoria cannot be promoted into it and its clubs cannot be relegated into them. Size is set administratively, not by results: Western United were removed by Football Australia before 2025-26 (13 -> 12), Auckland FC were added in 2024-25, and Canberra United's men's side is now targeted for 2028-29. The Australian Championship (16 NPL clubs, 4 groups, post-season spring competition) is a separate competition, not a tier, and confers no promotion. |
| 2 | 3 | 1 | 1 | 1 | 1 | New South Wales: NPL NSW bottom club relegated automatically, 2nd-bottom enters a promotion/relegation play-off against the NSW League One runner-up (League One champion goes up automatically); NPL NSW stays at 16. | bottom_n | This is the only real movement in the country. The play-off slot is 0-or-1 per side, so a season can move 1 or 2 clubs each way (in 2025 both went down because the League One runner-up won the play-off; 2026 sent one down automatically and one into the play-off, while UNSW and SD Raiders came up). NPL NSW 1st is the top of the NSW pyramid: no promotion above it. |
| 2 | 3 | 2 | 1 | 3 | 0 | Victoria: NPL Victoria bottom three relegated to Victoria Premier League 1; VPL1 champion and runner-up promoted automatically, with a third promotion place decided by a play-off among VPL1 3rd-6th; NPL Victoria stays at 14. | bottom_n | Symmetric 3-down/3-up (2026: Bentleigh Greens, Dandenong Thunder, Green Gully down; Brunswick Juventus, Melbourne Knights, Northcote City up). VPL1 itself relegates three to VPL2, so the level 2 -> 3 boundary feeds a live lower pyramid. NPL Victoria 1st is the top of the Victorian pyramid: no promotion above it. |

## Mismatches and open questions

- Level 2 is only partly represented: the database holds 2 of the 9 member-federation NPLs (NSW 16 + Victoria 14 = 30 clubs) out of roughly 110. Missing at level 2: NPL Queensland (12), NPL South Australia (12), NPL Western Australia (12), NPL Northern NSW (12), NPL Capital Football/ACT (11), NPL Tasmania (10) and the Northern Territory's NorZone Premier League (8).
- A-League academy sides hold NPL slots that cannot climb: Sydney FC Youth and Western Sydney Wanderers Youth in NPL NSW (2 of 16), Melbourne City Youth in NPL Victoria (1 of 14). In NSW they are explicitly ineligible for the Australian Championship and finals. They can still go down (Central Coast Mariners Academy was relegated out of NPL NSW after 2025; Melbourne Victory Youth was relegated out of NPL Victoria after 2026), and Victoria even let Melbourne City Youth be promoted from VPL1 into NPL Victoria for 2026, so 'academy' blocks upward movement above NPL but not downward movement or intra-state promotion.
- Licence withdrawal, not sport: Western United had their A-League licence removed by Football Australia for financial reasons before 2025-26, cutting the league from 13 to 12, and Western United Youth then folded out of Victoria Premier League 1 during 2026. A simulation must model A-League exits as licence events, since there is no relegation.
- Expansion is pending but not for this season: Auckland FC entered in 2024-25 (making 13 before Western United's removal); the Canberra men's licence has slipped repeatedly and on 17 July 2026 was re-targeted at 2028-29, so 2026-27 stays at 12.
- Calendar mismatch inside one 'season' label: the A-League runs 16 Oct 2026 - 5/6 Jun 2027, while NPL competitions run February - September in the same calendar year. A '2026-27' snapshot therefore pairs A-League 2026-27 with NPL 2026 (already finished, 13 Sep 2026) rather than NPL 2027.
- Level-2 rows are parallel state leagues, not one national tier: there is no sporting movement between NPL NSW and NPL Victoria, and a club relocating states joins that state's pyramid through the annual declaration of leagues rather than by promotion or relegation, so a mover between A2SW and A2VI is not a pyramid move.
- New South Wales publishes a 1 + play-off relegation model (not a fixed 2), so treat the NSW boundary as one automatic place plus a 0-or-1 play-off place; Victoria publishes a fixed 3 down / 2 + 1 up. Sizes are therefore stable at 16 and 14 but the number of movers per season is not identical.
