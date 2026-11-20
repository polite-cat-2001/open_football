# Season-window refinement pass

Target: the 55 leagues in `assets/data/league_regulations.json` whose season
window has at least one date replaced by a class default (`"filled"` is
`start`, `end` or `start+end`). Those dates are honest defaults, not source
values, and they distort the season boundary (the midpoint between the last
round of one season and the first round of the next).

This pass finds the real dates. It does **not** touch the asset: each report is
merged into `assets/data/league_regulations.json` afterwards.

## Source hierarchy

1. The season article on the **national-language** Wikipedia for the season
   whose window starts in 2026 (`2026`, `2026–27`, `2026-27`, ...).
2. The same season's **English** Wikipedia article.
3. The league's official site or an official fixture list.

A different season may only be used as a proxy with `"proxy": true`,
`"confidence": "low"` and a note.

## Rules

- The dataset stores `MM-DD`, so **only an exact day counts**. A source that
  says "May 2027" or "TBD 2027" does not fill a day: record `"found": null`,
  `"precision": "month"` or `"none"`, and leave the default in place.
- Never guess a day from a month, a round number or another league.
- Quote the source value verbatim (a short infobox line or sentence).
- A phase row (an `Apertura`/`Clausura` row that is one half of a league) is
  resolved against **that phase's** dates, and the note must say so.
- Missing article, defunct league, or a competition that moved under a new
  name: `"found": null`, `"precision": "none"`, explain in the note.
- Confidence: `high` = exact day in the season article; `medium` = exact day
  from a secondary source (official site, news); `low` = proxy season or an
  ambiguous source.

## Output

One file per country: `docs/research/season-windows/<country-slug>.json`
(lowercase ASCII, hyphens: `puerto-rico.json`, `united-arab-emirates.json`).

```json
{
  "country": "Romania",
  "checked": "2026-11-20",
  "leagues": [
    {
      "id": "RO1",
      "fields": [
        {
          "field": "end_md",
          "current": "05-23",
          "found": "06-01",
          "precision": "day",
          "proxy": false,
          "confidence": "high",
          "source": "https://ro.wikipedia.org/wiki/...",
          "quote": "Ultima etapă: 1 iunie 2027",
          "note": "End of the championship round; play-off dates are separate."
        }
      ]
    }
  ]
}
```

`field` is `start_md` or `end_md`. `current` is the value in the asset today
(the default when `filled` covers that field, otherwise the real one).
`found` is `null` when no exact day exists.

## Merge

The merge read every `*.json` here and applied a field only when
`precision == "day"` and the entry was not a previous-season proxy. It then
cleared that part of `filled`, took the report's `confidence`, appended the
source and the quote to the record note, and rewrote the note of every league
marked `inherited_from` so the top-division facts stay on the division that
owns them. It lives outside the repository: the reports in this folder are the
audit trail.

## Result (2026-11-20)

55 leagues, 30 country reports. 26 fields resolved to an exact day, 25 of them
changed the asset (one already equalled the value). 11 previous-season proxies
were **not** merged — never guess a day from another season — and stay here as
documentation. 35 leagues keep a class-default end and are still marked
`filled`.

Four leagues came out with a window of 85–134 days: `PRA1`, `CRPD` and `PN1A`
are one phase of an Apertura/Clausura championship (checked against the Panama,
Costa Rica and Puerto Rico articles), so their "gap" to the next season is
230–280 days and the season boundary is meaningless for them until formats
land. `UR2T` looked similar but is not: the Uruguayan Segunda División is one
double round-robin of 230 matches from 13 March to December, and the row is the
whole league under a phase name — it was corrected, and the earlier `05-02`
(the Torneo Competencia final) rejected as the season end.

The calendar must therefore treat a window shorter than five months as a phase
(a month of pre-season) instead of taking the midpoint of that gap.
