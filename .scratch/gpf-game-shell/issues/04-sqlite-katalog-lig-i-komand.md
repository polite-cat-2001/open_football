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
`scenes/team_select.tscn` (`scripts/ui/team_select.gd`) открывается кнопкой **Select Teams** в
главном меню, показывает 280 лиг / 4652 команды из базы, даёт выбрать Home/Away и сохраняет выбор
в `ShellState`; **Start Match** на этом экране пока открывает `gpf_slice` со старыми C++-id
(пакет матча — тикет 06). Тесты: `tests/check_team_catalog.gd` (сверка с `manifest.json`,
ошибки отсутствующей/битой базы) и `tests/check_team_select_ui.gd` (меню → экран, выбор,
сохранение, сообщение об ошибке).

- [x] Godot читает базу без C++-каталога.
- [x] Экран выбора показывает лиги и команды из базы.
- [x] Отсутствие или повреждение базы показывается понятным сообщением.
- [x] Тест читает ожидаемое число лиг и команд.
- [x] Выбор команд сохраняется для следующего шага.
