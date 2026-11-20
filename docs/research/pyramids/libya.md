# Libya — football pyramid 2026-27

Research for the career simulation. Scope: the single row we carry (Libyan Premier League, level 1).
The Libyan First Division (level 2) is outside our data. Cups and CAF places are out of scope.

## Sources

| Source | Used for |
| --- | --- |
| https://libyaobserver.ly/sports/libyan-football-federation-approves-premier-league-format-new-season | the approved 2026-27 format: 28 clubs, two groups of 14, home-and-away first stage, top two per group to a final four, six clubs directly relegated |
| https://en.wikipedia.org/wiki/Libyan_Premier_League | league identity, historical "36 clubs / 4 groups" shape, relegation to the First Division |
| https://www.transfermarkt.us/libyan-premier-league/startseite/wettbewerb/LPL | live 2026-27 tables confirming two groups of 14 and the club list |

This is the one country in the batch where the season article does not exist on Wikipedia and the
official federation statement (via Libya Observer) is the primary source. The Transfermarkt tables
were used as an independent check of the group count.

## Leagues

| id | name | level | size | format | up | down |
| --- | --- | --- | --- | --- | --- | --- |
| LPL | Libyan Premier League | 1 | 28 | 2 groups of 14, 26 rounds + final four | — (top) | 6 |

Size 28 and level 1 in our database are correct **for 2026-27**. The Wikipedia infobox still says 36
clubs in 4 groups; that is the previous shape.

## The real structure

Libya does not run a single national table.

1. **First stage:** 28 clubs split into **two groups of 14**, each played home and away —
   **26 matches** per club. This is where almost the whole season happens.
2. **Final four:** the **top two of each group** advance. The two group winners play one match for
   the title and the runners-up play one match for third place. Third place is not cosmetic: it
   feeds a continental place.
3. **Relegation:** **six clubs are relegated directly** at the end of the season (LFF decision). To
   keep the division at 28, six clubs must come up from the First Division.

So the "top four" in Libya is a **two-match final four**, not a semi-final/final bracket of four
playing two rounds: the winners' match and the third-place match are the only knockout games.

## Decisions

1. **`format.kind: "groups"`** with `groups: 2`, `teams_per_group: 14`, `rounds: 26`, and `stages`
   spelling out the final four. Not `"split"` (there is no common first phase) and not `"cup_phase"`
   (the league phase is the primary competition).
2. **`playoff.kind: "title"`, entries "top 2 per group (4 clubs)"**, one leg. The third-place match is
   included in the note because it decides a continental place and, in a career sim, prize/qualifying
   outcomes.
3. **`closed_up` / `closed_down` both true** — single-row country in our list.
4. **No boundary object**, because the First Division is not in our data.
5. **`down: 6` is in the notes, not in a boundary** — there is no boundary to attach it to, but the
   number is essential: it is 21% of the division and would be a disaster if a sim defaulted to 2.
6. **Not modelled:** the Libyan Cup, Libyan Super Cup, CAF Champions League/Confederation Cup places
   and the security-driven venue/neutral-ground constraints.

## Oddities

- **The size is not stable over time.** 16 → 36 (4 groups) → 28 (2 groups of 14) in recent years.
  The 36/4 description is still in the Wikipedia infobox and will mislead anyone who trusts it;
  listed in `conflicts`.
- **Six relegations** is the highest proportion in this batch. Combined with two groups, a club can
  be relegated from a group of 14 by finishing 11th.
- **The final four is one match each.** A "top four play-off" normally implies two semi-finals; here
  it is winners-v-final and runners-up-v-third-place, so the group winner's reward is a single
  final, not a semi-final.
- Libyan football is regularly disrupted by security and travel problems (clubs play at neutral
  venues, some competitions have been abandoned mid-season). A sim assuming a full 26-round group
  stage will overstate completed matches in some seasons.
- The 2025-26 title was decided the same way (Al-Sweihli beat Al-Nasr in the final, June 2026), so
  the format is not brand new — only the group count changed.

## Confidence

**Medium.** The 28/2x14/final-four/six-down structure comes from the federation's own approved
format as reported by Libya Observer (21 September 2026) and is corroborated by the live tables.
What is *not* verified: the exact promotion count from the First Division (six is arithmetic, not a
quoted number), whether the groups are seeded geographically, and whether any relegation play-off
exists. Wikipedia cannot confirm any of it because there is no 2026-27 season page.
