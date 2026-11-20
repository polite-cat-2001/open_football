# Georgia — football pyramid, 2026 (career year 2026-27)

Georgia plays a **calendar-year season** (February–December 2026), so the 2026 season is the one
that overlaps the 2026-27 career year; `"season": "2026-27"` in the JSON is only the dataset label.
Cups and UEFA competitions are out of scope.

Both of our rows are 10-club divisions that meet each other **four times** (36 matches) — there is
no split and no group phase anywhere in the Georgian top two.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | GE1N | Erovnuli Liga (Crystalbet) | 10 | quadruple round robin | 36 | — (closed) | 1 direct + 2 play-off |
| 2 | GEO2 | Erovnuli Liga 2 | 10 | quadruple round robin | 36 | 1 direct + 2 play-off | 1 direct (to Liga 3) |

## Level 1 — Erovnuli Liga

- 10 clubs, 36 rounds: each team plays every other home and away **twice**.
- **Relegation:** 10th is relegated directly. 9th plays the Liga 2 **runner-up** and 8th plays the
  Liga 2 **3rd**, both over two legs. So three places are at stake and two of them are contested.
- 2025 outcome (the intake into the 2026 season): Rustavi up as champions, Spaeri and Meshakhte up
  through the play-offs after beating Gareji and Telavi, Kolkheti down directly. Iberia 1999 entered
  2026 as defending champions.

## Level 2 — Erovnuli Liga 2

- 10 clubs, 36 rounds, same shape as the top flight.
- **Promotion:** champion up directly (Rustavi in 2026). Runner-up and 3rd go into the two-legged
  play-offs against the 9th and 8th of the Erovnuli Liga.
- **Relegation:** only the last-placed club is relegated, to Liga 3 (not in our rows). There is no
  play-out at the bottom.
- Note the asymmetry: three clubs can leave level 2 (one up direct, two via play-off) but only one
  comes down from level 1 directly, because the play-off losers stay where they are.

## Check against our database

| id | our name | our level | real level | our size | real size 2026 | verdict |
|---|---|---|---|---|---|---|
| GE1N | Erovnuli Liga | 1 | 1 | 10 | 10 | correct |
| GEO2 | Erovnuli Liga 2 | 2 | 2 | 10 | 10 | correct |

No numeric conflicts. The only thing our rows cannot express is that Liga 3 exists below Liga 2.

## Caveats

- The 36-match calendar means the season is effectively four round robins; a sim that assumes a
  double round robin will produce a table half the real length.
- Georgian clubs are heavily concentrated in Tbilisi; travel is not a factor in any split, because
  there are no regional groups at these levels.
- Reserve sides (e.g. Iberia 1999-2) play in Liga 3, not in the top two, so they do not disturb the
  promotion path modelled here.

## Sources

- https://en.wikipedia.org/wiki/2026_Erovnuli_Liga
- https://en.wikipedia.org/wiki/Erovnuli_Liga
- https://en.wikipedia.org/wiki/Erovnuli_Liga_2
