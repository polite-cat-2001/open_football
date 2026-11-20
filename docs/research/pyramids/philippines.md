# Philippines — football pyramid 2026-27

Research for the career simulation. Scope: level 1 only, the Philippines Football League
(PFL). Our list has a single Philippine row, so the league is closed in both directions in
our data — which happens to be true in reality as well.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Philippines_Football_League | 2026-27: ten teams, "double round robin consisting of 20 games", the league table and its Championship/Classification labels, who joined and left |
| https://en.wikipedia.org/wiki/2025%E2%80%9326_Philippines_Football_League | the previous season: eleven teams, title decided on the single table on the final matchday |

Only English Wikipedia was used; no PFF competition regulations could be read.

## League

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| PFL1 | Philippines Football League | 1 | 10 | 20 rounds (double round-robin) | — (top) | — |

Our 10 clubs and level 1 are correct.

- Ten clubs, double round-robin: **20 matches each**, no split, no groups.
- 2025-26 had eleven clubs and was decided on the single table (Manila Digger won by two
  points on the final matchday), with no play-off.
- Membership is by invitation/licence, not by promotion: One Taguig (2nd in 2025-26) and
  Don Bosco Garelli dropped out for 2026-27 and Azkals Development Club rejoined. Clubs
  come and go between seasons without any sporting route, so a career sim cannot treat
  the ten as a closed pool that only changes through results.

## The "round" labels

The 2026-27 table marks places 1-5 as **Championship round** and 6-10 as **Classification
round**, and its positions-by-round grid runs to 20. No source describes a second phase,
and last season's title was decided on the single table. Either a split was planned and
not documented, or the labels are editorial. This is recorded as an unresolved conflict;
the encoded format is the single 20-round table that the season article states in words.

## Promotion and relegation

- There is none. The PFL has no tier below it in our data and no relegation place; clubs
  leave by withdrawing or failing the licence, and new clubs join by application.
- `closed_up: true`, `closed_down: true`, no boundaries.

## Decisions

1. **`format.kind: "single"`, `rounds: 20`** — the only format stated in words.
2. **`size: 10`**, from the team list and the season article.
3. **`playoff: null`.**
4. **Conflict recorded** for the Championship/Classification labels rather than encoding
   a split nobody describes.

## Oddities

- The league has changed size almost every season (11 in 2025-26, 10 in 2026-27), and the
  changes are administrative, not sporting.
- The 2026-27 season started a day late because of monsoon rain, and the opening fixture
  was postponed; the table was uneven for weeks. Cosmetic, but it shows how thin the
  competition's operational layer is.
- Some clubs are armed-forces or university sides (Philippine Army, Mendiola 1991) and
  one is a development team (Azkals Development Club); "club" here covers very different
  entities.

## Confidence

**Medium-high** for size, level and the 20-round double round-robin (stated in words).
**Low** for the second-phase question: the table's own labels imply a split that no text
supports, and the PFL rulebook was not readable.
