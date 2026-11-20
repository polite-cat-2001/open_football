# Iraq — football pyramid 2026-27

Research for the career simulation. Scope: the single row we carry (Iraq Stars League, level 1).
The Iraqi Premier Division League (level 2) is outside our data. Cups and AFC/Arab competition
places are out of scope.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Iraq_Stars_League | 20 teams, season dates (14 Aug 2026 – 28 May 2027), the 2026-27 relegation rule and the 18-team target |
| https://en.wikipedia.org/wiki/Iraq_Stars_League | league structure: 20 clubs, 38 rounds, 380 matches, normal promotion/relegation mechanics and the 18th-place play-off |

No official site could be read: `iraqstarsleague.com` is JS-rendered and served no table; the
Wikipedia season article cites it for the standings, so the club list is effectively the same
source twice.

## Leagues

| id | name | level | size | rounds | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| IRQ1 | Iraq Stars League | 1 | 20 | 38 | — (top) | 4 |

Size 20 and level 1 in our database are correct. One table, double round-robin: 20 clubs x 38 =
380 matches, which is exactly what the league article states.

## The 2026-27 exception

This is not the normal shape. For 2026-27 only:

- the **bottom four** are relegated to the Iraqi Premier Division League;
- only the **top two** of the Premier Division League are promoted;
- 20 - 4 + 2 = **18 clubs for 2027-28**. The Iraqi FA ratified the cut (Shafaq, 16 June 2026,
  cited by the season article) specifically to shrink the top flight.

In a normal season the league runs 3 up / 3 down: bottom two relegated directly, the **18th-placed
club** plays a two-legged tie against the winner of a play-out between the Premier Division
League's 3rd and 4th, and the Premier Division League's top two go up. 2025-26 followed that shape
(three promoted: Al-Jolan, Ghaz Al-Shamal, Karbala; three relegated: Amanat Baghdad, Al-Najaf,
Al-Qasim).

A career sim started in 2026-27 must therefore relegate four and promote two, then switch back to
the 3/3 shape from 2027-28. Modelling the normal shape in 2026-27 would leave the division at 20
clubs forever.

## Decisions

1. **`closed_up` and `closed_down` are both true** because this is the only Iraqi league in our
   list: no league above (it is the top flight) and no league below in our data, even though clubs
   really do move to and from the Premier Division League.
2. **No boundary object.** A boundary needs two adjacent levels in our data; Iraq has one.
3. **`format.kind: "single"`**, 38 rounds. No split, no groups, no championship play-off — the
   champion is the table winner.
4. **`playoff: null`.** The 18th-place relegation play-off does not exist in 2026-27 and is not a
   promotion play-off inside the division anyway.
5. **Not modelled:** the AFC Champions League Elite / ACL Two / Arab Club Champions Cup / GFF Gulf
   Club Champions League places, the Iraqi FA Cup and the Iraqi Super Cup. They do not affect
   promotion or relegation.

## Oddities

- The season article says goal difference became the first tiebreaker for the first time since
  2019-20; before that head-to-head came first. Only matters if the sim replicates tiebreakers.
- Squad rules are unusually specific (18-30 registered, at least five Iraqis under 21, at most
  seven foreign outfield players, five on the pitch, no foreign goalkeepers, the first four
  foreigners from top-90 FIFA nations). Not needed for a pyramid model, noted because it will
  surprise anyone building a transfer layer.
- The league table on Wikipedia shows 20 teams and 13 rounds played on 10 November 2026, i.e. the
  season is live. Nothing in the table contradicts the 20-club size.

## Confidence

**High.** Size, level, round count and the 2026-27 relegation change are stated explicitly in two
places (the season article's "New rules" section and the league article's "Promotion and
relegation" section), and the arithmetic closes (20 - 4 + 2 = 18). The only soft spot is the exact
normal-season play-off pairing, which is described in one sentence on the league page.
