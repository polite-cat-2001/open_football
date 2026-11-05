# 09: PreMatch — роли и тактика

**What to build:** Перед матчем можно выбрать капитана, пенальтиста, исполнителей штрафных и
угловых и тактическую схему. Матч использует выбранные роли и тактику, а не значения по умолчанию.

**Blocked by:** 08

**Status:** done (2026-11-01; покрыт тикетом 20)

- [x] Роли выбираются и сохраняются в пакете матча.
- [x] Тактическая схема выбирается и видна в матче.
- [x] C++ использует выбранные роли и тактику.
- [x] Headless-тест проверяет роли и смену схемы.

**As-built:** сделано в тикете 20 (Game plan): `GpfGamePlan` — вкладка Game plan в премате и
экран из паузы, секции Tactics/Positions/Roles; `MatchLineup.roles`/пакет `roles` →
`MatchData::SetRolePlayer`, in-match `set_team_role`; тактики — `TacticalSchemes` (6 схем) +
`MatchLineup.apply_scheme`/`apply_tactical_scheme` (`ApplySchemeToTeam`). Тесты:
`tests/check_tactical_schemes.gd`, `tests/check_gpf_match_package.gd` (роли доходят до
`MatchData` и `get_squad`), `tests/check_gpf_game_plan.gd` (Roles/Tactics, in-match bridge,
2P ownership). Все PASS.

> **UI-политика:** если этому тикету нужен UI, портировать соответствующий экран/элемент из
> оригинала (`GameplayFootball-of_port/src/menu/...`) — та же раскладка, подписи, иконки,
> управление и порядок экранов. Godot-UI не изобретать заново; отступления документировать.
