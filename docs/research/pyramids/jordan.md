# Jordan — football pyramid 2026-27

Research for the career simulation. Scope: the single row we carry (Jordanian Pro League, level 1).
The Jordanian First Division League (level 2) is outside our data. Cups and AFC places are out of
scope.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Jordanian_Pro_League | 10 teams, dates (3 Sep 2026 – 15 May 2027), double round-robin, the two promoted and two relegated clubs |
| https://en.wikipedia.org/wiki/Jordanian_Pro_League | league identity, level 1, relegation to the First Division League |

The 2026-27 season article carries two maintenance tags (primary sources, unreliable sources), so
the size claim rests on it plus the arithmetic of its own club list (ten named clubs) and the
2025-26 promotion/relegation list. No independent official table could be read (the JFA site is
Arabic and JS-driven).

## Leagues

| id | name | level | size | rounds | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| JO1L | Jordanian Pro League | 1 | 10 | 18 | — (top) | 2 |

Size 10 and level 1 in our database are correct. One table, double round-robin: 10 clubs x 18 =
90 matches.

## Promotion and relegation

- Bottom two relegated to the Jordanian First Division League.
- Top two of the First Division League promoted.
- No play-off: 2025-26 saw Al-Arabi (back after 12 years) and Doqara (first time) come up, and
  Al-Sarhan and Al-Ahli go down. 8 + 2 = 10 again.

Both are table positions, so if Jordan had a second level in our data the boundary would read
`up: 2, down: 2, selection: bottom_n`.

## Decisions

1. **`closed_up` / `closed_down` both true** — single-row country in our list.
2. **No boundary object.** A boundary needs two adjacent levels in our data.
3. **`format.kind: "single"`, `rounds: 18`.** No split, no championship play-off; the table winner
   is champion.
4. **`playoff: null`.**
5. **Not modelled:** Jordan FA Cup, Jordan Super Cup, AFC Champions League Two / AFC Challenge
   League places.

## Oddities

- Only 10 clubs is unusually small for a national top flight; it makes the league a 90-match season
  and means two relegation places is 20% of the division. Any "relegate the bottom 3" default rule
  would wreck it.
- The 2026-27 rules allow clubs to register one Palestinian as a **local** player if he has six
  official caps for Palestine's senior or Olympic team (JFA decision, 3 August 2026). A sim with a
  simple foreign-player quota will diverge from the real squad rules.
- The season article's infobox says "matches = 40", which is simply the count played at the time of
  the last update (9 November 2026), not the season total. Not a conflict, but do not read it as a
  40-match season.

## Confidence

**High** on size (10), level (1) and the 2-up/2-down movement: the ten-club list is explicit and
the arithmetic closes. **Medium** only in the sense that the page is tagged as weakly sourced; no
second source contradicted it.
