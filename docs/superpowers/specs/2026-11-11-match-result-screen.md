# Экран конца матча и выбор исхода ничьей (GPF-срез) — дизайн

**Дата:** 2026-11-11
**Статус:** к реализации (решения зафиксированы grilling-сессией 2026-11-11).
**Референс:** FIFA-подобный экран «Player Performance» (пасхалка из брифинга; см. описание
компоновки ниже). Референс — источник **компоновки и стиля**, не источник данных.

## Что делаем

Заменяем два «чёрных окна» конца матча (`GpfHud._build_phase_menu` и
`GpfShootoutView._build_end_menu`) на **два дизайн-системных экрана**, повторяющих раскладку
меню паузы:

1. **RESULT** (`scenes/match/match_result.tscn`) — итог матча: верхний скорборд-виджет и 2×2
   плиток, где `ADVANCE` (выход в главное меню) и `RESTART MATCH` (тот же пакет) живые, а
   `MATCH HIGHLIGHTS` и `PERFORMANCE` — `SOON`. Справа — большая `SOON`-панель
   `PLAYER PERFORMANCE`.
2. **DECISION** (`scenes/match/match_choice.tscn`) — показывается только при **ничьей на 90:00**:
   тот же скорборд-виджет и те же 4 клетки, но с выбором `CLASSIC` / `GOLDEN GOAL` (`SOON`) /
   `PENALTIES` / `DRAW`.

Это верно и для быстрого матча, и для сетевого: путь одинаков, различается только то, кто
принимает решение (см. «Сеть и 2P»).

## Компоновка референса (что повторяем)

- Фон — замороженный кадр матча под тёмно-синим скримом; контент 1920×1080.
- Сверху мелкая строка-мета в разрядку: турнир (у нас — лига хозяев из пакета).
- Скорборд-хедер: герб слева, по центру `HOME  score – score  AWAY`, над счётом — маленькая
  подпись; тонкая линия-разделитель под блоком.
- Тело: слева сетка плиток 2×2, справа большая информ-панель.
- Снизу слева — блок подсказок управления (наш `UiHintsBar`).

## Решения (зафиксированы)

- **Два независимых сцены**, не режимы `PauseScreen` и не один экран с двумя состояниями.
  Общий низкоуровневый слой — один класс-база `MatchOverScreen` (скорборд, мета-строка, 2×2 +
  правая панель, `UiHintsBar`, `UiTransition`, `UiNav`); каждая сцена — только свой набор из 4
  плиток и своих действий. Образец — `prematch`/`network_match_hub` поверх `MatchHubView`.
- **Верхний виджет переиспользуем**: `PauseScoreboard` без изменений.
- **Правая панель** — `SOON`-заглушка (`BentoTile` `still`): заголовок `PLAYER PERFORMANCE`
  (+ иконка), чип `SOON`. Никаких выдуманных данных игрока/тренера в первом заходе.
- **Хедер:** `clock = "FULL TIME"`; для финала серии пенальти вместо часов подпись
  `PENALTIES 5 – 4` (слот `caption` того же виджета).
- **Язык** — английский, как вся дизайн-система.
- **Живые только `ADVANCE` и `RESTART MATCH`**; всё остальное — `SOON` с `disabled = true`.
  `GOLDEN GOAL` — заглушка без логики.
- **Ничья после доп. времени** (120:00) — сразу серия пенальти, без экрана выбора
  (уже так работает в C++).
- **Ничья после 1-го доп. времени** (105:00) — обычное 2-е доп. время, без экрана выбора.
- **Решает хост / P1** (см. «Сеть и 2P»).
- **`ADVANCE` в сети** уводит в главное меню обоих пиров (как сейчас у shootout-end).
- **Оба старых окна удаляем.**

## Потоки

```
90:00, счёт разный   → (мост) GameOver                 → RESULT
90:00, ничья         → DECISION
   ├─ CLASSIC        → continue_after_phase_break()    → доп. время (+ пенальти на 120' при ничьей)
   ├─ PENALTIES      → start_shootout()                → серия
   ├─ DRAW           → end_match_now() (GameOver)      → RESULT
   └─ GOLDEN GOAL    → заблокировано (SOON)
105:00, счёт разный  → (мост) GameOver                 → RESULT
105:00, ничья        → обычный брейк (BEGIN SECOND EXTRA TIME), без выбора
120:00, счёт разный  → (мост) GameOver                 → RESULT
120:00, ничья        → (мост) авто-серия пенальти
конец серии           → RESULT (счёт серии в подписи)
```

`DECISION` открывается вместо брейк-экрана паузы только при `phase_break_next_phase == 3`
(начало 1-го доп. времени) и равном счёте. Брейки 45:00 (`2`) и 105:00 (`4`) остаются
существующим экраном паузы (`GpfPauseMenu.open_break`).

## Экран RESULT

- Мета-строка: лига хозяев, uppercase, разрядка.
- Скорборд: `PauseScoreboard.setup(home, away, score0, score1, "FULL TIME")`; при финале серии —
  `caption = "PENALTIES %d – %d"`.
- Плитки (2×2, слева):
  - `ADVANCE` (иконка `exit`) → главное меню.
  - `RESTART MATCH` (иконка `resume`) → тот же пакет заново.
  - `MATCH HIGHLIGHTS` (иконка `replay`, `SOON`, disabled).
  - `PERFORMANCE` (иконка `skills`, `SOON`, disabled).
- Правая панель: `PLAYER PERFORMANCE` (иконка `ratings`, `SOON`, `still`).
- `UiHintsBar`: move / select (геймпад — D-PAD / A).

## Экран DECISION

