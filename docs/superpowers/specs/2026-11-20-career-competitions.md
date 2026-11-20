# Career competitions (container) — v1

Status: draft, 2026-11-20. Research: `docs/research/competition-formats/`
(national cups, super cups, international club competitions). Builds on
`2026-11-20-career-season-formats.md` (stages, clauses, aggregate).

## Problem

A career season is one league. Real clubs play a league, a national cup, a
super cup and, for the best, a continental competition at the same time. The
league model cannot express that: the snapshot, the table and "next fixture"
all assume one competition.

## Model

A season is a **set of competitions**. The league is one of them and stays the
only one with promotion and relegation.

```json
"competitions": [
  {"id": "ES1", "kind": "league", "role": "primary"},
  {"id": "ESCUP", "kind": "cup", "country": "Spain",
   "participants": {"country": "Spain", "tiers": [1, 2, 3, 4]},
   "format": {"stages": [ ... single-leg knockout with byes ... ]}},
  {"id": "ESSSC", "kind": "super_cup", "country": "Spain",
   "participants": {"from": ["ES1", "ESCUP"], "rule": "winners_and_runner_up"},
   "format": {"stages": [ ... four-team mini-tournament ... ]}}
]
```

- `kind`: `league` | `cup` | `super_cup` | `international` | `friendly` |
  `pre_season`.
- **Non-competitive matches.** `friendly` is a single match with a generated
  opponent (4–6 in the pre-season, chosen by country and strength); it has no
  table, no winner, no berth, and never touches the league standings or the
  form strip, but it does count for player condition and can injure. A
  `pre_season` competition is a named tournament (4–8 clubs, knockout or a small
  group, possibly international) with a trophy but again no berth and no effect
  on any table. Both are scheduled before the first competitive fixture and are
  marked `non_competitive: true`, which every table, form and review reader
  excludes.
- A country may have **more than one cup**, and each is its own `kind: "cup"`
  competition: England has the FA Cup and the EFL Cup, Portugal the Taça de
  Portugal and the Taça da Liga, Scotland two, Brazil has regional cups
  (Copa do Nordeste, Copa Verde) beside the Copa do Brasil. The berth map names
  the specific competition, never "the national cup".
- The set of competitions is **per season**, not a constant: Wales' League Cup
  is cancelled for 2026-27, France's Coupe de la Ligue (2020), Argentina's Copa
  de la Liga (2025) and Mexico's Copa MX (2020) are abolished. A berth may also
  feed another domestic cup (Brazil's regional cup winner enters the Copa do
  Brasil third round), not only a continental one.
- `role`: `primary` marks the career league (the one with promotion and
  relegation, the one the hub tile shows by default).
- `participants` rules: `league` (its clubs), `country` + `tiers` (every club of
  those tiers), `from` (winners/runners-up of named competitions), `berths`
  (the qualification graph, below). The resolved set is the **first stage's**
  `entrants`, so a competition may state one or the other, never both.
- `kind` extension: `fixture_list` is a stage kind, not a competition kind (see
  below), so the two enums do not collide.
- `format` is the same stage model as the league formats: `league`/`group`/
  `knockout` stages, clauses, `legs`, conditional stages. Two additions:
  - `kind: "fixture_list"`: a fixed pairing list (the UEFA league phase). The
    list is generated once from pots (`pots: [[clubs], ...]`, `matches_per_club`,
    `max_per_country`), stored in the save, and never re-paired. A round-robin
    builder cannot produce it.
  - `legs` per round is already there; a two-legged **final** (Brazil) is just
    `{"name": "final", "legs": 2}`.
- Calendar: each competition has its own window; fixtures interleave. The
  career season window is the **union** of the primary league and every
  competition the club enters (formats spec), so a UCL qualifier in early July
  widens the season instead of falling outside it.

## Engine

- Every fixture gains `competition` (the id above) besides `stage`, `group`,
  `stage_round`. Ids: `<competition>:<stage>:<round>-<n>`, except a primary
  league with no `format`, which keeps `r%02d-%02d` so its results survive the
  migration.
- `career.schedule` becomes the union of the competitions the career club is
  in. Other clubs' fixtures of those competitions are generated too, because a
  bracket needs their results.
- Tables are per competition: the view becomes `{competition, stage, stages,
  group, exclude_round}`, `competition` defaulting to the primary league. The
  hub shows the primary league by default with a tab per other competition, and
  each competition's tab contains that competition's stage tabs (the aggregate
  sits inside the primary league).
- "Next fixture" is the earliest unplayed fixture across all competitions.
  `season.next` carries `competition` and the competition's label.
- The season review: primary league (table, promotion/relegation) plus one
  block per other competition (winner, final score). Non-competitive
  competitions appear as a single "pre-season" line (matches played, no table).
- Promotion and relegation read the primary league only.
- Friendly and pre-season fixtures are excluded from `_played_fixtures`, from
  the form strip, from `last_played_round` and from every standings call; they
  only feed player condition.
