# 02 — Скриптовый ввод и потиковая сверка

Status: research
Type: notes
Дата: 2026-10-25
Основание: [тикет 02](../issues/02-scripted-input-and-trace.md), [карта](../map.md).
Эталонный C++: `C:/Users/Egor/Desktop/projects/GameplayFootball-of_port` (далее — `of_port`).
Прежний C# oracle: `.scratch/oracle/`, `src/gpf/`, `src/lab/`, `tools/*.gd`, `tests/scenarios/`.

## Короткий ответ

Скриптовый ввод — это новый класс `IHIDevice`, который кладётся на место `controllers[0]`
(клавиатура) и читает сценарий по номеру тика. Обработку ввода в `HumanController` и `Match`
трогать не нужно: `Match` хранит **ссылку** на вектор контроллеров
(`src/onthepitch/match.cpp:32`), а `UpdateControllerSetup` ищет клавиатуру по
`GetDeviceType()` (`src/onthepitch/match.cpp:587-613`).

Полный контур — это **четыре фазы на каждый тик** в одном потоке:
`Match::Process()` → `Match::PreparePutBuffers()` → `Match::FetchPutBuffers()` →
`Match::Put()`. Существующий `tools/determinism` вызывает только `Process()`
(`tools/determinism/main.cpp:101-104`), поэтому его SHA-1 — детерминированный, но
**не игровой** хеш: `CheckBallCollisions` читает AABB, которые пишет Put.

Трасса — это прежний 25-колоночный CSV без изменений (его читает старый
`tools/oracle_trace.gd`) плюс маленькие sidecar-файлы: `tick.csv` (ввод, RNG, хеши фаз),
`transitions.csv` (почему сменился клип), `touches.csv` (что именно ушло в мяч),
`pose.csv` (поза после Put), `manifest.csv`, `run.csv` (контракт прогона).

Сценарий — прежний delta-encoded формат (`src/lab/OracleScenario.cs:68-193`) плюс
опциональные `profile`, `trace_from` и `require`. `require` превращает «сценарий прошёл»
в «сценарий действительно доказал ведение/пас/удар».

## 1. Что переиспользуется, а что нет

| Что | Где | Вердикт |
|---|---|---|
| Формат сценария (seed/ticks/`dir`/`buttons`, дельта-кодирование, запрет `Switch`) | `src/lab/OracleScenario.cs:68-193`, `tests/scenarios/walk_line.txt` | Переиспользуется дословно; расширяется директивами |
| Ядро CSV: 25 колонок, `B`/`P`-строки, `%.6f`, нормализация имён клипов | `src/gpf/TraceWriter.cs:19-146`, `tools/oracle_trace.gd:19-69` | Переиспользуется без изменений |
| Манифест клипов и порядок | `src/gpf/TraceWriter.cs:77-96`, `tools/oracle_manifest.gd:87-130` | Переиспользуется без изменений |
| Алгоритм диффа: манифест → первое дискретное расхождение → окно роста → белый список | `tools/oracle_trace.gd:323-477` | Переиспользуется, но с тремя правками (ниже) |
| CLI диффа | `tools/trace_diff.gd:19-37` | Переиспользуется по смыслу; аргументов станет больше |
| Оркестрация прогона | `src/lab/BallLabMain.cs:515-702` | Только как образец: C#-лаба не переносится |
| Process-only SHA-1 | `src/utils/capturestate.cpp:10-25`, `tools/determinism/main.cpp:101-107` | Остаётся smoke-тестом; для тик-сверки не годится |
| `tools/run_scenario.gd` и `scenes/lab/ball_lab.tscn` | — | Не переиспользуются: это C#-порт |

Три правки старого диффа, без которых пас/удар нельзя сравнивать:

1. **Спаривать все `P`-строки по `(tick, player_id)`**, а не только `controlled = 1`.
   Иначе получатель паса и защитники не сравниваются, хотя именно они меняют мяч.
2. **Не останавливаться на «контроль переехал»** (`tools/oracle_trace.gd:373-380`).
   После паса `Team::UpdateSwitch` штатно отдаёт управление получателю
   (`src/onthepitch/team.cpp:508-541`); это событие, а не ошибка. Смена контроля должна
   сравниваться как дискретное поле и печататься в отчёте.
3. **Сравнивать мяч** (`B`-строки). Старый дифф намеренно исключал их
   (`tools/oracle_trace.gd:52-53`), потому что фаза 5 мяча не касалась. Для паса и удара
   вектор мяча — главный результат; без него «клип совпал» ничего не доказывает.
   Заодно убрать предупреждение `SAFE_BALL_DISTANCE = 10` (`tools/oracle_trace.gd:78-80`):
   на каждом тике ведения мяч будет ближе 10 м, и предупреждение станет шумом.

## 2. Почему Process-only SHA-1 недостаточен

Цепочка проверена по коду:

1. `Match::Process` при `IsInPlay()` вызывает `CheckBallCollisions()`
   (`src/onthepitch/match.cpp:922`), а внутри — `players[i]->GetHumanoidNode()->GetObjects(...)`,
   `Geometry::GetAABB()` и `GetDerivedPosition()`
   (`src/onthepitch/match.cpp:2038-2056`). Комментарий самого оригинала:
   `// todo: should not read geoms during process`.
2. `Geometry::GetAABB()` вычисляет AABB из `GetDerivedRotation()/GetDerivedPosition()`
   (`src/scene/objects/geometry.cpp:145-161`).
3. Derived-данные и кэш AABB инвалидируются только в `RecursiveUpdateSpatialData`
   (`src/scene/scene3d/node.cpp:293-313`, `src/types/spatial.cpp:162-173`), а его вызывает
   `HumanoidBase::Put()` (`src/onthepitch/player/humanoid/humanoidbase.cpp:759-800`) и
   `Match::Put()` (`src/onthepitch/match.cpp:1323`).
4. Есть и прямой путь: мяч в руках/на удержании ставится в `bodyPart->GetDerivedPosition()`
   (`src/onthepitch/player/humanoid/humanoid.cpp:648-660`) — это тоже кость, обновлённая Put.

