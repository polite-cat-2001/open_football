# Puerto Rico — football pyramid 2026-27

Research for the career simulation. Scope: level 1 only, Liga Puerto Rico Pro (LPR Pro).
Our row is the **Apertura**. There is no second division in our list and none of the
sources describes a promotion route, so the league is closed in both directions.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026%E2%80%9327_Liga_Puerto_Rico_Pro_season | 2026-27: the nine clubs, the Apertura/Clausura split, the round-robin + top-four play-off description, the two clubs that left |
| https://en.wikipedia.org/wiki/Liga_Puerto_Rico_Pro | the league's identity and top-flight status (cross-check) |

## League

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| PRA1 | Liga Puerto Rico Apertura | 1 | 9 | Apertura/Clausura, round-robin + 4-team play-off | — (top) | — |

Our 9 clubs and level 1 are correct: nine clubs take part in the Apertura 2026 (Guayama FC
and FC Mayagüez left after 2025-26, nobody joined).

## Format

- The season is **two championships**, Apertura (from 15 August 2026) and Clausura, "each
  in an identical format".
- The season article describes the format as "a round robin style, with the top four
  making the playoffs". The Apertura ladder runs to **17 matchdays** and clubs had played
  14-15 games by mid-November, which is more than a single round-robin of nine (8 games)
  and less than a triple round-robin (24). The precise number of rounds is not stated.
- Play-off: top four, then semi-finals and a final. Legs are not stated.
- **Internal contradiction:** the article says each tournament is "contested by eight
  teams" while listing nine and tabulating nine. The nine-club table is the reliable
  figure; the "eight" is probably a leftover from the 2025-26 edition.

## Promotion and relegation

- None documented. Clubs enter and leave the league administratively (two left before
  2026-27), there is no second division in our data and no relegation place in the
  season article.
- `closed_up: true`, `closed_down: true`, no boundaries.

## Decisions

1. **`size: 9`** from the participating-club list and the standings, not from the
   "eight teams" sentence.
2. **`format.kind: "apertura_clausura"`, `rounds: null`**, with the round-count problem
   explained in the note. A number would be a guess.
3. **`playoff: {"kind": "title", "entries": "top 4", "legs": null}`** — the play-off
   exists but its match format is not described.
4. **Both directions closed**, no boundaries.

## Oddities

- The nine clubs include a university side (DS Edusoccer), a surf-brand club and several
  city clubs; several play at grounds with capacities of 1,000 or less, and two share a
  stadium. Home advantage in this league is close to meaningless as a stadium fact.
- Puerto Rico is a CONCACAF member but not a FIFA member, so there is no continental
  route through this league to anchor a season structure on.
- The Apertura is the league's fifth season split into Apertura/Clausura and its third
  under the LPR Pro name — the competition is young and its format has changed repeatedly.

## Confidence

**Low-medium.** Nine clubs and the two-tournament structure are solid. The round count is
genuinely unresolved (the article contradicts itself on eight v nine and never states
rounds), and both the play-off legs and any promotion/relegation route are undocumented.
