# Nicaragua — football pyramid, 2026-27

Nicaragua runs **Apertura and Clausura** inside one season: Apertura in the second half of the calendar
year, Clausura in the first half of the next. Cups and CONCACAF competitions are out of scope.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | NC1A | Liga Primera | 10 | Apertura + Clausura, double round robin + 6-club knockout | 18 each | — (closed) | 1 direct + 1 play-off |
| 2 | NC2A | Liga de Ascenso (Segunda División) | 12 | two groups of 6, then knockout | 10 each | 1 direct + 1 play-off | — |
| 3 | — | Segunda División B / amateur (not modelled) | — | — | — | — | — |

## Level 1 — Liga Primera

- 10 clubs. Each tournament: 18 rounds (double round robin), then the **top two go straight to the
  semi-finals and 3rd-6th play a quarter-final**; both rounds are two-legged.
- **Relegation is decided on the aggregate table across Apertura + Clausura**: last place goes down,
  **9th plays the Ascenso runner-up** over two legs. That is why the boundary's `selection` is
  `average_table`, not `bottom_n`.
- 2026 example: Real Madriz finished last and went down; UNAN Managua (9th) beat Matiguás 3–1 over two
  legs and stayed; San Marcos came up as Ascenso champions.

## Level 2 — Liga de Ascenso

- The official name is **Segunda División de Nicaragua**; the league and Transfermarkt brand it *Liga de
  Ascenso*. Our name and id (`NC2A`) follow the branded form.
- **12 clubs in two groups of six** (Centro and Costa), 10 rounds per group, group leaders into a
  knockout, then a two-legged final.
- Champion promoted; runner-up into the play-off against the Liga Primera 9th.

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| NC1A | Liga Primera de Nicaragua Apertura | 1 | 1 | 10 | 10 | correct size; name carries one tournament |
| NC2A | Liga de Ascenso de Nicaragua Apertura | 2 | 2 | 12 | 12 | correct (branded name) |

Both `Apertura` suffixes name a half-season, not the competition.

## Caveats

- Relegation depends on two tournaments' worth of results; a sim that only plays one tournament cannot
  reproduce it.
- The Wikipedia season page is partly a stub (TBD placeholders, dates copied from 2024-25 in the
  infobox). Sizes and formats come from the participant list and the league site, hence medium
  confidence rather than high.

## Sources

- https://en.wikipedia.org/wiki/2026%E2%80%9327_Liga_Primera
- https://www.ligaprimera.com/
- https://es.wikipedia.org/wiki/Segunda_Divisi%C3%B3n_de_Nicaragua