`tools/determinism` не вызывает ни `PreparePutBuffers`, ни `FetchPutBuffers`, ни `Put`.
Значит, его прогон навсегда остаётся в стартовой позе: отскок мяча от тела и позиция
удерживаемого мяча — другие. SHA-1 при этом совпадает, потому что `Match::ProcessState`
вообще не сериализует гуманоида и контроллер
(`docs/specs/2026-08-09-determinism-gate-design.md:76-91`,
`src/onthepitch/player/playerbase.cpp:156-161`, `src/onthepitch/player/player.cpp:590-607`).

Дополнительно Put зависит от времени: `HumanoidBase::Put` берёт
`timeDiff_ms` из snapshot-времён (`src/onthepitch/player/humanoid/humanoidbase.cpp:764-767`),
а `TemporalSmoother` получает начальные значения из `EnvironmentManager::GetTime_ms()`
при создании гуманоида (`src/onthepitch/player/humanoid/humanoidbase.cpp:34-35`).
Без подмены часов на номер тика два прогона с одинаковым вводом разъедутся на позе.

## 3. Скриптовый `IHIDevice`

### 3.1. Класс

`IHIDevice` уже содержит всё нужное, включая `SetButton`
(`src/hid/ihidevice.hpp:57-82`). Скриптовое устройство повторяет форму `HIDKeyboard`
(`src/hid/keyboard.cpp:40-75`), но состояние берёт не из SDL, а из сценария:

```cpp
class OracleHIDDevice : public IHIDevice {
public:
  OracleHIDDevice(const OracleScenario *scenario) : scenario(scenario) {
    deviceType = e_HIDeviceType_Keyboard;   // см. 3.3
    identifier = "oracle";
  }
  void SetTick(int tick) { currentTick = tick; }

  void LoadConfig() override {}
  void SaveConfig() override {}
  void Process() override {}               // ввод не сэмплируется из ОС

  bool GetButton(e_ButtonFunction f) override {
    return scenario->GetButton(currentTick, f);
  }
  float GetButtonValue(e_ButtonFunction f) override {
    return GetButton(f) ? 1.0f : 0.0f;
  }
  void SetButton(e_ButtonFunction, bool) override {}

  bool GetPreviousButtonState(e_ButtonFunction f) override {
    return scenario->GetButton(currentTick - 1, f);   // фронт кнопки = тик-1
  }
  Vector3 GetDirection() override {
    return scenario->GetDirection(currentTick);       // сырой вектор, не нормализованный
  }
private:
  const OracleScenario *scenario = nullptr;
  int currentTick = -1;
};
```

Почему `GetPreviousButtonState` — это `tick - 1`, а `Process()` пустой: в настоящем цикле
`GameTask::ProcessPhase` вызывает `controllers[i]->Process()` ровно раз за тик
(`src/gametask.cpp:182-184`), и `HIDKeyboard::Process` сдвигает `previous = current`
(`src/hid/keyboard.cpp:40-46`). Сценарий уже развёрнут в состояние на каждый тик
(`OracleScenario.cs:177-190`), поэтому «предыдущее» — это состояние прошлого тика,
а не прошлого чтения. Внутри одного тика `GetButton` вызывается многократно
(`HumanController::Process` и `RequestCommand`); ответ обязан быть идемпотентным.

### 3.2. Точка вставки

1. Собрать `std::vector<IHIDevice*> controllers` как в `InitGameContext`, но с
   `controllers[0] = new OracleHIDDevice(...)` вместо `new HIDKeyboard()`
   (`src/gamecontext.cpp:267-270`).
2. До `new Match` задать состав сторон:
   `SideSelection{controllerID=0, joystickID=0, controllerImage=nullptr, side=-1, confirmed=true}`
   и `menuTask->SetControllerSetup({...})`. Без этого `Match::UpdateControllerSetup` никого
   не посадит за команду: он ищет клавиатуру по `GetDeviceType()`
   (`src/onthepitch/match.cpp:594-611`).
3. `new Match(matchData, GetControllers())` — `Match` хранит ссылку
   (`src/onthepitch/match.cpp:32`), поэтому вектор должен жить дольше матча.
4. `GameTask`/`RefreshGamepads` не использовать: `RefreshGamepads` может добавить реальный
   геймпад (`src/gamecontext.cpp:275-308`), а `GameTask` ещё и проверяет отключение
   устройств (`src/gametask.cpp:131-180`).

Ни `HumanController`, ни `Team`, ни `Match` не меняются.

### 3.3. Договор о типе устройства

Устройство обязано представляться **клавиатурой**, потому что от этого зависят две
ветки, влияющие на результат:

- удар: `autoDirectionBias = 1.0f` для клавиатуры
  (`src/onthepitch/player/controller/humancontroller.cpp:188`);
- пас: `fullAutoDirection = true` для клавиатуры
  (`src/onthepitch/AIsupport/AIfunctions.cpp:1115-1118`).

При этом `GetDirection` возвращает **сырой аналоговый вектор из сценария**, а не 8-позиционный
цифровой, как `HIDKeyboard::GetDirection` (`src/hid/keyboard.cpp:68-75`). Это сознательный
гибрид, повторяющий прежний C# oracle: сценарий должен уметь `dir 0.7071,0.7071,0`.
Он должен быть записан в `run.csv` (`device=keyboard`, `analog_direction=1`), иначе
стороны могут сравниться при разных ветках ввода.

Порог мёртвой зоны — **0.3**, как в `of_port` (`src/gamedefines.hpp:31`), а не 0.75 из
старого C#-порта. `dir` с длиной < 0.3 означает «ввода нет»: `_GetHidInput` подставляет
текущее направление тела и `idleVelocity`
(`src/onthepitch/player/controller/humancontroller.cpp:498-511`).

## 4. Оркестратор полного контура

### 4.1. Где

