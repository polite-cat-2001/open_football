# International club competitions — structure map

Checked 2026-11-20. Season articles used: 2026-27 for the split-year competitions, 2026 for the
single-year ones. Numbers and dates are taken verbatim from the phase tables quoted in
`international.json`; where an article did not state something the field is `null`.

## Compact table

| Competition | Clubs (proper) | Phase shapes | Two-legged rounds | Window |
|---|---|---|---|---|
| UEFA Champions League | 36 (+45 in qualifying) | Q1-Q3 + play-off → 8-match pot league (36, one table) → KO play-off → R16 → QF → SF → F | all qualifying rounds, KO play-off, R16, QF, SF | 07-07 → 06-05 |
| UEFA Europa League | 36 | Q1-Q3 + play-off → 8-match pot league → KO play-off → R16 → QF → SF → F | all qualifying rounds, KO play-off, R16, QF, SF | 07-09 → 05-26 |
| UEFA Conference League | 36 | Q1-Q3 + play-off → 6-match pot league → KO play-off → R16 → QF → SF → F | all qualifying rounds, KO play-off, R16, QF, SF | 07-09 → 06-02 |
| CONMEBOL Libertadores | 47 total, 32 in groups | 3 single-elim qualifying stages → 8×4 groups (6 MD) → R16 → QF → SF → F | all qualifying stages, R16, QF, SF | 02-03 → 11-28 |
| CONMEBOL Sudamericana | 56 total, 32 in groups | 1-leg first stage → 8×4 groups (6 MD) → KO play-off → R16 → QF → SF → F | KO play-off, R16, QF, SF | 03-03 → 11-21 |
| AFC Champions League Elite | 32 | 1-leg preliminary → 8-match pot league, 16 West + 16 East → R16 → QF → SF → F (centralised) | R16 only | 08-11 → 05-01 |
| AFC Champions League Two | 32 | 1-leg preliminary → 8×4 groups (6 MD, 4 West + 4 East) → R16 → QF → SF → F | R16, QF, SF | 08-12 → 05-15 |
| CAF Champions League | 61-64 entered, 16 in groups | Q1, Q2 → 4×4 groups (6 MD) → QF → SF → F | Q1, Q2, QF, SF, final | 09-04 → 05-31 |
| CAF Confederation Cup | 56 entered, 16 in groups | Q1, Q2 → 4×4 groups (6 MD) → QF → SF → F | Q1, Q2, QF, SF, final | 09-04 → 05-31 |
| CONCACAF Champions Cup | 27 | round one (11 ties) + 5 byes → R16 → QF → SF → F | round one, R16, QF, SF | 02-03 → 05-30 |
| OFC Men's Champions League | 8 (+3 in qualifying) | 3-team preliminary group → 2×4 groups (3 MD) → SF → F, single venue | none | 01-31 → 08-22 |
| AFC Challenge League | 20 | 1-leg preliminary → 5×4 groups (3 MD) → QF → SF → F | QF, SF | 08-11 → 05-08 |

Secondary confederation competitions not modelled above: CONCACAF Central American Cup and
CONCACAF Caribbean Cup are the feeders that supply Champions Cup berths (sub-regional, run by
CONCACAF); the UEFA Super Cup, Recopa Sudamericana and CAF Super Cup are single matches between
two champions and need no bracket at all. From 2026 the OFC global berth (Intercontinental Cup,
Club World Cup) comes from the **OFC Professional League** winner, not from the OFC Men's
Champions League; the global layer is in `international-global.md`.

## What is shared, what is new

**One shape covers nine of the twelve:** seeded field → two-legged qualifiers → groups of four
(double round robin, 6 matches) → two-legged knockout → single final. Libertadores, Sudamericana,
ACL Two, CAF Champions League, CAF Confederation Cup, CONCACAF Champions Cup (no groups, byes
instead), OFC (single-venue groups, 3 matches) and AFC Challenge League all fit "group stage +
knockout" with cosmetic differences in field size. A game that already has a league table, a group
stage and a knockout bracket can express all of them.

**Two mechanics are genuinely new:**

1. *The pot-drawn partial league* (UCL, UEL, UECL, ACLE). This is **not** a round-robin and **not**
   a Swiss system that re-pairs after each round. It is one fixed draw: clubs are seeded into pots,
   each club is handed `matches_per_club` distinct opponents (two per pot in UEFA's four-pot
   version), the whole schedule is published before matchday 1, and everyone sits in one table
   (ACLE: one table per region). So the engine needs a *schedule generator* that, given a seeded
   list and a match count, produces a valid opponent set with home/away balance and no repeats —
   not a new "Swiss" resolver. A 36-club table with 8 rounds is 288 fixtures on 8 dates; there is
   no per-round pairing logic to write.
2. *Qualification by league position across countries.* Every confederation picks its field from
   domestic tables (plus cup winners) using its own ranking of associations: UEFA coefficient
   (1-5 → four teams, 6 → three, 7-15 → two, rest → one, plus performance spots), AFC regional
   slot tables, CAF 5-year ranking (top 12 → two teams), CONMEBOL fixed berths (BRA 7, ARG 6,
   everyone else 4), CONCACAF zone quotas. The engine needs one "berth allocation" table per
   competition, not a formula.

**Cross-country clubs are not a mechanic, they are a data requirement:** the fixture list must be
allowed to pair clubs from anywhere, home and away, without a shared domestic calendar — and the
calendar has to survive a club playing domestically on the weekend and continentally midweek.

**Cross-competition transfers** are the one flow UEFA and CONMEBOL both need: losers of round N in
competition A enter competition B at round M (UCL → UEL → UECL; Libertadores Q3/group-third →
Sudamericana). It is a "on elimination, enqueue into another competition" hook.

**Two-legged finals** exist (CAF Champions League and Confederation Cup). Everything else ends in
one match.

## Cost ranking

- **Cheap** — CONCACAF Champions Cup, CAF Champions League, CAF Confederation Cup, AFC Champions
  League Two, AFC Challenge League, OFC Men's Champions League: existing group + knockout code with
  a berth table; the only new work is "two legs" as a property of a tie.
- **Medium** — CONMEBOL Libertadores, CONMEBOL Sudamericana, UEFA Europa League, UEFA Conference
  League: add the cross-competition drop-down (Libertadores → Sudamericana; UCL → UEL → UECL) and,
  for the two UEFA ones, the pot-drawn partial league plus a 9th-24th play-off round.
- **Expensive** — UEFA Champions League and AFC Champions League Elite: same pot-drawn league plus
  a regional split (ACLE West/East tables, regional R16, single-leg centralised QF/SF/final), the
  largest qualification graph in Europe, and the full three-competition UCL/UEL/UECL transfer net.

Ranked by cost for an engine that already has knockout stages, group stages and a league table:
`CONCACAF ≈ CAF ≈ ACL Two ≈ OFC ≈ ACL Challenge < Libertadores ≈ Sudamericana ≈ UEL ≈ UECL < UCL ≈ ACLE`.
