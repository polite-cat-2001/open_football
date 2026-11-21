# Career calendar asset and FIFA pauses — plan

Status: 2026-11-21. Phase 0 remainder, **logic only, no UI**.
Specs: `2026-11-20-career-season-formats.md` (calendar rules),
`2026-11-20-career-data-assets.md` (asset fields).

## Goal

A career's fixtures never fall inside a FIFA international window or a World
Cup, the season still starts on the boundary nearest to the data snapshot and
ends the day before the next boundary, and every round stays inside the league
window. The rules come from a shipped asset, not from code constants.

## Non-goals

- Continental tournaments (Euro, AFCON, Asian Cup, Copa América): they need a
  country→confederation map, which arrives with the competitions container.
- The union of the club's competitions (cups, qualifiers): the container.
- Any UI or hub golden. `check_career_hub` and `career_hub_golden` stay out of
  scope until the logic is signed off.

## Asset

`assets/data/intl_calendar.json`:

```json
{
  "checked": "2026-11-21",
  "rules": [
    {"kind": "window", "label": "March", "start": "2026-03-23", "end": "2026-03-31",
     "applies_to": "world", "pauses_club_football": true, "source": "..."},
    {"kind": "window", "label": "March", "start_md": "03-23", "end_md": "03-31",
     "every_years": 1, "anchor_year": 2029, "approximate": true,
     "applies_to": "world", "pauses_club_football": true}
  ]
}
```

- An **explicit** rule has `start`/`end` ISO dates and covers one edition.
- A **recurring** rule has `start_md`/`end_md` plus `every_years` and
  `anchor_year`; `start_md > end_md` crosses New Year.
- `pauses_club_football: false` means the competition releases players but the
  league keeps playing; such a rule never blocks a fixture.
- 2026–2028 are copied exactly from `docs/research/calendar/fifa-windows.json`
  (the annual windows drift by a day or two between years). From 2029 the
  annual windows and the quadrennial World Cup repeat by month and day from the
  2026 pattern and are marked `approximate`.
- Only `applies_to: "world"` rules are wired in this slice. Continental rules
  are added when the confederation map lands.

## TDD cycles

1. **Asset + loader.** Red: `check_intl_calendar_data` expects `rules` to load,
   every rule to have a source, the 2026 World Cup and the four 2026 windows to
   be present, and no rule to lack `applies_to`. Green: `IntlCalendar.load_all`
   / `rules`.
2. **Wiring into creation.** Red: `check_career_pauses` creates a career in a
   league whose season crosses the September–October and November windows and
   asserts no fixture date is blocked. Green: `CareerFactory.create` passes the
   asset rules and `"world"` scope to `build_schedule`.
3. **Rollover and repairs.** Red: the same test advances to the next season
   (`next_season`) and asserts the new schedule avoids the 2027 windows.
   Green: `next_season` and `ensure_schedule` pass the same rules.

## Definition of done

- `check_intl_calendar_data`, `check_career_pauses` and the six calendar tests
  pass; `check_career_creation` golden is regenerated only if its first/last
  fixtures move (round 1 and round 38 are outside the windows, so it should not).
- No UI file is touched.
- The asset is committed; the conversion script is not.

## Risks

- The 2029+ windows are an approximation and must be refreshed when FIFA
  publishes the next calendar.
- The annual windows are release windows in reality; this slice treats them as
  hard pauses, as the formats spec says (no national-team call-ups are modelled).
- A league whose window is shorter than the number of free days can still
  compress rounds; the allocator falls back to the even spread and the pause is
  documented as broken in that edge case.
