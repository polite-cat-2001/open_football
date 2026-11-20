# Career season formats (slice c) — v3.1

Status: v3 revised after three audits, the last one by attempting to encode all
23 in-scope leagues. Not implemented. Order starts with the calendar slice.

## Scope

- 25 rows carry `phases: "apertura_clausura"`; the label is replaced by
  `format`. Research: 10 are really Apertura/Clausura, the rest are one table,
  zones, groups, or paths.
- `AR3F` is now the merged **Torneo Federal A**: one 37-club competition (the
  former `AR3R` Reválida row was merged into it), with a Campeonato path and a
  Reválida path fed by the losers. It stays `out_of_scope: true` until its
  two-path format is encoded in phase 1, so the game never plays it as a
  37-club round-robin. `M191`/`M21A` stay single-table (no calendar). Tier-99
  youth leagues (18 rows) are not career leagues at all: excluded from creation
  and from the transition's league list.
- Chile's `CL2Z` (a 2-club zonal play-off group) is merged into `CL2F` as one
  14-club level 3; the empty row is gone from the database, the asset and the
  canon.
- Out: cups, continental competitions, national teams, the Costa Rica/Nicaragua
  cross-division play-off, per-phase transfer rules.

## Data model

```json
"format": {
  "season": "2026",
  "proxy": false,
  "start_md": "07-16", "end_md": "05-24",
  "champion": "aggregate",
  "aggregate": ["apertura", "clausura"],
  "stages": [
    {"id": "apertura", "kind": "league", "label": "Apertura",
     "start_md": "07-16", "end_md": "11-22", "precision": "day",
     "rounds": 1,
     "entrants": [{"rule": "all"}],
     "champion": "table"},
    {"id": "clausura", "kind": "league", "label": "Clausura",
     "start_md": "01-09", "end_md": "04-26", "precision": "proxy",
     "rounds": 1, "entrants": [{"rule": "all"}], "champion": "table"},
    {"id": "title", "kind": "knockout", "label": "Liguilla",
     "start_md": "11-25", "end_md": "12-13",
     "entrants": [{"rule": "top", "from": "apertura", "n": 8}],
     "rounds": [{"name": "qf", "legs": 2}, {"name": "sf", "legs": 2},
                {"name": "final", "legs": 2}],
     "champion": "winner"}
  ],
  "relegation": [{"rule": "none"}],
  "promotion": [{"rule": "none"}]
}
```

### Rules

- **Season window**: `format.start_md`/`end_md` win over the row. `end_md <
  start_md` means the season ends in the following year. The row's own
  `start_md`/`end_md` are **recomputed** to equal the format window for every
  league that has a format, and the validator asserts the equality. The note
  says the format supersedes the row. `row_is` (`league` | `phase`) stays a
  research fact only; it changes nothing in the engine.
- `start_md`/`end_md` on a stage: either bound may be `null`; `precision` is
  `day` | `month` | `none`, and `proxy: true` separately marks a previous-season
  estimate. An undated first stage is anchored at `format.start_md`; an undated
  stage between dated ones takes the gap; **consecutive undated stages split
  that gap evenly**; a trailing undated stage is spread up to `format.end_md`.
  A stage whose `start_md` is earlier in the year than its predecessor rolls
  +1 year.
- `format.start_md`/`end_md`: either bound may be `null` with `format.precision`
  (`day` | `month` | `none`). A null end means the season ends at the last known
  stage end; a null start means the season starts at the first stage's start.
- `champion` at format level: `aggregate` | `stage:<id>` | `none`; at stage
  level: `table` | `winner` | `none`. A `group` stage must be `none`; a `league`
  stage's champion is its table leader; a `knockout` stage's is `winner`.
- `aggregate`: the stages summed into the annual table; listing a group stage
  sums all its groups. `from: "aggregate"` is a **reserved table name** usable
  in any clause (entrants, promotion, relegation) and always means that table.
- `out_of_scope: true` on the row (not `format: null`) marks a league that must
  not appear in career creation or in the promotion league list. The three seams
  are `team_catalog`'s career league listing, `CareerFactory.create` (a direct
  create must refuse too) and the transition's `career_leagues()` walk. An
  existing career in such a league keeps playing single-table.