Новый бинарник `tools/oracle_runner` (рядом с `determinism_runner`,
`CMakeLists.txt:324-340`) и такой же вызов из GDExtension. Общий код — в
`src/oracle/oraclerun.{hpp,cpp}`, чтобы standalone и встроенный runtime исполняли
**один и тот же** цикл. `Match`, `Humanoid`, `Ball` о файлах не знают; писатель
вызывается оркестратором, как в C# (`src/gpf/TraceWriter.cs:12-14`).

В репозитории уже есть скелет GDExtension: `gdextension/src/match_node.cpp`, `_process`
пока пуст (`:59-61`). Оракул в нём — отдельный метод узла (например
`run_oracle(scenario_path, out_dir)`), который целиком вызывает `OracleRun`; GDScript
только передаёт пути и читает готовые файлы. Реализовывать потиковый цикл в GDScript
нельзя: тогда появится третий, не сверяемый ни с чем runtime.

### 4.2. Инициализация

Повторить путь `tools/determinism/main.cpp:47-99`:

- `graphics3d_renderer=mock`, `audio_renderer=mock`;
- прибить конфиг, влияющий на симуляцию: `match_difficulty`, `match_duration`,
  `audio_volume` (от него зависит, тянется ли `random()` на звук касания,
  `src/onthepitch/ball.cpp:553-560`), `gameplay_*` (значения по умолчанию из
  `src/gamedefines.hpp:48-62`);
- `menuTask->SetTeamIDs(...)` и `new MatchData(...)` — как в детерминизм-раннере;
- **`randomize(seed)` непосредственно перед `new Match`**;
- один `Match` на процесс.

`PlayerBase::playerCount` — статический счётчик, который не сбрасывается
(`src/onthepitch/player/playerbase.cpp:22-24`). Второй `Match` в том же процессе получит
другие `player_id`; поэтому «один прогон — один процесс», как у эталона.

### 4.3. Цикл

```cpp
randomize(scenario.seed);
Match *match = new Match(matchData, controllers);
StageProfile(match, scenario.profile);        // см. §6.3

for (int tick = 0; tick < scenario.ticks; ++tick) {
  device->SetTick(tick);

  match->Process();                            // 10 мс, внутри actualTime_ms += 10

  trace.WriteCore(tick, match);                // 25-колоночный CSV: все активные игроки + B
  unsigned long t = match->GetActualTime_ms(); // время только что завершённого тика

  uint64 h_sim  = HashSim(match);
  match->PreparePutBuffers(t);                 // см. 4.4
  uint64 h_buf  = HashBuf(match);
  match->FetchPutBuffers(t);
  match->Put();                                // поза, AABB, retainer
  uint64 h_pose = HashPose(match);

  trace.WriteTick(tick, h_sim, h_buf, h_pose);
}
```

Порядок и кратность жёсткие: **ровно один Put на один Process**, сразу после него.
`Match::Put` сам guard'ит `GetIterations() < 2` (`src/onthepitch/match.cpp:1259`), поэтому
на тике 0 Put — no-op; это нормально и одинаково у сторон, первый настоящий Put — тик 1.
Если Put вызывать реже или чаще, `TemporalSmoother` и AABB поедут, и трасса перестанет
быть функцией номера тика.

### 4.4. Два узких шва в `Match`

`PreparePutBuffers`/`FetchPutBuffers` сейчас берут время из шедулера и стенных часов
(`src/onthepitch/match.cpp:1188-1255`). Для фиксированного цикла нужны явные времена:

```cpp
void PreparePutBuffers(unsigned long snapshotTime_ms = 0);
void FetchPutBuffers(unsigned long putTime_ms = 0);
```

`0` — прежнее поведение; ненулевое значение используется оркестратором. Это не меняет
игру и не требует трогать `GameTask`.

Второй шов — **симулированные часы** в `EnvironmentManager` (`GetTime_ms`,
`src/managers/environmentmanager.cpp:22-26`): включить до `new Match`, стартовать с 0,
двигать на 10 мс за тик. Он нужен не для `Match::Process` (там время уже отвязано), а для
инициализации `TemporalSmoother` при создании гуманоида
(`src/onthepitch/player/humanoid/humanoidbase.cpp:34-35`) и для `previousPutTime_ms`
в конструкторе матча (`src/onthepitch/match.cpp:287-288`). Без него поза будет зависеть
от того, сколько миллисекунд прошло до старта процесса.

### 4.5. Одинаковый прогон на эталоне и встроенном runtime

«Эталон» здесь — не обычный `gameplayfootball.exe` (он сидит RNG от времени,
`src/main.cpp:145-148`), а **standalone-сборка того же `of_port` с `src/oracle/*`**.
Порядок:

1. Обе сборки компилируют один и тот же `src/oracle/*`: standalone-бинарник
   `oracle_runner` и GDExtension (`MatchNode::run_oracle`). Цикл и писатель — общий код,
   не две реализации.
2. Одинаковый CWD/`data/`, один и тот же `football.config`, прибитые ключи из §4.2,
   MSVC x64 Release, `/fp:precise`, одна версия boost.
3. Standalone: `oracle_runner.exe <scenario> <out_dir>`.
   Встроенный: headless-сцена Godot, которая вызывает `run_oracle(<scenario>, <out_dir>)`.
   Оба получают **один и тот же файл сценария** и один и тот же `seed`.
4. Сначала сравниваются `run.csv` и `manifest.csv`; только потом — тики.
5. Если расхождение на тике 0 — инициализация/порядок клипов/часы; на тике 1 — Put;
   дальше — обычная классификация §8.2.

Отдельный процесс на прогон обязателен: `PlayerBase::playerCount` не сбрасывается
(`src/onthepitch/player/playerbase.cpp:22-24`), а глобальные менеджеры и `Match`
не рассчитаны на второй матч в том же процессе.

## 5. Формат сценария

### 5.1. Совместимость

База — прежний формат:

```
# комментарий
seed 20260731
ticks 150
0    dir 1,0,0   buttons Sprint
70   dir 0.7071,0.7071,0
120  buttons -
```

Правила прежнего парсера сохраняются (`src/lab/OracleScenario.cs:88-193`):
`seed` и `ticks` до первой строки тика; тики по возрастанию; строка без `dir` и `buttons`
запрещена; `-` очищает кнопки; состояние держится до следующего изменения; `Switch`
запрещён (ручной переезд контроля непредставим одним устройством).

