# Latvia — football pyramid 2026

Research for the career simulation. Scope: levels 1-2 as carried in our database. The Second League
(LIIGA, level 3) is outside our data. Cups and European places are out of scope.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026_Latvian_Higher_League | 10 clubs, four rounds from 6 March to 8 November 2026, the 9th-place play-off marker and the 10th-place relegation marker, champion and relegated club |
| https://en.wikipedia.org/wiki/Latvian_Higher_League | level 1, 10 clubs, promotion/relegation with the second tier |
| https://en.wikipedia.org/wiki/Future_League | second tier: 14 clubs, 26 games, champion promoted, 2nd in a two-legged play-off against the Virsliga's second-from-bottom, bottom two relegated and 3rd-from-bottom in a play-off |

The 2026 Virsliga article is tagged **AI-generated**, so the 36-round shape was checked against the
LFF regulations it cites (four rounds) and against the general league article. The Future League
article gives the second-tier rules in one clear paragraph.

## Leagues

| id | name | level | size | rounds | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| LET1 | Virsliga | 1 | 10 | 36 | — (top) | 2 (1 auto + 1 PO) |
| LET2 | Futbola Pirmā līga (now Nākotnes līga / Future League) | 2 | 14 | 26 | 2 (1 auto + 1 PO) | 2 (+1 PO to Second League) |

Both sizes match our rows. Virsliga: one table, **four** meetings per pair = 36 matches. Future
League: one table, double round-robin = 26 matches.

## The boundary, precisely

| between | up | of which PO | down | of which PO | allocation | selection |
| --- | --- | --- | --- | --- | --- | --- |
| 1-2 | 2 | 1 | 2 | 1 | free | bottom_n |

- **Up:** the Future League champion is promoted automatically. Its **runner-up** plays the
  Virsliga's **9th-placed** club over two legs for a place in the next Virsliga.
- **Down:** the Virsliga's **10th** is relegated automatically; the **9th** is the club in that
  play-off.

So there is **one shared play-off place**: in any given season either the top-flight 9th or the
second-tier 2nd goes/stays, never both. Real movement therefore varies between 1+1 and 2+2 each
way. `up: 2 / down: 2` with one play-off place on each side is the honest encoding (same convention
as Wales and Kosovo in this dataset).

2026 outcome: RFS champions; Ogre United (10th) relegated. The 9th-place play-off decided the other
place.

## Decisions

1. **`format.kind: "single"` at both levels.** No split, no groups, no championship play-off.
2. **`rounds: 36` for the Virsliga** — four rounds, not two. A default "10 clubs = 18 rounds" would
   halve the season.
3. **`rounds: 26` for the Future League** (14 clubs, two rounds).
4. **One play-off place on each side of the boundary** rather than 0 or 2, because the tie is
   between a top-flight and a second-tier club.
5. **`closed_down: true` for LET2** because the Second League is not in our data; note that its own
   relegation is 2 direct + 1 play-off (3rd-from-bottom vs the Second League's 3rd), which a sim
   would need if level 3 were added.
6. **Not modelled:** Latvian Cup, UEFA Champions League/Conference League places.

## Oddities

- **The second tier has been renamed.** It is "Futbola Pirmā līga" in our rows, "Nākotnes līga"
  (Future League) since 2021, and "LVBET League" for sponsorship in 2026. The id LET2 is unaffected,
  but name-based matching will miss it.
- **The Virsliga is tiny and top-heavy**: 10 clubs, 36 rounds, and the champion has been RFS or Riga
  for years. Two relegation places is 20% of the division per season.
- **A four-round season with a 36-match calendar in a country with Latvian winters** means the
  season is compressed into March–November; there is no winter break to absorb postponements.
- The 2026 infobox says 170 matches against an expected 180. Internal inconsistency in the source,
  recorded in `conflicts`; not evidence of a 9-club season (all ten clubs appear in the results
  grid).
- Latvian second-tier clubs are frequently reserve sides (RFS-2, Riga-2 historically), which cannot
  be promoted; as with Kazakhstan, promotion needs an eligibility flag.

## Confidence

**Medium.** Sizes (10/14), levels and the 26-match second tier are solid. The Virsliga round count
and the 2026 outcome rest on an AI-flagged article, cross-checked against the LFF regulations it
cites and against the play-off markers in its own table (9th = play-off, 10th = relegation), which
are consistent. The weak point is the 170-vs-180 match count.
