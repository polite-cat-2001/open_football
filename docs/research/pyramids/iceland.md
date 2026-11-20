# Iceland — football pyramid, 2026 (career year 2026-27)

Iceland plays **calendar-year seasons** (May–October 2026), so the 2026 season is the one that
overlaps the 2026-27 career year; `"season": "2026-27"` is only the dataset label.

The system is unusually tidy: **every men's level has 12 clubs and exactly two move each way at each
boundary**. The only split is in the top flight.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | IS1 | Besta deild | 12 | double RR, then 6/6 split | 22 + 5 | — (closed) | 2 |
| 2 | IS2 | Lengjudeild (1. deild) | 12 | double round robin | 22 | 1 direct + 1 play-off | 2 |
| 3 | ISL3 | 2. deild | 12 | double round robin | 22 | 2 direct | 2 (to 3. deild) |

## Level 1 — Besta deild

- 12 clubs, 22 rounds, then a 6/6 split: each team meets its group rivals once more (a third meeting
  overall), five more games, 27 in total. Points carried in full.
- The championship group decides the title; the bottom two of the relegation group go down directly
  (Vestri and Afturelding in 2025). No relegation play-off.
- 2026 promoted clubs: Þór Akureyri (champions) and Keflavík (play-off winners).

## Level 2 — Lengjudeild (1. deild karla)

- 12 clubs, plain 22-round double round robin, no split.
- **Promotion:** champion up directly; **2nd to 5th play a knockout for the second place** — that is
  where Keflavík came from in 2025. It is the only promotion play-off in the Icelandic pyramid.
- **Relegation:** bottom two down to 2. deild.

## Level 3 — 2. deild

- 12 clubs, 22 rounds, no split.
- Top two promoted to 1. deild; bottom two relegated to 3. deild (level 4, not in our rows).
- Unlike 1. deild, no promotion play-off is documented at this boundary — both places are direct.

## Check against our database

| id | our name | our level | real level | our size | real size 2026 | verdict |
|---|---|---|---|---|---|---|
| IS1 | Besta deild | 1 | 1 | 12 | 12 | correct |
| IS2 | Lengjudeild | 2 | 2 | 12 | 12 | correct (sponsor name of 1. deild karla) |
| ISL3 | 2. deild | 3 | 3 | 12 | 12 | correct |

No conflicts. Only nuance: Besta deild is the sponsor name of the top division (Pepsi-deild before),
and Lengjudeild is the sponsor name of 1. deild — the ids use the sponsor names, which is what a
player sees.

## Caveats

- The top-flight split is 6/6 with five extra games, not a full second round robin; a model that
  assumes 10 extra games overstates the season by five matches.
- Two clubs per boundary is the rule, but a club without a licence can refuse promotion, which
  effectively reduces the intake in a given year.
- 3. deild and below (4. deild in groups with a knockout, 5. deild) are not in our rows; 2. deild's
  relegation therefore has nowhere to go in the dataset.

## Sources

- https://en.wikipedia.org/wiki/2026_Besta_deild_karla
- https://en.wikipedia.org/wiki/Besta_deild_karla
- https://en.wikipedia.org/wiki/1._deild_karla
- https://is.wikipedia.org/wiki/1._deild_karla_%C3%AD_knattspyrnu
- https://en.wikipedia.org/wiki/2._deild_karla
- https://en.wikipedia.org/wiki/Icelandic_football_league_system
