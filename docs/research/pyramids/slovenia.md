# Slovenia — football pyramid, 2026-27

Two small professional levels and a U19 league. The PrvaLiga is a **10-club quadruple round robin**
(36 matches: every pair meets twice at home and twice away). The 2. SNL is a **16-club double round
robin** (30 matches).

The boundary is **2 up / 2 down with one shared tie**: the 2. SNL champion is promoted, the PrvaLiga
bottom club is relegated, and the PrvaLiga 9th plays the 2. SNL runner-up over two legs for the last
place. That tie decided 2026-27's composition (Nafta 1903 beat Primorje 1-0 on aggregate).

Our third row, **SL19**, is the U19 league ("EON NextGen Liga"), not a senior tier.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | SL1 | Prva liga Telemach | 10 | single table, 4 meetings | 36 | — (closed) | 1 direct + 1 play-off |
| 2 | SL2 | 2. SNL (Druga liga) | 16 | single table, double round robin | 30 | 1 direct + 1 play-off | 2 direct |
| 99 | SL19 | EON NextGen Liga (U19) | 16 | youth championship | n/a | — (closed) | — (closed) |

Level 3 (3. SNL, regional groups) is not in our dataset, so the 2. SNL is closed downward here.

## Level 1 — Prva liga Telemach

- 10 clubs, 36 rounds (four meetings per pair: 180 matches). 2026-27 began 17 July 2026, ends 22 May
  2027.
- 10th is relegated directly; **9th plays the 2. SNL runner-up over two legs**. 2026-27 lineup:
  Brinje Grosuplje came up as 2. SNL champions, Nafta 1903 won the play-off and returned; Domžale
  folded its senior team mid-2025-26.
- No split, no championship play-off: the table decides the title.

## Level 2 — 2. SNL

- 16 clubs, 30 rounds, double round robin (the 2017 format; the league was 10 clubs playing a triple
  round robin from 2005 to 2017).
- Champion promoted directly; 2nd enters the two-legged play-off against the PrvaLiga 9th.
- Bottom two relegated to the 3. SNL (level 3, regional, not modelled).

## Level 99 — EON NextGen Liga (Slovenian Junior League)

- The top **under-19** league, one national division of **16** youth sides of Slovenian clubs
  (2026-27: Aluminij, Beltinci, Bravo, Brežice, Brinje, Celje, Fužinar, Ilirija, Jadran Dekani,
  Koper, Maribor, Mura, Olimpija, Radomlje, Rudar Velenje, Triglav).
- Youth competition, not a pyramid tier: no promotion into the PrvaLiga, nothing below. Closed both
  ways.

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| SL1 | Prva Liga | 1 | 1 | 10 | 10 | correct |
| SL2 | Druga Liga | 2 | 2 | 16 | 16 | correct |
| SL19 | NextGen Liga | 99 | youth (U19) | 16 | 16 | correct as a t99 marker, size matches |

All three rows are right. The sponsored names are Prva liga Telemach and EON NextGen Liga.

## Caveats

- 36 rounds at level 1 is unusual and easy to get wrong: it is four meetings, not two or three.
- Promotion from the 2. SNL is subject to licensing; a champion without a licence does not go up.
- The 3. SNL is regional (four groups in recent seasons, variable), so any "level 3" shape below the
  2. SNL should not be hardcoded.
- Youth league is closed and must never be used as a relegation destination.

## Sources

- https://en.wikipedia.org/wiki/2026%E2%80%9327_Slovenian_PrvaLiga
- https://en.wikipedia.org/wiki/Slovenian_Second_League
- https://en.wikipedia.org/wiki/Slovenian_Junior_League
