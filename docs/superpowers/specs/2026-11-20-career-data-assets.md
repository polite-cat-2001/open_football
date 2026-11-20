# Career data assets — v1

Status: draft, 2026-11-20. Ties the research in `docs/research/` to the files the
game reads. Three specs own the semantics (season formats, competitions,
calendar); this one owns the **files**.

## Principle

The game reads the database and `assets/data/*.json` only. Research files are the
audit trail, never a runtime source. Every asset is a **snapshot**: "agreed, not
current", refreshed by a manual pass, with the source and the season it belongs
to. Ids are Transfermarkt ids; a value we do not know is `null` with a note, not
a guess.

## Assets

| file | contents | source | refresh |
|---|---|---|---|
| `assets/data/league_regulations.json` | 277 leagues: season window (`start_md`/`end_md`), legacy `phases`, tiebreak, relegation, `format` (the league's stages), `inherited_from`, confidence, source, note | season-window + formats research | manual, yearly |
| `assets/data/league_pyramids.json` | 277 leagues: level, size, closed directions, format note; 108 boundaries with `up == down`, playoff counts, allocation | pyramid research + database topology | manual, when the DB changes |
| `assets/data/competitions.json` *(new)* | cups, super cups, internationals: id, kind, country/confederation, participants rule, `format` (same stage model), calendar, `out_of_scope` | cups + international research; TM ids from the canon | manual, yearly |
| `assets/data/access_lists.json` *(new)* | per confederation: association coefficients, rank bands with entry rounds, cup slots (`add`/`consume`/`none`), drop-down map, suspended associations | access-list research | manual, yearly (pinned to the previous season's ranking) |
| `assets/data/intl_calendar.json` *(new)* | FIFA windows and tournament dates per year | FIFA calendar research | manual, yearly |
| `assets/data/team_links.json` *(new)* | `reserve` flags, `parent_club_id` by id, `berth_via` overrides (Vaduz, Toronto, Vancouver, Wellington) | database names + manual review | when the DB changes |

The database itself (`data/databases/default/open_football.sqlite`) stays the
source for leagues, clubs, players, squads and formations; the assets only
reference its ids.

## Field rules

- Dates are `MM-DD` everywhere except the FIFA calendar (`YYYY-MM-DD`).
  A missing value is `null` with `"precision": "day|month|none"`.
- A league row's `format` wins over its own `start_md`/`end_md`; the row window
  is recomputed from the format and the loader asserts equality.
- Competitions that do not exist in a season are absent from that season's list
  (Wales' League Cup 2026-27, Peru's cup since 2021, Indonesia's since 2018-19).
- `up == down` on every boundary; a one-season structural change is recorded in
  the note, never applied as a permanent boundary.
- `reserve` teams link to their parent **by id**, never by name (Willem II is a
  club, not a reserve side).
- `berth_via` exists only where a club's qualifying country differs from its
  league's country.
- Suspended associations are a list separate from the berth table, so the
  `politics_mode` flag can include or exclude them without touching the data.

## Loaders and validation

- One loader per asset under `scripts/data/` (`LeagueRegulations` exists;
  `Competitions`, `AccessLists`, `IntlCalendar`, `TeamLinks` follow), each with
  a static cache and a `last_error`.
- A validation test per asset, run headless:
  - windows: `MM-DD`, stage windows inside the format window, row == format,
    no fixture falls inside a FIFA blackout (runtime check, not a data check);
  - boundaries: `up == down`, sizes equal the database team counts;
  - forms: every `format` parses, entrant clauses resolve on a synthetic
    league, promotion/relegation slots sum to the boundary counts;
  - access lists: 55 coefficients, bands cover ranks 1–55 with no gap, every cup
    slot has a `mode`, every drop-down points at an existing stage;
  - calendar: windows don't overlap, tournaments have a confederation;
  - team links: the parent exists, is in the same country, is not itself a
    reserve team; `berth_via` clubs exist.
- The merge scripts that build the assets from `docs/research/` are **not** in
  the repository (decision taken earlier); the research files are the audit
  trail and the assets are committed.

## Out of scope for the data

- Result adjustments (points deductions, awarded matches): no data is collected
  until the mechanics exist; the extension point is a per-club, per-season
  `adjustments` list in the table builder.
- Club identity changes (renames, dissolutions, shared ownership): the database
  snapshot is fixed.
- Women's competitions, youth squads, national teams: no data.
- Brazilian state championships: deferred (ids known: BCP1, BRCG, BRCM, BRRS,
  BRCB, plus the other 22 states to research).

## Order

1. `league_regulations.json` format + `competitions.json` (league formats first,
   then cups and super cups).
2. `team_links.json` (reserve flags and the four `berth_via` clubs).
3. `access_lists.json` and `intl_calendar.json` when the international cut
   starts.
