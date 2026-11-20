# Türkiye — football pyramid, 2026-27

Season runs August 2026 → May 2027.

| Level | Competition | Clubs | Shape | Rounds |
|---|---|---|---|---|
| 1 | Süper Lig | 18 | double round-robin | 34 |
| 99 | U19 Süper Lig (U19 Elit A Ligi) | 18 | double round-robin, then top-8 finals | 34 |

Our rows are right: 18 clubs at level 1, and the U19 competition is a youth league, not a tier.

## Level 1 — Süper Lig

18 clubs since 2025-26 (down from 20), 34 matches. The **bottom three are relegated directly** to
the TFF 1. Lig; there is no relegation play-off at this boundary.

## Level 2 — TFF 1. Lig (not one of our rows)

Recorded here because the top flight's relegation only makes sense with it:

- 20 clubs, 34 rounds, bottom four relegated to the 2. Lig (2025-26: Serikspor, Sakaryaspor,
  Hatayspor, Adana Demirspor).
- **Promotion is 2 direct + 1 play-off**: champion and runner-up up, then 3rd to 7th play off —
  3rd goes straight to the final, 4th v 7th and 5th v 6th are single games at the higher seed,
  then two-legged semi-finals, final at a neutral venue (2025-26: Çorum won it from 4th).

So the 1 ↔ 2 boundary, if level 2 is ever added, is 3 up (1 play-off) / 3 down (0 play-off).

## Level 99 — U19 Süper Lig

This is the youth competition of the Süper Lig clubs, run by the TFF under its "Gelişim Ligleri"
(development leagues) umbrella:

- exactly the **18 Süper Lig clubs' U19 teams**; entry is compulsory (a fine applies for not
  entering), and each club's U19 fixture list mirrors its senior fixture list;
- 34 matches, double round-robin;
- the **top eight** then play the "Türkiye Finalleri": 1v8, 2v7, 3v6, 4v5, then a draw for the
  semi-finals, single matches at neutral venues, plus a third-place match;
- the champion qualifies for the **UEFA Youth League**;
- **no promotion and no relegation** in either direction: the field is fixed by who is in the
  Süper Lig, and clubs enter or leave only when their senior team is promoted or relegated.

Squad rules (U19): players 16-19, at most five 20-21-year-olds, at most one foreign player.
That is why `level` stays at the sentinel 99 and both closed flags are true.

## Data problems in our rows

1. Nothing wrong with `TR1` (18, level 1).
2. `T191` is correctly labelled youth, but it must never be treated as level 2: it is level 99,
   has entry by senior-club membership rather than by sporting merit, and is fully closed.

## Confidence

High for the Süper Lig (size, rounds, three relegations). High for the U19 league's field, mirror
fixture list, top-8 finals and UEFA Youth League prize — all stated by the TFF-sourced article.
Medium on the exact 2026-27 play-off pairings in the 1. Lig, which is not in our rows anyway.

## Sources

- https://en.wikipedia.org/wiki/Süper_Lig (18 clubs, 34 matches, bottom three down, 1. Lig = 2 direct + play-off)
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Süper_Lig (current season, clubs)
- https://en.wikipedia.org/wiki/TFF_1._Lig (20 clubs, 3rd-7th play-off, four relegated)
- https://tr.wikipedia.org/wiki/U19_Elit_A_Ligi (U19 Süper Lig: Süper Lig clubs only, top-8 finals, UEFA Youth League)
