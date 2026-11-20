# Estonia — football pyramid 2026

Scope: levels 1–3 as carried in our database (Meistriliiga, Esiliiga, Esiliiga B). No cups, no
UEFA competitions.
Research date: 2026-11-20. Calendar-year season, March–November; 2026 finished in November.

## Pyramid at a glance

| id | League | Level | Clubs | Rounds per club | Shape |
|----|--------|-------|-------|-----------------|-------|
| EST1 | Meistriliiga (Premium Liiga) | 1 | 10 | 36 | one table, quadruple round-robin |
| EST2 | Esiliiga | 2 | 10 | 36 | one table, quadruple round-robin |
| EST3 | Esiliiga B | 3 | 10 | 36 | one table, quadruple round-robin |

All three rows are correct: **10 clubs each**, levels 1–3, 36 matches each.

## Formats

Every level is ten clubs playing each other four times (two at home, two away), 36 matches, no
split. The pyramid is unusually uniform — what differs is only who may go up.

## Boundaries

| between | up | of which PO | down | of which PO | allocation | selection |
|---------|----|-------------|------|-------------|------------|-----------|
| 1–2 | 2 | 1 | 2 | 1 | free | playoff |
| 2–3 | 3 | 1 | 3 | 1 | free | playoff |

**1 ↔ 2**

- Up: Esiliiga champion (licence required, reserve teams ineligible); Esiliiga 2nd plays the
  Meistriliiga 9th over two legs.
- Down: Meistriliiga 10th direct; 9th through that same tie.

**2 ↔ 3**

- Up: Esiliiga B 1st and 2nd direct; 3rd plays the Esiliiga 8th over two legs.
- Down: Esiliiga 10th and 9th direct; 8th through that tie.

The Esiliiga B 9th also plays a play-off against the II liiga winner, but that is below our floor
(level 4, not modelled).

## Reserve teams — the main trap

Esiliiga 2026 includes **Flora U21, Levadia U21, Nõmme Kalju U21 and Nõmme United U21**; Esiliiga
B includes Tallinna Kalev U21, Tammeka U21, Narva Trans U21, Vaprus U21 and FCI Levadia U19.
Reserve sides must play at least one level below the senior team and **cannot be promoted**.
A sim that promotes the top two of the Esiliiga will promote an ineligible club whenever a U21
side finishes there — the place must pass to the next eligible club.

## Oddities

- All three divisions are 10 clubs / 36 games, so a single fixture generator works for the whole
  pyramid; only the movement rules differ.
- The Esiliiga sends three down (two direct + 8th to a play-off) while the Esiliiga B sends three
  up (two direct + 3rd to a play-off). Both directions are 3, but the clubs do not pair one-to-one.
- Promotion to the Meistriliiga is licence-gated; the champion can be refused.

## Sources

- https://en.wikipedia.org/wiki/Meistriliiga — ten clubs, "all teams play each other four times",
  bottom club relegated, second-last in a two-legged play-off with the Esiliiga runner-up
- https://en.wikipedia.org/wiki/Esiliiga — ten clubs, 36 games; reserve teams ineligible for
  promotion; promotion/relegation details (champion + 2nd play-off; bottom two down; 8th v
  Esiliiga B 3rd)
- https://en.wikipedia.org/wiki/Esiliiga_B — ten clubs, four meetings; 1st and 2nd promoted, 3rd
  in a play-off with the Esiliiga 8th; bottom two relegated, 9th in a play-off

## Confidence

**High.** Sizes, round counts and every promotion/relegation route are stated explicitly on the
three league pages, and the reserve-team rule is called out on both lower-league pages.

## Added by the merge

- EE19 U19 Eliitliiga Esiliiga: level 99, 12 clubs, closed both ways — not covered by the research pass.
- ELME U19 Eliitliiga Meistriliiga: level 99, 8 clubs, closed both ways — not covered by the research pass.
