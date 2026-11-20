# Lebanon — football pyramid 2026-27

Research for the career simulation. Scope: the single row we carry (Lebanese Premier League,
level 1). The Lebanese Second Division (level 2) is outside our data. Cups and AFC places are out of
scope.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Lebanese_Premier_League | 12 clubs, dates (8 Oct 2026 – 12 Apr 2027), the two-phase split, half-points carry, the reversal of the 10-club plan |
| https://en.wikipedia.org/wiki/2025%E2%80%9326_Lebanese_Premier_League | the same format in practice under war disruption: 4-team championship group, 3-team relegation group, halved points |
| https://en.wikipedia.org/wiki/2024%E2%80%9325_Lebanese_Premier_League | the canonical split: 11-match first phase, two groups of six, half-points, top six/bottom six barrier |
| https://en.wikipedia.org/wiki/Lebanese_Premier_League | league identity, level 1, promotion/relegation with the Second Division |

The Arabic sources the article cites (`elsport.com`, `the-lfa.com.lb`) were not read; the structure
is triangulated across three season articles instead.

## Leagues

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| LIB1 | Lebanese Premier League | 1 | 12 | 11 rounds + split 6/6, half points → 21 | — (top) | 2 |

Size 12 and level 1 in our database are correct.

## The split

- **First phase:** one table, single round-robin — 11 matches each.
- **Barrier:** after the split a club can never move out of its own half, however many points it
  scores. A 7th-placed club cannot be champion even with a perfect second phase.
- **Second phase:** top six (championship group) and bottom six (relegation group). Each club plays
  the other five in its group home and away — 10 more matches, **21** in total.
- **Points:** **half** the first-phase total carries over, fractions rounded up. This is the one
  place in this batch where points are not carried in full.
- **Relegation:** the bottom two of the relegation group go down; the Second Division's top two
  come up.

## A likely-wrong sentence in the source

The 2026-27 article says both:

> "the league is divided into two groups of six"

and

> "the top four teams enter the championship group, while the bottom four enter the relegation
> group"

Those cannot both hold for 12 clubs. The paragraph also says each club plays "the other five clubs
in its group twice, for a further 10 matches", which only works with **two groups of six**, and both
2024-25 and 2025-26 used a 6/6 split. The 6/6 reading is used; the "top four/bottom four" sentence is
recorded in `conflicts` as a probable copy error (it describes the 8-team split used in some other
competition or an earlier draft).

## Decisions

1. **`closed_up` / `closed_down` both true** — single-row country in our list.
2. **No boundary object** — a boundary needs two adjacent levels in our data.
3. **`format.kind: "split"`, `split_after: 11`, `groups: [6,6]`, `rounds: 21`, `points_carry: true`.**
   The halving is in the note; the flag says points do carry (they are not reset to zero).
4. **`playoff: null`** — the championship group decides the title as a league, not a knockout.
5. **Not modelled:** Lebanese FA Cup, Lebanese Super Cup, AFC Challenge League places, and the
   licensing/withdrawal rules (Bourj withdrew mid-season in 2025-26 and was placed last and
   relegated by disciplinary decision).

## Oddities

- **The 10-club plan was reversed.** On 26 August 2026 the LFA executive committee scrapped the
  plan to cut the league to 10 clubs for 2027-28, which would have meant four relegations in
  2026-27. Anyone working from July 2026 reporting will have the wrong relegation count.
- **Weather/war shocks are normal here.** 2025-26 was suspended by the 2026 Lebanon war, its
  remaining fixtures were cancelled for the withdrawn club, and the LFA improvised a 4-team
  championship group and a 3-team relegation group. The "21 matches" figure is the intended shape,
  not something every recent season actually reached.
- **A four-team championship group is not a play-off**; Ansar won 2025-26 by winning that group.
  Do not model it as a semi-final/final.
- Half-points with rounding up creates half-point totals in the table; a sim using integers only
  will drift from the official standings.

## Confidence

**Medium.** Size (12), level (1), the split and half-points are confirmed by three separate season
articles. The split width (6/6 vs 4/4) is contradicted inside the 2026-27 article itself and had to
be resolved by arithmetic and by the two previous seasons, so it is the one fact here that could be
wrong.