- `stages`: chronological. Each stage has `kind` (`league` | `group` |
  `knockout`), `entrants`, `champion`, and either `rounds: 1|2|"unknown"` for
  table stages or `rounds: [{name, legs}]` / `"unknown"` for brackets.
- `groups: {sizes: [..], assign: "seeded"|"geographic"|"draw"|"fixed"}`: a
  **table partition**. `sizes` may be uneven (9/9/9/10). `seeded`, `geographic`
  and `fixed` split the resolved entrant order in order into `sizes` (geography
  is not modelled: a documented approximation); `draw` partitions the resolved
  order deterministically from the stage id.
  `schedule: {kind: "merged"|"per_group", interzonal: n}` says how fixtures are
  built: `merged` is one cross-group round-robin, `per_group` is inside groups,
  `interzonal` adds n cross-group rounds (Argentina, Panama, Argentina-2).
- `entrants` is an ordered list of clauses, earlier wins, duplicate clubs
  dropped keeping the first occurrence. Clause fields: `rule` (`all`, `top`,
  `winners`, `losers:<round name>`, `rest`), `from` (default: previous stage;
  `"aggregate"` allowed), `n`, `rank` (start position, default 1), `per_group`
  (evaluate the rule once per group of `from`, with `rank` inside each group),
  `best_of: n` (with `per_group`: the best n by table position across groups).
  Without `per_group`, `top` reads the stage's **combined** table.
- `size` is optional: the bracket size is the resolved entrant count padded to
  the next power of two. A bracket may shrink to 3, 1 or 0 entrants; a bracket
  with fewer than two distinct clubs is skipped.
- `bonus`: ordered rules `{from, rank: [..], value, per_group?, best_of?}`.
  Signed values; `rank` is a position inside a group table; `per_group` and
  `best_of` are mutually exclusive.
- `carry`: `{points: "none" | "full" | "half", goals: "carry" | "reset"}` — the
  carried record is shown in the receiving stage's table and visible wherever
  that table is read. A split league usually carries points and resets goals
  (Ecuador, Egypt); Uruguay's Segunda carries both.
- A split is expressed as several `group` stages, each fed by a rank range of
  the regular stage (`from: "regular", rank: 1, n: 6`; `rank: 7, n: 4`; ...).
  Ecuador's three groups (championship 6, Sudamericana 4, relegation 6) are the
  worked case; no new stage kind is needed.
- Conditional stages: `if: {skip_when: "shared" | "same_club", stages: [ids]}`:
  `shared` means one club holds every named stage's champion spot; `same_club`
  means the resolved entrants hold fewer than two distinct clubs.
  `champion_fallback: "shared" | "stage:<id>"` says who is champion when the
  stage is skipped.
- `promotion`/`relegation` are ordered lists of the same clause shape, with
  `rule`: `top`, `bottom`, `winner`, `average`, `unknown`, `none`, plus `from`
  (a stage or `"aggregate"`), `slots` (the total across groups, even when
  `per_group` is set), `per_group`, `rank` (start position) and
  `among: "champions"` (restrict a top/bottom rule to the named stages'
  champions). Rules apply in order and each takes its slots from clubs **not
  already named**, so overlapping rules do not over-relegate. `average` is
  simulated as the aggregate until club history exists, and the review says so.
  `[]` is only legal when the league has **no** format; a format league states
  `none` explicitly when nothing moves.
