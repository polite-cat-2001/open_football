# Серия пенальти в GPF-срезе — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** В GPF Gameplay Slice появляется полноценная серия пенальти (5+5 + sudden death) внутри C++-рантайма: F3 — debug-запуск из любого состояния, ничья после 120' — авто-запуск. Человек бьёт свои удары и защищает чужие. Godot-сторона рисует кружки-индикаторы, баннеры исходов, fade-переходы и финальный экран.

**Architecture:** Серия живёт в referee/match-слое внешнего чекаута `GameplayFootball-of_port` (состояние, чередование, монетка, выбор ворот, очередь по навыку пенальти, классификация исходов с таймаутом, эмоции-клипы, подавление кик-оффа/повторов/часов), переиспользуя штатный одиночный пенальти. GDExtension-обёртка экспортирует `debug_force_shootout()` + поля серии в снапшот. `gpf_slice.gd` — чистая презентация. Legacy `match.tscn` не трогаем.

**Tech Stack:** C++ (GameplayFootball `of_port`), GDExtension (godot-cpp), Godot 4.7 GDScript, CMake + Visual Studio 2022. Тесты — headless `SceneTree`-скрипты (`tests/check_gpf_*.gd`).

## Global Constraints

- Чекаут: `C:\Users\Egor\Desktop\projects\GameplayFootball-of_port` (ветка `of_port`, локальные коммиты `3b42ef9`, `da1d99f` — прецедент правок под срез).
- **Сборка расширения** (из AGENTS.md):
  ```
  cmake -S gdextension -B gdextension/build-ofport -G "Visual Studio 17 2022" -A x64 -DGODOTCPP_TARGET=template_release -DGPF_REPO="C:\Users\Egor\Desktop\projects\GameplayFootball-of_port" -DGPF_BUILD="C:\Users\Egor\Desktop\projects\GameplayFootball-of_port\build-ofport"
  cmake --build gdextension/build-ofport --config Release --target open_football_gdext
  ```
  C++-библиотеки GPF — Release x64 в `build-ofport` чекаута; линкуется `netlib.lib`.
- **Запуск:** `godot --path . res://scenes/gpf_slice.tscn`; headless-тесты: `godot --headless -s res://tests/check_gpf_*.gd`.
- GDScript **не двигает игроков** — вся расстановка в C++. Godot делает только: F3, HUD, fade, quit.
- Стиль среза: поллинг снапшота в `_process`, прямые вызовы, никакой сигнальной архитектуры с GDScript-стороны (события серии — поля снапшота).
- Спек: `docs/superpowers/specs/2026-10-29-penalty-shootout-gpf.md`.

---

## Структура файлов

**Внешний чекаут `GameplayFootball-of_port`:**
- `src/onthepitch/referee.cpp`, `src/onthepitch/match.cpp`, `src/gamedefines.hpp` (+ что покажет Task 1: `setpiece*.cpp/hpp`, `player/controller/*`).

**В репозитории:**
- `gdextension/src/gpf_runtime_node.cpp` / `.h` — `debug_force_shootout()` + снапшот-поля.
- `scripts/match/gpf_slice.gd` — F3, HUD, fade, финальный экран.
- `tests/check_gpf_shootout.gd` — headless.
- `docs/wiki/порт-gdextension.md`, `docs/wiki/пенальти.md`, `log.md`, `AGENTS.md`.

---

## Task 1: Разведка чекаута — швы для серии

**Files:** чтение внешнего чекаута (правок нет).

**Interfaces:**
- Produces (записываем в Task-заметку/комментарии, не в код): точные места для: (1) вход серии вместо `GameOver()` на ничьей; (2) вычисление штатного пенальтиста/атрибут навыка пенальти (для сортировки очереди); (3) триггер клипов celebration/happy/sad (как запускаются поимённо); (4) подавление extended replay и кик-оффа после гола; (5) `debug_force_set_piece`-путь расстановки одиночного пенальти (переиспользование); (6) способ заморозки полевых (как referee держит их при сете).

- [ ] **Step 1: Найти штатный тэйкер-выбор и атрибут навыка пенальти**
  Grep в чекауте: `Penalty` в `src/onthepitch/setpiece/*`, `GetSetPieceTaker` / `set_piece_taker` / `RequestSetPieceTaker` в `match.cpp`; определить, какой атрибут/рейтинг определяет пенальтиста (ожидаемо: класс атрибутов игрока), и как получить отсортированный список игроков команды. Результат: поле для очереди.
