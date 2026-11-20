# Indonesia — football pyramid, 2026-27

Four levels: Super League (1), Championship (2), Liga Nusantara (3), Liga 4 (4, not in our rows).
All three of our rows were renamed in the last two years — Liga 1 is now **Super League**, Liga 2 is
**Championship** (Kejuaraan), Liga 3 became **Liga Nusantara** in 2024.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | IN1L | Super League | 18 | double round robin | 34 | — (closed) | 3 |
| 2 | ILI2 | Championship Indonesia | 20 | 2 geographical groups of 10, triple RR | 27 | 2 direct + 1 play-off | 2 direct + 1 play-off |
| 3 | IN3L | Liga Nusantara | 24 | group phase (2026-27 draw not published) | — | 2 + 1 play-off | 2 + 1 play-off (to Liga 4) |
| 4 | — | Liga 4 (not modelled) | 64 in the national phase | provincial leagues, then national rounds | — | 6 to Liga Nusantara | — |

## Level 1 — Super League

- 18 clubs, 34 rounds, straight double round robin — no title play-off in the 2026-27 season article
  (2024-25 had a Championship Series, so this has changed more than once).
- **Relegation: three clubs** (PSBS, Semen Padang and Persis Solo went down in 2025-26).
- **Promotion in:** three from the Championship — both group winners plus the runners-up play-off
  winner (Garudayaksa and PSS direct, Isenmulang Kalteng through the play-off in 2026).

## Level 2 — Championship

- **20 clubs in two geographical groups of ten**, each playing a **triple** round robin (27 games).
  Group membership is by geography, so promotion is not a single table.
- **Promotion:** both group winners up directly; the **two runners-up play off** for a third place.
- **Relegation:** both 10th-placed clubs down directly; the **two 9th-placed clubs play off** and the
  loser goes down too — three down in total, one of them by play-off.
- VAR has been used in the final and the promotion play-off since 2024-25 and across the league since
  2025-26.

## Level 3 — Liga Nusantara

- **24 clubs** in 2026-27 (15 retained, 3 down from the Championship, 6 up from Liga 4). The season
  started on 13 November 2026 and its group structure was not published in the sources used, so the
  JSON records the group format with a null group count instead of guessing.
- Three clubs go up to the Championship (two direct plus a play-off winner, as in 2025-26) and three
  go down to Liga 4 (two direct plus a play-off loser).
- Semi-professional; operated by the league body, not the provinces, since 2024-25.

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| IN1L | Super League | 1 | 1 | 18 | 18 | correct (current name) |
| ILI2 | Championship Indonesia | 2 | 2 | 20 | 20 | correct (current name; official "Championship") |
| IN3L | Liga Nusantara | 3 | 3 | 24 | 24 | correct |

No numeric conflicts. The gap is Liga 4 (level 4), which feeds six clubs into Liga Nusantara every
season and is therefore the real floor of the pyramid.

## Caveats

- The Championship's two groups are geographical, and Indonesia's geography is extreme: a group can
  span three time zones. Any "free" allocation model for its promotion places is wrong.
- Liga Nusantara's shape has changed every season since 2024 (2 groups of 8, then 24 clubs in
  2026-27); treat its format as season data, not structure.
- Club identity is fluid: relocations and renames are ratified at the PSSI congress (Adhyaksa Banten
  became Isenmulang Kalteng; Malut United became Java United for 2026-27).

## Sources

- https://en.wikipedia.org/wiki/2026%E2%80%9327_Super_League_(Indonesia)
- https://en.wikipedia.org/wiki/Super_League_(Indonesia)
- https://en.wikipedia.org/wiki/Championship_(Indonesia)
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Liga_Nusantara
- https://en.wikipedia.org/wiki/Liga_Nusantara
- https://en.wikipedia.org/wiki/Indonesian_football_league_system
- https://en.wikipedia.org/wiki/Liga_4_(Indonesia)
