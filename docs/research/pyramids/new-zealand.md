# New Zealand — pyramid research

Season: 2026  |  confidence: high

## Sources

- https://en.wikipedia.org/wiki/New_Zealand_National_League
- https://en.wikipedia.org/wiki/2026_New_Zealand_National_League
- https://en.wikipedia.org/wiki/Northern_League_(New_Zealand)
- https://en.wikipedia.org/wiki/Central_League_(New_Zealand)
- https://en.wikipedia.org/wiki/Southern_League_(New_Zealand)
- https://en.wikipedia.org/wiki/New_Zealand_football_league_system

## Leagues

| id | name | level | size | up | down | format |
|---|---|---|---|---|---|---|
| NZL1 | NZL1 | 1 | 11 | True | True | single |
| NNL1 | National League - North | 2 | 12 | False | False | single |
| NCL1 | National League - Central | 2 | 10 | False | False | single |
| NSL1 | National League - South | 2 | 10 | False | False | single |

## Boundaries

| upper | lower | up | up playoff | down | down playoff | allocation | selection | note |
|---|---|---|---|---|---|---|---|---|
| 1 | 2 | 9 | 0 | 0 | 0 | regional_fixed | bottom_n | Qualification, not promotion: 4 Northern + 3 Central + 2 Southern = 9 level-2 clubs enter the Championship; the other 2 of the 11 are the automatic reserve sides that belong to no level-2 league. down=0 because the Championship has no relegation - the 9 qualifiers return to their regional league. Treat this boundary as non-transferring for membership (up=down=0 in that sense): applying up=9 as real moves would give level 1 20 clubs and level 2 23, which is exactly the bug this pyramid invites. |
| 2 | 3 | 4 | 2 | 4 | 0 | regional | bottom_n | Inside each region only: Northern 2 up / 2 down (NRFL Championship), Central 1 up / 1 down (Central League 2; the up slot is the Capital Premier vs Federation League play-off), Southern 1 up / 1 down (Canterbury Premiership, Nelson Bays Premiership, Southern Premiership; decided by play-offs). up is the total and up_playoff is how many of those 4 are decided by a play-off. The 4/2 split is derived from the promoted clubs named in the 2026 season articles, not from a published slot table; level-3 league sizes are not in the database and vary by region. |

## Mismatches and open questions

- All three rows are marked level 1. They are the level-2 regional stage: the pyramid has exactly one level-1 competition (the National League Championship) and three parallel level-2 leagues.
- The real level 1 (National League Championship, 11 clubs) is missing from the database entirely, so the top of this pyramid has no row.
- The three level-2 rows are parallel, not a hierarchy: their club pools are disjoint (north / centre / south of the country) and clubs never move between them. A simulation that treats them as 1st/1st/1st of one ladder, or that promotes between them, is wrong.
- The names hide the competition format: 'National League - North/Central/South' are the regional leagues that feed the National League, not national divisions of it.
- Nothing records the fixed 4/3/2 qualifying quota or the two automatic reserve entrants (Auckland FC Reserves, Wellington Phoenix Reserves), which are the reason level 1 has 11 clubs rather than 9.
- The 2027 restructure (12-club national double round robin, summer phase scrapped) is already announced; the rows describe the 2021-2026 format only.
