# Scotland — football pyramid, 2026-27

Scotland's four senior tiers are the SPFL: 12 / 10 / 10 / 10 clubs. Level 1 plays a **split**
(33 rounds, then 6+6 for 5 more, 38 total). Levels 2-4 are plain quadruple round robins (36
rounds each: teams meet four times).

The characteristic feature is that **every boundary is 2 up / 2 down, and one of those two places
is always a play-off**, not the table. The same ladder shape repeats at all three boundaries:

1. 3rd v 4th over two legs (quarter-final).
2. 2nd v that winner over two legs (semi-final).
3. the semi-final winner v the **11th/9th/9th-placed club of the division above** over two legs.

So a division's champion and a play-off winner go up; the division's bottom club and the loser of
that final tie go down. A division's 2nd, 3rd and 4th all enter, but only one of them can be
promoted.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | SC1 | Scottish Premiership | 12 | split 6+6 after 33 | 38 | — (closed) | 1 direct + 1 play-off |
| 2 | SC2 | Scottish Championship | 10 | single table, 4 meetings | 36 | 1 direct + 1 play-off | 1 direct + 1 play-off |
| 3 | SC3 | Scottish League One | 10 | single table, 4 meetings | 36 | 1 direct + 1 play-off | 1 direct + 1 play-off |
| 4 | SC4 | Scottish League Two | 10 | single table, 4 meetings | 36 | 1 direct + 1 play-off | 1 play-off (no direct) |

Levels 5 and below (Highland League, Lowland League East/West, then the regional leagues) are not
in our dataset, so League Two is closed downward here. In reality its bottom club is **Club 42**,
which defends its place in a two-legged tie against the winner of the tier-5 play-off, subject to a
bronze-level SFA licence.

## Level 1 — Scottish Premiership

- 12 clubs. Each plays the other 11 three times (33 matches), then the table splits into top six and
  bottom six, each playing the other five once (5 matches) → **38 per club**. The fixture list is
  balanced so that post-split pairs are usually 2 home / 2 away over the season, but that is not
  always possible.
- 12th is relegated directly; **11th plays the Championship play-off winner** over two legs.
- 2026-27 started 31 July 2026 with St Johnstone promoted and Livingston relegated.

## Level 2 — Scottish Championship

- 10 clubs, 36 rounds (4 meetings each: two at home, two away, split into two halves of the season).
- Champion promoted. 2nd-4th enter the ladder described above; the ladder winner meets the
  Premiership's 11th.
- 10th relegated; 9th plays the League One ladder winner over two legs.

## Level 3 — Scottish League One

- Identical shape to the Championship: 10 clubs, 36 rounds, champion up, 2nd-4th in the ladder, 10th
  down, 9th in a two-legged tie against the League Two ladder winner.

## Level 4 — Scottish League Two

- 10 clubs, 36 rounds. Champion up; 2nd-4th in the ladder; that winner meets League One's 9th.
- **No automatic relegation place.** The bottom club (10th, "Club 42") goes into the pyramid
  play-off: from 2026-27 the Highland League and the two new Lowland League divisions (East and
  West) each send a champion, those three play off, and the winner meets Club 42 over two legs.
  Promotion from tier 5 also requires a bronze SFA club licence.

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| SC1 | Scottish Premiership | 1 | 1 | 12 | 12 | correct |
| SC2 | Scottish Championship | 2 | 2 | 10 | 10 | correct |
| SC3 | Scottish League One | 3 | 3 | 10 | 10 | correct |
| SC4 | Scottish League Two | 4 | 4 | 10 | 10 | correct |

Nothing to correct. Note the common modelling mistake: the Premiership is **not** a plain 38-round
double round robin, and levels 2-4 are **four** meetings, not two.

## Caveats

- 2026-27 is the first season of the restructured tier 5 (Lowland League split into East and West),
  so the Club 42 play-off route changed this year.
- The split makes the Premiership's final table depend on which six clubs are in each half; a
  simulator that plays 38 rounds without a split will produce a different fixture set (though the
  same number of matches).
- Play-off ties are two-legged at every boundary; only the Championship's internal ladder is
  sometimes described as "one-leg" in older sources — 2026-27 uses two legs throughout.

## Sources

- https://en.wikipedia.org/wiki/Scottish_football_league_system
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Scottish_Premiership
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Scottish_Championship
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Scottish_League_One
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Scottish_League_Two
