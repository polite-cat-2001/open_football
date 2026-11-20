# Netherlands — football pyramid, 2026-27

Four levels, all 18–20 clubs, all August–May. Two things make the Dutch pyramid different from every
other country here: promotion into the Eerste Divisie is decided partly by **period titles**, and the
Eerste Divisie is **closed at the bottom**.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | NL1 | Eredivisie | 18 | double round robin | 34 | — (closed) | 2 direct + 1 play-off |
| 2 | NL2 | Keuken Kampioen Divisie (Eerste Divisie) | 20 | double round robin | 38 | 2 direct + 1 play-off | — (closed) |
| 3 | NTD | Tweede Divisie | 18 | double round robin | 34 | — (closed) | 1 direct + 1-2 play-off |
| 4 | 510 | Derde Divisie A | 18 | double round robin (two parallel divisions) | 34 | 1 direct + 1 play-off | 2+ (to level 5) |
| 5 | — | Vierde Divisie (not modelled) | — | — | — | — | — |

## Level 1 — Eredivisie

- 18 clubs, 34 rounds.
- **17th and 18th relegated directly.** **16th goes into the nacompetitie** with Eerste Divisie clubs.
- 2026-27's shape is normal: 3 up from the Eerste Divisie (ADO, Cambuur, Willem II), 3 down (Volendam,
  NAC, Heracles), 18 clubs again.

## Level 2 — Eerste Divisie

- 20 clubs, 38 rounds.
- **Champion and runner-up promoted directly.**
- **Six more clubs enter the nacompetitie**, alongside the Eredivisie 16th: the four **period champions**
  (best club of each quarter of the season) plus the two best-placed clubs not already qualified. In
  practice that is usually 3rd-8th.
- Two pools, semi-finals, finals; one Eredivisie place at stake.
- **Reserve teams (Jong Ajax, Jong PSV, Jong AZ, Jong Utrecht) can win the league but cannot be
  promoted** — the place passes to the next eligible club. In 2026-27 four of the 20 are Jong sides.
- **No relegation.** The KNVB suspended promotion/relegation with the Tweede Divisie in June 2022 for
  5-10 seasons because amateur clubs could not afford professional football. The only exchange left is
  a reserve-team swap.

## Level 3 — Tweede Divisie

- 18 clubs, 34 rounds, two reserve teams allowed (Jong Sparta, Jong Almere City in 2025-26).
- **Relegation counted on first teams only**: the 16th first team goes down direct; the 14th and 15th
  first teams play off with the Derde Divisie period champions for one further place.
- **Reserve teams have their own ladder**: 17th/18th reserve → relegated to the Under-21 competition;
  10th-16th reserve → a play-off against the U21 champion; top nine reserve → nothing.
- **No promotion** for first teams (see above). Quick Boys won the 2025-26 title as amateurs and stayed.
- So `closed_up` is true at level 3 while `closed_down` is false — the opposite of most pyramids.

## Level 4 — Derde Divisie A (id `510`)

- Two parallel divisions (A and B), 18 clubs each, 34 rounds. We carry only A.
- **Both division winners are promoted mandatorily** to the Tweede Divisie.
- Bottom clubs (plus play-off losers) go down to the Vierde Divisie, which we do not model.

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| NL1 | Eredivisie | 1 | 1 | 18 | 18 | correct |
| NL2 | Keuken Kampioen Divisie | 2 | 2 | 20 | 20 | correct (sponsor name for Eerste Divisie) |
| NTD | Tweede Divisie | 3 | 3 | 18 | 18 | correct |
| 510 | Derde Divisie A | 4 | 4 | 18 | 18 | correct; id is opaque |

Only oddity: the id `510` for Derde Divisie A. Everything else matches.

## Caveats

- Period titles make the Eerste Divisie play-off field dependent on *when* clubs won their games, not
  just the final table. A sim that picks 3rd-8th will usually be right and occasionally wrong.
- Because level 2→3 is closed, NTD clubs cannot climb and Eerste Divisie clubs cannot fall: the Dutch
  pyramid has a hard floor at level 2. Model that deliberately or the sim will invent promotions.

## Sources

- https://en.wikipedia.org/wiki/2026%E2%80%9327_Eredivisie
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Eerste_Divisie
- https://en.wikipedia.org/wiki/Eerste_Divisie
- https://en.wikipedia.org/wiki/Tweede_Divisie
- https://en.wikipedia.org/wiki/2025%E2%80%9326_Tweede_Divisie
- https://en.wikipedia.org/wiki/Derde_Divisie