- [ ] **Step 2: Найти путь `GameOver()` на ничьей после 120'**
  `referee.cpp:141`, `:233-249` — фаза PENALTIES → `GameOver()`. Определить, где ветвится: оставить серию «внутри фазы PENALTIES» (рекомендуется: не завершать матч, пока серия не решена).
- [ ] **Step 3: Найти механизм запуска анимации по клипу**
  Grep `celebration`, `happy`, `sad`, `SetAnimationByName`/`FunctionType` в `src/`; как referee заставляет конкретного игрока играть клип (ожидаемо: command/`_SetPlayerFunction`). Результат: вызов для `happy_normal`/`happy_extreme`/`sad_normal` на конкретном игроке.
- [ ] **Step 4: Найти эмитент extended replay и кик-офф после гола**
  `sig_OnExtendedReplayMoment`, логика «гол → празднование → кик-офф» в `referee.cpp`/`match.cpp`. Определить точку глушения для режима серии.
- [ ] **Step 5: Найти способ заморозки полевых и расстановки на центральной линии**
  Как referee паркует не-участников при сет-писах; есть ли готовый «парк всех» (как `toggle_debug_park_opponents`). Результат: способ поставить всех не-участников на центральную линию и заморозить.
- [x] **Step 6: Записать выводы** — ВЫПОЛНЕНО (2026-10-29):

  **1. Вход в серию.**
  - Авто: `referee.cpp:244-247` (фаза PENALTIES → `GameOver()`) → заменить на `StartShootout()`.
  - F3: новый биндинг `debug_force_shootout()` → `Match::StartShootout()` (рядом с `debug_force_set_piece`, `gpf_runtime_node.cpp:890-935`). Запуск только из чистого состояния (не в сет-писе, как у `debug_force_set_piece`).

  **2. Штатный удар/расстановка (переиспользуем).**
  - `referee.cpp:376-393` `DebugForceSetPiece` → buffer (stop/prepare/start: +2с/+4с) + `StopPlay()`; `PrepareSetPiece` (`:291-302`) → `ResetSituation(restartPos)` + `TeamAIController::PrepareSetPiece` + `buffer.taker`.
  - Тэйкер по умолчанию: `teamAIcontroller.cpp:966-984` — роль `e_TeamRole_PenaltyTaker` (`GetRolePlayer` → DB-роль → фолбэк `SuggestRoleSlot` по `TeamRoleSuitability`). **Навык пенальти существует**: `teamdata.cpp:76-77` `TeamRoleSuitability(PenaltyTaker)` = `technical_shot*0.6 + mental_calmness*0.4` — это и есть ключ сортировки очереди серии.
  - Форс-тэйкер: `TeamAIController::PrepareSetPiece(setPiece, takerTeamID, forcedTaker)` (`teamAIcontroller.cpp:678,962-963`); публичный путь — `Match::RequestSetPieceTaker(pending, match.cpp:1584-1586)` / `SetSetPieceTaker` (`match.cpp:716-731`).
  - Позиция тэйкера: `PositionSetPieceTaker` (`teamAIcontroller.cpp:1004-1020`) — за мячом по хеддингу, сдвиг под сильную ногу.
  - Точка мяча: `gpf_runtime_node.cpp:906-908` `restart = -side*(pitchHalfW-11)`; для серии с выбранными воротами: `restart.x = chosenGoalX ± 11` (в поле от выбранных ворот).
  - Вратарь-защитник: hard-clamp к «своей» штрафной (`keeperlogic.hpp:42`, `gamedefines.hpp:147`) — нужен обход на время серии, если выбранные ворота не «родные» для защищающего вратаря.
  - Нырок/человек-вратарь: `match.cpp:2401-2430` (`GetDefenderStick`/`UpdatePenaltyDefense`/`CommitPenaltyDive`) работают в серии без изменений.

  **3. Удар/розыгрыш.**
  - `referee.cpp:271-286` — на `TouchAnim` тэйкера `StopSetPiece`, мяч в игре.
  - Человек-бьющий: `humancontroller.cpp:263-295` (aim/charge → shot); переключение управляемого: `Team::SelectPlayer` (`team.cpp:404`) — на своих ударах серии на тэйкера очереди.

  **4. Исходы.**
  - Гол: `match.cpp:1718-1736` (`CheckForGoal` → `goalScored`/`lastGoalTeamID` + счёт матча). В серии: гейт на счёт матча (не трогаем), гол считаем только в выбранные ворота (`shootoutGoalSide`).
  - Сейв: мяч у вратаря (`GetBallRetainer()` == keeper; сброс — `SetBallRetainer(nullptr)` как в `debug_set_ball`).
  - Мимо: мяч за линиями без гола / мёртв; страховка 3с.
  - Ранний `return` в `Referee::Process` при `shootoutActive` — иначе сработают ветки «мяч за линией» (`referee.cpp:149-218`) и «гол → кик-офф +6с» (`:164-171`).

  **5. Эмоции.**
  - `elizacontroller.cpp:88-91`: `!IsInPlay() && IsGoalScored()` → `_AddCelebration`; тип: `team == lastGoalTeam ? happy(1) : sad(2)` (`:1157-1163`); `madeGoal=2` (happy_extreme) для `lastTouchPlayer` (`:1165-1182`); клип через `e_FunctionType_Special` (`specialVar1=тип`, `specialVar2=madeGoal`) в окне `stopTime+2..4с` (`:1188-1198`).
  - Решающий гол: держим `goalScored` ~5с → eliza сам отыграет счастье (в т.ч. extreme скоррером) + scorer-камера (`match.cpp:1384-1407`).
  - Рядовой гол: гасим `goalScored` сразу после классификации → празднования нет.
  - Сейв/мимо (грусть бьющего): вручную инжектим игроку Special-команду (по образцу `:1188-1198`) через новый Match-метод; ~2с → переход.

  **6. Подавления.**
  - Extended replay: `match.cpp:1402-1406` (`goalScoredTimer>=6000` → pause + `sig_OnExtendedReplayMoment`) — гейт `shootoutActive`; сброс флага `:1288`.
  - Часы матча: `match.cpp:1709` — гейт `shootoutActive`.
  - `step_one_tick` форс-энд (`gpf_runtime_node.cpp:387-401`) — не трогать при `shootoutActive`.

  **7. Парковка не-участников на центральной линии.**
  - `ResetSituation` + дефолт-ветка `PrepareSetPiece` (`teamAIcontroller.cpp:947-953`) возвращают игроков в формацию; eliza «stand still»-ветка (`:118-138`) тянет к формации → парковку применять **каждый тик серии**: `ResetPosition` на центральную линию (обе команды) + eliza-гейт «серия: не участник — стоять на месте». Участники удара: тэйкер у мяча, вратарь-защитник в выбранных воротах.

  **8. Где живёт состояние серии.**
  - Новые поля/методы в `Match` (или секция в `Referee`): `shootoutActive`, фазы, счёт, очереди (`std::vector<Player*>` по `TeamRoleSuitability`), round, `chosenGoalSide`, `winner`. Привод — `Referee::Process` (серия — «свой мир» внутри referee), минимум правок в `Match::Process`.

