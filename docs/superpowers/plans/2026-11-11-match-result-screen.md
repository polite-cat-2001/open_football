# Экран конца матча и выбор ничьей — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** заменить два «чёрных окна» конца матча на дизайн-системные экраны `RESULT` (итог) и
`DECISION` (ничья на 90:00), одинаково работающие в быстром и сетевом матче.

**Architecture:** две тонкие сцены поверх общей базы `MatchOverScreen` (верхний `PauseScoreboard`,
мета-строка, 2×2 плиток + правая `SOON`-панель, `UiHintsBar`, `UiTransition`, `UiNav`).Действия
`classic`/`penalties`/`draw` идут в мост: существующие `continue_after_phase_break()` /
`debug_force_game_over()` плюс новый `start_shootout()`. Маршрутизацию по снапшоту держит
`gpf_slice.gd`.

**Tech Stack:** C++ (`of_port`) + GDExtension (godot-cpp), Godot 4.7 GDScript. Тесты — headless
`SceneTree`-скрипты `tests/check_*.gd`.

## Global Constraints

- Референс и принятые решения — `docs/superpowers/specs/2026-11-11-match-result-screen.md`.
- Сборка расширения (из `AGENTS.md`):
  ```
  cmake -S gdextension -B gdextension/build-ofport -G "Visual Studio 17 2022" -A x64 -DGODOTCPP_TARGET=template_release -DGPF_REPO="C:\Users\Egor\Desktop\projects\GameplayFootball-of_port" -DGPF_BUILD="C:\Users\Egor\Desktop\projects\GameplayFootball-of_port\build-ofport"
  cmake --build gdextension/build-ofport --config Release --target open_football_gdext
  ```
- Проверки: `godot --headless --quit`; `godot --headless -s res://tests/check_<x>.gd`.
- GDScript не двигает актёров; решение о продолжении матча — только C++/мост.
- UI только из дизайн-системы: никаких локальных панелей/легенд, подсказки — `UiHintsBar`.
- Плитки и состояния — `BentoTile`/`BentoGrid`; новых визуальных сущностей не заводим.

---

## Task 1: Турнир в пакете матча

**Files:** `scripts/data/match_package.gd`, `tests/check_match_package.gd`

**Interfaces:**
- Produces: ключ `league` (String) в каждом `package["home"]`/`package["away"]` — имя лиги из
  `catalog.league_by_id(team.league_id)`, пустая строка при отсутствии.

- [ ] **Step 1:** добавить `"league"` в `_team_package(...)` (передать имя лиги из `build()` или
  посчитать внутри по `team.league_id`), не меняя остальных ключей.
- [ ] **Step 2:** в `tests/check_match_package.gd` добавить проверку `league` непустой у обеих
  команд фикстуры (и что остальные ключи не сломались).
- [ ] **Verify:** `godot --headless -s res://tests/check_match_package.gd` — PASS.

## Task 2: `start_shootout()` в мосте

**Files:** `gdextension/src/gpf_runtime_node.h`, `gdextension/src/gpf_runtime_node.cpp`

**Interfaces:**
- Produces: `start_shootout()` — снимает `phase_break_pending`/`phase_break_next_phase`, зовёт
  `match->SetPhaseBreak(false)`, `match->Pause(false)`, затем `match->StartShootout(true)`.
  Не запускает серию повторно (`shootoutActive`), ничего не делает при `game_over_seen`.
- Consumes: `Match::StartShootout(bool)`, `Match::SetPhaseBreak`, `Match::Pause`.

- [ ] **Step 1:** объявить и забиндить `start_shootout()` рядом с `debug_force_shootout`.
- [ ] **Step 2:** реализовать по `Interfaces`.
- [ ] **Step 3:** пересобрать расширение (команды выше).
- [ ] **Verify:** `godot --headless -s res://tests/check_gpf_shootout.gd` — PASS (старый путь не
  сломан).

## Task 3: База `MatchOverScreen` + сцена RESULT

