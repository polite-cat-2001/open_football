# Greece — football pyramid, 2026-27

Greece is a two-phase league: a 26-round regular season, then three separate mini-leagues that
decide the title, the last European place and the two relegations. Both our rows are correct in size
for 2026-27, but level 2 changed shape this season.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | GR1 | Super League 1 (Stoiximan) | 14 | double RR + 4/4/6 split | 26 + 6/6/10 | — (closed) | 2 (both via play-outs) |
| 2 | GRS2 | Super League 2 (Superbet) | 16 | one group, double round robin | 30 | 2 direct | 4 (to Gamma Ethniki) |

## Level 1 — Super League 1

- 14 clubs, 26 rounds (two rounds of 13 match days, opponents drawn per round).
- **Second phase:**
  - **Championship play-offs** — top 4, play each other twice (6 games), **points and goals carried
    over in full**; the champion is decided here on 32 games.
  - **Europe play-offs** — 5th to 8th, 6 games, but they **enter with half their regular-season
    points**. The winner only gets a Conference League place if the cup winner is already in the top
    four (in 2025-26 OFI won the cup and the play-off became moot).
  - **Relegation play-outs** — 9th to 14th, 10 games, deciding **which two clubs go down**. The
    regular-season bottom club is not automatically relegated; it has to lose the play-out.
- 2025-26 outcome for reference: AEK champions in the fourth championship match day; Lamia and
  Athens Kallithea relegated through the play-outs.

## Level 2 — Super League 2

- **16 clubs in a single group**, 30 rounds, no play-offs and no play-outs.
- Top two promoted directly to Super League 1 (Iraklis and Kalamata in 2026, as north and south
  champions of the previous, two-group format).
- Bottom four relegated to Gamma Ethniki (level 3, not in our rows).
- **B teams** (PAOK B, Asteras Tripolis B, Olympiacos B) can be relegated but **cannot be
  promoted**; if a B team finishes in the top two, the promotion place passes down.

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| GR1 | Super League 1 | 1 | 1 | 14 | 14 | correct |
| GRS2 | Super League 2 | 2 | 2 | 16 | 16 | correct |

Conflict of shape, not of size: Super League 2 was **two groups (North/South) in 2025-26** and is a
single 16-club group in 2026-27, with the play-offs and play-outs removed in the same reform.

## Caveats

- The three-way split is not a "top half / bottom half" split: the middle group (5th–8th) plays for a
  European place with **halved** points, so any generic split model gets the standings wrong.
- Relegation is genuinely decided by the play-out group; a model that relegates 13th and 14th from
  the regular season is wrong here.
- One detail I could not verify: whether the relegation play-outs also carry regular-season points in
  full. The safe reading is that the bottom two of the play-out group go down.

## Sources

- https://en.wikipedia.org/wiki/2026%E2%80%9327_Super_League_Greece
- https://en.wikipedia.org/wiki/2025%E2%80%9326_Super_League_Greece
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Super_League_Greece_2
- https://en.wikipedia.org/wiki/Super_League_Greece_2