---

## Task 2: C++ — состояние серии и цикл ударов (чекаут)

**Files (чекаут):** `src/gamedefines.hpp`, `src/onthepitch/referee.cpp`, `src/onthepitch/match.cpp` (+ швы из Task 1).

**Interfaces:**
- Produces (C++-сторона, контур):
  - `enum ShootoutPhase { None, SeriesIntro, KickSetup, KickAim, KickOutcome, Emotion, Transition, DecisiveCelebration, Finished }` (или по существующей стилистике referee-состояний).
  - `Match::StartShootout()` (debug-вход) и авто-вход из `referee` при ничьей после 120'.
  - Внутренние: `shootout_score[2]`, `shootout_kicks_done`, `shootout_order[2][N]` (отсортировано по навыку, Task 1), `shootout_round`, `shootout_active`, `shootout_winner` (-1).
  - Правила: 5+5 с ранним стопом; sudden death парами; монетка на первый удар; случайный выбор ворот один раз на серию.

- [ ] **Step 1: Состояние и данные серии в Match**
  Поля выше + флаг `shootout_active`; в `Match`-инициализации — дефолты. Рандом через существующий seed-зависимый RNG матча.
- [ ] **Step 2: Вход `StartShootout()`**
  Заморозить часы/счёт матча (не трогать до конца серии); запомнить составы; построить очереди сортировкой по навыку (Task 1); выбрать ворота и первого бьющего; расставить всех полевых на центральную линию замороженными; вызвать штатную расстановку одиночного пенальти (`debug_force_set_piece(6, team)`-путь) для первого удара; выставить `shootout_phase`.
