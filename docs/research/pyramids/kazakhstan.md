# Kazakhstan — football pyramid 2026

Research for the career simulation. Scope: levels 1-2 as carried in our database. The Second League
(level 3) is outside our data. Cups and European places are out of scope.

## Sources

| Source | Used for |
| --- | --- |
| https://en.wikipedia.org/wiki/2026_Kazakhstan_Premier_League | 16 clubs, 30 rounds, 240 matches, dates (7 Mar – 31 Oct 2026), the 14→16 expansion, the two relegated clubs |
| https://ru.wikipedia.org/wiki/%D0%A7%D0%B5%D0%BC%D0%BF%D0%B8%D0%BE%D0%BD%D0%B0%D1%82_%D0%9A%D0%B0%D0%B7%D0%B0%D1%85%D1%81%D1%82%D0%B0%D0%BD%D0%B0_%D0%BF%D0%BE_%D1%84%D1%83%D1%82%D0%B1%D0%BE%D0%BB%D1%83_2026 | independent cross-check of the Premier League: 16 teams, 30 rounds, 240 matches, 2 relegated |
| https://en.wikipedia.org/wiki/Kazakhstan_First_League | second tier: 14 clubs, double round-robin, promotion to the Premier League, relegation to the Second League |

The English 2026 Premier League article is explicitly tagged **AI-generated** (July 2026) and
"update" (May 2026). It was therefore treated as untrusted until the Russian Wikipedia article
confirmed the same 16/30/240/2 numbers. They do.

## Leagues

| id | name | level | size | rounds | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| KAS1 | Premier Liga | 1 | 16 | 30 | — (top) | 2 |
| KAS2 | Pervaya Liga | 2 | 14 | 26 | 2 | to Second League (count unverified) |

Both sizes match our rows: 16 for the top flight (new for 2026) and 14 for the second tier. One
table at each level, double round-robin (16 → 30 rounds → 240 matches; 14 → 26 rounds).

## The 2026 expansion

This is the one thing that looks like a bug but is not. The Premier League was **14 clubs** through
2025 and expanded to **16** for 2026. To get there, 2025 ran an asymmetric transition:

- only the **bottom club** (Turan) was relegated;
- the **top three** of the First League were promoted (Caspiy as champion, Irtysh Pavlodar and one
  more).

From 2026 onward the shape is the normal **2 up / 2 down**: in 2026 Zhetysu and Kaisar were
relegated. A sim that replays 2025 with a 2/2 rule will field 15 clubs in 2026.

## Boundaries

| between | up | of which PO | down | of which PO | allocation | selection |
| --- | --- | --- | --- | --- | --- | --- |
| 1-2 | 2 | 0 | 2 | 0 | free | bottom_n |

No play-off in either direction in the current format: the First League's top two go up, the
Premier League's bottom two go down. 16 - 2 + 2 = 16; 14 - 2 + 2 = 14.

## Decisions

1. **`format.kind: "single"` at both levels.** Kazakhstan has no split and no championship
   play-off, unlike most post-Soviet leagues.
2. **`up: 2`, `down: 2`, `selection: "bottom_n"`.** No play-off places are encoded.
3. **`closed_down: true` for KAS2**, because the Second League is not in our list. The *number* of
   clubs the First League sends down could not be verified, so it is left out of the boundary
   rather than guessed (the README's rule: use null, explain in notes).
4. **`closed_down: false` for KAS1** (the First League is in our data).
5. **Not modelled:** Kazakhstan Cup, Super Cup, UEFA Champions League/Conference League places, and
   the stadium/financial licensing that the KFF tightened for the newly promoted clubs in 2026.

## Oddities

- **Reserve teams.** The First League regularly fields second teams (e.g. Aktobe-2). They cannot be
  promoted, so a naive "top two go up" will sometimes try to promote a club that is ineligible.
  This is the same pattern as Spain's filiales and needs an eligibility flag, not a new rule.
- The First League's club count has swung between 7 and 16 in the last decade (2020 was played in
  two groups of seven). "14" is the 2025-26 figure, not a constant.
- The national league is administered by the QFL (Kazakhstanskaya Futbolnaya Liga) for the Premier
  League while the First League is run under the KFF umbrella; different rulebooks.
- Distances are extreme (Aktobe to Almaty is ~2,000 km), which is why the calendar is March–October
  and why winter fixtures do not exist.

## Confidence

**Medium.** The Premier League (16/30/240/2-down) is confirmed by two independent Wikipedia
language editions. The First League's 14 clubs and 2-up are single-sourced and no 2026 season page
exists, so its promotion count and its relegation count below are the weakest facts in this file -
the former is encoded, the latter is not.
