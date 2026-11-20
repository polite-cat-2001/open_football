# Romania — football pyramid 2026-27

Research for the career simulation. Scope: levels 1-2 as carried in our database
(SuperLiga / Liga I and Liga 2). Cups and European places are out of scope, including the
separate European play-offs inside the Liga I play-out.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Liga_I | 2026-27 Liga I: 16 clubs, play-off 6 / play-out 10, points halved, 13th-14th in the relegation play-offs, 15th-16th relegated, who came up and went down |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Liga_II | 2026-27 Liga II: **22 clubs**, the 21-round regular season, the top-six promotion play-off, the two play-out groups, the play-off 3rd/4th v Liga I 13th/14th, the fifth relegation place, the promotion-eligibility caveat |
| https://en.wikipedia.org/wiki/2025%E2%80%9326_Liga_II | the same format in the previous season (21 + 10 / 7 rounds, points carried, seeding of the play-out groups, the 6th-place relegation play-off) |

The Romanian Wikipedia articles (`SuperLiga României 2026-2027`, `Liga a II-a 2026-2027`)
exist as language links but were not read; the English versions carry the same tables and
the play-off/play-out sections verbatim.

## Leagues

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| RO1 | SuperLiga | 1 | 16 | 30 rounds + split 6/10 | — (top) | 2 direct + 2 play-off |
| RO2 | Liga 2 | 2 | 22 | 21 rounds + play-off 6 / two play-out groups of 8 | 2 direct + 2 play-off | 5 |

RO1's 16 and level 1 are correct. **RO2's 23 is wrong: Liga II has 22 clubs in 2026-27.**

## Liga I format

- Regular season: 16 clubs, 30 rounds (double round-robin).
- Then the table splits: 1st-6th play a **championship play-off** (10 more matches,
  double round-robin) and 7th-16th a **relegation play-out** (9 more matches, each pair
  once). Points from the regular season are **halved and rounded up**, and nothing else
  carries over: a club on 31 points starts the split on 16.
- So there is no single round count: the top six play 40 matches, the bottom ten 39.
- Overall places 7-16 come from the play-out ranking, not from the regular season.
- Relegation: 15th and 16th overall go down directly; **13th and 14th** each play a
  two-legged promotion/relegation play-off against the 3rd- and 4th-placed clubs of the
  Liga II promotion play-off. 7th and 8th enter the separate European play-offs (ignored
  here).
- No title play-off: the play-off winner is champion.

## Liga II format — 22 clubs

- Regular season: **22 clubs, single round-robin, 21 rounds** (each pair meets once).
- Top six → **promotion play-off**, double round-robin, 10 matches (31 in total). All
  regular-season points are carried, not halved.
- The other 16 → **two relegation play-out groups of eight**, seeded by regular-season
  position (7th, 10th, 11th, 14th, 15th, 18th, 19th, 22nd in one; 8th, 9th, 12th, 13th,
  16th, 17th, 20th, 21st in the other), single round-robin, 7 matches (28 in total). All
  points carried.
- Promotion: the top two of the play-off go up (subject to eligibility); 3rd and 4th go
  to the two-legged play-offs against Liga I's 13th and 14th.
- Relegation: the last two of each play-out group (4 clubs) plus the loser of a play-off
  between the two **sixth-placed** play-out clubs — five places in total.

## Promotion eligibility — the real gate

Liga II promotion is not open to every club. In 2026-27, **12 of the 22 clubs are
ineligible for promotion** because of their legal status or ownership (the article cites
Eurosport: more than half the division). Steaua cannot be promoted while owned by a
governmental entity; other clubs lack the corporate form or the licence. So the top two
of the play-off are promoted only if eligible, and a club can win the play-off and stay
down. This is the single biggest distortion in the Romanian pyramid and is why the
boundary is encoded as `by_licence`.

## Boundaries

| between | up | of which PO | down | of which PO | allocation | selection |
| --- | --- | --- | --- | --- | --- | --- |
| 1-2 | 4 | 2 | 4 | 2 | by_licence | bottom_n |

- Up: Liga II play-off 1st and 2nd directly (if eligible), 3rd and 4th via two-legged
  play-offs against Liga I's 13th and 14th.
- Down: Liga I 15th and 16th directly; 13th and 14th only if they lose their play-offs.
- The same four ties decide both a relegation and a promotion, so the numbers balance:
  exactly two of {13th, 14th, Liga II 3rd, Liga II 4th} are in the top flight next season,
  alongside the two direct promotions.
- In practice fewer than four can move: in 2026 only three clubs came up (two direct,
  Voluntari via the play-off) and three went down.

## Decisions

1. **`RO2` size 22**, overriding our 23, with the conflict recorded. The 2026-27 league
   table's `team_order` lists 22 codes and the article says "twenty-two teams" twice.
2. **`RO1` `format.kind: "split"`, `rounds: 40`, `split_after: 30`, `groups: [6, 10]`**,
   `points_carry: false` with the halving explained in the note — halving is not "carry"
   and is not "reset", so the boolean alone cannot express it.
3. **`RO2` `format.kind: "split"`, `rounds: 31`, `split_after: 21`, `groups: [6, 8, 8]`**,
   `points_carry: true`.
4. **`allocation: "by_licence"`** on the 1-2 boundary, because promotion is closed to more
   than half the division by legal status, not merely gated by a licence check at the top.
5. **`selection: "bottom_n"`** — relegation is positional, even though the last two places
   pass through play-offs.

## Oddities

- Halving points at the split makes the regular season worth less than it looks: a
  10-point lead becomes 5, and rounding up gives odd-point clubs a half-point gift.
- Liga II's play-out seeding is deliberately interleaved (7th with 22nd, 8th with 21st),
  so the weakest clubs are spread between the two groups rather than concentrated.
- The 2026-27 Liga II lost Politehnica Iași and Hermannstadt to withdrawals before the
  season; two clubs (Dinamo București and Olimpia Satu Mare) were spared relegation as a
  result, which is why only three went down from 2025-26 instead of the nominal five.
- Both levels are single national divisions; there is no regional third tier in our data,
  so Liga II is closed downwards.

## Confidence

**High** for Liga I (format, split, halving, 13th/14th play-offs and 15th/16th relegation
are all explicit). **High** for Liga II's 22 clubs and its stage structure (the 2025-26
article spells out the same format with tables). **Medium** for the exact interplay of
eligibility and the play-offs, which is described in prose and changed clubs' fates in
2025-26 (Bihor Oradea and Steaua were ineligible after qualifying).
