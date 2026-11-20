# Global and secondary club competitions — structure map

Checked 2026-11-21. Companion to `international.json` (the 12 confederation competitions).
Data: [`international-global.json`](international-global.json). Seasons: 2026 for the
single-year competitions, 2029 for the FIFA Club World Cup (no 2026 edition), 2026 for the
UEFA Super Cup. Dates are verbatim from the phase tables quoted in the JSON; where an
article gave no phase table the field is `null` and says so.

None of these has a verified Transfermarkt id, so the ids are stable dataset codes
(`CWC`, `FIC`, `USC`, `RSU`, `CAFSC`, `CACC`, `CARC`, `CFUS`, `OFCPL`).

## Compact table

| Competition | Kind | Clubs | Phase shape | Two-legged rounds | Window | Confidence |
|---|---|---|---|---|---|---|
| FIFA Club World Cup | global | 32 | 8×4 groups (3 MD) → R16 → QF → SF → F, all single leg | — | 06-14 → 07-13 (2025 template; next edition June–July 2029) | high |
| FIFA Intercontinental Cup | global | 6 | 4 single matches: AAP play-off → 2nd round (AAP Cup + Derby of the Americas) → Challenger Cup → final; UEFA bye to the final | — | 08-26 → 12-16 | high |
| UEFA Super Cup | super_cup | 2 | one match | — | 08-12 | high |
| Recopa Sudamericana | super_cup | 2 | two legs, Libertadores winner hosts the second | final | 02-19 → 02-26 | high |
| CAF Super Cup | super_cup | 2 | one match, CL winner hosts, no extra time | — | 11-08 | high |
| CONCACAF Central American Cup | feeder | 20 | 4×5 single round-robin (4 MD) → QF → SF + play-in → final | QF, SF, play-in, final | 07-28 → 12-06 | high |
| CONCACAF Caribbean Cup | feeder | 10 | 2×5 single round-robin (4 MD) → SF → third place + final | SF, third place, final | 08-04 → 12-05 | medium |
| CFU Club Shield | feeder | 22 | single-leg knockout, one host country | — | 07-23 → 08-02 | high |
| OFC Professional League | feeder | 8 | 5 neutral-venue circuit rounds (14 MD) → Leaders/Challengers groups → play-off → SF → final | — | 01-17 → 05-24 | high |

## What is shared, what is new

**Shared.** Two of the three super cups are one match between two title holders already
produced by competitions in `international.json` — they add no stage kind at all. The
feeders (Central American Cup, Caribbean Cup, Club Shield) are an existing group-plus-knockout
plus the berth hook the spec already has. The Club World Cup's bracket is the plain
8×4 → top two → single-leg knockout shape, with no third-place match.

**New, and it matters for the berth graph:**

1. **Berths keyed on placement, not on the winner.** The Central American Cup sends six
   clubs to the Champions Cup (four semi-finalists + two play-in winners; champion to the
   round of 16); the Caribbean Cup sends three (final winner to the round of 16, final loser
   and third-place winner to round one). A berth rule of the form "winner of X" cannot
   express this. `berths` needs placement sets: `{competition, stage, reach: "semi_final"}`.
2. **A third-place play-off that carries a berth** (Caribbean Cup). The only case found
   where finishing third is worth a place.
3. **Groups of five.** Both CONCACAF feeders use 5-club groups with a 4-match single
   round-robin; every sample in `international.json` is 4-club. Cheap, but the group builder
   must not assume four.
4. **Two-legged finals** appear three times here (Recopa, and both CONCACAF feeders' finals)
   — already supported, now confirmed as the norm outside Europe's single-match model.
5. **A quadrennial competition.** The Club World Cup is 2025 → 2029, so a season allocator
   must be able to say "not this year" rather than generate a field every summer.
6. **A field made of title holders, not of a league's clubs.** The Intercontinental Cup's
   six entrants are six named continental winners; the entrant source is "winner of
   competition Y, previous season", across confederations.
7. **A franchised, neutral-venue league with a mid-season split** (OFC Professional League):
   five circuit rounds in six host cities, then one table split into Leaders and Challengers
   groups, then a knockout. Not home-and-away, not a pot-drawn league.

**Why the OFC Professional League is in this list.** From 2026 the OFC place in the
Intercontinental Cup (and the OFC pathway to the 2029 Club World Cup) comes from the
Professional League winner, not from the OFC Men's Champions League. The OFC Champions
League entry in `international.json` therefore no longer carries a global berth — that is
a correction to the existing berth map, not just a new competition.

## Gaps

- **No 2026 Club World Cup.** It is quadrennial; the next edition is 2029 in June–July. The
  2029 access list is unpublished ("FIFA are yet to announce the access list"), a 48-club
  expansion is reported but unconfirmed, the host is unknown, and UEFA discussed boycotting
  the 2029 edition in August 2026. Model 32 clubs until FIFA publishes.
- **Intercontinental Cup 2026 is unfinished at check time.** Final on 16 December; the
  Derby of the Americas (9 December) has no CONMEBOL club named yet (Libertadores final is
  28 November) and the Challenger Cup (12 December) has no winner.
- **Away goals are live in CONCACAF.** Both the Central American Cup ("if tied on aggregate,
  the away goals rule will be used") and the Caribbean Cup use them, which contradicts the
  spec's blanket "no away-goals rule". Either the rule becomes per-competition data or the
  spec changes.
- **Caribbean Cup source contradicts itself** on the group shape ("Ten teams from six CFU
  member associations" and two groups of five vs "the winners and runners-up of each of the
  four groups"). Two groups is used because the tables and bracket show Groups A and B;
  confidence `medium` for that reason alone.
- **No AFC super cup.** The AFC's 2026-27 club competition list is Elite, Two and Challenge
  League only; there is no senior men's AFC super cup to model. Verified by absence, so
  `medium` if it ever appears.
- **Unverified:** a UEFA–CONMEBOL club challenge was played in 2023; no 2026 edition could
  be confirmed, so it is not modelled.
- **Dates that sources do not state:** the Club World Cup group stage's last matchday (the
  article has no phase table; 26 June is visible only in match reports, so `end_md` is
  null), and the OFC Professional League's qualification play-off and semi-final dates
  separately from the final (24 May).
- **Re-check yearly.** Berths, slot counts and even the existence of these competitions
  change between seasons (the OFC case above is this season's example).
