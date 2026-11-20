# Ireland — football pyramid 2026

Research for the career simulation. Scope: the single row we carry (League of Ireland Premier
Division, level 1). The League of Ireland First Division (level 2) is outside our data. Cups and
European places are out of scope.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026_League_of_Ireland_Premier_Division | 10 clubs, dates (6 Feb – 30 Oct 2026), 180 matches, four meetings per pair, the 2026 relegation outcomes |
| https://en.wikipedia.org/wiki/League_of_Ireland_Premier_Division | 36 matches per club, spring-to-autumn calendar since 2003, one-up/one-down plus play-off mechanics |

The season article cites the FAI/League of Ireland for dates; `leagueofireland.ie` is readable but
the tables load client-side, so the club list and round count rest on the two Wikipedia pages (the
180-match count in the infobox is independent arithmetic: 10 x 36 / 2).

## Leagues

| id | name | level | size | rounds | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| IR1 | League of Ireland Premier Division | 1 | 10 | 36 | — (top) | 2 (1 auto + 1 PO) |

Size 10 and level 1 in our database are correct. One table; every club plays every other club
**four times** (twice home, twice away), which is 36 matches per club and 180 in the division. The
"rounds" figure is therefore 36, not the 18 a double round-robin would give.

## Promotion and relegation

The Premier Division runs a one-up/one-down system with a play-off:

- **10th** is relegated automatically and replaced by the First Division champion.
- **9th** plays the winner of the First Division promotion play-offs in a two-legged tie; the
  winner takes the last Premier Division place.

2026 confirms the mechanics from the other side: Sligo Rovers were relegated directly (9 October,
ending a 21-year stay) and Drogheda United were relegated on 7 November after losing 2-1 to UCD,
the First Division play-off winner. So two clubs left the division in 2026.

There is no relegation play-off *inside* the division, which is why `playoff` is `null`: the
play-off decides a place between a Premier Division and a First Division club, i.e. it belongs to
the 1-2 boundary, and level 2 is not in our data.

## Decisions

1. **`closed_up` / `closed_down` both true** — single-row country in our list. Real clubs do move
   to and from the First Division, but it is outside our data.
2. **No boundary object**, because a boundary needs two adjacent levels in our data.
3. **`format.kind: "single"`, `rounds: 36`.** One table, quadruple round-robin. Do not encode this
   as two double round-robins or as a split: there is no split and no points reset.
4. **`playoff: null`** — the championship is decided by the table.
5. **Not modelled:** FAI Cup, President's Cup, UEFA Champions League / Europa League / Conference
   League places (including the cup-winner route).

## Oddities

- The league is **cross-border**: Derry City play in it from Northern Ireland. A career sim that
  keys clubs to countries by league will mislabel them.
- Seasons run February–October, so the 2026 season is finished while European 2026-27 seasons are
  mid-flight. Any sim that stores one global "season" string needs per-country seasons.
- Our row's `size: 10` is right, but the division has been 10 since 2022; older data saying 12
  (1985-2002 shape) would be wrong.
- Licensing, not sport, has removed clubs before (Cobh Ramblers 2008 lost a First Division licence
  and dropped two tiers; several clubs were expelled in 2009-10). A sim that only reads the table
  will occasionally keep a club that would really have been refused a licence.

## Confidence

**High.** Size, round count and the relegation mechanics are each stated twice (season article
infobox/lead plus the competition-format section of the league article), and the 2026 outcomes
match the described mechanics exactly.
