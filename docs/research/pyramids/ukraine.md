# Ukraine — football pyramid, 2026-27

Season runs July 2026 → June 2027 with a long winter break (December-February).

| Level | Competition | Clubs | Shape | Rounds |
|---|---|---|---|---|
| 1 | Ukrainian Premier League (UPL) | 16 | double round-robin | 30 |
| 2 | Persha Liha (First League) | 16 | double round-robin | 30 |
| 3 | Druha Liha (Second League) | 18 | 2 groups (A, B) × 9, then championship play-off | 16 + play-off |
| 99 | Premier Liga 2 (UPL youth/reserve) | 16 | youth championship | - |

Our levels are right. Our Druha Liha size (18) matches the 2026-27 group list, though the league
article's infobox still says 22.

## Level 1 — Ukrainian Premier League

16 clubs, 30 matches, unchanged for 2026-27 (top 12 + First League top 2 + play-off winners).

- **15th and 16th relegated directly** to the Persha Liha.
- **13th and 14th go to two-legged relegation play-offs** against the First League's 3rd and 4th.
- So the nominal boundary is 2 direct + 2 play-off places in each direction. In 2026-27 it resolved
  as **three up / three down**: Bukovyna and Chornomorets went up directly, Livyi Bereh won a
  play-off, Oleksandriya lost one (so one UPL club survived), SC Poltava and Oleksandriya went
  down and Rukh Lviv withdrew.

## Level 2 — Persha Liha

16 clubs, 30 rounds. Champion and runner-up are promoted directly; 3rd and 4th enter the play-offs
against the UPL's 13th and 14th. At the bottom, relegation to the Druha Liha is normally by
two-legged play-offs (two ties), but since 2011 these have been scheduled ad hoc and are regularly
cancelled when clubs withdraw — the 2025-26 play-offs were cancelled outright "due to clubs'
withdrawal", and no play-off was played into 2026-27. Clubs that finish last lose professional
status and drop to regional football rather than being relegated by table position.

## Level 3 — Druha Liha is regional

The third level is one competition in **two geographic groups** (A = west, B = east/south), nine
clubs each in 2026-27 (18 total; the infobox's 22 is stale). Each group plays a double round-robin
(16 rounds). The two group winners then meet in a **championship match** for the title (single game
at a neutral venue; two legs in some seasons), and the second and third places of each group have
their own placement play-off. That championship match decides the title only — both group winners
are normally promoted.

Promotion from level 3 is therefore **2 places** (one per group) with the caveat that reserve teams
cannot be promoted and that vacancies are frequently filled by extra clubs when the Persha Liha
loses members to withdrawal. In 2025-26 the group winners Kulykiv-Bilka and Lokomotyv Kyiv both
went up, while the runners-up were reserve sides (Polissya-2, Kolos-2) and ineligible.

**Relegation out of Druha Liha does not exist as a sporting rule**: the PFL has not relegated clubs
since 2006-07. Clubs that finish bottom either lose professional status and return to their regional
association, or withdraw. Hence `closed_down` is true — but for administrative, not sporting,
reasons, and a career sim should model exits, not relegations.

## Level 99 — "Premier Liga 2"

The UPL runs youth competitions for its member clubs (an U-21 championship, inherited from the old
reserve league, and an U-19 championship which also admits some lower-league clubs; the U-19
champion enters the UEFA Youth League). There is **no senior competition called "Premier Liga 2"**
in the Ukrainian system, so the row is best read as the UPL's second (reserve/youth) competition,
with 16 clubs — one per UPL club for the U-21 championship. It is not a tier: no promotion, no
relegation, membership follows the senior league.

## Boundaries as numbers

| Boundary | Up | of which play-off | Down | of which play-off | Allocation |
|---|---|---|---|---|---|
| 1 ↔ 2 | 3 | 1 | 3 | 2 | free |
| 2 ↔ 3 | 2 | 0 | 2 | 0 | by geography |

The 1 ↔ 2 numbers are the 2026-27 outcome (3 and 3); the nominal shape is 2 + 2 each way. The
2 ↔ 3 "down" pair is nominal only: relegation from the Persha Liha is by play-off or not at all,
and in 2026-27 the two clubs that dropped (Metalurh Zaporizhia, Podillya Khmelnytskyi) were placed
in Druha Liha groups by geography.

## Data problems in our rows

1. `UKR1` 16 and `UKR2` 16 — correct, 30 rounds each.
2. `UA3L` 18 — correct for the 2026-27 group list (9 + 9), but the league's own article infobox
   still shows 22; do not use 22.
3. `UA2P` "Premier Liga 2" — no such senior competition exists. It is the UPL youth/reserve
   championship, level 99, closed. Keep the id but never let it take part in promotion.
4. Druha Liha has no relegation by rule, only exits. A model that "relegates" its bottom clubs is
   wrong for Ukraine.

## Confidence

High on levels 1-2 sizes, rounds and the play-off shape (the 2026-27 season article and the league
articles agree). Medium on level 3, where group sizes and the number of promotions flex with
withdrawals every season, and low on the meaning of `UA2P` (inferred, not documented).

## Sources

- https://en.wikipedia.org/wiki/Ukrainian_Premier_League (16 clubs, bottom clubs relegated, U-19/U-21 youth championships)
- https://en.wikipedia.org/wiki/2026%E2%80%9327_Ukrainian_Premier_League (16 clubs, 13th/14th play-off, 15th/16th down, promoted/relegated lists)
- https://en.wikipedia.org/wiki/Ukrainian_First_League (16 clubs, 2 up, play-offs, withdrawals)
- https://en.wikipedia.org/wiki/Ukrainian_Second_League (two regional groups, no relegation since 2006-07, group winners' championship match, 2026-27 group list)
