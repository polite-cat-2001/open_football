# 05: Статы и формация в Godot

**What to build:** Godot считает итоговые статы игроков и позиции/роли формации по формулам
оригинала. Экран состава показывает результат. Матч пока идёт старым путём, поэтому поведение игры
не меняется — проверяется только правильность чисел.

**Blocked by:** 04

**Status:** done

**Resolution:** `scripts/data/player_stats.gd` (`PlayerStats`) переносит `CalculateStat` из
`src/utils.cpp` (curve/NormalizedClamp, идеальный возраст 27, aged base ×1.2, profile ×2,
clamp 0.01..1). `scripts/data/formation.gd` (`Formation`) переносит `TeamData::InitFromRaw`:
разбор `formation_xml`, смешение базы с дефолтной позицией роли 60/40 и расталкивание
не-вратарей до 0.5 (10 итераций, клампы -1..1). `TeamCatalog.load_squad()` читает состав по
индексам `team_id`/`nationalteam_id` (клубы и сборные), сортирует по
`formationorder`/`nationalteamformationorder` и считает статы; `SqliteReader` получил
index-b-tree (`select_indexed`), поэтому состав грузится ~0.1 с вместо ~2.6 с полного скана.
Экран `scenes/squad.tscn` (`scripts/ui/squad.gd`) открывается кнопкой **View squad** на экране
выбора: схема с 11 позициями и список игроков с итоговыми статами. Эталон C++ —
`tools/player_stats_reference/main.cpp` → `tests/fixtures/player_stats_reference.json`
(суммы/суммы квадратов по всем 125 402 игрокам + 1306 сэмплов + 7 формаций). Тесты:
`tests/check_player_stats.gd` и `tests/check_squad_ui.gd` — PASS; регресс
`check_team_catalog`, `check_team_select_ui`, `check_gpf_game_shell`, menu-load — PASS.

- [x] Формула «база + профиль + возраст» перенесена; тест сверяет результат с эталоном C++ для всех игроков в допуске.
- [x] Формация парсится и нормализуется как в оригинале; позиции и роли совпадают для выборки команд.
- [x] Экран состава показывает итоговые статы и позиции.
- [x] Матч пока использует прежний путь; игровое поведение не меняется.
