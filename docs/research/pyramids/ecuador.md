# Ecuador — football pyramid 2026

Scope: levels 1–2 as carried in our database (LigaPro Serie A, Serie B). No cups, no CONMEBOL
competitions.
Research date: 2026-11-20. The 2026 season is complete (champion: Independiente del Valle).

## Pyramid at a glance

| id | League | Level | Clubs | Rounds per club | Shape |
|----|--------|-------|-------|-----------------|-------|
| EC1N | LigaPro Serie A | 1 | 16 | 30 + 10 (or 6) | one 30-round first stage, then top 6 / 7th–10th / bottom 6 |
| EC2L | LigaPro Serie B | 2 | 12 | 22 + 10 | one 22-round first stage, then top 6 / bottom 6 |

Both rows are correct: **16 / 12**.

## Serie A: one season, three final groups

1. **First stage** — 16 clubs, double round-robin, **30 matches** (20 February – 14 September
   2026).
2. **Final stage** — the table is cut into three groups, points carried:
   - **championship hexagonal**, top six, double round-robin, **10 more → 40**; decides the title
     and the Libertadores places;
   - **Copa Sudamericana quadrangular**, 7th–10th, double round-robin, **6 more → 36**; one
     Sudamericana place;
   - **relegation hexagonal**, bottom six, double round-robin, **10 more → 40**; bottom two go
     down.

This is not Apertura/Clausura: there is one champion and one 30-round qualifying table. The JSON
uses `kind: "split"` with `split_after: 30` and `groups: [6, 4, 6]`.

## Serie B: 22 rounds, then two groups of six

1. **First stage** — 12 clubs, double round-robin, **22 matches**.
2. **Promotion round** — top six, double round-robin, **10 more → 32**; top two promoted.
3. **Relegation round** — bottom six, double round-robin, **10 more → 32**; bottom two relegated.

Points are carried into both groups (the 2025 tables start at the first-stage totals).

## Boundaries

| between | up | of which PO | down | of which PO | allocation | selection |
|---------|----|-------------|------|-------------|------------|-----------|
| 1–2 | 2 | 0 | 2 | 0 | free | bottom_n |

Two direct places each way. No play-offs.

## Oddities

- **Relegation in Serie A is a mini-league, not a table cut.** The bottom six replay a 10-match
  hexagonal carrying their points; its bottom two go down. That is why a club can be last after
  30 rounds and still survive.
- **The Serie B league page is stale.** Its prose still describes "top four after both stages" and a
  playoff for promotion. The 2025 season used the six-team promotion round, and the 2025 final
  tables (32 matches per club, points carried) are the evidence.
- **Reserve sides:** Independiente Juniors is in Serie B and cannot be promoted. In 2025 it
  finished 3rd in the promotion round, so the second promotion place passed down the table. A
  naive "top two go up" promotes an ineligible club.
- The 2026 Serie A relegation hexagonal was still being played at the research date, so the two
  relegated clubs are not yet fixed in the sources I read.

## Sources

- https://en.wikipedia.org/wiki/LigaPro_Serie_A — 16 clubs; "the current format ... consists of
  three stages"; first and second stage double round-robin; relegation "after the Second Stage"
  (older prose, superseded by the 2026 season article)
- https://en.wikipedia.org/wiki/2026_LigaPro_Serie_A — 2026 format: 30-match first stage, top six
  championship hexagonal, 7th–10th Sudamericana quadrangular, bottom six relegation hexagonal,
  points carried, two relegated
- https://en.wikipedia.org/wiki/Ecuadorian_Serie_B — 12 clubs in 2026; promotion to Serie A,
  relegation to Segunda Categoria
- https://en.wikipedia.org/wiki/2025_Ecuadorian_Serie_B — 12 clubs, 22-round first stage, six-team
  promotion and relegation rounds, 32 matches, points carried, reserve team ineligible

## Confidence

**High.** The 2026 Serie A format is described in detail in its season article (and matches the
2026 tables), and the Serie B shape is confirmed by a completed season. The only soft spot is the
regional prose on the two league index pages, which I flag rather than follow.