- Мета-строка и скорборд — те же (счёт на 90:00, `FULL TIME`).
- Плитки (2×2, слева):
  - `CLASSIC` (иконка `resume`) → доп. время + пенальти.
  - `GOLDEN GOAL` (иконка `trophy`, `SOON`, disabled).
  - `PENALTIES` (иконка `pitch`) → сразу серия.
  - `DRAW` (иконка `sides`) → принять ничью, экран RESULT.
- Правая панель: `MATCH INFO` (`SOON`, `still`).
- `UiHintsBar`: move / select; для сети — статус `WAITING FOR HOST`, плитки не фокусируемы.

## Визуальный стиль

Всё берётся из существующих токенов (`UiTokens`): плитки `TILE`, фокус `FOCUS_FILL`, акцент
`RAIL` (маджента) на выбранной, мета `FOCUS_INK_2`, подпись серии `FOCUS_MARK`. Скругления/тени
уже в `BentoTile`. Новых стилевых сущностей нет. Открытие — `UiTransition` (fade+scale 150/240),
как у паузы; скрим — `ColorRect` как у `PauseScreen`.

## C++/мост

- **Не хватает одного биндинга.** `debug_force_shootout()` зовёт `StartShootout(false)`, а на
  брейке матч вне игры → нужен публичный `start_shootout()`, который снимает брейк-латч
  (`SetPhaseBreak(false)`, `Pause(false)`) и зовёт `StartShootout(true)`.
- **Принять ничью** — существующий `debug_force_game_over()` (без проверок чистого состояния);
  отдельного биндинга не заводим.
- Всё остальное уже есть: `phase_break_pending`/`phase_break_next_phase`, `begin_phase_break()`,
  `continue_after_phase_break()`, авто-ET и авто-серия на 120'.

## Сеть и 2P

- **Сеть:** решение принимает хост; клиент показывает экран выбора в режиме ожидания
  (`WAITING FOR HOST`, без фокуса). Выбор хоста отражается снапшотом (`phase_break`/`game_over`/
  `shootout_active`), поэтому клиентский оверлей закрывается сам — нового сетевого кода нет.
- **Локальный 2P:** решение принимает устройство P1 (первый человеческий контроллер), как владелец
  оверлея в меню исполнителя стандарта; ввод второго устройства игнорируется.
- `RESTART MATCH` в сети — **disabled** с чипом `ONLINE LOBBY` (локальный рестарт десинкает; как и
  сейчас `_start_fresh_match` отказывается работать в сети).

## Данные

Пакет матча сейчас не несёт турнир. Добавляем в запись команды пакета ключ `league` (имя лиги из
каталога по `league_id`) — мета-строка берёт его из `home`. Больше ничего.

## Что удаляем

- `GpfHud._build_phase_menu`/`_open_phase_menu`/`_refresh_phase_menu`/`_close_phase_menu`/
  `handle_phase_menu_key` и связанные поля (FULL TIME-окно).
- `GpfShootoutView._build_end_menu`/`_open_end_menu`/`handle_end_menu_key`/`_continue`/`_restart` и
  экран `КОНЕЦ МАТЧА`.
- Оба экрана больше не показываются: их пути заменяет новый оверлей.

## Тестирование

- `tests/check_match_result_ui.gd` — headless: 4 плитки, две живые / две `SOON`, правый `SOON`-таб,
  фокус и раскладка на 1920 и 1280, `ADVANCE`/`RESTART` сигналы, мета-строка и `FULL TIME`.
- `tests/check_match_choice_ui.gd` — headless: 4 плитки `CLASSIC`/`GOLDEN GOAL`/`PENALTIES`/`DRAW`,
  `GOLDEN GOAL` disabled, сигнал выбора, режим ожидания в сети.
- `tests/check_gpf_result_flow.gd` — headless на синтетическом снапшоте: маршрутизация
  (ничья-90 → DECISION; `game_over` → RESULT; брейк 45/105 → старый экран паузы), действия
  `classic`/`penalties`/`draw` зовут правильные методы моста, серия-финал → RESULT.
- `tests/check_gpf_shootout.gd` — обновить: конец серии открывает RESULT, старое меню больше не
  ищется.
- `ui_lab` — состояния `RESULT` и `DECISION` + скриншоты 1920/1280.

## Затрагиваемые файлы

- `gdextension/src/gpf_runtime_node.cpp` / `.h` — биндинг `start_shootout()`.
- `scripts/data/match_package.gd` — `league` в записи команды.
- `scripts/ui/match_over_screen.gd` (новый, база), `scripts/ui/match_result.gd`,
  `scripts/ui/match_choice.gd` (новые, адаптеры).
- `scenes/match/match_result.tscn`, `scenes/match/match_choice.tscn` (новые).
- `scripts/match/gpf_match_over.gd` (новый носитель-оверлей) — или встроить в `GpfSlice`, см. план.
- `scripts/match/gpf_slice.gd` — маршрутизация обоих экранов, действия, гейтинг хост/P1.
- `scripts/match/gpf_hud.gd`, `scripts/match/gpf_shootout_view.gd` — удаление старых меню.
- `scripts/ui/ui_lab.gd` — состояния стенда.
- `tests/*` — новые/обновлённые, см. выше.
- `docs/wiki/порт-gdextension.md`, `docs/wiki/дизайн-система-ui.md`, `AGENTS.md`, `log.md`.

## Вне рамок

- Настоящие MATCH HIGHLIGHTS / PLAYER RATINGS / PERFORMANCE / ACCOMPLISHMENTS (данных нет).
- Golden goal как механика.
- Реванш в сети (идёт через лобби, отдельная задача).
- Изменения `PauseScoreboard` (виджет трогаем только вызовом).
