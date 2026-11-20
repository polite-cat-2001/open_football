# Canada — football pyramid 2026

Scope: level 1 only (Canadian Premier League). No promotion or relegation anywhere in the pyramid; no
cups, no CONCACAF places.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026_Canadian_Premier_League_season | 8 clubs, "quadruple round-robin ... twice at home and twice away", 28 matches, top four to the play-offs, two-legged semi-finals and a single final |
| https://en.wikipedia.org/wiki/Canadian_Premier_League | `teams = 8`, no promotion/relegation, the 2026 composition (FC Supra du Québec in, Valour FC out) |

## League

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| CDN1 | Canadian Premier League | 1 | 8 | 28 rounds, quadruple round-robin | — (closed) | — (closed) |

Our row (CDN1, level 1, 8 clubs) is correct.

## Format

- 8 clubs, each pair meets **four times** (twice at home, twice away) = **28 matches**, 112 in total.
- Regular season April–October; the regular-season winner takes the **CPL Shield** and a CONCACAF
  Champions Cup place.
- Play-offs: the **top four** play two-legged semi-finals (1v4, 2v3) and a single championship final in
  November. `playoff.kind` is `title`, entries 1–4.
- No split, no groups, no apertura/clausura.

## Pyramid

- The CPL has **no promotion and no relegation** — it is a closed league. There is no level 2 that feeds
  it: below the CPL sit semi-professional regional leagues (League1 Ontario, League1 BC, Première Ligue
  de soccer du Québec) that are not connected by sporting merit.
- Hence `closed_up: true` and `closed_down: true`, and no boundaries. That is the real structure here,
  not a gap in our data.

## Oddities

- The competition has 8 clubs in 2026 only because Valour FC suspended operations and FC Supra du Québec
  debuted; it had 8 clubs before as well, so the size is stable but the membership is not.
- 2026 is the first senior competition anywhere to trial the "clear daylight" offside rule — a
  competition-rule curiosity, irrelevant to promotion/relegation but worth knowing if match rules are
  simulated.
- A closed league means a career sim cannot relegate a Canadian club; the only movement is expansion
  and clubs folding.

## Confidence

**High.** Eight clubs, 28 rounds, the four-club play-off and the absence of promotion/relegation are all
stated in both the season article and the league article.