- **Roster size is the invariant.** For every boundary `up == down` (the
  pyramid asset's rule; 106 of 108 boundaries comply, the two exceptions are
  documented one-season structural changes: Serbia's 14→12 shrink, Chinese
  Taipei's expansion). A league's `format.promotion`/`relegation` slots must sum
  to the boundary counts; when they disagree the boundary wins and the review
  notes it, and `check_league_formats` asserts the sum. A league closed in a
  direction moves nobody, whatever its format says.
- **Parallel leagues.** A level may hold several equal leagues (Italy's three
  Serie C groups, Germany's regional leagues, France's N4/N5 groups). A
  boundary is level-to-level, not league-to-league: each lower league promotes
  its own qualifiers per its stage rules, and the upper league's relegation
  slots are filled by the leagues that sent clubs up — a league that sent `n`
  receives `n`, distributed in league-id order when several sent the same
  number. Geography is not modelled; the totals always equal the boundary's
  `down`. Australia's level 1→2 boundary is closed (licence league) and New
  Zealand's level-1 "9 up" is qualification for a phase, not promotion, so both
  move nobody.
- `unknown` is legal for a champion and for a promotion/relegation rule.

## Simulation contract

- `round` is a season-wide matchday index; all groups of a stage share one round
  number. **A round is a date window, not one date**: every fixture carries its
  own date inside it (Friday–Monday normally), and a fixture may be postponed
  to a free midweek when its club plays a cup or continental match. Each fixture
  also carries `stage`, `group` (or `""`) and `stage_round`
  (`round - stage_first_round + 1`).
- Ids: single-table leagues keep `r%02d-%02d`; a league with a format uses
  `<stage>:<round>-<n>`.
- `CareerFactory.standings(career, clubs, view := {})`:
  `{stage = "", stages = [], group = "", exclude_round = -1}`. Empty view = the
  current loop over every result (single-table leagues, byte-identical). A
  format league always passes an explicit view; the empty view is not used for
  them.
- `season.standings` = the current stage's table; `season.aggregate` = the
  annual table. The season-complete tile and `own_row` read the aggregate; the
  hub tile and the matchday delta read the stage. For a `group` stage,
  `season.standings` is the club's own group table and the overlay shows one tab
  per group; the combined table exists only for clause resolution, and the two
  matchday callers pass the club's `group`.
- Stages are generated lazily and idempotently: `career.data["stages_generated"]`
  stores `fixtures` | `skipped` per stage. Generation is a precondition of
  **any** `next_fixture` read: `snapshot` (on every hub open), `advance_to`,
  `play_next_match` and `_commit_advance` generate first. A conditional stage is
  evaluated only once every stage named in `if.stages` is produced; until then
  it is not recorded. A bracket that resolves to zero entrants is produced at
  generation. A stage counts as *produced* only when it was skipped or all its
  fixtures are played; a `champion: none` stage is produced when its last
  fixture is played.
- `next_fixture` returns the earliest unplayed fixture by date; the schedule is
  sorted `(date, id)` after an append. `_season_state` does the same (it
  currently scans in array order).
- `advance_to` keeps the **date sweep** (`date <= target`), not a round sweep:
  odd-club leagues skip rounds, and a round sweep strands them. `play_next_match`
  simulates the round's other fixtures whose date is on or before the club's own
  fixture date.
- **Fixture congestion**: a club never plays twice within two days. A fixture
  that clashes with a cup or continental match keeps its `round` and is re-dated
  to the nearest free midweek before the season end; every postponed fixture is
  played before the last round. The scheduler is per club, not per round.
- Schedule builders: `create`, `ensure_schedule` and `next_season` all switch to
  the stage builder when the league has a format.
- **Calendar blackouts**: a new asset `assets/data/intl_calendar.json` holds the
  FIFA international windows and the tournament dates per year (a snapshot with
  sources). Rounds are spread inside the league window **around** the blackouts:
  no fixture falls inside a window or a tournament, and the last round still
  ends on the real final matchday, so rounds compress around the pauses. A pause
  longer than 30 days advances in one step (the stage-gap skip rule).
- Results: `{home, away, aet?: {home, away}, pens?: {home, away}}`; ties carry
  `{tie, leg}` on the fixture. Extra time only in the last leg; the timeline
  renders `aet` as 91-120 and prints the deciding line.
- Normalisers in `Career.from_save`: fixtures gain `stage`, `group`,
  `stage_round`, `tie`, `leg`; results gain `aet`, `pens`; every numeric field,
  including the nested `aet`/`pens` and `tie`/`leg`, is cast to int so the
  round-trip stays byte-equal. `stages_generated` survives as arbitrary data.
  The store test round-trips a staged career.
- Version gates: the store and `from_save` accept `version <= SAVE_VERSION` and
  reject only newer saves; the message about migrations applies to newer saves.
  `from_save` must not stamp the current version before the migration runs —
  the migration is keyed on `schedule_version` only. `ensure_schedule` sets
  `data["version"] = SAVE_VERSION` once the migration succeeds.
- Migration resets results **only when the fixture-id set changes**; single-table
  leagues keep `r%02d-%02d`, so their results survive a date migration. The
  store keeps the `.bak` for exactly one save after loading an older version:
  `load_career` sets a one-shot flag, `save` skips both backup removals for that
  call and clears the flag, and `delete()` removes the `.bak` as well.
- `season_end` stays window-derived (day before the next boundary).
- `transition` reads the format's promotion/relegation rules; the constants are
  a fallback only for leagues without a format. `none` means no movement;
  `unknown` means no movement and a note in the review. **The roster size is
  preserved**: the clubs that leave a league equal the clubs that join it, taken
  from the boundary counts, not from the constants.
- `review` gains `champion` (`{id, name, logo}`) and `stages`
  (`[{id, label, champion, final}]`); `next_season` journals `review.champion`,
  not `table[0]`.
- `_played_fixtures` (form, last result) filters to table-producing stages.
  `matchday_state` lists the last **played** fixture's own round (a knockout leg
  shows that leg's result); only the round *label* falls back to the last table
  round.
- Matchday delta: suppressed per row when that club has `played == 0` in the
  "before" table (covers round 1 and byes).
- Skip rule: only a **next-stage** gap longer than 30 days jumps to that stage's
  first matchday; the off-season reel is untouched, and the jump commits without
  `_sim_start` so the tile re-renders from the new date.

## UI

- Table tile: current stage's table, labelled; aggregate when the season is
  complete.
- Overlay: tabs for top-level stages (all stages are top-level now: `parent` was
  dropped) plus an aggregate tab when a rule or the champion uses it.
- Review: league champion, one line per stage with a champion (or `none` /
  `unknown`), then the relegation table.
- One `stage_label`/`stage_round` formatter replaces the six literal
  `ROUND %d`, the `Round` info row and the lowercase `round %d`.
- `next` in the hub model gains `home_id`, `away_id` and `stage`; the three hub
  sites resolve the fixture by `fixture_id` from `career.schedule`.

## Migration, tests, goldens

- Phase 0 = the calendar slice agreed earlier; nothing below starts before it is
  green.
- `SAVE_VERSION` +1; `check_career_save_store` uses computed versions and loads
  the old fixture successfully (that is the point of the gate change).
- `check_career_creation._fixtures` gains `stage`/`group`/`stage_round`, with
  `stage_round` defaulting to `round`.
- `career_match_golden` is not regenerated (the test builds its fixture by hand).
  `career_creation`, `career_advance`, `career_hub` change only because of the
  calendar dates and the new fixture fields; ids for single-table leagues stay.
- `check_league_regulations` loses its `PHASES` assertions in the same commit as
  the data.
- New tests: `check_league_formats.gd` (parse; `row window == format window`;
  null/crossing windows; clauses resolve on a synthetic league; group sizes,
  draws and combined tables; promotion/relegation slots sum to the boundary
  counts; ids unique) and `check_career_stages.gd` (two phases, three phases,
  group + knockout, a skipped conditional stage, a `none` relegation league with
  zero movement, aggregate relegation, per-row delta suppression, determinism).
- Wiki: career season page gains a stage section.

## Implementation phases

0. **Calendar** (the open work on the branch): boundary-based season start,
   season end before the next boundary, tests and the two date-bearing goldens
   green, commit.
1. **Data**: schema, the 22 formats encoded (`AR3F` among them as the merged
   two-path tournament, then `out_of_scope` removed; `M191`/`M21A` single), row
   windows recomputed, loader, validation test, `check_league_regulations`
   updated — this lands in `assets/data/competitions.json`, one `format` per
   competition.

Phases 2–6 of this slice are executed as the container phases in
`2026-11-20-career-competitions.md` (stage engine, schedule, persistence,
brackets, UI), because the container owns the data model: a league is one
`kind: "league"` competition and shares the stage engine with cups. This spec
owns the league-format semantics (entrants, bonus, carry, aggregate,
promotion/relegation, conditional stages); that one owns the container.

## Open decisions

- `CO22` promotion (three conditional branches): `unknown`; the game promotes
  the aggregate top two until the rule is modelled.
- `ARGC` relegation combines the average bottom and the aggregate penultimate;
  the ordered "not already named" rule takes the overlap out.
- `ARG2`'s reducido field is not enumerated in the research; the stage is
  encoded as `entrants: [{"rule": "unknown"}]` until a source line is added.
- Cross-division relegation play-offs: out of scope.
- Average/coefficient relegation is simulated as the aggregate until club
  history exists.
