# Japan — football pyramid 2026-27

Research for the career simulation. Scope: J1, J2, J3 and the Japan Football League as carried in
our database. The regional leagues (level 5) are outside our data. Cups, the J.League Cup and AFC
places are out of scope.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_J1_League | 20 clubs, dates 7 Aug 2026 – 6 Jun 2027, first two-calendar-year season, 3 relegated from 2025 / 3 promoted from J2 |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_J2_League | 20 clubs = 14 + 3 from J1 + 3 from J3; summer-to-spring format |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_J3_League | 20 clubs, promotion rules, "as many as two clubs relegated to the JFL" |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Japan_Football_League | 16 clubs, champion promoted automatically, 2nd in a play-off with J3's 19th, bottom two (15th/16th) relegated directly |
| https://en.wikipedia.org/wiki/J1_100_Year_Vision_League | the one-off 2026 half-season: 20 clubs, East/West groups of ten, no relegation |
| https://en.wikipedia.org/wiki/J1_League | 20 clubs, relegation to J2; the 2026 transition and the special tournament announcement |
| https://en.wikipedia.org/wiki/Japan_Football_League | JFL adopted the J.League calendar from 2026-27; J3/JFL promotion mechanics |
| https://en.wikipedia.org/wiki/2024_J1_League | 20-club format from 2024 and "three clubs were relegated ... without relegation play-offs" |

## Leagues

| id | name | level | size | rounds | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| JAP1 | J1 League | 1 | 20 | 38 | — (top) | 3 |
| JAP2 | J2 League | 2 | 20 | 38 | 3 (2 auto + 1 PO) | 3 |
| JAP3 | J3 League | 3 | 20 | 38 | 3 (2 auto + 1 PO) | 0-2 |
| JFL | Japan Football League | 4 | 16 | 30 | 1 (+1 PO) | 2 (to regional leagues) |

All four sizes match our rows. J1/J2/J3 have been 20 clubs each since 2024; one table, double
round-robin (38 rounds). The JFL is 16 clubs, 30 rounds.

## What "2026-27" means in Japan

This is the important, non-obvious part. Japan did not simply start a new season in 2026; it
**changed its calendar**, and 2026 contains a competition that is not part of the pyramid.

1. **2025 (Feb–Dec 2025)** — the last normal calendar-year J.League season. It decided who is in
   J1/J2/J3 for 2026-27: three relegated from J1 (Yokohama FC, Shonan Bellmare, Albirex Niigata),
   three promoted from J2 (Mito HollyHock, V-Varen Nagasaki, JEF United Chiba via the play-offs).
2. **First half of 2026 (6 Feb – 7 Jun 2026)** — the **J1 100 Year Vision League**, a one-off
   tournament the J.League created to fill the gap: the same 20 J1 clubs, split into East and West
   groups of ten, double round-robin inside the group, a penalty shoot-out for every draw (2 points
   for a shoot-out win, 1 for a loss), then a prize play-off. Its article is explicit: "there was no
   relegation to the J2 League". It has **no effect** on 2026-27 membership.
3. **2026-27 (from Aug 2026)** — the first autumn-spring season. J1 7 Aug 2026 – 6 Jun 2027; J2 and
   J3 from 8 Aug 2026; JFL 29 Aug 2026 – 23 May 2027. Twenty clubs in each J.League division, 16 in
   the JFL.

The JFL followed the J.League: 2025 was its last calendar-year season, and 2026-27 is its first
autumn-spring one.

So a career sim starting in "2026-27" must seed Japan from the **2025** final tables, skip the 100
Year Vision League entirely (it is a friendly-grade prize tournament), and run the new season from
August. Starting Japan in Feb 2026 with a 38-round season would collide with the real 2026-27
calendar.

## Boundaries

| between | up | of which PO | down | of which PO | allocation | selection |
| --- | --- | --- | --- | --- | --- | --- |
| 1-2 | 3 | 1 | 3 | 0 | free | bottom_n |
| 2-3 | 3 | 1 | 3 | 0 | free | bottom_n |
| 3-4 | 1 | 1 | 1 | 1 | by_licence | bottom_n |

- **1-2:** J2 top two automatic, 3rd-6th in a single-leg play-off for the third place. J1's bottom
  three relegated — since 2024 there is **no** J1/J2 promotion-relegation play-off (the pre-2024
  "16th vs J2 play-off winner" tie is gone).
- **2-3:** same shape one level down. The J3 play-off winner needs a J2 licence.
- **3-4:** this is a **licence gate, not a pure table rule**. The JFL champion replaces J3's
  20th-placed club automatically *if it holds a J3 licence*; the JFL runner-up plays the J3
  19th-placed club if it holds one. If neither JFL club is licensed, nothing moves and J3 relegates
  nobody — hence "0-2 down". That is why `allocation` is `by_licence` and both sides carry a
  play-off place.
- **JFL down:** the bottom two (15th and 16th) are relegated **directly** to the regional leagues
  from 2026-27; the old 15th-place play-off against the regional champions was abolished. Level 5 is
  outside our data, so JFL `closed_down` is true.

Arithmetic: 20 - 3 + 3 = 20 at every J.League boundary.

## Decisions

1. **`format.kind: "single"` everywhere.** No split, no groups, no Apertura/Clausura. The J.League
   abandoned multi-stage seasons after 2016.
2. **`rounds: 38` for J1-J3, `30` for the JFL.** 20 and 16 clubs, double round-robin.
3. **`closed_up: true` only for J1; `closed_down: true` only for the JFL**, because the regional
   leagues are not in our data.
4. **`playoff.kind: "promotion"` for J2 and J3**, entries "3rd-6th", one leg. These are real
   promotion play-offs, unlike the JFL's promotion, which is direct for the champion (so `null`).
5. **Not modelled:** the J.League Cup, Emperor's Cup, AFC Champions League Elite/Two places, the
   J.League associate-membership system, and the stadium/licence criteria that decide 3-4.

## Oddities

- **Three competitions in one calendar year (2026).** Any sim that assumes one league season per
  calendar year will mis-handle Japan for exactly one year. The transition is a one-off.
- **The 100 Year Vision League had experimental scoring** (shoot-out after every draw, 2/1 points).
  Do not import it as a league format; it is not part of the pyramid.
- **Promotion can be refused.** Honda won the 2025 JFL and declined promotion (no intention to turn
  professional), so only the play-off winner (Reilac Shiga) went up and Azul Claro Numazu came down.
  A pure table-based sim would have promoted Honda and left Numazu in J3.
- **J3's relegation count is variable (0-2)** depending on JFL licences — the only place in this
  pyramid where a season can relegate nobody.
- J1/J2/J3 all being 20 clubs makes the three divisions look interchangeable; they are not, and the
  play-off entries differ only in that J3's winner additionally needs a J2 licence.

## Confidence

**High.** Every size and level is stated on the relevant 2026-27 season page and cross-checked by
the club-change arithmetic (14+3+3 = 20, 16+3+1 = 20, 13+1+2 = 16). The calendar change, the 100
Year Vision League's no-relegation status and the new JFL relegation rule are each stated
explicitly. Residual risk is the licence-dependent 3-4 boundary, which is inherently conditional,
and the J1 relegation count: the 2026-27 page does not yet say how many go down, so it is taken
from the rule in force since 2024 (three, no play-off), which the 2025 outcome confirms.
