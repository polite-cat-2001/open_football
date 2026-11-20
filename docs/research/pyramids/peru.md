# Peru — football pyramid 2026

Research for the career simulation. Scope: the three levels in our database — Liga 1
(our row is the **Clausura**), Liga 2 and Liga 3. The Copa Perú and the regional leagues
below Liga 3 are outside it. Cups and CONMEBOL places are out of scope.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026_Liga_1_(Peru) | 2026 Liga 1: 18 clubs, Apertura and Clausura of 17 rounds each, aggregate table, the play-off bracket, the 2026 team changes (2 up from Liga 2, 2 down + 1 disqualified) |
| https://en.wikipedia.org/wiki/2026_Liga_2_(Peru) | 2026 Liga 2: 18 clubs in two regional groups of 9, championship groups, the promotion play-offs, the two relegation groups |
| https://en.wikipedia.org/wiki/2026_Liga_3_(Peru) | 2026 Liga 3: the 37-club team list, four regional groups, the four second-stage groups, the knockout stage, the 2025/26 promotion and relegation changes |

All three are current 2026 seasons, so the sizes are read from team lists and tables
rather than from infoboxes.

## Leagues

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| TDeC | Liga 1 Clausura | 1 | 18 | 17 rounds per tournament + season play-off | — (top) | 2 |
| PER2 | Liga 2 | 2 | 18 | 2 regional groups of 9 (18 rounds), then 3 groups of 4 | 2 | 2 |
| PLI3 | Liga 3 | 3 | 37 | 4 regional groups, then 4 groups of 4, then knockout | 2 | to Copa Perú (not modelled) |

Our sizes (18 / 18 / 37) and levels are all correct.

## Liga 1 (our row = Clausura)

- 18 clubs. The season is two tournaments, **Apertura** (January-May) and **Clausura**
  (July-November), each a **single round-robin of 17 rounds**. Our row is the Clausura.
- Both feed a season **aggregate table** (Apertura + Clausura). The season champion is
  decided by a **four-team play-off**: the Apertura winner, the Clausura winner and the
  two best aggregate-table clubs not already qualified. Semi-finals and final are two
  legs. If one club wins both tournaments (or tops the aggregate as well) it takes a bye,
  which is what happened in 2026: Alianza Lima won the Apertura and led the aggregate,
  so only one semi-final was played.
- The Clausura table alone does **not** crown a champion. Encoding the row as "17 rounds,
  champion on points" would be wrong.
- Relegation: the bottom two of the aggregate table go down (17th and 18th in 2025).
  There is no relegation play-off; a club can also lose its place administratively
  (Binacional were disqualified in 2025), which is not a sporting route.

## Liga 2 — 18 clubs, three stages

1. **Regional stage:** two geographical groups of nine, double round-robin, **18
   matchdays**.
2. **Championship groups:** the top six of each group (12 clubs) go into three groups of
   four, six matchdays, with bonus points (2 for the two group winners and the best
   runner-up, 1 for the other runner-up and the third-placed clubs).
3. **Promotion play-offs:** semi-finals over two legs between the three group winners and
   the best runner-up; the final winners play for the title and the losers go to a
   repechaje; the champion goes up and the winner of a single **runner-up match** (final
   loser v repechaje winner) takes the second promotion place.
4. **Relegation groups:** the six clubs that missed the top six are split into two
   triangular groups of three (four matchdays); the bottom club of each is relegated.

So Liga 2 promotes two and relegates two, but neither place is decided by a plain league
table — both come out of play-off/relegation groups.

## Liga 3 — 37 clubs

This is not a normal division and must not be simulated as a 37-team table.

- **37 clubs**, including eight reserve sides of Liga 1/2 clubs ("II" teams: Alianza Lima
  II, ADT II, Cienciano II, Melgar II, Sport Boys II, Sporting Cristal II, Universitario
  II, Universidad César Vallejo II). Reserve sides are not excluded from promotion — Sport
  Huancayo II went up for 2026 — so they are ordinary members for our purposes.
- **Torneo Regional:** four geographical groups (the group sizes are uneven: 8-10 clubs
  each), each played as a round-robin; the qualifiers move to a second stage.
- **Second stage:** four groups of four.
- **Knockout:** quarter-finals, semi-finals and final over two legs; the two finalists are
  promoted to Liga 2.
- Relegation is to the Copa Perú / departmental leagues, which we do not model, so Liga 3
  is closed downwards in our data.
- Entry is not purely sporting either: the 2026 field includes clubs promoted from the
  Copa Perú and from the under-18 Torneo Juvenil, and clubs were expelled or withdrew
  mid-season (Deportivo Municipal disqualified, Corazón de León retired after two
  walkovers, Defensor José María Arguedas excluded). This is the messiest competition in
  the set.

## Boundaries

| between | up | of which PO | down | of which PO | allocation | selection |
| --- | --- | --- | --- | --- | --- | --- |
| 1-2 | 2 | 2 | 2 | 0 | free | bottom_n |
| 2-3 | 2 | 2 | 2 | 0 | free | other |

- **1-2:** both promotion places come from the Liga 2 play-offs (title final and the
  runner-up match), hence `up_playoff: 2`. Liga 1 relegation is the bottom two of the
  aggregate table, `bottom_n`.
- **2-3:** both Liga 3 promotion places are the two finalists, `up_playoff: 2`. Liga 2
  relegation is "bottom of each triangular relegation group", which is a table outcome
  inside a group, not a plain bottom-n of the division — hence `other`.

## Decisions

1. **`TDeC` as `apertura_clausura`, `rounds: 17`**, with the play-off in `playoff`
   (`kind: "title"`, two legs) because the season champion comes from it, not from the
   Clausura table.
2. **`PER2` as `groups`, `groups: 2`, `rounds: 18`**, stages listed in the format note;
   the championship and relegation groups are described there rather than modelled as
   separate competitions.
3. **`PLI3` as `groups`, `groups: 4`, `rounds: null`** — the regional groups have unequal
   sizes, so there is no single round count.
4. **`selection: "other"` on the 2-3 boundary**, because relegation is decided by group
   position inside a play-out, not by a division-wide bottom-n.

## Oddities

- Liga 1's play-off can shrink: in 2026 the Apertura winner also led the aggregate and
  the semi-finals became a single tie. Three-team and two-team variants have existed.
- Liga 3 is effectively two competitions bolted together (a regional league and a national
  knockout) and its field changes shape every season through Copa Perú promotions,
  withdrawals, mergers and disqualifications. Any seeded 37-club table will be wrong
  before the season starts.
- Reserve teams ("II") are a large part of Liga 3 (8 of 37 this season) and one of them
  was promoted for 2026, so reserve status is not a promotion bar.

## Confidence

**High** for Liga 1 and Liga 2 (current season articles with tables and explicit format
sections). **Medium** for Liga 3: the 37 clubs are counted from the team list, the four
regional groups and the 8-team knockout are explicit, but the group sizes, the exact
number of qualifiers per group and the promotion count are read from the stage tables
rather than stated in a regulations document.
