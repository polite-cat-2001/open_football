# International match calendar for the club scheduler

Checked 2026-11-20. Data in `fifa-windows.json`; every date carries `source`, verbatim `quote`
and `confidence`. Nothing here is calculated — a date the source does not state is `null` with a
`precision` of `month`.

## What a window means for a club calendar

FIFA's calendar is a **release obligation, not a league holiday**. Inside a window clubs must
release called-up players, so:

- **No domestic fixture may be scheduled inside a window** for a club that has internationals —
  and in practice a league round placed there is played with half its squad missing. Treat each
  window as a dead zone of its own length (8–16 days, longer for the 4-match September–October
  window).
- **A window that contains a confederation final is not free either.** June–July 2027/2028 are
  filled by the Gold Cup, AFCON, Euro, Copa América and the OFC Nations Cup, so the whole block
  from mid-June to mid-July disappears from the club schedule in the affected region. A league
  whose season normally runs through that block loses those weeks outright (that is what
  `pauses_club_football: true` records).
- **Outside the tournament's own confederation the league keeps playing** and only loses players
  (`auxiliary/fifa_release_period_rule`: 4-day release, 5 days cross-continent, 48 h for
  friendlies). An AFCON in December therefore does *not* stop the Premier League — but it does
  empty it of African internationals, and it does stop the African leagues themselves.
- **Season boundaries move around the World Cup.** 2026 is the extreme case: the club season for
  players in final squads ended 24 May and squads were released 25 May, six weeks before the
  11 June kick-off (`auxiliary/club_release_world_cup_2026`). A 2025-26 season has to finish
  early, and the 2026-27 season starts after 19 July.
- **Dates are the bracket, not the whole absence.** Add travel/return: a player released for a
  window that ends on the 17th is not available on the 18th if he plays on another continent.

Practical rule for the generator: `blocked = union(windows, tournaments where pauses_club_football)`,
then place league rounds in the gaps; a league on a Feb–Nov calendar gets roughly 4 windows plus
its own confederation final per year, a European league 4 windows plus Euro/World Cup years.

## Compact table — windows

| Year | Window | Dates | Matches |
|---|---|---|---|
| 2026 | March | 2026-03-23 → 2026-03-31 | 2 |
| 2026 | June (WC prep) | 2026-06-01 → 2026-06-09 | 2 |
| 2026 | September–October | 2026-09-21 → 2026-10-06 | 4 |
| 2026 | November | 2026-11-09 → 2026-11-17 | 2 |
| 2027 | March | 2027-03-22 → 2027-03-30 | 2 |
| 2027 | June | 2027-06-07 → 2027-06-15 | 2 |
| 2027 | September–October | 2027-09-20 → 2027-10-05 | 4 |
| 2027 | November | 2027-11-08 → 2027-11-16 | 2 |
| 2028 | March | 2028-03-20 → 2028-03-28 | 2 |
| 2028 | May–June | 2028-05-29 → 2028-06-06 | 2 |
| 2028 | September–October | 2028-09-18 → 2028-10-03 | 4 |
| 2028 | November | 2028-11-13 → 2028-11-21 | 2 |

## Compact table — tournaments

| Year | Tournament | Dates | Confederation | Pauses club football? |
|---|---|---|---|---|
| 2026 | Africa Cup of Nations 2025 | 2025-12-21 → 2026-01-18 | CAF | yes |
| 2026 | FIFA World Cup | 2026-06-11 → 2026-07-19 | world (CAN/MEX/USA) | yes |
| 2027 | CONCACAF Gold Cup | 2027-06-17 → 2027-07-11 | CONCACAF | yes (MLS) |
| 2027 | Africa Cup of Nations | 2027-06-19 → 2027-07-17 | CAF (KEN/TAN/UGA) | no (off-season) |
| 2027 | AFC Asian Cup | 2027-12-23 → 2028-01-21 | AFC (Saudi Arabia) | yes |
| 2028 | AFC Asian Cup (final stage) | 2027-12-23 → 2028-01-21 | AFC | yes |
| 2028 | UEFA Euro | 2028-06-09 → 2028-07-09 | UEFA (ENG/SCO/WAL/IRL) | yes |
| 2028 | Africa Cup of Nations | 2028-06-07 → 2028-07-10 | CAF (host TBD) | no (off-season) |
| 2028 | Copa América | June – July 2028 (`null` days) | CONMEBOL (host TBD) | yes |
| 2028 | Olympic men's football | 2028-07-10 → 2028-07-29 | world (USA) | no (not a release window) |

## Published vs estimated

- **Windows: 2026, 2027 and 2028 are all published** by FIFA (Men's International Match Calendar
  2023-2030, day precision, high confidence). The 2026 rows are already in the past as of the
  check date; only 2027–2028 are actionable for a career starting now.
- **Tournament dates: all day-precise except Copa América 2028** (only June–July published,
  `precision: "month"`) and **AFCON 2028** (7 June – 10 July published, but the host is TBD and
  FIFA's calendar note allows a move to December 2028 – January 2029).
- **One conflict to remember:** the Gold Cup start is 17 June in the tournament article and
  19 June in FIFA's calendar table; the JSON takes the tournament article and flags it.
- **2027 has no January window any more:** the AFC Asian Cup was postponed from
  7 Jan – 5 Feb 2027 to 23 Dec 2027 – 21 Jan 2028, and the January 2027 row disappeared from the
  calendar with it.

## Caveat on sourcing

The FIFA PDF (`digitalhub.fifa.com/.../Men-s-International-Match-Calendar-2023-2030_EN.pdf`) could
not be fetched as text in this environment (PDF content type rejected, proxy blocked). The window
dates and quotes therefore come from the Wikipedia table that cites that PDF — the December 2025
revision for 2026, the current revision for 2027–2028, which agree with each other where they
overlap. Re-check against the PDF before shipping a career that depends on a single day.
