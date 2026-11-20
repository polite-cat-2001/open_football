# Israel — football pyramid 2026-27

Research for the career simulation. Scope: levels 1-2 as carried in our database. Liga Alef
(level 3) is outside our data. Cups and European places are out of scope.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Israeli_Premier_League | 14 clubs for 2026-27, the regular-season table with its Championship-round / Relegation-round markers, dates (22 Aug 2026 – 22 May 2027) |
| https://en.wikipedia.org/wiki/Israeli_Premier_League | format: 26 rounds, top six meet twice, bottom eight meet once, 33-36 matches per club, 240 matches; "the two lowest-placed teams are relegated ... two highest-placed teams of Liga Leumit are promoted" |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Liga_Leumit | 16 clubs, table markers: 1st-8th to the promotion play-offs, 9th-16th to the relegation play-offs |
| https://en.wikipedia.org/wiki/Liga_Leumit | 16 clubs, 30-match round-robin, split into a promotion group and a relegation group of eight |
| https://en.wikipedia.org/wiki/2025%E2%80%9326_Liga_Leumit | completed season used to check the split: final tables show 37 matches and full points carried (no halving) |

## Leagues

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| ISR1 | Ligat ha'Al | 1 | 14 | 26 rounds + split 6/8 → 36 / 33 | — (top) | 2 |
| ISR2 | Liga Leumit | 2 | 16 | 30 rounds + split 8/8 → 37 | 2 | 2 (to Liga Alef) |

Both sizes and levels match our rows. The Premier League article's own summary — "teams playing
between 33 and 36 matches each, totalling 240 matches" — is the arithmetic check:
(6 x 36 + 8 x 33) / 2 = 240.

## The split, precisely

**Ligat ha'Al.** 14 clubs play a double round-robin (26 matches). The table then splits:

- 1st-6th: Championship round, each team meets the other five **twice** → 10 more matches, **36**.
- 7th-14th: Relegation round, each team meets the other seven **once** → 7 more matches, **33**.
- Points and goals carry over in full. Points were halved until 2011; that is gone.
- The championship-round winner is champion. The bottom two of the relegation round are relegated.

**Liga Leumit.** 16 clubs play a double round-robin (30 matches), then split into 1st-8th
(promotion group) and 9th-16th (relegation group). Each group plays a single round-robin, 7 more
matches, **37** total. The promotion group's top two go up; the relegation group's bottom two go
down to Liga Alef.

## Boundaries

| between | up | of which PO | down | of which PO | allocation | selection |
| --- | --- | --- | --- | --- | --- | --- |
| 1-2 | 2 | 0 | 2 | 0 | free | bottom_n |

Both directions are table-only. There is **no** promotion/relegation play-off between the two
divisions in the current format, and no intra-division knockout at either level: Liga Leumit's
"promotion play-offs" are a league phase of eight, not a bracket. That is why `playoff` on ISR2 is
recorded as a promotion stage with `entries: "1st-8th"` and the note that it is not a knockout.

Arithmetic: 14 - 2 + 2 = 14; 16 - 2 + 2 = 16.

## Decisions

1. **`format.kind: "split"`** for both, with `split_after`, `groups` and `points_carry: true`. The
   two groups have different lengths at level 1, so `rounds: 36` is the maximum and the note in the
   JSON/markdown records the 33 for the bottom eight.
2. **One round count cannot describe level 1.** A sim must apply 36 to the top six and 33 to the
   rest, or it will schedule an extra fortnight for the relegation group.
3. **`up: 2`, `down: 2`, no play-off places.** Liga Leumit's promotion group is how the two places
   are *decided*, not an extra place.
4. **`closed_down: false` for ISR1** (Liga Leumit exists in our data), **`true` for ISR2** because
   Liga Alef (level 3) is not in our list.
5. **Not modelled:** Israel State Cup and the UEFA places (champion to Champions League Q2, 2nd and
   3rd to Conference League Q2, cup winner to Europa League Q1). Also not modelled: the points
   deductions that regularly decide this league (Ironi Tiberias carried -6 into 2026-27 after a
   dual-contracts case, -8 the season before).

## Oddities

- **Points deductions are structural here, not exceptional.** Two consecutive seasons have had a
  club start on minus points. A sim that ignores disciplinary deductions will mis-rank the bottom
  half.
- Several Liga Leumit clubs cannot host and play at neutral grounds (Kafr Qasim, Kiryat Yam,
  Ra'anana, Modi'in, Bnei Reineh, Kiryat Gat, Maccabi Jaffa in 2026-27). Promotion is partly a
  stadium/licence question, and the 2026-27 Liga Leumit field itself was set by the 2026 war
  stopping the non-professional leagues: the two Liga Alef leaders were promoted on position when
  the season was abandoned.
- The 2025-26 Premier League played rounds 25-26 behind closed doors because of the 2026 Iran war.
  Scheduling assumptions (every match has a crowd) do not hold.
- Wikipedia's Liga Leumit article still describes halved points and a single round-robin split -
  stale text, contradicted by its own 2025-26 season tables (37 matches, full points). Conflicting
  statements are listed in `conflicts`.

## Confidence

**High** on sizes, levels and the 2-up/2-down boundary: each is corroborated by the league article,
the 2026-27 season article and the completed 2025-26 season. **Medium** only on the exact split
mechanics if the IFA changes them again; the 33/36 asymmetry and the 37-match second tier are
confirmed by played fixtures, not just prose.
