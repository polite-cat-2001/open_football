# League pyramids research

One report per country, used to build `assets/data/league_pyramids.json`.
Each country has two files: `<slug>.md` (human) and `<slug>.json` (machine).
Slug: lowercase, spaces and punctuation replaced by hyphens (e.g. `czech-republic`, `chinese-taipei`).

## What we collect

Only the leagues that exist in our database (the ids are given in the task).
For every league: our level, the real size for the season, whether it is closed
in each direction, its format, and its play-offs.
For every boundary between adjacent levels: how many clubs move each way and how
those places are decided.

## JSON shape

```json
{
  "country": "England",
  "season": "2026-27",
  "sources": ["https://..."],
  "leagues": [
    {"id": "GB1", "name": "Premier League", "level": 1, "size": 20,
     "closed_up": true, "closed_down": false,
     "format": {"kind": "single", "rounds": 38},
     "playoff": null}
  ],
  "boundaries": [
    {"upper": 1, "lower": 2, "up": 3, "up_playoff": 1, "down": 3, "down_playoff": 0,
     "allocation": "free", "selection": "bottom_n", "note": "2 direct + 1 play-off"}
  ],
  "conflicts": [],
  "confidence": "high",
  "notes": ""
}
```

- `up` — clubs promoted from the lower level to the upper; `down` — clubs relegated
  from the upper level to the lower. `up_playoff` / `down_playoff` — how many of those
  places are decided by a play-off rather than the table.
- `allocation`: `free` (any club), `by_geography`, `by_affiliation`, `by_licence`, `none`.
- `selection`: `bottom_n`, `playoff`, `promedio`, `average_table`, `other` (+ note).
- `closed_up` / `closed_down`: true when no sporting route exists in that direction.
  A league with no league above (or below) in our list is closed in that direction,
  even if real clubs do move to a division we do not have.
- `format.kind`: `single`, `split`, `apertura_clausura`, `groups`, `cup_phase`, `other`.
  Details go into the same object: `rounds`, `split_after`, `groups`, `points_carry`, `stages`.
- `playoff`: `null` or `{"kind": "title|promotion|relegation|europe", "entries": "3-6", "legs": 1, "note": ""}`.

## Rules

- Sources: the country's own Wikipedia first, English Wikipedia to cross-check; official
  league sites when a count is contested. Cite the URLs actually used.
- Never guess a number. Use `null` and explain in `notes`.
- Our `level` and `size` may be wrong — confirm and correct them.
- Our ids must be used exactly. If a real league is missing from our rows, still describe it
  in `notes` (and in the markdown), but do not invent ids outside our list.
- No cups, no continental competitions.
- Put anything that contradicts another source into `conflicts`.
