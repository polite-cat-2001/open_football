# 04: SQLite-каталог лиг и команд в Godot

**What to build:** Godot сам открывает базу и показывает реальные лиги и команды в экране выбора.
C++-каталог для этого больше не нужен. Выбор команд сохраняется в состоянии оболочки и будет
использован на следующем шаге.

**Blocked by:** None (can start immediately)

**Status:** done

**Resolution:** Godot читает `database.sqlite` сам: `scripts/data/sqlite_reader.gd`
(`SqliteReader`) — read-only разбор table b-tree (листья, interior-страницы, overflow, serial
types), `scripts/data/team_catalog.gd` (`TeamCatalog`) — лиги/команды и читаемые ошибки
(«not found» / «could not be read»), `scripts/data/shell_state.gd` (`ShellState`, статическое
состояние оболочки, чтобы работало и в headless `-s` без autoload). Экран
`scenes/team_select.tscn` (`scripts/ui/team_select.gd`) — **порт оригинального
`TeamSelectPage`**: две панели Player 1/Player 2, карусели Country/Competition/Team
(`UiIconCarousel`), Ready; 280 лиг / 4652 команды из базы, выбор уходит в `ShellState`, Ready
обеих сторон открывает прематч (пакет матча — тикет 06). `TeamCatalog` дополнительно отдаёт
страны, `logo_url` лиг/команд и `kit_url` для UI. Тесты: `tests/check_team_catalog.gd` (сверка
с `manifest.json`, ошибки базы) и `tests/check_team_select_ui.gd` (меню → экран, карусели,
Ready → прематч, сообщение об ошибке).

- [x] Godot читает базу без C++-каталога.
- [x] Экран выбора показывает лиги и команды из базы.
- [x] Отсутствие или повреждение базы показывается понятным сообщением.
- [x] Тест читает ожидаемое число лиг и команд.
- [x] Выбор команд сохраняется для следующего шага.

> **UI-политика:** если этому тикету нужен UI, портировать соответствующий экран/элемент из
> оригинала (`GameplayFootball-of_port/src/menu/...`) — та же раскладка, подписи, иконки,
> управление и порядок экранов. Godot-UI не изобретать заново; отступления документировать.
