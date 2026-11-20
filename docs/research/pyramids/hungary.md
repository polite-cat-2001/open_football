# Hungary — football pyramid, 2026-27

Both rows are simple single-table leagues; the interesting part is that **2026-27 introduces a
relegation play-off between the 11th-placed NB I club and the NB II runner-up**, which replaces the
old "top two up, bottom two down" rule.

## At a glance

| Level | id | Competition | Clubs | Format | Rounds | Up | Down |
|---|---|---|---|---|---|---|---|
| 1 | UNG1 | Nemzeti Bajnokság (NB I) | 12 | triple round robin | 33 | — (closed) | 1 direct + 1 play-off |
| 2 | UN2 | Nemzeti Bajnokság II. | 16 | double round robin | 30 | 1 direct + 1 play-off | 3 (to NB III) |

## Level 1 — Nemzeti Bajnokság

- 12 clubs, 33 rounds: each team plays every other three times. No split, no title play-off — the
  table winner is champion.
- The league dropped its sponsor name for 2026-27 (it was Fizz Liga).
- **Relegation:** 12th is relegated directly; **11th plays a single match against the NB II runner-up**
  at a neutral venue chosen to be roughly equidistant, on 29 May 2027. The venue must be VAR-capable.
  Winner plays NB I next season, loser NB II.
- 2026-27 intake: Vasas and Kispest-Honvéd promoted; Diósgyőr and Kazincbarcika relegated.

## Level 2 — Nemzeti Bajnokság II.

- 16 clubs in one group, 30 rounds (single group since 2024-25).
- **Promotion:** champion up directly; runner-up into the one-match play-off against the NB I 11th.
  So the division promotes one or two clubs, depending on that match.
- **Relegation:** bottom three go down to NB III, which is played in three regional groups (not in our
  rows); its three group winners come up, keeping level 2 at 16.

## Check against our database

| id | our name | our level | real level | our size | real size 2026-27 | verdict |
|---|---|---|---|---|---|---|
| UNG1 | Nemzeti Bajnokság | 1 | 1 | 12 | 12 | correct |
| UN2 | Nemzeti Bajnokság II. | 2 | 2 | 16 | 16 | correct |

One contradiction between sources, recorded in `conflicts`: the NB II article still states the old
rule (top two promoted, NB I 11th and 12th relegated). The 2026-27 NB I page and the Hungarian
season page both describe the new single-match play-off, so the play-off is what is recorded.

## Caveats

- The play-off is one match, not two legs, and is new this season — do not carry the old Hungarian
  two-legged play-off habit into it.
- Licensing decides promotions in practice (a champion without an NB I licence is not promoted and
  the place passes down), so the table alone does not determine the intake.
- NB III's three groups are regional, so the three relegated clubs are placed by geography, not by a
  fixed group.

## Sources

- https://en.wikipedia.org/wiki/2026%E2%80%9327_Nemzeti_Bajnoks%C3%A1g_I
- https://hu.wikipedia.org/wiki/2026%E2%80%932027-es_magyar_labdar%C3%BAg%C3%B3-bajnoks%C3%A1g_(els%C5%91_oszt%C3%A1ly)
- https://hu.wikipedia.org/wiki/Magyar_labdar%C3%BAg%C3%B3-bajnoks%C3%A1g_(m%C3%A1sodoszt%C3%A1ly)
- https://en.wikipedia.org/wiki/Nemzeti_Bajnoks%C3%A1g_II
