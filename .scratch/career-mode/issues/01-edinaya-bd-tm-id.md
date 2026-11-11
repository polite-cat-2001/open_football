# 01: Единая БД на tm_id

**What to build:** Игра и карьера читают один `open_football.sqlite` с единственным id = tm_id.
Dev-инструмент собирает его из игровой `database.sqlite` и `canon.db`: страны, лиги, клубы и
игроки получают tm_id как `id` (лиги — коды вида `MEXA`); добавляются поля карьеры (рыночная
стоимость, overall, потенциал, дата рождения, номер, стадион, tier_rank), свободные агенты и
дедупликация 3 500 строк «клуб + сборная». Выбор команд, формы, лица, киты и MatchPackage
продолжают работать, но на новых id; дефолтная пара — Barcelona (131) против Real Madrid (418).

**Blocked by:** None (can start immediately)

**Status:** done (2026-11-09)

**Resolution:** `tools/build_open_football_db.py` собирает `open_football.sqlite` из игровой БД и
`canon.db` по tm_id, пишет eligibility/manifest. `TeamCatalog`/`UiAssets`/`network_lobby`/тесты
переведены на tm_id (id лиг — коды, `legacy_id` только для старых медиа); `SqliteReader` исправлен
для `TEXT PRIMARY KEY`; дефолт — Barcelona 131 / Real Madrid 418. Проверены `check_team_catalog`,
`check_team_select_ui`, `check_kit_select_ui`, `check_match_package`, `check_player_stats`,
`check_gpf_*` (включая net_lobby/net_ui/net_two_process), menu-load и match-scene baseline.

- [x] Инструмент сборки выдаёт `open_football.sqlite` и `open_football_eligibility.json` в data-root; повторный запуск пересобирает файл без ручных шагов.
- [x] В БД ровно одна строка на сущность: 4 406 клубов + 246 сборных, 121 927 игроков, 279 лиг + `NAT`, 106 стран + `International`; `id` = tm_id.
- [x] Поля карьеры присутствуют и заполнены (market_value, overall, pot, birth_date, shirt_number, стадион, tier_rank); свободные агенты доступны.
- [x] `TeamCatalog`, `KitCatalog`, `UiAssets`, `MatchPackage` читают новую БД; id лиг — строки, стран/клубов/игроков — целые.
- [x] Обновлены дефолтная пара, фикстуры и тесты; `check_team_catalog`, `check_team_select_ui`, `check_kit_texture`, `check_match_package`, `check_gpf_*`, menu-load — PASS.
- [x] Quick Match, выбор команд и сетевой лобби не изменились визуально и функционально.