Два исправления к прежнему парсеру:

- `seed` — **uint32** (`randomize(unsigned int)`, `src/base/math/bluntmath.cpp:74-84`);
  значение > `0xFFFFFFFF` отвергать, а не молча обрезать.
- порог мёртвой зоны — 0.3 (`of_port`), а не 0.75.

### 5.2. Новые директивы (все — до первой строки тика)

| Директива | Смысл |
|---|---|
| `version 2` | явная версия; без неё — v1, без новых директив |
| `profile <name>` | постановка стартовой ситуации (см. 5.3) |
| `trace_from <tick>` | первый записываемый тик; по умолчанию 0 |
| `require <metric> <op> <value>` | гейт покрытия; невыполнение — код 3, а не «match» |
| `device keyboard` | утверждение, что устройство — клавиатура (для `run.csv`) |

Метрики `require` (считаются по трассе, а не по сценарию):

- `possession_ticks` — тиков, где у контролируемого `has_possession = 1`;
- `touch_<FunctionType>` — число касаний с данной функцией (`BallControl`, `ShortPass`, `Shot`, …);
- `ball_speed_after_<FunctionType>` — максимальная скорость мяча в 0–2 тиках после касания;
- `ball_forward` — максимальное перемещение мяча по X от старта;
- `goal_events` — число голов;
- `max_ball_distance` — максимальная дистанция мяча от контролируемого.

### 5.3. Профили старта

Без профиля матч стартует с естественного кикоффа. Это плохо для коротких сценариев:
`Referee` готовит стандарт на тике 0 и включает игру только на `actualTime_ms == 2000`,
то есть на тике 200 (`src/onthepitch/referee.cpp:16-23,191-247`), а до этого
`_SetPieceCommand` игнорирует движение и держит игрока на месте
(`src/onthepitch/player/controller/playercontroller.cpp:261-275`).

Профиль ставит открытую игру через **существующие публичные методы**, не меняя логику:

```cpp
void StageOpenPlay(Match *m, const Vector3 &ballPos, float behind = 0.3f) {
  m->SetMatchPhase(e_MatchPhase_1stHalf);
  m->StartPlay();
  m->StopSetPiece();
  m->ResetSituation(ballPos);              // чистит владение/историю, мяч в focusPos
  m->GetBall()->SetPosition(ballPos);      // момент 0, история очищена
  m->GetBall()->SetMomentum(Vector3(0));
  m->SetBallRetainer(nullptr);

  // команда 0 атакует +X (Team::GetSide() == -1, GetSide() см. team.cpp:102-111)
  Player *p = AI_GetClosestPlayer(m->GetTeam(0), ballPos, false);
  Vector3 behindPos = ballPos - Vector3(behind, 0, 0);
  m->GetTeam(0)->SelectPlayer(p);
  p->ResetPosition(behindPos, ballPos);
}
```

Профили:

| Профиль | Старт | Для чего |
|---|---|---|
| `kickoff` | без вмешательства | проверка естественного кикоффа; первые 200 тиков ввод игнорируется |
| `open_play` | мяч `(0, 0, 0.11)`, игрок в 0.3 м позади | ведение, короткий пас |
| `open_play_shot` | мяч `(38, 0, 0.11)`, игрок в 0.3 м позади | удар (15 м до ворот) |

`ResetPosition` сбрасывает клип и `movementHistory` (`humanoidbase.cpp:929-1012`),
поэтому первый `Process` не тащит хвост от конструкции. `ResetSituation` тратит RNG на
idle-кадры всех игроков; обе стороны делают это одинаково, а `rng_draws` в `run.csv`
фиксирует фактическое число.

## 6. Формат трассы

### 6.1. `trace.csv` — прежние 25 колонок, без изменений

```
kind,tick,player_id,controlled,anim_name,anim_id,anim_type,function_type,frame_num,touch_frame,foot,enum_velocity,quadrant_id,pos_x,pos_y,pos_z,angle,rel_body_angle,move_x,move_y,move_z,action_smuggle,movement_smuggle,rotation_smuggle_begin,rotation_smuggle_end
```

- `P` — все **активные** игроки (обычно 22), источник — публичные геттеры
  `HumanoidBase` (`src/onthepitch/player/humanoid/humanoidbase.hpp:217-246`);
  `touchFrame` читается из `GetCurrentAnim()->touchFrame`, `foot` — из
  `GetCurrentAnim()->anim->GetOutgoingFoot()`, `quadrant_id` — из
  `GetVariable("quadrant_id")`.
- `B` — мяч: `Predict(0)` и `GetMovement()` (`src/onthepitch/ball.cpp:86-89`).
- порядок: `B`, затем `P` по возрастанию `player_id`; все float — `%.6f`,
  разделитель — запятая, имена клипов нормализованы как в
  `src/gpf/TraceWriter.cs:43-62` (срезать `animations/`, срезать `.anim`, нижний регистр,
  прямые слэши; запятая в имени — ошибка).
- `B`-строка по-прежнему заполняет только колонки 3–8; остальные пустые.

Этот файл читается старым `tools/oracle_trace.gd` без правок. Меняется только
**политика сравнения** (см. §8), а не схема.

### 6.2. Sidecar-файлы

Все — CSV с заголовком, те же правила float/int.

**`tick.csv`** — по строке на тик; здесь то, чего нет в 25 колонках:

```
tick,rng_draws,input_dir_x,input_dir_y,input_mask,controlled_id,controlled_has_possession,controlled_function_type,controlled_anim_id,controlled_touch_frame,in_play,in_set_piece,match_phase,ball_retainer_id,designated_player_id,best_possession_team,score0,score1,hash_sim,hash_buf,hash_pose
```

- `input_mask` — 18 бит `e_ButtonFunction` (`src/hid/ihidevice.hpp:17-37`);
- `rng_draws` — кумулятивное число вызовов `random()` с момента `randomize(seed)`;
- `hash_sim` — SHA-1 состояния после `Process` (позиции/углы/движение, `Anim` целиком,
  владение, мяч, счёт, фазы). `Match::ProcessState` для этого не годится: он не включает
  гуманоида (`src/onthepitch/player/playerbase.cpp:156-161`).
