# Sweden — football pyramid, 2026 (career year 2026-27)

Sweden plays **calendar-year seasons**, so the season that overlaps the 2026-27 career year is the
**2026 season** (April to November). The JSON uses `"season": "2026-27"` only as the dataset label;
every competition fact below is the 2026 season, which has just finished (Superettan ended
7 November 2026).

Three levels, all 16 clubs and all 30-round double round robins — the shape is simple, the play-offs
are not. Both boundaries use **two-legged ties** and both are 4-club shuffles:

- Level 1→2: 2 up / 2 down direct, plus the Allsvenskan **14th v the winner of the Superettan
  3rd-v-4th tie** for one more place each way.
- Level 2→3: the two Ettan winners go up directly; **each Ettan runner-up plays one of Superettan's
  13th/14th** over two legs. So 4 up, 4 down, half of them through play-offs.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | SE1 | Allsvenskan | 16 | single table, double round robin | 30 | — (closed) | 2 direct + 1 play-off |
| 2 | SE2 | Superettan | 16 | single table, double round robin | 30 | 2 direct + 1 play-off | 2 direct + 2 play-off |
| 3 | SE3N | Ettan Norra | 16 | single table, double round robin | 30 | 1 direct + 1 play-off | 3 direct (+1 play-off) |
| 3 | SE3S | Ettan Södra | 16 | single table, double round robin | 30 | 1 direct + 1 play-off | 3 direct (+1 play-off) |

Division 2 (level 4) is not in our dataset, so both Ettan divisions are closed downward here.

## Level 1 — Allsvenskan

- 16 clubs, 30 rounds. 2026 began 5 April and ends in November 2026.
- **Relegation:** 15th and 16th go down directly; **14th plays the Superettan play-off winner over
  two legs**. The Superettan side first has to win its own 3rd-v-4th tie.
- 2026 promoted: Västerås SK, Kalmar FF, Örgryte IS; 2025's relegated: Östers IF, IFK Värnamo,
  IFK Norrköping.

## Level 2 — Superettan

- 16 clubs, 30 rounds (3 April - 7 November 2026).
- **Promotion:** top two direct; **3rd hosts 4th over two legs**, and that winner meets the
  Allsvenskan 14th over two legs.
- **Relegation:** 15th and 16th direct; **13th and 14th each play one of the two Ettan runners-up**
  over two legs (two separate ties, not a bracket).

## Level 3 — Ettan Norra / Ettan Södra

- 32 clubs in two geographic divisions of 16, 30 rounds each (April to November).
- Each **winner is promoted directly** (2 up); each **runner-up plays a Superettan 13th/14th** over
  two legs (2 more possible).
- **Relegation:** bottom three in each division go down to Division 2 (6 total); the 13th-placed club
  in each division also plays a two-legged play-off against a Division 2 play-off winner. Division 2
  is not modelled, so this bottom route is described but not recorded as a boundary.

## Check against our database

| id | our name | our level | real level | our size | real size 2026 | verdict |
|---|---|---|---|---|---|---|
| SE1 | Allsvenskan | 1 | 1 | 16 | 16 | correct |
| SE2 | Superettan | 2 | 2 | 16 | 16 | correct |
| SE3N | Ettan Norra | 3 | 3 | 16 | 16 | correct |
| SE3S | Ettan Södra | 3 | 3 | 16 | 16 | correct |

All correct. Sweden is the cleanest size-wise of the countries in this batch.

## Caveats

- The 2026 season is over, so the JSON records the regulatory rules and 2027 compositions are being
  decided by the November play-offs, not by a table alone.
- Reserve/farm teams (e.g. Hammarby TFF, Norrköping's B side historically) can play in Ettan but not
  in Superettan or Allsvenskan; a naive "winner goes up" rule can promote an ineligible side.
- Two separate two-legged relegation ties (13th and 14th v the two Ettan runners-up) are easy to
  flatten into one bracket; they are independent.
- Division 2 is regional (six groups), so nothing below Ettan should be hardcoded.

## Sources

- https://en.wikipedia.org/wiki/2026_Allsvenskan
- https://en.wikipedia.org/wiki/2026_Superettan
- https://en.wikipedia.org/wiki/Ettan_Fotboll
