# 11: Унификация экрана плана игры

**What to build:** один экран плана (SQUAD / FORMATIONS / ROLES) для карьеры, прематча и паузы
матча вместо двух реализаций.

**Status:** done (2026-11-13) — экран общий; осталась чистка мёртвого кода (см. чек-лист).

**Как сделано:**
- Карьера открывает `GpfGamePlan` (`scripts/match/gpf_game_plan.gd`) в режиме prematch
  полноэкранным оверлеем хаба (`Design/PlanHost`) — тот же экран, что в прематче и паузе.
  Ввод идёт через `handle_ui_action`, закрытие — `close_requested`.
- Данные — адаптер `CareerPlan` (`scripts/career/career_plan.gd`): собирает `MatchLineup` из
  `CareerSquad.snapshot` (старт/скамейка/резерв, формация, роли), при закрытии пишет обратно
  `career.lineup`, `career.bench_order`, `career.formation`, `career.role_assignments` и сохраняет.
- FORMATIONS показывает 20 карьерных формаций: у плана появился источник
  `formation_source` (id/label/entries), применение пишет `formation_id` и позиции в
  `MatchLineup`. Без источника план работает на шести `TacticalSchemes`, как раньше.
- Доступность: `_entry_from_player` несёт `available`/`injury`/`suspension`/`fatigue`;
  недоступного игрока нельзя выбрать (статус «is unavailable»), на карточке красная рамка.
- Преьвю в обзоре состава — `PauseLineup` (виджет из паузы матча: перспективное поле, майки,
  рейтинг/фамилия), а не вторая отрисовка плана.
- Роли: в плане шесть игровых (капитан, пенальти, штрафные near/far, угловые left/right);
  седьмая карьерная `free_kick_long` в сейве остаётся, но в плане не редактируется.

**Осталось:**
- [ ] Удалить мёртвый план из `CareerSquadView` (`View.PLAN/DETAILS`, отрисовка поля/схем/ролей/
  деталей, `_open_plan`, `handle_details`) — UI его больше не вызывает.
- [ ] Решить, что делать с `free_kick_long` (свернуть в near/far при сборке пакета или убрать из
  карьерных ролей).
- [ ] Скриншоты карьеры/прематча/паузы совпадают по макету; тесты обновлены.