- When the club is eliminated from a cup or continental competition, the rest
  of that bracket is **generated and simulated immediately**, so the winner
  exists for next season's berths; the competition then drops out of the hub
  tabs.

## Qualification (the hard part)

Next season's berths depend on results across **many** leagues: the top N of
each league enters the continental competition, cup winners enter another.

**Decision: a background world season.** Once per season the engine simulates
every league it needs (all 106 countries) in bulk and stores each final table in
`career.data["world_seasons"]`, keyed by the career season, so the run happens
once and survives a save. The Poisson sim is cheap (~40k fixtures), and the
stored tables also give the transfer market a real world instead of a strength
guess. The run is anchored to the **career club's** boundary (one date for every
league, read as of that date), happens after the domestic review and before the
next season's berths are allocated, and produces **tables only**: other leagues'
membership is frozen for the save. The player's own league is not re-simulated:
its table is the one the career played.

Cups add a smaller version of the same problem: their fields include clubs from
tiers we do not fully have in the database. The cup field is therefore built
from the clubs that exist (all clubs of the named tiers in the snapshot), and
the missing amateur rounds are not modelled.

## International competitions

Research in `docs/research/competition-formats/international.md`. Three groups
by cost:

- **Group + knockout** (CAF, CONCACAF, AFC Two, AFC Challenge League, OFC,
  **Libertadores and Sudamericana**): the existing stage model covers them; only
  the berth graph and two-legged ties are new. CONMEBOL belongs here, not in the
  pot-league group.
- **Pot league + knockout** (UEL, UECL): need `fixture_list`, the 9–24 play-off
  and cross-competition transfers.
- **Pot league + regions + centralised finals** (UCL, AFCL Elite): the same plus
  a regional split and a qualification graph across all countries.

Recommended order (agreed): container and domestic cups → super cups →
berths with the background world season → group+knockout internationals →
pot-league internationals → UCL/AFCL Elite.

The global and secondary layer (Club World Cup, Intercontinental Cup, the
continental super cups, the CONCACAF feeders and the OFC Professional League) is
**not** part of the 12; it is researched in
`docs/research/competition-formats/international-global.json` and scheduled as
phase 7.

## Full qualification network (agreed)

The international cut models the real qualification chain, not direct entrants
only.

- **Access list** from the association coefficients: associations 1–5 → four
  clubs, 6 → three, 7–15 → two, 16–55 → one, plus the two performance spots and
  the title-holder berths. The coefficients and the rules are a new asset
  (`assets/data/access_lists.json`), a snapshot with the season it belongs to.
  The list is pinned to the coefficient ranking **finished at the end of the
  previous season**, not the live table. Three special cases: Russia keeps its
  coefficient rank and the zero-club ban lives only in the suspension list, so
  `kind` mode can hand it its berths; Liechtenstein has no league and sends
  only its cup winner (UECL Q2); England is the only association whose second
  cup earns a berth (EFL Cup → UECL play-off round).
- **Paths**: Champions Path and League Path, Q1–Q3 and the play-off round,
  every round two legs with the aggregate, no away goals, extra time and
  penalties on a level tie.
