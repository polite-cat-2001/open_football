# Jamaica — football pyramid 2026-27

Research for the career simulation. Scope: the single row we carry (Jamaica Premier League,
level 1). The JFF Championship (level 2) is outside our data. Cups and CONCACAF places are out of
scope.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Jamaica_Premier_League | 14 clubs, the return to three rounds, "increased the number of games each team played from 26 to 39", September 2026 – May 2027 |
| https://en.wikipedia.org/wiki/Jamaica_Premier_League | 14 clubs since 2022-23, three-round regular season (39 matches), top-six play-off shape, bottom two relegated |

The season article is flagged "outdated" and its infobox match count is wrong (see below), so the
structure rests mainly on the league article plus the season article's own prose about the format
change. `jamaica-gleaner.com` and `jamaicaobserver.com` articles are cited by Wikipedia for the
format change but could not be read directly.

## Leagues

| id | name | level | size | rounds | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| JPL1 | Jamaica Premier League | 1 | 14 | 39 | — (top) | 2 |

Size 14 and level 1 in our database are correct. One table, **three** rounds (each club plays
every other club three times) = 39 matches per club, 273 in the division.

## Format and play-off

- Regular season: single table, 39 matches.
- Top six contest the title: **1st and 2nd go straight to the semi-finals**, 3rd-6th play a
  single-leg quarter-final round (at the higher seed). Semi-finals and final follow.
- Bottom two are relegated; the top two of the JFF Championship replace them.

The champion is therefore *not* the table winner. `playoff.kind` is `title`, with entries 3rd-6th,
because those are the clubs that play an extra round; 1st and 2nd are already in the semi-finals.

## Decisions

1. **`closed_up` / `closed_down` both true** — single-row country in our list. The JFF Championship
   exists and clubs really move, but it is outside our data.
2. **No boundary object** — a boundary needs two adjacent levels in our data.
3. **`format.kind: "single"`, `rounds: 39`.** Not `"split"`: there is one table and no points
   reset; the play-off is a separate knockout after the table.
4. **`playoff.kind: "title"`** with `entries: "3rd-6th"`, one leg, and the bye for 1st/2nd spelled
   out in the note.
5. **Not modelled:** CONCACAF Caribbean Cup (top two) and CFU Club Shield (third), plus the JFF
   Championship promotion route.

## Oddities

- **2026-27 is a format change.** 2022-23 through 2025-26 played 26 matches (two rounds); 2026-27
  returns to the pre-COVID three-round, 39-match season. Any cached JPL fixture list from last
  season will be half the right length.
- **The infobox match count (247) is impossible** for 14 clubs x 39 rounds (273). Listed in
  `conflicts`; the 39-match figure is stated in prose and is self-consistent, so it is used.
- Club names in the 2026-27 article include several that are not yet stable as Wikipedia articles
  ("Tru Juice", "Racing Utd"), i.e. sponsorship/renamed clubs. A sim keyed on club names will need
  aliases.
- Two clubs came up from the second division for 2026-27 (the article names them only by prose),
  so the division is genuinely 14 and not 12.

## Confidence

**Medium.** The size (14), the level (1) and the six-team play-off are solid (two pages agree, and
14 clubs has been the shape since 2022-23). The 39-match round count is solid in prose but
contradicted by the same article's infobox; the season is also only a few months old, so no
completed three-round season exists to check against.
