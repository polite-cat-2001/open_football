# Malta — football pyramid, 2026-27

Malta runs one August–May season. Cups and UEFA competitions are out of scope. The pyramid is short
and completely open at the top two boundaries — but the Premier League's relegation is a **knockout**,
not a table position.

## At a glance

| Level | id | Competition | Clubs | Format | Matches | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | MT1N | Premier League (Opening + Closing Rounds) | 12 | split 6/6, points reset, twice | 32 | — (closed) | 2, via 4-team play-off |
| 2 | MAL2 | Challenge League | 16 | split 8/8 | 22 | 2 | 2 |
| 3 | MAL3 | National Amateur League I | 12 | double round robin | 22 | 2 | 4 (to level 4) |
| 4 | — | National Amateur League II (not modelled) | — | — | — | — | — |

## Level 1 — Premier League

- 12 clubs. Each plays the other once (11 rounds), then splits into Top Six / Bottom Six and plays
  those five again → 16 matches. Then the **Closing Round repeats the whole thing with points reset**.
- **Relegation** is decided at the end of the season by a four-team play-off: the bottom two of the
  Opening Round table and the bottom two of the Closing Round table. Two one-off matches, and the two
  losers are relegated. In 2025-26 Mosta beat Naxxar and Żabbar beat Tarxien, so Naxxar and Tarxien
  went down — neither was last in the aggregate table.
- So `selection` for this boundary is `playoff`, not `bottom_n`. Our row's name says "Opening Round",
  which is one half of the season, not the league.

## Level 2 — Challenge League

- 16 clubs, single round robin (15), split into Top Eight / Play-Out Eight for 7 more → 22 matches.
- **Top two promoted.** 2025-26 needed a one-off play-off between Swieqi and Birżebbuġa because they
  finished level on points *and* goal difference; that is an exception, not the rule.
- Bottom two relegated to the Amateur League I.

## Level 3 — National Amateur League I

- **12 clubs in 2026-27**, 22 rounds. It had 14 clubs and 26 rounds in 2025-26; four went down and the
  Challenge League's two relegated clubs plus the two Amateur League II promoted clubs refilled it.
- Top two up to the Challenge League; bottom four down to the Amateur League II.
- 2025-26 also needed a tie-break play-off for the fourth relegation place (Pembroke beat Xgħajra).

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| MT1N | Premier League Opening Round | 1 | 1 | 12 | 12 | size/level correct, **name is a phase not a league** |
| MAL2 | Challenge League | 2 | 2 | 16 | 16 | correct |
| MAL3 | National Amateur League I | 3 | 3 | 12 | 12 | correct for 2026-27 (14 in 2025-26) |

## Caveats

- The Premier League's two champions (one per round) and the Final Four are a presentation problem for
  the sim; the JSON only records the league shape.
- Because relegation is a knockout, a mid-table club can go down. Do not derive it from the aggregate table.

## Sources

- https://en.wikipedia.org/wiki/2025%E2%80%9326_Maltese_Premier_League
- https://en.wikipedia.org/wiki/2025%E2%80%9326_Maltese_Challenge_League
- https://en.wikipedia.org/wiki/2025%E2%80%9326_Maltese_National_Amateur_League
