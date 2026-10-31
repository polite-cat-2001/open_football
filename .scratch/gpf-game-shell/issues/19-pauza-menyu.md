# 19: Меню паузы матча

**What to build:** Пауза по ходу матча с меню как в оригинале (`src/menu/ingame/ingame.cpp`,
`IngamePage`): Continue, game plan, controller select, side selection, camera settings, visual
options, system settings, replay, forfeit. C++ замораживает матч, Godot рисует меню; возврат
снимает паузу. В 2P пауза общая (как в оригинале), пункт Continue показывает голоса, если
появится сеть.

**Blocked by:** 11, 17

**Status:** in-progress (каркас и основные действия готовы; подменю — по мере 20/21)

- [x] `runtime.pause_match()` / `resume_match()` в мосте (C++ `Match::Pause`).
- [x] Godot-меню паузы по раскладке `IngamePage`: Continue, game plan, controller select,
      side selection, camera settings, visual options, system settings, replay, forfeit.
- [ ] Подменю: camera/visual/system — сейчас это быстрые действия (стадионная камера,
      освещение, fullscreen), а не полноценные экраны оригинала.
- [x] Forfeit → подтверждение → главное меню; Continue → resume.
- [x] Клавиатура и геймпад: B/Esc закрывает, A/Enter выбирает; фокус виден.
- [x] Геймпад проверен вживую: Start, D-pad, левый стик, A, B; работает даже с не
      назначенного стороне геймпада (Start/пауза обрабатываются до `input_slots`).
- [x] `ui_lab` + скриншоты 1920/1280; layout/focus-тест зелёный.
- [ ] В 2P пауза ставит матч и не ломает управление после resume — проверить вживую.
- [x] Headless-тест: пауза → `snapshot.paused`, resume → тик идёт.

**As-built (2026-10-31):** `scripts/match/gpf_pause_menu.gd` (`GpfPauseMenu`) — CanvasLayer,
центрированная панель, все 9 пунктов `IngamePage`, подтверждение форфейта. `gpf_slice` открывает
её по `Esc`/Start, зовёт `runtime.pause_match()`/`resume_match()`, роутит клавиатуру/геймпад.
Continue/forfeit работают; camera/visual/system переключают стадионную камеру, освещение и
fullscreen; game plan/controller/side/replay показывают честную подсказку (20/21/следующие
тикеты). Добавлено состояние `PAUSE` в `ui_lab` (9 состояний, 26 PNG), `check_gpf_pause` PASS.
Живой прогон: Esc ставит матч на паузу (`paused: true`), Enter продолжает и тик идёт.

> **UI-политика:** если этому тикету нужен UI, портировать соответствующий экран/элемент из
> оригинала (`GameplayFootball-of_port/src/menu/...`) — та же раскладка, подписи, иконки,
> управление и порядок экранов. Godot-UI не изобретать заново; отступления документировать.
