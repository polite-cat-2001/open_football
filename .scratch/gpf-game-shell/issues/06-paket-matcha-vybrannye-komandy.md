# 06: Пакет матча — выбранные команды на поле

**What to build:** Выбор двух команд ведёт через минимальный прематч (длительность, сложность) в
матч. Godot собирает пакет: команды, игроки с готовыми статами, позиции, роли и опции. C++
строит матч из этого пакета и больше не читает базу для матча. На поле правильные команды,
составы, статы и позиции.

Это первый переход, который сдвигает случайную последовательность: C++ больше не тратит случайные
числа на чтении базы. Временной заглушки нет — следующая ручная проверка геймплея в тикете 07.

**Blocked by:** 03, 05

**Status:** done

**Resolution:** `scripts/data/match_package.gd` (`MatchPackage`) собирает пакет: обе команды,
весь состав с 22 итоговыми статами из `PlayerStats`, 11 нормализованных ролей/позиций из
`Formation`, formation/tactics XML, цвета, `logo_url`/`kit_url` с префиксом `databases/default/`
и опции `duration`/`difficulty`. `TeamCatalog.load_squad` теперь читает и внешность
(`skincolor`/`hairstyle`/`haircolor`/`height`/`strong_foot`/`tm_id`) и полные тактические колонки.
Экран `scenes/prematch.tscn` (`scripts/ui/prematch.gd`) — **порт `PreMatchPage`**: 7 вкладок
Kit/Stadium/Kick-off/Game plan/Options/Camera/System, Kick-off (два столбца стартовых, Edit
lineups, Start match), Options-слайдеры длины/сложности, Kit-превью. Ready на team select
открывает хаб, **Start match** кладёт пакет в `ShellState.match_package` и открывает
`gpf_slice`. Встроенной пары команд нет: `gpf_slice` без пакета возвращает в выбор команд;
**Start Match** в меню ведёт по оригинальному пути Controller Select → Team Select → PreMatch,
пакет каждый раз собирается заново на Start match.

C++ (чекаут `of_port`): `PlayerDataRaw.stats` и `TeamDataRaw.formation` принимаются как готовые
данные; добавлен `MatchData(const TeamDataRaw&, const TeamDataRaw&)`; `GpfRuntimeNode::set_match_package`
валидирует пакет, `start_match()` строит `MatchData` только из пакета (без SQL) и применяет
`match_duration`/`match_difficulty` из опций; без пакета старт возвращает `false`. Legacy-чтение
базы (`MatchData(int,int)`) в мост не подключено. `debug_get_formation` отдаёт расстановку из
живого `TeamData` для проверки.

RNG: C++ больше не вызывает `random(1,4)` на цвет кожи при чтении базы (по одному на игрока,
включая запасных). Мост по-прежнему делает `blunted::randomize(seed)` прямо перед созданием
матча, поэтому поток RNG *после* reseed тот же; сдвиг — в потреблении до reseed, а геймплей может
пойти иначе из-за float/double в статах/формации. Ручная проверка — тикет 07.

Тесты: `check_match_package` (схема, статы, позиции, опции, ошибки), `check_gpf_match_package`
(C++: имена, 22 игрока, счёт, часы, формация из пакета), `check_prematch_ui` (выбор → прематч →
матч). Регресс PASS: match cycle, full match, 90 winner, rematch, setpieces (все сценарии),
shootout, game shell, slice UI, team select/catalog, player stats/squad, menu-load. Вики —
`docs/wiki/пакет-матча.md`.

- [x] Godot собирает пакет матча из выбранных команд.
- [x] C++ строит матч из пакета и не читает базу для матча.
- [x] На поле правильные команды: имена, 22 игрока, статы и позиции соответствуют пакету.
- [x] Headless-тест запускает матч из пакета и проверяет имена, счёт, время и состав.
- [x] UI-путь: выбор двух команд → минимальный прематч → матч.
- [x] В тикете зафиксировано, что случайная последовательность изменилась; дальше идёт тикет 07.

> **UI-политика:** если этому тикету нужен UI, портировать соответствующий экран/элемент из
> оригинала (`GameplayFootball-of_port/src/menu/...`) — та же раскладка, подписи, иконки,
> управление и порядок экранов. Godot-UI не изобретать заново; отступления документировать.
