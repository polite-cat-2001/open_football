# 20: Game Plan и замены по ходу матча

**What to build:** Портировать оригинальный `GamePlanPage` (`src/menu/gameplan.cpp`) как экран
состава/замен: карточки игроков на поле, скамейка, выбор «кто уходит / кто выходит», очередь
замен, секции Positions/Tactics/Roles/Size. Сейчас и прематчевый «Edit lineups», и Game Plan —
черновой `LineupEditor` (ItemList + сетка), не оригинал. Тем же экраном пользоваться в матче из
меню паузы; in-match swap уходит в `Match::QueueSubstitution`, применяется на ближайшем рестарте.
C++ уже умеет `QueueSubstitution`/`CancelSubstitution`/`ApplyPendingSubstitutions` и заметки о
заменах; портируется shell-слой.

**Blocked by:** 08, 19

**Status:** done (2026-11-01)

- [x] `GamePlanPage`-раскладка: поле с карточками, скамейка, курсор, секции; заменить черновой
      `LineupEditor` в прематче и использовать тот же экран в матче (отступления — в тикете).
- [x] Мост: `queue_substitution(team, out_id, in_id)`, `cancel_substitution(team, out_slot)`,
      `get_pending_substitutions()`, `get_substitution_notices()` (счётчик/тексты).
- [x] In-match: выбор пары стартовый/скамейка → очередь замен, отмена, подтверждение.
- [x] In-match: **любая пара игроков одной команды** — стартовый↔стартовый (своп ролей/позиций
      через `swap_squad_players`, не замена), запасной↔запасной (порядок скамейки) и
      стартовый↔запасной (очередь замены).
- [x] Замена применяется на ближайшем рестарте (C++ решает момент); уведомление «вышел/вышел».
- [x] Ушедший игрок исчезает с поля, вышедший появляется; nameplate/подсветка корректны.
- [x] В 2P каждая сторона меняет только свою команду.
- [x] Tactics: 6 оригинальных схем, предпросмотр на поле, применение в премате и матче.
- [x] Roles: капитан и стандарты, назначение игрока, перенос в пакет и in-match bridge.
- [x] Headless-тест: queue → apply на рестарте → состав изменился, лимит замен соблюдён.
- [x] Скриншоты/`ui_lab`-состояния game plan/tactics/roles/select/notice; layout/focus-тест.

**As-built (2026-11-01):**

- `scripts/match/gpf_game_plan.gd` (`GpfGamePlan`) — порт `GamePlanPage`: тёмный экран, заголовок,
  hint, карточки на поле (роль + рейтинг + фамилия + полоса усталости, рамка курсора), скамейка
  справа (роль/имя/«-»/«+»/«(out)»/порядок), нижняя полоса Tactics/Positions/Roles/Size и caption.
  Один экземпляр в прематче (вкладка Game plan, `Edit lineups` переключает на неё) и в матче
  (пункт «game plan» в паузе; пауза-меню прячется без resume).
- **Positions:** выбираются **любые два игрока одной команды**. Стартовый↔стартовый в матче
  меняет роли/позиции (`swap_squad_players`, без счётчика замен); запасной↔запасной меняет
  локальный порядок скамейки (сбрасывается на новый матч); стартовый↔запасной ставит очередь
  `queue_substitution`. В прематче все пары меняются в `MatchLineup.swap_players`. Выбранный
  игрок подсвечивает все остальные карточки/строки как валидные цели (`→`, зелёный), статус
  объясняет результат; **X** снимает очередь под курсором.
- **Tactics:** `scripts/data/tactical_schemes.gd` (`TacticalSchemes`) — 6 схем, венгерское
  назначение роль/позиция на текущих игроков (GK закреплён), `match_scheme`. Список заменяет
  скамейку, курсор двигает preview, A/Enter применяет: премате — `MatchLineup.apply_scheme`,
  матч — `apply_tactical_scheme` → C++ `ApplySchemeToTeam`.
- **Roles:** 6 ролей оригинала (Captain, Free kick far/near, Penalty taker, Left/Right corner) в
  пользовательском порядке. Строка списка показывает текущего исполнителя; A/Enter — выбор
  игрока на поле, A — назначить, B — отмена. Премате хранит слот в `MatchLineup.roles` и в
  пакете (`roles`), C++ применяет к `MatchData::SetRolePlayer` до старта матча; in-match —
  `set_team_role(team, role, slot)`. В премате роли материализуются из тех же подсказок, что
  показывает UI.
