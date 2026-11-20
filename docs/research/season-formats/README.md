# Season-format research (slice c, two-phase seasons)

Target: the 25 leagues in `assets/data/league_regulations.json` whose `phases`
field says `apertura_clausura`. That label is **not trustworthy**: it was
inherited from country-level research and at least one league (Uruguay's
Segunda División, `UR2T`) is a single double round-robin. Verify the format of
each league from sources; do not repeat the label.

## What to answer per league

1. **Structure** of the 2026 (or 2026–27) season:
   `single` (one table), `two_phases` (Apertura + Clausura, each with its own
   table), `three_phases` (e.g. Uruguay's Apertura / Intermedio / Clausura),
   `split` (one regular table, then championship/relegation groups) or `other`.
2. **Phase windows**: for every phase, the exact first and last matchday as
   `MM-DD`, with the source and a verbatim quote. A month-only answer is
   `null` + `"precision": "month"`.
3. **Points** between phases: `none`, `full`, `half` or `unknown`.
4. **Champion**: decided by the phase table (`table`), by a match/final between
   phase winners (`phase_final`), by a knockout among the top places
   (`playoff`), or `unknown`. Give the number of teams and the playoff window
   when there is one.
5. **Relegation**: `aggregate` (annual table), `per_phase`, `average`
   (multi-season coefficient), `none`, `unknown`.
6. Whether the database row is the **whole league** or **one phase** of it.
   Some rows are named after a phase but hold the whole division's clubs (both
   Uruguay rows do); say which it is.

## Sources

Same hierarchy as `docs/research/season-windows`: the season article on the
national-language Wikipedia first, then English Wikipedia, then the official
league site. A different season may only be a proxy with `"proxy": true` and
`"confidence": "low"`. Never invent a date or a format detail.

## Output

One file per country: `docs/research/season-formats/<country-slug>.json`.

```json
{
  "country": "Mexico",
  "checked": "2026-11-20",
  "leagues": [
    {
      "id": "MEXA",
      "season": "2026-27",
      "structure": "two_phases",
      "phases": [
        {"label": "Apertura", "start_md": "07-17", "end_md": "11-22",
         "precision": "day"},
        {"label": "Clausura", "start_md": "01-09", "end_md": "05-10",
         "precision": "day"}
      ],
      "points_carry": "none",
      "champion": "playoff",
      "playoff": {"teams": 8, "window": "2026-11-25..2026-12-13"},
      "relegation": "aggregate",
      "row_is": "league",
      "source": "https://...",
      "quote": "Apertura: 17 July – 22 November 2026 ...",
      "confidence": "high",
      "note": "Liguilla decides the champion; the table only seeds it."
    }
  ]
}
```

`row_is` is `league` or `phase`. Keep notes short and factual.