**Files:** `scripts/ui/match_over_screen.gd` (new), `scenes/match/match_result.tscn` (new),
`scripts/ui/match_result.gd` (new), `scripts/ui/ui_lab.gd`

**Interfaces:**
- `class_name MatchOverScreen extends Control`:
  - `const PANEL_W := 1480.0`, `const HEADER_H := 156.0`, `const META_H := 22.0`.
  - `func set_match_data(data: Dictionary)` — `{home, away, score0, score1, caption, meta}`;
    пишет в `PauseScoreboard.setup(home, away, score0, score1, "FULL TIME", caption)` и в
    мета-`Label`.
  - `func tiles() -> Array` — 4 плитки в порядке сетки.
  - `func open()`, `func close()`, `func hide_now()`, `func is_open()`, `func is_closing()`.
  - `func handle_key(InputEventKey) -> bool`, `func handle_joy(InputEventJoypadButton) -> bool`
    (fallback без autoload, как у `PauseScreen`).
  - Сигналы базы: нет; наследник объявляет свои.
- `class_name MatchResultScreen extends MatchOverScreen`:
  - сигналы `advance_requested`, `restart_requested`.
  - `func set_online(is_online: bool)` — в сети `RESTART MATCH` disabled, чип `ONLINE LOBBY`.
- Layout: как `PauseScreen._layout()` — design 1920×1080, `PANEL_W` по центру; мета над хедером;
  тело `HEADER_H + GAP` ниже; левая сетка `(PANEL_W - GAP)/2`, правая панель столько же;
  `BentoGrid` `columns=2, rows=2`; hints — `HINTS_GAP` под телом.

- [ ] **Step 1:** написать базу: узлы (`Scrim`, `Design`, `Meta`, `Scoreboard`, `Body/Grid`,
  `Body/InfoTile`, `Hints`), `_layout()`, `open/close/hide_now`, ввод (фокус по сетке, A/Enter,
  B/Esc не закрывает результат), `UiTransition` (headless bypass).
- [ ] **Step 2:** сцена `match_result.tscn` — 4 `BentoTile` (`ADVANCE`/exit, `RESTART MATCH`/resume,
  `MATCH HIGHLIGHTS`/replay+SOON, `PERFORMANCE`/skills+SOON) и правая `PLAYER PERFORMANCE`
  (`ratings`, SOON, `still`).
- [ ] **Step 3:** адаптер `match_result.gd` — tile wiring, `set_online`, сигналы; `RESTART` не
  эмитится, когда disabled.
- [ ] **Step 4:** `ui_lab` — состояние `RESULT` на синтетическом снапшоте/данных.
- [ ] **Step 5:** тест `tests/check_match_result_ui.gd` — 4 плитки, 2 живые / 2 SOON, фокус только
  по живым, `ADVANCE`/`RESTART` эмитят, `RESTART` disabled в онлайне, ширины на 1920 и 1280.
- [ ] **Verify:** `godot --headless -s res://tests/check_match_result_ui.gd` — PASS; скриншоты
  `.scratch/ui_shots/` не деградировали.

## Task 4: Сцена DECISION

**Files:** `scenes/match/match_choice.tscn` (new), `scripts/ui/match_choice.gd` (new),
`scripts/ui/ui_lab.gd`

**Interfaces:**
- `class_name MatchChoiceScreen extends MatchOverScreen`:
  - сигнал `option_chosen(id: String)` — `"classic" | "penalties" | "draw"`.
  - `func set_online(is_online: bool)` — плитки не фокусируемы, статус `WAITING FOR HOST`,
    `option_chosen` не эмитится.
- Плитки: `CLASSIC`/resume, `GOLDEN GOAL`/trophy+SOON+disabled, `PENALTIES`/pitch, `DRAW`/sides;
  правая панель `MATCH INFO` (tactics, SOON, `still`).

- [ ] **Step 1:** сцена + адаптер поверх базы (только свой набор и wiring).
- [ ] **Step 2:** `ui_lab` — состояние `DECISION`.
- [ ] **Step 3:** тест `tests/check_match_choice_ui.gd` — 4 плитки, `GOLDEN GOAL` disabled,
  фокус пропускает её, `option_chosen` для трёх живых, сетевой режим ожидания.