- 2P: панели home/away строятся по `ShellState.controllers`; клавиатура правит только свою панель,
  геймпад — только назначенную ему; соперник в 1P read-only. В 1P геймпад без назначения стороне
  тоже управляет панелью. Выход в 2P — голосование (READY TO LEAVE).
- Мост `GpfRuntimeNode`: `queue_substitution`, `cancel_substitution`, `get_pending_substitutions`,
  `get_substitution_notices`, `get_substitution_notice_counter`, `get_squad(team)` (id/слот/имя/
  роль/позиция/active/left_pitch/pending/rating/fatigue + designated/effective `roles`),
  `apply_tactical_scheme`, `set_team_role`, `swap_squad_players`. В snapshot добавлены
  `substitutions0/1`, `substitutions_max`, `substitution_notice_counter`, `substitution_notices`.
- C++ применяет очередь на ближайшем рестарте (`ApplyPendingSubstitutions` в referee). `gpf_slice`
  по смене счётчика зовёт `GpfActors.sync_roster(get_player_ids())`: тело/подпись ушедшего
  удаляются, вышедший получает новое тело/подпись/kit-цвет; `GpfHud` показывает тексты 5 с.
  Проверено живьём: `Moreno off, Fierro on`, `get_player_ids` больше не содержит Moreno (id58),
  содержит Fierro (id78), `Actors.count()==25`; 4-3-3 и Roles применены из паузы.
- **Ввод/UX:** стрелки и левый стик двигают курсор; Enter/A — взять/выбрать/подтвердить; Esc/B —
  назад (held → секции → выход); **Y/Tab** мгновенно переключает поле ↔ скамейку; **X** снимает
  очередь. Под заголовком — постоянная подсказка; статус ведёт по шагам («choose another player —
  B cancel», «QUEUED: X off, Y on — next restart», «Swapped positions: X <-> Y»). Убран 180 мс
  кулдаун клавиш (остался только для стика), чтобы управление не «залипало». `gpf_slice`
  помечает keyboard/gamepad-события открытого меню/плана `set_input_as_handled()`, чтобы
  GUI-focus не проскакивал строку «game plan» в паузе.

**Отступления от оригинала (осознанные, для этого среза):**

- Size — присутствует кнопкой и caption, но остаётся заглушкой («not ported yet»); Tactics/Roles
  живые.
- Портретов нет (как и в остальном shell): карточка — цвет команды + роль/рейтинг/фамилия.
- Список схем/ролей заменяет скамейку в той же колонке (в оригинале Tactics тоже занимает колонку
  скамейки, Roles — полосу под полем). Отступление сделано ради читаемости на 1280×720.
- Порядок запасных в матче — локальный порядок shell (C++ его не хранит); сбрасывается на новый
  матч. В прематче порядок скамейки входит в пакет.
- Курсор скамейки подсвечивается цветом строки (в оригинале — GUI-focus рамка); Y/Tab и X
  добавлены как явные шорткаты.
- `ui_lab` Game Plan — демо-составы (`setup_demo`), без C++; живые данные — из `get_squad`.

**Тесты:** `tests/check_gpf_substitutions.gd` (queue/cancel/limit 5 → apply на рестарте → notice/
roster; роли, схемы и своп стартовых в C++), `tests/check_gpf_game_plan.gd` (премачевые и
in-match свопы любой пары, стратегия/роли, очередь/отмена, X/Y/Tab, достижимость скамейки, 2P
ownership, read-only), `tests/check_tactical_schemes.gd` (6 схем, GK pinned, Hungarian-назначение),
`tests/check_gpf_actor_roster.gd` (sync_roster), `tests/check_prematch_ui.gd`,
`tests/check_match_package.gd`/`check_gpf_match_package.gd` (roles в пакете и MatchData),
`tests/check_ui_layout.gd` (1920/1280, вкладка Game plan и 15 состояний ui_lab),
`tests/capture_ui_shots.gd` (40 PNG: game plan single/2P/Tactics/Roles/Select, notice,
prematch_gameplan).

> **UI-политика:** если этому тикету нужен UI, портировать соответствующий экран/элемент из
> оригинала (`GameplayFootball-of_port/src/menu/...`) — та же раскладка, подписи, иконки,
> управление и порядок экранов. Godot-UI не изобретать заново; отступления документировать.