- [ ] **Step 3: Авто-вход на ничьей после 120'**
  В `referee.cpp` ветка PENALTIES: вместо `GameOver()` → `StartShootout()` (если человек не запустил F3 раньше).
- [ ] **Step 4: Цикл ударов**
  Текущий удар = штатный одиночный пенальти (прицел/заряд/`CommitPenaltyDive`/`GetDefenderStick` уже работают; управление человека — на бьющего своей команды, на вратаря — на чужом ударе). По исходу (Task 3) — продвинуть счёт серии, кружки, проверить ранний стоп/sudden death; если не решено — `Transition` (перестановка под Godot-fade, причём Godot ждёт от C++ маркер «актёры уже на местах»), затем следующий удар.
- [ ] **Step 5: Победитель**
  `shootout_winner = team`; фаза `DecisiveCelebration` (Task 3); затем `Finished` — снапшот-флаг, по которому Godot покажет баннер и сделает quit.

**Verify:**
- Пересборка расширения (команды Global Constraints) — линкуется без ошибок.
- Ручной запуск: F3 → серия начинается, игроки на центральной линии, первый удар штатно.

- [ ] **Step 6: Коммит (чекаут + репозиторий)**
  Чекаут: отдельный коммит в `of_port`-истории (стиль `3b42ef9`). Репозиторий: бинарники не коммитим — коммит gdextension-биндингов отдельно (Task 4).

---

## Task 3: C++ — исходы, таймаут, эмоции, подавления

**Files (чекаут):** referee/match + швы Task 1.

**Interfaces:**
- Produces: классификация `goal/save/miss` + страховочный таймаут 3с; эмоции по правилам спека; подавление кик-оффа/extended replay/часов; событие исхода для снапшота.

- [ ] **Step 1: Классификация исхода**
  Переиспользовать существующую детекцию гола/сейва; «мимо» = мяч мёртв/покинул пределы без взятия; если мяч в неопределённом состоянии 3с → `miss`. Исход писать в `shootout_last_outcome {type, kicker_id, decisive}`.
- [ ] **Step 2: Эмоции**
  Обычный сейв/мимо: бьющий играет `sad_normal` ~2с (`Transition` ждёт). Обычный гол — без клипов. Решающий гол: бьющий `happy_extreme` + штатное празднование 5с. Решающий промах соперника: вратарь `happy_normal` + штатное празднование 5с.
- [ ] **Step 3: Подавления**
  В серии: нет кик-оффа после гола; `sig_OnExtendedReplayMoment` не эмитится; часы/счёт матча заморожены (Step 2 Task 2); `step_one_tick`-форс-энд не срабатывает, пока `shootout_active`.
- [ ] **Step 4: Снапшот-маркеры для Godot**
  `shootout_kicks_done` → `kicks0/kicks1` (массив 5 значений 0/1/2 для кружков, в sudden death — расширяемые), `shootout_event` (одноразовое событие на удар), `shootout_decisive`, `shootout_celebrating`, `shootout_winner`, `shootout_phase` (для знания, когда актёры переставлены под fade).

**Verify:** пересборка + ручной запуск: эмоции видны, после гола нет кик-оффа, повтор не включается.

---

## Task 4: GDExtension — биндинги и снапшот-поля

**Files:**
- Modify: `gdextension/src/gpf_runtime_node.cpp`, `gdextension/src/gpf_runtime_node.h`

**Interfaces:**
- Produces:
  - `void debug_force_shootout()` (в `_bind_methods` рядом с `debug_force_set_piece`).
  - Поля `get_snapshot()`: `shootout_active, shootout_round, shootout_score0, shootout_score1, shootout_kicks0, shootout_kicks1, shootout_event, shootout_decisive, shootout_celebrating, shootout_winner, shootout_phase`.

- [ ] **Step 1: Прокинуть вызовы Match в ноду**
  `debug_force_shootout()` → `Match::StartShootout()` (или через referee-путь, если таков шов Task 2).
- [ ] **Step 2: Заполнить снапшот**
  В `get_snapshot()` добавить поля выше (Dictionary). Типы: `shootout_event` = Dictionary `{outcome: String, kicker_id: int}` или пустой; `kicks0/kicks1` = Array[int].
- [ ] **Step 3: Сборка**
  `cmake --build gdextension/build-ofport --config Release --target open_football_gdext`; прогнать существующий headless-смоук (`check_gpf_setpieces.gd`) — регрессий нет.
- [ ] **Step 4: Коммит**
  ```
  git add gdextension/src/gpf_runtime_node.cpp gdextension/src/gpf_runtime_node.h
  git commit -m "feat(gpf): shootout bindings + snapshot fields"
  ```