- `hash_buf` — `buf_animApplyBuffer` всех игроков + буферы мяча.
- `hash_pose` — derived-позиции/повороты всех узлов `nodeMap` (отсортированы по имени) +
  узел мяча, сырые биты float.

**`transitions.csv`** — по строке на смену клипа (или первый тик с `interrupt != None`):

```
tick,player_id,team_id,role,from_anim_id,from_anim_name,from_function_type,to_anim_id,to_anim_name,to_anim_type,to_function_type,to_frame_count,to_touch_frame,to_foot,interrupt,interrupt_name,controlled
```

`interrupt` — `e_InterruptAnim` (`src/onthepitch/player/humanoid/humanoidbase.hpp:47-56`):
`None/Switch/Sliding/Bump/Trip/Cheat/Cancel/ReQueue`. Причина перехода — именно он плюс
`from_function_type`; `to_anim_id` позволяет сразу отличить «выбрали другой клип» от
«тот же клип, но другой кадр». Значение пишется из `currentAnim->originatingInterrupt`
(`src/onthepitch/player/humanoid/humanoidbase.cpp:1577`).

**`touches.csv`** — по строке на тик, где `touch_frame == frame_num`:

```
tick,player_id,team_id,function_type,anim_id,anim_name,touch_frame,frame_num,desired_dir_x,desired_dir_y,desired_dir_z,desired_power,input_power,auto_direction_bias,auto_power_bias,target_player_id,ball_x,ball_y,ball_z,ball_mx,ball_my,ball_mz,controlled,rng_draws
```

`desired_*`, `auto_*`, `target_player_id` берутся из
`currentAnim->originatingCommand.touchInfo` (`src/onthepitch/player/humanoid/humanoid.cpp`
использует их при касании: `:463-582`). `ball_*` — состояние мяча **в конце того же тика**;
`Ball::Touch` сразу ставит `momentum = target` (`src/onthepitch/ball.cpp:91-99`), поэтому
`ball_m*` на тике касания и есть фактический вектор, ушедший в мяч. Отдельный хук в
`Ball::Touch` не нужен.

**`pose.csv`** — `tick,player_id,hash`. Полный дамп костей (`pose_dump_<tick>.csv`:
`tick,player_id,node_name,pos_x,pos_y,pos_z,rot_x,rot_y,rot_z,rot_w`) пишется только по
запросу для тика первого расхождения — иначе файл распухает.

**`manifest.csv`** — прежний `index,anim_name,anim_type,foot,frame_count`
(`src/gpf/TraceWriter.cs:24,77-96`).

**`run.csv`** — контракт сравнимости, одна строка:

```
seed,tick_ms,profile,device,analog_direction,scenario_sha1,clips_sha1,anim_order_sha1,config_sha1,build,rng_draws_after_construct,rng_draws_tick0,start_player_id,start_ball_x,start_ball_y,start_ball_z
```

`build` — MSVC-версия, x64, Release, `/fp:precise`, версия boost. `anim_order_sha1` —
SHA-1 упорядоченного списка путей `.anim` **до** нормализации: именно он ловит разный
порядок обхода каталога, даже если имена не повторяются.

### 6.3. Что писать не нужно

- Вращение мяча: публичного геттера нет (`Ball::rotation_ms` приватно,
  `src/onthepitch/ball.hpp:91-92`); для паса/удара достаточно `momentum`.
- `floatVelocity`: выводится не из `GetMovement()`; для сверки хватает `enum_velocity`
  и `move_*` (как в прежней спеке).
- Полные 22×14 костей на каждом тике: хеша достаточно, дамп — по запросу.

## 7. RNG и порядок загрузки

### 7.1. Три потока случайности

`of_port` использует три независимых потока:

| Поток | Где | Кто тянет |
|---|---|---|
| `random()` (boost `mt19937` + `uniform_real<float>`) | `src/base/math/bluntmath.cpp:16-26,86-97` | геймплей + камера/звук/солнце/щиты |
| `srand()`/`rand()` | `src/base/math/bluntmath.cpp:78-80`, `src/misc/perlin.cpp` | только Perlin (газон) |
| `fastrandom()` (LCG) | `src/base/math/bluntmath.hpp:34-44` | только шум газона |

`randomize(unsigned int)` сидит **все три** (`src/base/math/bluntmath.cpp:78-84`).
`main.cpp` в обычной игре сидит их от времени (`src/main.cpp:145-148`), поэтому обычный
`gameplayfootball.exe` недетерминирован; оракул обязан вызвать `randomize(seed)`.

### 7.2. Что именно тянет геймплейный `random()`

До нулевого тика (конструкция `Match`):

- 22 idle-кадра: `Player::Activate` → `Humanoid::ResetPosition` →
  `currentAnim->frameNum = random(0, frameCount - 1)`
  (`src/onthepitch/player/humanoid/humanoidbase.cpp:954`);
- 23 щита (`Match::RandomizeAdboards`, `src/onthepitch/match.cpp:571`),
  1 полоса газона (`src/onthepitch/proceduralpitch.cpp:455`),
  6 солнце (`src/onthepitch/match.cpp:501-516`).

Первый `Process` (кикофф): 22 idle-кадра от `ResetSituation` + 20 джиттеров позиции
(`PrepareSetPiece`, по 10 полевых на команду, `src/onthepitch/teamAIcontroller.cpp:699-709`).

Каждый тик: 2 числа на дрожание камеры (`src/onthepitch/match.cpp:759`).
Каждое озвученное касание: 1 число на питч (`src/onthepitch/ball.cpp:556`),
но только если `finalGain > 0.01`, а он зависит от `audio_volume`.

