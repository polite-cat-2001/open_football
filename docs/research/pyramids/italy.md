# Italy — football pyramid, 2026-27

Season: **2026-27** (Serie A 22 Aug 2026 – 30 May 2027; Serie B 21 Aug 2026 – 14 May 2027;
Serie C 21 Aug 2026 – 25 Apr 2027). Cups and UEFA competitions are out of scope.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | IT1 | Serie A | 20 | single round robin, asymmetric calendar | 38 | — (closed) | 3 direct |
| 2 | IT2 | Serie B | 20 | single round robin, asymmetric calendar | 38 | 2 direct + 1 play-off | 3 direct + 1 play-out |
| 3 | IT3A/B/C | Serie C, 3 geographical groups | 20 + 20 + 20 = 60 | 3 groups, double round robin | 38 | 3 group winners + 1 national play-off | 3 direct + 6 play-out (9 total) |
| 4 | — | Serie D (not modelled) | 9 groups | 9 groups | — | 9 group winners | 9 from Serie C |

All four levels are fully open in both directions: no `closed_up` / `closed_down` anywhere except
the top of Serie A (nothing above it domestically).

## Level 1 — Serie A

- 20 clubs, 38 matches, one group, asymmetric return calendar (the second half does not repeat the
  first half's order). Two midweek rounds.
- Bottom 3 (18th–20th) are relegated directly. There is **no** relegation play-off in Serie A.
- Confirmed by the 2026-27 season: Cremonese, Verona and Pisa came down from 2025-26, and the
  2026-27 table marks places 18–20 as relegation.

## Level 2 — Serie B

- 20 clubs, 38 matches.
- **Promotion:** top 2 direct. Places 3–8 enter the promotion play-off. Exception: the 3rd-placed
  club is promoted directly, without play-offs, if it finishes **at least 15 points** clear of 4th.
- Play-off bracket (as played):
  - preliminary round, single leg at the better-placed club: 5th v 8th and 6th v 7th; level after
    90' → extra time, then the better-placed club advances;
  - semi-finals, two legs: 3rd v winner(6/7) and 4th v winner(5/8); level on aggregate → the
    better-placed club advances;
  - final, two legs; level on aggregate → the better-placed club is promoted (extra time/penalties
    only if the two clubs finished the regular season level on points).
  - No away-goals rule.
- **Relegation:** 18th, 19th and 20th go down directly. 16th v 17th play a two-legged play-out
  (16th hosts the second leg); level on aggregate → the 17th-placed club is relegated. The play-out
  is **not played** if the 17th-placed club finishes 5 or more points behind the 16th — then the
  17th goes down directly.
- Net: 3 up, 4 down.

## Level 3 — Serie C

One league of 60 clubs split into three geographical groups of 20 (A = north, B = centre,
C = south), each playing a 38-match double round robin. The group composition is decided by the
Serie C league committee in July–August, not fixed by regulation.

### Promotion: 4 clubs

- The winner of each group is promoted directly (**3**).
- The winner of the national play-off is the **4th** promoted club.
- The play-off field is 27 clubs (2nd–10th of each group) plus the Coppa Italia Serie C winner,
  with substitution rules if the cup winner is already qualified or ineligible (slot cascades to
  the beaten finalist, then down the cup winner's group table as far as 11th). Three phases:
  1. **group phase** — 4th–10th of each group, single leg at the better-placed club: 5v10, 6v9, 7v8,
     then the three winners plus the 4th-placed club play a single-leg round; level after 90' → the
     better-placed club advances.
  2. **national phase** — two legs. First round: the 6 group-phase winners + the 3 third-placed
     clubs + the cup winner (10 clubs, 5 ties, the 3rd-placed clubs and cup winner seeded).
     Second round: the 5 winners + the 3 second-placed clubs (8 clubs, 4 ties). Seeds host the
     second leg; level on aggregate → better-placed/seed advances.
  3. **Final Four** — four survivors, drawn freely; semi-finals and final over two legs, with
     extra time and penalties if still level. The final winner is promoted.

### Relegation: 9 clubs

- Last in each group (20th) is relegated directly (**3**).
- Play-outs, two legs, in each group: 16th v 19th and 17th v 18th (the worse-placed club hosts the
  first leg). The two losers go down (**6**), so **9** in total.
- A play-out is skipped if the gap between the two clubs is **more than 8 points**; the worse-placed
  club is then relegated directly.

### How the four Serie B relegated clubs are distributed

There is no fixed quota per group. The four clubs are assigned to A/B/C **by geography**, and the
split changes every summer. In 2026-27 it landed:

| Club (relegated from Serie B) | Serie C group |
|---|---|
| Reggiana | B |
| Spezia | B |
| Pescara | B |
| Bari | C |

→ Group A 0, Group B 3, Group C 1. A naive "one or two per group" model would be wrong; the
assignment is a placement decision, not a sporting allocation.

## Level 4 (outside our DB) — Serie D

Serie D has nine interregional groups (A–I); their nine winners are the nine clubs promoted to
Serie C, and Serie C's nine relegated clubs enter Serie D. In 2026-27 the nine winners were Vado,
Folgore Caratese, Treviso, Desenzano, Grosseto, Ostia Mare, Scafatese, Barletta and Savoia, placed
3 in each Serie C group (A: Desenzano, Folgore Caratese, Treviso; B: Grosseto, Ostia Mare, Vado;
C: Barletta, Savoia, Scafatese). This level is **not** in our database; the JSON therefore stops at
the 2↔3 boundary and this section is context only.

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| IT1 | Serie A | 1 | 1 | 20 | 20 | correct |
| IT2 | Serie B | 2 | 2 | 20 | 20 | correct |
| IT3A | Serie C Girone A | 3 | 3 | 20 | 20 | correct |
| IT3B | Serie C Girone B | 3 | 3 | 20 | 20 | correct |
| IT3C | Serie C Girone C | 3 | 3 | 20 | 20 | correct |

No factual conflicts. One modelling caveat: IT3A/B/C are **groups of one 60-club competition**, not
three separate leagues — the promotion play-off and the relegation play-outs are competition-wide,
and clubs move between groups each summer by geographical placement.

## Caveats

- Group composition for 2026-27 is formalised in July–August; our rows assume the usual 20/20/20.
- Promotion and relegation counts are nominal: the Serie B play-off place disappears if 3rd is 15+
  points clear, and the Serie B play-out place disappears if 17th is 5+ points adrift. Serie C's
  play-outs can also be skipped on the 8-point rule.
- Serie C relegation is 9, not 3 — a career sim that only reads "last place goes down" will leave
  six extra clubs in the third tier every season.

## Sources

- https://it.wikipedia.org/wiki/Serie_A_2026-2027
- https://it.wikipedia.org/wiki/Serie_B_2026-2027
- https://it.wikipedia.org/wiki/Serie_C_2026-2027
- https://it.wikipedia.org/wiki/Serie_B (play-off/play-out format)
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Serie_A
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Serie_B
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Serie_C

## Added by the merge

- ITJ7 Campionato Under 18: level 99, 20 clubs, closed both ways — not covered by the research pass.
- IJ1 Primavera 1: level 99, 20 clubs, closed both ways — not covered by the research pass.
