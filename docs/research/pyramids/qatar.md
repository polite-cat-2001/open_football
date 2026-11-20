# Qatar — football pyramid 2026-27

Research for the career simulation. Scope: levels 1-2 as carried in our database (Qatar
Stars League and Qatar Stars League 2). Cups and AFC places are out of scope.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Qatar_Stars_League | 2026-27 QSL: 12 clubs, the table (9 rounds), 11th marked relegation play-off and 12th relegation, the promoted/relegated pair (Lusail up, Umm Salal down) |
| https://en.wikipedia.org/wiki/Qatar_Stars_League_2 | QSL2 identity, the 2026-27 club list (8 clubs), the promotion play-off description, the "no relegation" statement and the contradictory infobox |
| https://es.wikipedia.org/wiki/Segunda_Divisi%C3%B3n_de_Catar | cross-check: "eight clubs", one promoted |
| https://ar.wikipedia.org/wiki/%D8%AF%D9%88%D8%B1%D9%8A_%D8%A7%D9%84%D8%AF%D8%B1%D8%AC%D8%A9_%D8%A7%D9%84%D8%AB%D8%A7%D9%86%D9%8A%D8%A9_%D8%A7%D9%84%D9%82%D8%B7%D8%B1%D9%8A | cross-check: eight clubs, 1st promoted, 2nd into a play-off against the second-last QSL club, no relegation from QSL2 |

## Leagues

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| QSL | Qatar Stars League | 1 | 12 | 22 rounds (double round-robin) | — (top) | 1 direct + 1 play-off |
| QU2L | Qatar Stars League 2 | 2 | 8 | 14 rounds (double round-robin) | 1 direct + 1 play-off | — |

QSL's 12 and level 1 are correct. **QU2L's 12 is wrong: the second division has eight
clubs.**

## Level 1

- 12 clubs, double round-robin, 22 rounds. The 2026-27 table had nine rounds played by
  early November, consistent with a 22-round season.
- Relegation: 12th goes down directly; 11th plays a play-off for the last top-flight
  place. No split and no title play-off — the champion is the table leader.
- Only one club changes division each way in the ordinary case, plus the play-off club.

## Level 2

- **Eight clubs** in 2026-27 (es and ar Wikipedia both say eight, and the English
  article's 2026-27 club list names eight: Al Bidda, Al Kharaitiyat, Al-Khor,
  Al-Mesaimeer, Al-Shahania, Al-Waab, Al Rayyan Next-Gen, Muaither).
- 14 rounds is derived from eight clubs playing home and away; no season article exists
  to quote a round count.
- Promotion: the champion goes up directly; the runner-up plays the QSL's second-last
  club for a second place. In 2025-26 Lusail won QSL2 and were promoted, replacing Umm
  Salal.
- **Relegation:** the Spanish and Arabic articles say there is none (QSL2 is the bottom
  tier). The English infobox, however, lists relegation to a "Qatar Stars League 3". No
  QSL3 season or club list was found, and the same English article's body says "there is
  no relegation from the second division". Treated as no relegation: `closed_down: true`
  because any third tier is outside our data anyway.
- The 2026-27 field includes **Al Rayyan Next-Gen**, a reserve/development side formed in
  2026 — reserve teams are now part of the second tier.

## Boundary 1-2

| between | up | of which PO | down | of which PO | allocation | selection |
| --- | --- | --- | --- | --- | --- | --- |
| 1-2 | 2 | 1 | 2 | 1 | free | bottom_n |

- Up: QSL2 champion directly, runner-up via the play-off.
- Down: QSL 12th directly, 11th via the same play-off. The play-off is a single match
  (QSL2's runner-up is the home side per the Arabic article); exactly one of {QSL 11th,
  QSL2 runner-up} is in the top flight next season.
- No licence, geography or affiliation gate is described. Qatar's clubs are all in the
  Doha conurbation or within an hour of it, so geography is not a factor.

## Decisions

1. **`QU2L` size 8**, overriding our 12, with the conflict recorded.
2. **`QSL` `format.rounds: 22`**, `QU2L` `rounds: 14` — both derived from club counts
   (the 2026-27 QSL table is consistent; the QSL2 figure is arithmetic).
3. **`allocation: "free"`, `selection: "bottom_n"`** for the one boundary.
4. **`QU2L` `closed_down: true`**, because no third tier is modelled and the sources
   disagree about whether one exists at all.

## Oddities

- The English QSL2 article's promotion rule is outdated: it says the QSL2 champion plays
  the **10th**-placed QSL club (the 2022-23 rule), while the 2026-27 QSL table marks the
  **11th** and the Arabic article describes the runner-up v second-last play-off. The
  current shape is 1st up directly + 2nd in the play-off.
- QSL2 has only eight clubs, so 14 rounds is a very short season; a single injury crisis
  or a withdrawal (as happened to several Qatari clubs historically) distorts it badly.
- A reserve side in the second tier is new for 2026-27 and may change the promotion maths
  if reserve teams are barred from the top flight (not documented).

## Confidence

**Medium.** QSL (12 clubs, 22 rounds, 1 + 1 relegation) is solid. QSL2's eight clubs are
confirmed by three language editions, but the second tier's round count, promotion
mechanics and whether a third tier exists are all either derived or contradicted between
sources.