- **Cup slots are not uniform.** A cup berth is `add` (an extra place, e.g.
  England's FA Cup → UEL league phase) or `consume` (it takes one of the
  association's league places: Chile and Uruguay give the cup winner the
  country's last Libertadores spot). A cup winner may also earn **nothing**
  continental (Vietnam → ASEAN Club Championship, New Zealand, the Philippines,
  Cambodia; Costa Rica only a Recopa place; Russia none under the ban). Some
  countries have **no cup at all** (Peru since 2021, Indonesia since 2018-19).
  The map stores `mode: add | consume | none` per slot.
- **Drop-downs exist only where the confederation has them.** UEFA: UCL →
  UEL → UECL (Q1/Q2 losers, Q3 → UEL play-off, play-off → UEL league phase,
  UEL play-off → UECL league phase). CONMEBOL: Libertadores third-stage losers
  → Sudamericana **group stage**, third-placed group teams → Sudamericana
  **knockout play-off**. AFC: Elite play-off losers → CL Two groups, CL Two
  preliminary losers → Challenge League groups, and the winners climb back up.
  CAF, CONCACAF and OFC have **no** drop-down in 2026-27 (CAF's historic
  Champions League → Confederation Cup transfer was removed in the reformat;
  verify before modelling it). The map is per confederation data, not a rule.
- **Data**: association coefficients (a snapshot like the league windows, with
  the source and the season), the access list, the path assignment rules (a
  club's domestic position plus its association rank), and the drop-down map.
- **Engine**: the enqueue is a generated entrant (like lazy stage generation),
  recorded in `stages_generated` so it is not re-applied; the tie is the same
  two-legged knockout we already specify.
- **Prerequisite**: the background world season — the access list needs every
  league's final table, and the path assignment needs every club's position.

## Edge cases (agreed)

- **Politics mode**: a simulation flag `politics_mode` = `kind` (default) |
  `political`. `kind` ignores political suspensions: every association gets its
  coefficient berths, Russia included. `political` applies the suspension list:
  Russia and Belarus get zero berths and their clubs never enter a continental
  competition. The ban list is stored separately from the berth table, so both
  modes read the same data. The flag lives in the save; the shipped game
  defaults to `kind` (decided 2026-11-21).
- **Reserve and youth teams**: `reserve: true` on the team plus `parent_club_id`
  (a data link built once and reviewed **by id** — names lie, e.g. Willem II is
  a club, not a reserve side). Two modes, a save flag `reserve_teams_mode`:
  - `linked` (default, realistic): a reserve team plays its league but is never
    promoted into its parent's division; its promotion ceiling is a per-country
    field (default: not the top division; Germany and Spain: not the top two);
    it does not enter the domestic cup.
  - `independent`: reserve teams are ordinary clubs, unlinked, can be promoted,
    meet the first teams and play the cup.
  The shipped game defaults to `linked` and exposes the toggle (decided
  2026-11-21).
- **Cross-border clubs**: a club may play in another country's league. Its berth
  path is a per-club override (`berth_via`), because the league's country is not
  always the qualifying country: Vaduz qualifies only through the Liechtenstein
  Cup (not Switzerland), Toronto and Vancouver through the Canadian
  Championship (not the US Open Cup), Wellington Phoenix has no continental
  berth. Cardiff, Swansea, Wrexham, Monaco and FC Andorra qualify through their
  league's country, as today.

## Limitations to state in the UI and the wiki

- Cup fields are built from the clubs in the database; early amateur rounds are
  not modelled.
- A cup or super cup that does not exist in the snapshot (Mexico) stays absent.
- Two-legged finals are supported; extra time only in the last leg (penalties after
  it). **Away goals are off by default; the CONCACAF Central American Cup and
  Caribbean Cup use them**, so the rule is per-competition data, not a global
  switch.
- The background world season is a simulation, not a real table.
- Brazilian state championships are out of scope for now (the club plays the
  national league only).
- National-team competitions (qualifiers, World Cup, Euro, Copa América, AFCON,
  Asian Cup) are out of scope; only their calendar pauses are modelled, from
  `assets/data/intl_calendar.json`. Player call-ups are not modelled.

## Phases

0. **Calendar** (the open work on the branch): boundary-based season start,
   tests and goldens green. Nothing below starts before this.
1. **Container and stage engine**: competitions in the save, fixtures with
   `competition`, the union schedule, per-competition standings, hub tabs,
   review blocks; the stage engine from the formats spec lands here, with the
   league as the only competition (no behaviour change for single-table
   leagues). This replaces the formats spec's phases 2 – 4; the two specs share
   one `format` object. League competitions keep their rows in
   `assets/data/league_regulations.json`; cups, super cups and internationals
   live in a new `assets/data/competitions.json`. The generated pre-season
   friendlies land here too: they test the non-competitive path without any
   data.
2. **League formats data**: the 58 encoded formats.
3. **Domestic cups**: single-leg knockout with byes, the two-legged attachment,
   Turkey's group hybrid; all **106 countries** from the cups research (17 in
   `national-cups.json`, 89 in `cups-*.json`). The berth `mode`
   (`add`/`consume`/`none`) is not needed here; it lands with the berth pass in
   phase 5 (decided 2026-11-21).
4. **Super cups**: two-team single match and the four-team mini-tournament, plus
   named pre-season tournaments when their data is known.
5. **Berths and the background world season**; then group+knockout
   internationals.
6. **Pot-league internationals**: UEL and UECL first, then UCL and AFC Elite in
   the same phase. **All 12** confederation competitions are in the first
   playable version (decided 2026-11-21): the pot-league engine is shared, the
   extra cost of UCL is the cross-country qualification graph, of AFC Elite the
   regional split and centralised finals.
7. **Global and secondary competitions**: the nine in
   `docs/research/competition-formats/international-global.json` (FIFA Club World Cup,
   Intercontinental Cup, UEFA and CAF Super Cups, Recopa Sudamericana, CONCACAF
   Central American Cup, Caribbean Cup, CFU Club Shield, OFC Professional League),
   researched before phase 0 and scheduled after the 12. The Club World Cup is
   quadrennial (2029 next), so the allocator must support "not this season". The
   OFC global berth comes from the Professional League winner, not the OFC
   Champions League.

## Open decisions

- **Result adjustments** (points deductions, awarded matches) are not modelled
  now; the door stays open through one extension point: a per-club, per-season
  `adjustments` list applied when a table is built (the table builder already
  sums from results, so it is one lookup away). No data is collected until the
  mechanics exist.
- CAF drop-down: the 2026-27 sources show none, but the historic Champions
  League → Confederation Cup transfer existed until the reformat. Verify before
  modelling it; today the map has no CAF entry.
- Belarus in the access list: the report gives it one Champions League club
  although Belarusian clubs are suspended. The ban list handles it in
  `political` mode, but the berth table itself needs a check.
- Whether the club's cup participation is visible on the dashboard before the
  first round (a "cup draw" tile) or only when a fixture exists.