Пас и удар дополнительно тянут RNG в `GetDifficultyFactors`
(`src/onthepitch/player/humanoid/humanoid_utils.cpp:198`), `GetBestPossibleTouch`
(`src/onthepitch/player/humanoid/humanoid.cpp:2410-2480`) и `GetShotVector`
(6 чисел: 3 направления + 1 worst-case + 2 кривизны,
`src/onthepitch/player/humanoid/humanoid_utils.cpp:474-515`). Поэтому `rng_draws` —
самый ранний индикатор расхождения в пасе/ударе: лишний/недостающий `random()` виден
на тике касания даже при случайно совпавшем векторе мяча.

### 7.3. Политика для встроенного runtime

Рекомендуемая и самая дешёвая: **не вырезать презентационные потребители из `Match`**.
Оракул собирает матч тем же путём, что `determinism_runner` (стадион, газон, солнце,
звук), а Godot просто не показывает эти объекты. Тогда 30 предстартовых чисел и
2/тик камеры совпадают у standalone и у встроенного runtime.

Если встроенная сборка не может позволить себе стадион/газон, единственный корректный
вариант — вынести эти сайты в **отдельный** поток RNG (как `DeterministicRandomScope` в
старом форке) и сделать это одинаково на обеих сторонах. Молча пропустить 30 чисел
нельзя: сдвинется весь геймплейный поток, начиная с idle-кадров.

`audio_volume` обязателен в списке прибитых ключей: при 0 `TriggerBallTouchSound`
не тянет число (`finalGain = 0`), и поток уезжает на каждом касании.

Проверка — счётчик в `random()`: инкремент внутри уже существующего `randMutex`
(`src/base/math/bluntmath.cpp:90-97`), сброс в `randomize()`, геттер
`GetRandomDrawCount()`. Это диагностика, не игровая логика; в обычной игре счётчик
просто не читается.

### 7.4. Порядок загрузки анимаций

`DirectoryParser::Parse` обходит `boost::filesystem::directory_iterator` **без сортировки**
(`src/utils/directoryparser.cpp:28-56`). `AnimCollection::Load`:

1. 10 шаблонов из `templates/` в порядке обхода (`animcollection.cpp:385-396`);
2. `GenerateAutoAnims` — вложенные циклы по шаблонам (`animcollection.cpp:167-173`),
   поэтому порядок шаблонов задаёт индексы **всех** автогенов;
3. автогены: сначала зеркало, потом оригинал (`animcollection.cpp:407-418`);
4. файловые клипы в порядке обхода, для каждого сначала оригинал, потом зеркало
   (`animcollection.cpp:432-475`); `templates` и `luxury` пропускаются.

Индексы важны не только для `anim_id`: стабильная сортировка отбора разрешает равные
ключи порядком исходного списка, поэтому другой порядок клипов меняет выбранный клип без
ошибки в логике. Манифест (`index` включительно) — первая стадия диффа.

Контрольная цифра: в `of_port` 10 шаблонов и 283 файловых `.anim` (293 всего минус 10
шаблонов). При прежнем наборе это даёт 566 файловых клипов и 886 легальных автогенов,
итого **1452** — ровно столько было в старом манифесте. Расхождение — находка до всякой
трассы.

Для переносимости между машинами: добавить в `run.csv` `anim_order_sha1`; если нужна
жёсткая воспроизводимость на разных ФС, сделать в оракуле **отсортированный** вариант
парсера и использовать его на обеих сторонах. В production-загрузке сортировку не менять:
это изменит `anim_id` относительно текущего эталона.

### 7.5. Сборка

Обе стороны — MSVC, x64, Release, `/fp:precise`, без fast-math, одна версия boost.
Тогда побитовое совпадение float ожидаемо; допуски ниже — страховка, а не норма.
Разные архитектуры (x86 vs x64) или разные `/fp`-флаги делают побитовую сверку
бессмысленной.

## 8. Критерий сравнения

### 8.1. Порядок стадий

1. **`run.csv`** — seed, tick_ms, профиль, устройство, хеши сценария/клипов/порядка/конфига,
   `build`. Не совпало — прогоны несравнимы (код 3), трассы не читаются.
2. **`manifest.csv`** — состав и порядок клипов. Не совпало — дальше не идём.
3. **`tick.csv`: ввод** — `input_dir_*`, `input_mask`. Расхождение ввода — ошибка сценария
   или тика устройства, а не симуляции.
4. **`trace.csv`: дискретные поля** — `anim_id` (после манифеста), `anim_name`,
   `anim_type`, `function_type`, `frame_num`, `touch_frame`, `foot`, `enum_velocity`,
   `quadrant_id`, `controlled`.
5. **`transitions.csv`** — причина и момент смены клипа; ловит случай «клип тот же,
   но выбран по другой причине».
6. **`touches.csv` / мяч** — наличие касания, `function_type`, `desired_power`,
   `target_player_id`, `ball_m*`. Это главный слой для паса и удара.
7. **`trace.csv`: непрерывные поля** — позиция/угол/движение/смаггл с допуском.
8. **`tick.csv` / `pose.csv`: `hash_sim`, `hash_buf`, `hash_pose`** — раннее
   предупреждение, что Put разошёлся раньше, чем это дошло до дискретного поля.

Для коротких сценариев окно роста — 5 тиков (в старом диффе 10;
`tools/oracle_trace.gd:73`). Дискретное расхождение всегда важнее роста.

### 8.2. Первое расхождение: как определить фазу

Пусть `t_input`, `t_clip`, `t_touch`, `t_ball`, `t_pose` — первые тики расхождения
соответствующего слоя. Правило:

| Условие | Где искать |
|---|---|
| есть `t_input` | сценарий/тик устройства; симуляция не виновата |
| `t_pose < min(t_clip, t_ball)` | Put: `Animation::Apply`, смещения, `Prepare/Fetch`, часы, `nodeMap` |
| `t_clip <= t_pose` и `t_clip <= t_ball` | отбор клипа/состояние: `interrupt`, `from_function_type`, предикаты, порядок клипов |
| `t_touch <= t_clip` и `t_touch <= t_ball` | касание: `touchFrame`, `touchPos`, `bumpyRideBias`, `desired_power`, `desired_dir` |
| `t_ball < t_clip` | физика мяча/коллизии: `Predict`, drag, отскок, `CheckBallCollisions` (AABB из Put) |
| всё в один тик | печатать все поля этого тика; это точка ветвления |

