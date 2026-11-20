# Iran — football pyramid, 2026-27

Two national single tables and one genuinely regional third tier. The Pro League **expanded from 16
to 18 clubs for 2026-27**, which is why one club went down and three came up last season.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | IRN1 | Persian Gulf Pro League | 18 | double round robin | 34 | — (closed) | 2 direct + 1 play-off |
| 2 | IRN2 | Azadegan League | 16 | double round robin | 30 | 2 direct + 1 play-off | 3 (to League 2) |
| 3 | IRN3 | League 2 | 28 | **two groups of 14** + final + play-off | 26 | 2 + 1 play-off | 4 (2 per group) |

## Level 1 — Persian Gulf Pro League

- 18 clubs, 34 rounds. First season at 18 since the league shrank to 16 in 2023-24.
- **Relegation:** two clubs directly plus the **14th-placed club in a two-legged tie against the
  Azadegan 3rd** — three places, one of them contested. That is the normal 18-club shape; 2025-26 is
  not a guide because the league was expanding: only Mes Rafsanjan went down, and only through the
  play-off, while three clubs came up to take the league from 16 to 18.
- The 2026-27 table legend marks 15th–18th as relegation, i.e. four places, which cannot be squared
  with a three-club Azadegan intake; that contradiction is recorded in `conflicts` and the three-place
  model is the one used.

## Level 2 — Azadegan League

- 16 clubs, 30 rounds (the 2026-27 field is 12 survivors + 1 relegated from the Pro League + 3
  promoted from League 2).
- **Promotion:** top two up directly; 3rd into the two-legged tie with the Pro League 14th.
- **Relegation:** bottom three down to League 2 (2025-26: Shahrdari Nowshahr, Navad Urmia, Damash
  Gilan).

## Level 3 — League 2

This is the one level where "28 clubs" is misleading: it is **two regional groups of 14**, not a
28-club league.

- 26 rounds per group (double round robin inside the group); clubs only meet clubs from their own
  region, so the two tables are separate competitions.
- **Promotion:** the two group winners meet in a **final** that decides the League 2 title, and both
  are promoted; the **two group runners-up play off** for a third promotion place. The 2026 Azadegan
  intake names exactly those three: Foolad Novin Khuzestan (champions), Naft Masjed Soleyman
  (runners-up of the final) and Shahin Bandar Ameri (play-off winners).
- **Relegation:** the bottom two of **each** group (four clubs) go down to League 3 (level 4, not in
  our rows).
- The older description of this league ("top two in each group are automatically promoted" — four
  clubs) is out of date; the current intake is three.

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| IRN1 | Persian Gulf Pro League | 1 | 1 | 18 | 18 | correct (18 only from 2026-27; it was 16 before) |
| IRN2 | Azadegan League | 2 | 2 | 16 | 16 | correct |
| IRN3 | League 2 | 3 | 3 | 28 | 28 | correct, but the 28 is two 14-club groups, not one table |

## Caveats

- The Pro League's size is mid-transition: 16 clubs until 2025-26, 18 in 2026-27. Hardcoding 18 will
  break if the league shrinks back.
- League 2 cannot be simulated as a single table: geography is the competition, and the promotion
  places are decided by a final and a runners-up play-off rather than by a combined table.
- Iranian second-tier clubs are frequently refused promotion for licensing or financial reasons, so
  the Azadegan intake does not always match the table.

## Sources

- https://en.wikipedia.org/wiki/2026%E2%80%9327_Persian_Gulf_Pro_League
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Azadegan_League
- https://en.wikipedia.org/wiki/2025%E2%80%9326_Azadegan_League
- https://en.wikipedia.org/wiki/Iran_Football%27s_2nd_Division