- [ ] **Verify:** `godot --headless -s res://tests/check_match_choice_ui.gd` — PASS.

## Task 5: Носитель и маршрутизация в срезе

**Files:** `scripts/match/gpf_match_over.gd` (new), `scripts/match/gpf_slice.gd`,
`scripts/match/gpf_hud.gd`, `scripts/match/gpf_shootout_view.gd`, `scenes/gpf_slice.tscn`

**Interfaces:**
- `class_name GpfMatchOver extends Node` — `setup()`, `set_match(runtime, package)`,
  `open_result(series_caption := "")`, `open_choice()`, `is_open()`, `is_choice()`,
  `handle_key(...)`, `handle_joy(...)`, `dismiss()`; сигналы `advance_requested`,
  `restart_requested`, `choice_made(id: String)`. Один `CanvasLayer` (layer 7).
- `GpfSlice`:
  - `_sync_match_over(snap)`: `game_over && !shootout_active` → RESULT; иначе
    `phase_break_pending && phase_break_next_phase == 3 && score0 == score1` → DECISION;
    ESC/пауза/сет-писы заблокированы, пока оверлей открыт.
  - `choice_made`: `classic` → `continue_after_phase_break()`; `penalties` →
    `runtime.start_shootout()`; `draw` → `runtime.debug_force_game_over()`.
  - `GpfShootoutView` на `PHASE_FINISHED` зовёт `open_result("PENALTIES %d – %d")` вместо своего
    меню.
  - Гейтинг: локально — только устройство P1 (`_end_screen_owner_device`), в сети — только хост
    (`set_online(true)` + `runtime.is_net_client()`).
- `GpfHud`: удалить `phase_menu*` (и `handle_phase_menu_key`/`is_phase_menu_open`); `game_over` в
  HUD-строке остаётся.
- `GpfShootoutView`: удалить `shootout_end_*` и `_build_end_menu`; `is_end_menu_open` больше не
  нужен — убрать вызовы из `gpf_slice`.

- [ ] **Step 1:** носитель + `preload` обоих сцен, ленивое создание, `UiTransition`-анимация.
- [ ] **Step 2:** маршрутизация и действия в `gpf_slice` (включая приоритет над паузой и taker-меню).
- [ ] **Step 3:** удалить старые окна и их вызовы; обновить тесты, которые их трогали
  (`check_gpf_slice_ui.gd`, `check_gpf_game_shell.gd`, `check_gpf_shootout.gd`).
- [ ] **Step 4:** тест `tests/check_gpf_result_flow.gd` на синтетических снапшотах: приоритеты
  маршрутизации, действия зовут `continue_after_phase_break`/`start_shootout`/`debug_force_game_over`,
  в сети клиент не эмитит выбор.
- [ ] **Verify:** `check_gpf_result_flow`, `check_gpf_pause`, `check_gpf_slice_ui`,
  `check_gpf_shootout`, `check_gpf_game_shell` — PASS; `godot --headless --quit` без новых ошибок.

## Task 6: Живая приёмка и документация

**Files:** `docs/wiki/порт-gdextension.md`, `docs/wiki/дизайн-система-ui.md`, `AGENTS.md`, `log.md`

- [ ] **Step 1:** ручной прогон: быстрый матч → разный счёт → RESULT → ADVANCE/RESTART; равный счёт
  → DECISION → DRAW/CLASSIC/PENALTIES; серия → RESULT.
- [ ] **Step 2:** обновить вики (экран результата, выбор ничьей, удалённые окна), `AGENTS.md`
  (раздел GDExtension slice), строку в `log.md`.
- [ ] **Verify:** `wiki-lint`-правила соблюдены (ссылки, константы не расходятся).

---

## Порядок

1 → 2 → 3 → 4 → 5 → 6. Task 3 требует 1 (мета-строка), Task 5 требует 2–4.