Это и есть ответ на «по первому разошедшемуся тику находить ошибку»: отчёт обязан
назвать **слой** первого расхождения, а не только поле. Старый дифф печатал первое
дискретное поле; новый печатает `t_input/t_clip/t_touch/t_ball/t_pose` и классификацию.

### 8.3. Допуски

| Класс | same-build (MSVC/x64) | будущий порт на другом языке |
|---|---|---|
| `position`, `angle` | 1e-6 | 1e-3 |
| `velocity`, `move_*` | 1e-6 | 1e-3 |
| `smuggle` | 1e-6 | 1e-4 |
| `ball_position`, `ball_momentum` | 1e-6 | 1e-3 |
| `gauge_ms`, `frame_num`, `touch_frame` | точно | точно |
| `hash_pose` | побитово | числовой дамп костей с 1e-4 |

Белый список (`tools/trace_whitelist.txt`) по формату прежний; на первом срезе он должен
быть пуст, кроме, возможно, `hash_pose`, если ticket 03 сознательно поменяет скиннинг.
Игровые поля белым списком не гасить.

### 8.4. Гейты покрытия

Прогон, который не коснулся мяча, не должен возвращать «match». Для каждого сценария
`require` проверяются на **эталоне** до диффа; не выполнено — код 3 и сообщение
«сценарий не доказал X». Это лечение болезни `walk_line`: он был зелёным именно потому,
что мяча не касался (`tests/scenarios/walk_line.txt:1-12`).

## 9. Минимальные сценарии

Все три — `profile open_play*`, поэтому не зависят от 200-тикового кикоффа и ИИ,
который может не отдать мяч. Ввод — в осях оригинала: X — длинная ось (±55, ворота),
Y — ширина (±36), Z — вверх; команда 0 атакует **+X** (`Team::GetSide() == -1`,
`src/onthepitch/team.cpp:102-111`).

### 9.1. `dribble_short.txt`

```
version 2
profile open_play
seed 20260731
ticks 150
require possession_ticks >= 80
require touch_BallControl >= 1
require touch_ShortPass == 0
require touch_Shot == 0
require max_ball_distance <= 3.0

0    dir 1,0,0 buttons Sprint
70   dir 0.7071,0.7071,0
120  dir 1,0,0
```

Доказывает: игрок получает мяч, ведёт его на спринте, меняет направление, мяч остаётся
в пределах 3 м. Клипы — `movement/*` + `BallControl`; касания — только `BallControl`.
Первый ожидаемый слой расхождения — `anim_id`/`quadrant_id` (отбор), затем мяч.

### 9.2. `pass_short.txt`

```
version 2
profile open_play
seed 20260731
ticks 120
require touch_ShortPass >= 1
require touch_Shot == 0
require ball_speed_after_ShortPass >= 5

0    dir 1,0,0
20   buttons ShortPass
30   buttons -
```

На тике 20 кнопка нажата, на 30 отпущена; `gauge_ms` ≈ 100–200, пас летит вперёд.
`touches.csv` фиксирует `desired_power`, `input_power`, `target_player_id` и вектор мяча.
Доказывает: `AI_GetPass` → выбор клипа `ShortPass` → `touchFrame` → `Ball::Touch` →
свободный полёт мяча. Первый ожидаемый слой — `touches.csv`, затем `B`-строки.

### 9.3. `shot_short.txt`

```
version 2
profile open_play_shot
seed 20260731
ticks 100
require touch_Shot >= 1
require touch_ShortPass == 0
require ball_speed_after_Shot >= 12
require ball_forward >= 30

0    dir 1,0,0
10   buttons Shot
45   buttons -
```

Мяч на `x = 38`, игрок сзади; до ворот 17 м. Удар заряжается ~350 мс, `GetShotVector`
тянет 6 чисел RNG. Доказывает: заряд → `Shot`-клип → касание → вектор мяча в сторону
ворот. Первый ожидаемый слой — `rng_draws` на тике касания и `ball_m*`.

Если нужен именно естественный кикофф, сценарий должен начинаться с `profile kickoff`,
и первые 200 тиков будут без полезного ввода; для доказательства ведения это лишние
2 секунды и лишний ИИ. Поэтому по умолчанию — `open_play`.

## 10. Источники

Тикет и карта:

- [02-scripted-input-and-trace.md](../issues/02-scripted-input-and-trace.md)
- [map.md](../map.md)

Прежний C# oracle:

- `.scratch/oracle/spec.md` — «Формат трассы» (стр. 386), «Дифф» (стр. 506), «Формат сценария» (стр. 343)
- `.scratch/oracle/trace-example.md` — живой пример 25 колонок и манифеста
- `.scratch/oracle/issues/09-etalon-nedeterministichen-iz-za-put-fazy.md` — почему Put нельзя игнорировать
- `.scratch/oracle/issues/17-rng-potrebiteli-vne-geympleya.md` — потребители RNG вне геймплея
- `src/gpf/TraceWriter.cs:19-146` — заголовок, `B`/`P`, нормализация имён
- `src/lab/OracleScenario.cs:68-193` — парсер сценария
- `src/lab/BallLabMain.cs:515-702` — оркестратор прогона (образец)
- `tools/oracle_trace.gd:19-69,323-477` — поля, стадии, первое расхождение
- `tools/trace_diff.gd:19-37` — CLI
- `tools/oracle_manifest.gd:87-130` — манифест и порядок
- `tests/scenarios/walk_line.txt:1-17` — почему старый сценарий не касался мяча

C++ `of_port`:

