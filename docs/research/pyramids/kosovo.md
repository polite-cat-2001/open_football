# Kosovo — football pyramid 2026-27

Research for the career simulation. Scope: the single row we carry (Superliga e Kosovës, level 1).
The First League of Kosovo (level 2) is outside our data. Cups and European places are out of
scope.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Football_Superleague_of_Kosovo | 10 clubs, dates (15 Aug 2026 – May 2027), 36 rounds, the Relegation-play-off marker in the table |
| https://en.wikipedia.org/wiki/2025%E2%80%9326_Football_Superleague_of_Kosovo | completed season used to check the format: "each team plays each other four times (36 matches)", 10 clubs, 2 relegated, and the relegation play-off pairing |
| https://en.wikipedia.org/wiki/Football_Superleague_of_Kosovo | league identity, level 1 |

No FFK page could be read directly (JS-rendered); the season articles cite `ffk-kosova.com` match
reports throughout, so the structure is effectively single-source at the federation level but
double-checked against a completed season.

## Leagues

| id | name | level | size | rounds | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| KO1 | Superliga e Kosovës | 1 | 10 | 36 | — (top) | 3 (2 auto + 1 PO) |

Size 10 and level 1 in our database are correct. One table, **four** meetings per pair (twice home,
twice away) = 36 matches per club, 180 in the division. Not 18.

## Promotion and relegation

The Superleague and the First League exchange clubs through three routes:

- **9th and 10th** in the Superleague are relegated directly.
- The **8th** enters a **relegation play-off**: the two First League group runners-up play a
  single semi-final, and the winner meets the Superleague's 8th for the last place.
- Each First League group champion is promoted (two groups, A and B), so two clubs come up
  automatically.

That is why the movement is best described as **3 up / 3 down with one shared play-off place** on
each side: minimum 2+2, maximum 3+3. 2025-26 is the worked example. Ferizaj and Prishtina e Re
finished 9th and 10th and went down; the 2026-27 promoted pair was Vushtrria (First League
champion) and Feronikeli (runner-up, one season after relegation); and the play-off was Dinamo
Ferizaj against Llapi — Dinamo beat Liria Prizren in the semi-final between the two group
runners-up, and Llapi kept the last place, since only Vushtrria and Feronikeli joined for 2026-27.

**Because the second tier is played in two geographic groups**, "the champion" is ambiguous: there
are two. A sim that models level 2 as one division of 16-20 will not reproduce this.

## Decisions

1. **`closed_up` / `closed_down` both true** — single-row country in our list. The First League
   exists and clubs move, but it is outside our data.
2. **No boundary object.** A boundary needs two adjacent levels in our data.
3. **`format.kind: "single"`, `rounds: 36`.** One table, quadruple round-robin, no split, no points
   reset.
4. **`playoff: null`** — the championship is the table; there is no title play-off inside the
   Superleague. The 8th-place play-off is a promotion/relegation tie with a lower division, so it
   cannot be encoded on a single league with no boundary.
5. **Not modelled:** Kosovar Cup, UEFA Champions League/Conference League places, and the licensing
   gate (clubs need a licence to be promoted, which is how the two-group First League occasionally
   promotes fewer than two).

## Oddities

- **Ten clubs and 36 rounds** is the densest schedule in this batch: 36 matchdays for a ten-team
  league, i.e. four meetings with everybody. Do not "fix" it to 18.
- **The play-off is between the 8th-placed top-flight club and a lower-division club**, not 9th —
  a common mistake when copying the Belgian/Dutch model. The bottom two go down outright.
- The First League's two groups are geographic and its runners-up are ranked against each other by
  a semi-final, not by a combined table. There is no single second-division table to read.
- Kosovo's clubs are increasingly owned/invested from the diaspora; squad rules and licences are
  the practical constraint, not the table.

## Confidence

**Medium.** Size (10), level (1) and the 36-round quadruple round-robin are solid (stated in prose
and confirmed by a completed season). The play-off pairing is stated explicitly for 2025-26, which
is strong evidence for the current rule, but the 2026-27 season article does not restate the
pairing, so a rule change for 2026-27 cannot be ruled out.
