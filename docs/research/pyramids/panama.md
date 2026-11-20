# Panama — football pyramid 2026-27

Research for the career simulation. Scope: level 1 only, the Liga Panameña de Fútbol
(LPF). Our row is the **Apertura** tournament, not a full league season. Liga Prom
(tier 2) is not in our list, so the Apertura is closed in both directions in our data.

## Sources

| Source | Used for |
| --- | --- |
| https://es.wikipedia.org/wiki/Torneo_Apertura_2026_(Panamá) | the Apertura 2026: 12 clubs, two conferences of six, 16 rounds, single-match play-offs and final, the calendar switch, the 2025 promoted/relegated clubs |
| https://es.wikipedia.org/wiki/Primera_División_de_Panamá | the league: two tournaments per year (Apertura/Clausura), 12 clubs since 2021 in two conferences, relegation on the accumulated table, Liga Prom champion promoted |
| https://en.wikipedia.org/wiki/Liga_LPF | cross-check of the league's identity and pyramid position (English article) |

No English-language 2026 season article exists; the Spanish Apertura page is the only
detailed source and the season structure is described in Spanish.

## League

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| PN1A | Liga Panameña de Fútbol Apertura | 1 | 12 | two conferences of 6, 16 rounds + 6-team play-off | — (top) | 1 per season (accumulated table) |

Our size (12) and level (1) are correct.

## Format of one tournament

- 12 clubs in **two conferences of six** (Este and Oeste). Each club plays its five
  conference rivals home and away (10 matches) plus six cross-conference matches, for
  **16 rounds**.
- Six clubs reach the play-offs: the top three of each conference.
  - Play-off #1: 2nd West v 3rd East; play-off #2: 2nd East v 3rd West — single match,
    extra time and penalties if level.
  - Semi-finals: 1st East v winner #1, 1st West v winner #2 — single match at the
    higher-placed club.
  - Final: single match at the Estadio Rommel Fernández.
- The season is **two such tournaments** (Apertura and Clausura), each crowning its own
  champion, each with its own table, no points carried between them.

## Calendar change

CONCACAF asked Panama to move back to the European calendar, so from 2026 the
second-half-of-year tournament is again called **Apertura** and the first-half one
**Clausura**. The 2025 "Clausura" was a transition tournament with no promotion or
relegation, which is why the same 12 clubs started the 2026-27 Apertura.

## Promotion and relegation

- One club is relegated per season on the **accumulated table** of Apertura + Clausura;
  one club comes up: the winner of the Liga Prom Superfinal (tier 2, not modelled).
- No play-off for the relegation place.
- Because our row is one tournament and our list has no Panamanian tier 2, the Apertura
  is `closed_up` and `closed_down` in the data. The real movement happens at the end of
  the Clausura, not inside the Apertura.

## Decisions

1. **`format.kind: "groups"`, `groups: 2`, `rounds: 16`**, with a note that the season
   is two such tournaments. The Apertura is one championship, so encoding the whole
   season as `apertura_clausura` would describe a competition we do not have a row for.
2. **`playoff: title`, entries "top 3 of each conference", `legs: 1`.**
3. **`size: 12`**, confirmed by both the tournament page and the league page.
4. **No boundary**; the accumulated-table relegation is described in `notes` only.

## Oddities

- Apertura 2026 lost round 12 to the October 2026 earthquake (matches postponed, the
  round replayed later), so mid-season tables are uneven in games played.
- Conference membership is a real constraint: a club cannot finish above a club from the
  other conference in the play-off seeding, because the bracket is fixed by conference
  position.
- The same 12 clubs appear in both tournaments; only the relegation at the end of the
  Clausura changes the pool.

## Confidence

**Medium-high.** The 12 clubs, two conferences, 16 rounds and the play-off bracket are
explicit in the Apertura page. Confidence is not high because the only detailed source
is a single Spanish Wikipedia season article (itself citing LPF), and the accumulated
relegation rule is stated on the general league page rather than for 2026-27.
