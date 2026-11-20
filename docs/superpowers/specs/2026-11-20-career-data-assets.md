# Career data assets — v1

Status: draft, 2026-11-20. Ties the research in `docs/research/` to the files the
game reads. Two specs own the semantics (season formats — including the
calendar — and competitions); this one owns the **files**.

## Principle

The game reads the database and `assets/data/*.json` only. Research files are the
audit trail, never a runtime source. Every asset is a **snapshot**: "agreed, not
current", refreshed by a manual pass, with the source and the season it belongs
to. Ids are Transfermarkt ids; a value we do not know is `null` with a note, not
a guess.

## Assets

| file | contents | source | refresh |
|---|---|---|---|
| `assets/data/league_regulations.json` | 284 leagues: season window (`start_md`/`end_md`), legacy `phases`, tiebreak, relegation, `format` (the league's stages), `inherited_from`, confidence, source, note | season-window + formats research | manual, yearly |
| `assets/data/league_pyramids.json` | 284 leagues: level, size, closed directions, format note; 108 boundaries with `up == down`, playoff counts, allocation | pyramid research + database topology | manual, when the DB changes |
| `assets/data/competitions.json` *(new)* | cups, super cups, internationals: id, kind, country/confederation, participants rule, `format` (same stage model), calendar, `out_of_scope` | cups + international research; TM ids from the canon | manual, yearly |
| `assets/data/access_lists.json` *(new)* | per confederation: association coefficients, rank bands with entry rounds, cup slots (`add`/`consume`/`none`), drop-down map, suspended associations | access-list research | manual, yearly (pinned to the previous season's ranking) |
| `assets/data/intl_calendar.json` *(new)* | **recurring rules, not a fixed list**: annual FIFA windows and multi-year tournaments (`every_years`, `anchor_year`, `start_md`/`end_md`, `applies_to`: `world` \| confederation \| country list) | FIFA calendar research (2026–2028) + the recurrence rule | manual, yearly |
| `assets/data/team_links.json` *(new)* | `reserve` flags, `parent_club_id` by id, the per-country promotion ceiling for reserve teams, `berth_via` overrides (Vaduz, Toronto, Vancouver, Wellington; `null` means "no continental berth") | database names + manual review | when the DB changes |

The database itself (`data/databases/default/open_football.sqlite`) stays the
source for leagues, clubs, players, squads and formations; the assets only
reference its ids.

## Field rules

- Dates are `MM-DD` everywhere except the FIFA calendar (`YYYY-MM-DD`).
  A missing value is `null` with `"precision": "day|month|none"`.
- A league row's `format` wins over its own `start_md`/`end_md`; the row window
  is recomputed from the format and the loader asserts equality.
- `phases` is **retained unread** after `format` lands, purely as the research
  audit trail; the engine never reads it.
- **Friendlies are generated, not data**: at season creation the career builds
  4–6 pre-season matches against clubs chosen by country and strength, seeded
  deterministically by the career seed, so they survive a save without an asset.
  Named pre-season tournaments are data when known and generated otherwise.
- The calendar loader **expands the recurrence rules** into concrete dates for
  the career seasons: annual events repeat by month and day, multi-year events by
  `every_years` from the anchor. After the last researched year (2028) the rule
  still applies and the expansion is marked as an approximation.
- Country names are normalised on load (`Türkiye`/`Turkey`, `USA`/`United
  States`, `Ireland`/`Republic of Ireland`, `Hongkong`/`Hong Kong`), because the
  research files and the database spell them differently.
- `out_of_scope` on a competition means it exists for berths but is never
  scheduled (the Brazilian regional cups, when added).
- Domestic→domestic berths (a regional cup winner entering another cup's round)
  live in `competitions.json` under the competition's `participants.berths`, not
  in `access_lists.json`, which is per confederation.
- Competitions that do not exist in a season are absent from that season's list
  (Wales' League Cup 2026-27, Peru's cup since 2021, Indonesia's since 2018-19).
- `up == down` on every boundary; a one-season structural change is recorded in
  the note, never applied as a permanent boundary.
- `reserve` teams link to their parent **by id**, never by name (Willem II is a
  club, not a reserve side).
- `berth_via` exists only where a club's qualifying country differs from its
  league's country.
- **Post-import merges.** `AR3R → AR3F` (one 37-club Torneo Federal A) and
  `CL2Z → CL2F` (one 14-club Chilean Segunda) are applied **after every database
  import**: the step moves the clubs in `database.sqlite` and `canon.db`, names
  the merged league and drops the extra row. A rebuild from the scraper canon
  re-creates the split rows, because the canon still carries them as separate
  competitions, so the merge is a mandatory post-step, not a one-off.
- Suspended associations are a list separate from the berth table, so the
  `politics_mode` flag can include or exclude them without touching the data.

## Loaders and validation

- One loader per asset under `scripts/data/` (`LeagueRegulations` exists;
  `Competitions`, `AccessLists`, `IntlCalendar`, `TeamLinks` follow), each with
  a static cache and a `last_error`.
- A validation test per asset, run headless:
  - windows: `MM-DD`, stage windows inside the format window **after inference**
    (null bounds and year rolls allowed), row == format;
  - boundaries: `up == down`, sizes equal the database team counts;
  - calendar: windows within one confederation don't overlap, every window and
    tournament has an `applies_to`, and a fixture never falls inside one that
    applies to its competition (runtime check);
  - forms: every `format` parses, entrant clauses resolve on a synthetic
    league, promotion/relegation slots sum to the boundary counts;
  - access lists: 55 coefficients, bands cover ranks 1–55 with no gap, every cup
    slot has a `mode`, every drop-down points at an existing stage;
  - team links: the parent exists, is in the same country, is not itself a
    reserve team; `berth_via` clubs exist.
- The merge scripts that build the assets from `docs/research/` are **not** in
  the repository (decision taken earlier); the research files are the audit
  trail and the assets are committed.

## Out of scope for the data

- **German level 4 is complete**: the database carries all five Regionalliga rows
  (`RLB3`, `RLN4`, `RLSW`, `RLN3`, `RLW3`). `RLN3`/`RLW3` were imported from
  Transfermarkt on 2026-11-20; `RLN`/`RLW` are the 1963–74 competition and must
  not be used.
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