- `src/onthepitch/match.cpp:32,587-613` — ссылка на контроллеры, выбор клавиатуры
- `src/onthepitch/match.cpp:904-1027` — `Process`, `CheckBallCollisions`, владение, время
- `src/onthepitch/match.cpp:1188-1255` — `PreparePutBuffers`/`FetchPutBuffers`
- `src/onthepitch/match.cpp:1257-1370` — `Put`, `RecursiveUpdateSpatialData`, replay
- `src/onthepitch/match.cpp:2038-2056` — AABB и derived-позиция в коллизии
- `src/onthepitch/player/humanoid/humanoidbase.cpp:34-35,569-714,716-800` — Put и время
- `src/onthepitch/player/humanoid/humanoidbase.cpp:1374-1601` — выбор клипа и причина
- `src/onthepitch/player/humanoid/humanoid.cpp:390-664` — касания, пас, удар, retainer
- `src/onthepitch/ball.cpp:86-103,553-600` — момент мяча, Touch, Put
- `src/onthepitch/player/playerbase.cpp:22-24,105-125,156-161` — Process, playerCount, state
- `src/onthepitch/player/controller/humancontroller.cpp:110-126,188,332-464,498-523` — ввод
- `src/onthepitch/team.cpp:102-111,320-446,508-541` — сторона, Process, авто-switch
- `src/onthepitch/referee.cpp:16-23,191-262` — кикофф и стандарт
- `src/onthepitch/teamAIcontroller.cpp:699-709` — джиттер позиций кикоффа
- `src/onthepitch/player/humanoid/animcollection.cpp:161-173,353-475` — порядок клипов
- `src/utils/directoryparser.cpp:28-56` — обход без сортировки
- `src/base/math/bluntmath.cpp:16-26,70-97` — RNG и `randomize`
- `src/main.cpp:145-148,189-223` — сиды от времени, две последовательности
- `src/gametask.cpp:131-214` — устройства, Process, Prepare/Fetch/Put
- `src/gamecontext.cpp:267-308` — контроллеры и `RefreshGamepads`
- `src/scene/objects/geometry.cpp:145-161`, `src/types/spatial.cpp:162-173`,
  `src/scene/scene3d/node.cpp:293-313` — цепочка Put → AABB
- `tools/determinism/main.cpp:47-107` — существующий Process-only SHA-1
- `src/utils/capturestate.cpp:10-25` — SHA-1 без гуманоида
- `docs/specs/2026-08-09-determinism-gate-design.md:76-91` — что не сериализуется
- `docs/wiki/матч.md` — фазы и текущее описание

## 11. Решение тикета

**Формат.**

- Сценарий: v1-compatible (`seed`/`ticks`/`dir`/`buttons`, дельта-кодирование) + опциональные
  `version 2`, `profile`, `trace_from`, `require`, `device`. `seed` — uint32, мёртвая зона 0.3,
  `Switch` запрещён.
- Трасса: `trace.csv` — прежние 25 колонок без изменений (все активные игроки, `B`/`P`);
  sidecars `tick.csv` (ввод, `rng_draws`, `hash_sim/hash_buf/hash_pose`),
  `transitions.csv` (`interrupt` + откуда/куда клип), `touches.csv`
  (`desired_power/dir`, `target`, вектор мяча), `pose.csv`, `manifest.csv`, `run.csv`.
- Дифф: стадии `run → manifest → input → discrete → transitions → touches/ball →
  continuous → hashes`; первое расхождение классифицируется по слою (`t_input/t_clip/
  t_touch/t_ball/t_pose`). Белый список и допуски — прежний механизм.

**Точки инструментации C++.**

- `src/oracle/scriptedhiddevice.{hpp,cpp}` — `IHIDevice`, `deviceType = Keyboard`,
  сырой `GetDirection`, `previous = tick-1`.
- `src/oracle/oraclescenario.{hpp,cpp}` — порт `src/lab/OracleScenario.cs:68-193`.
- `src/oracle/oracletrace.{hpp,cpp}` — писатель; зовётся оркестратором, не ядром.
- `src/oracle/oraclerun.{hpp,cpp}` + `tools/oracle/main.cpp` — инициализация как в
  `tools/determinism/main.cpp:47-99`, `randomize(seed)` перед `new Match`,
  `SideSelection` для команды 0, фиксированный цикл четырёх фаз, один матч на процесс.
- `controllers[0] = ScriptedHIDDevice` (`src/gamecontext.cpp:267-270`) — единственная
  точка подмены ввода; `HumanController`/`Match` не меняются.
- Узкие швы: явные `snapshotTime/putTime` в
  `Match::PreparePutBuffers/FetchPutBuffers` (`src/onthepitch/match.cpp:1188,1227`);
  симулированные часы в `EnvironmentManager` (`src/managers/environmentmanager.cpp:22-26`);
  счётчик `random()` в `src/base/math/bluntmath.cpp:90-97`; два диагностических геттера
  `gauge_ms`/`actionButton` в `HumanController` (сейчас `GetActionMode()` есть,
  `humancontroller.hpp:31`).
- CMake: новый `oraclelib` рядом с `determinism_runner` (`CMakeLists.txt:324-340`),
  слинкованный в standalone и в GDExtension.

**Критерии.**

- Прогон валиден, только если совпали `run.csv` и `manifest.csv`; иначе код 3.
- Для паса/удара обязателен слой `touches.csv` + `B`-строки; «клип совпал» — не вердикт.
- Контроль может переезжать; это дискретное событие, а не повод останавливать дифф.
- Гейты `require` проверяются на эталоне; недоказанный сценарий — код 3.
- Same-build допуски — 1e-6; `hash_pose` — побитово.
- Один матч на процесс; `GameTask`, `RefreshGamepads`, SDL-события не участвуют.

**Минимальные сценарии.**

1. `dribble_short.txt` — `open_play`, 150 тиков, ≥80 тиков владения, ≥1 `BallControl`,
   ноль пасов/ударов, мяч < 3 м.
2. `pass_short.txt` — `open_play`, 120 тиков, ≥1 `ShortPass`, мяч ≥ 5 м/с после касания.
3. `shot_short.txt` — `open_play_shot`, 100 тиков, ≥1 `Shot`, мяч ≥ 12 м/с и ≥ 30 м по X.

Эти три сценария плюс `pose/hash`-слои закрывают вопрос: они доказывают ведение, пас и
удар отдельно, а не «ходьбу без мяча», и на первом же расхождении называют фазу —
ввод, отбор клипа, касание, мяч или Put.