---

## Task 5: GDScript — F3, HUD, fade, финальный экран

**Files:**
- Modify: `scripts/match/gpf_slice.gd`

**Interfaces:**
- Consumes: снапшот-поля Task 4, `runtime.debug_force_shootout()`.
- Produces: F3; кружки-ряды (верх=home, низ=away, слева направо, зелёный/красный/серый); баннер GOAL/SAVE/MISS ~1.2с; fade 0.3/0.15/0.3 по фазам `shootout_phase`; финальный баннер «Победа: X:Y» 3с → `get_tree().quit()`.

- [ ] **Step 1: F3**
  В `_input()` (рядом с debug-клавишами `:806-820`): F3 → `runtime.debug_force_shootout()`; игнор, если `shootout_active`. Матчевые score/clock HUD скрыть при `shootout_active`.
- [ ] **Step 2: Кружки**
  Сборка узлов в `_ready` (ряд Control-кружков на CanvasLayer HUD): по 5 на команду + динамическое расширение для sudden death (читать длину `shootout_kicks*`). Цвета по значениям 0/1/2.
- [ ] **Step 3: Баннеры исходов**
  По `shootout_event`: GOAL/SAVE/MISS ~1.2с (стиль ReplayBanner `:715-727`).
- [ ] **Step 4: Fade-оверлей**
  `ColorRect` чёрный на верхнем CanvasLayer; по `shootout_phase` (переходы `Transition`/начало/конец серии) — анимация 0.3с→0.15с→0.3с через Tween; актёры переставлены C++ до снятия затемнения (ждём фазу/маркер, а не таймер вслепую).
- [ ] **Step 5: Финал**
  При `shootout_winner >= 0` и окончании `shootout_celebrating`: баннер «Победа: X:Y» 3с → `get_tree().quit()`.
- [ ] **Step 6: Коммит**
  ```
  git add scripts/match/gpf_slice.gd
  git commit -m "feat(gpf): shootout HUD, fade, F3 trigger, final banner"
  ```

---

## Task 6: Headless-тест серии

**Files:**
- Create: `tests/check_gpf_shootout.gd` (по образцу `tests/check_gpf_setpieces.gd` / `check_gpf_full_match.gd`)

- [ ] **Step 1: Написать тест**
  Сценарий: инстанс gpf-сцены headless, короткий `match_duration`, форс-старт серии (`debug_force_shootout` или авто-путь), драйв симуляции. Проверки: `shootout_active`, чередование бьющих команд, исходы классифицируются (форс-гол через `debug_set_ball` за линию), счёт серии растёт, `shootout_kicks*` заполняется, ранний стоп и sudden death завершают (`shootout_winner >= 0`), кик-оффы матча не происходят (`game_over` не выставляется до конца серии).
- [ ] **Step 2: Прогнать**
  Run: `godot --headless -s res://tests/check_gpf_shootout.gd` → `CHECK PASS`.
- [ ] **Step 3: Коммит**
  ```
  git add tests/check_gpf_shootout.gd
  git commit -m "test(gpf): headless shootout flow"
  ```

---

## Task 7: Документация

**Files:**
- Modify: `docs/wiki/порт-gdextension.md` (роадмап: пункт 1 — готово; описание серии, F3, ограничения), `docs/wiki/пенальти.md` (Фаза C — «не в этом рантайме», ссылка на новый спек), `AGENTS.md` (короткий раздел про серию), `log.md` (запись даты + суть).

- [ ] **Step 1: Внести правки вики/AGENTS/log**
- [ ] **Step 2: Коммит**
  ```
  git add docs/ AGENTS.md log.md
  git commit -m "docs(gpf): penalty shootout — wiki, agents, log"
  ```

---

## Ручная приёмка (после Task 6, до Task 7)

Запуск `godot --path . res://scenes/gpf_slice.tscn`:
- F3 из любого состояния → серия: полевые на центральной линии, монетка, случайные ворота.
- Свои удары: прицел/заряд/удар; чужие: вратарь стиком.
- Кружки заполняются слева направо; баннеры GOAL/SAVE/MISS; грусть бьющего на сейв/мимо.
- Fade-переходы без видимых телепортов; после гола нет кик-оффа и повтора.
- Ранний стоп и sudden death; решающий удар → празднование 5с → «Победа: X:Y» → quit.
- Ничья после 120' → серия запускается автоматически.
