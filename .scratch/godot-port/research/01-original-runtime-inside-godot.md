# Оригинальный C++ runtime внутри Godot

**Тикет:** `.scratch/godot-port/issues/01-original-runtime-inside-godot.md`
**Дата:** 2026-10-25
**Статус:** исследование завершено, решение ниже
**Исследован:** `C:\Users\Egor\Desktop\projects\GameplayFootball-of_port` @ `8b9df5c` (рабочее дерево чистое, кроме untracked `palette-*.html`)
**Как проверялось:** чтение исходников + две эмпирические сборки Release x64 из текущего дерева (в `%TEMP%`, дерево проекта не менялось) + прогон `determinism_runner` и одноразового probe-бинарника, который вызывает `GameTask::ProcessPhase()` / `GameTask::PutPhase()` с mock graphics/audio. См. §9.

---

## 0. Короткий ответ

Оригинальный матч можно целиком держать в одном GDExtension-DLL, без окна, OpenGL-контекста и без нового sim-thread:

1. Собрать существующие статические библиотеки игры (`blunted2`, `gamelib`, `menulib`, `datalib`, `leaguelib`, `gamecontextlib`, `hidlib`) и 6 "движковых" единиц трансляции (`gametask.cpp`, `utils.cpp`, `dbquery.cpp`, `gamedefines.cpp`, `misc/perlin.cpp`, `misc/hungarian.c`) в одну DLL вместе с `godot-cpp`. `main.cpp` не нужен.
2. Инициализировать runtime ровно как `determinism_runner`: `Properties` -> `blunted::Initialize` -> `InitGameContext` -> `GameTask` -> шрифты -> `MenuTask` -> `TaskSequence("game")` -> `LoadingMatchPage` -> `MatchData` -> `randomize(seed)` -> `GameTask::Action(StartMatch)`.
3. Гонять **оригинальные фазы**: на каждый логический тик (10 мс) - `GameTask::ProcessPhase()` (внутри: `IHIDevice::Process` -> `Match::Process()` -> `Match::PreparePutBuffers()`); на каждый render-кадр - `GameTask::PutPhase()` (внутри: `Match::FetchPutBuffers()` -> `Match::Put()` -> `UpdateFullbodyModel()` -> `UploadFullbodyModel()` -> `UploadGoalNetting()`). Godot только читает Blunted-ноды после `Put`.
4. Сделать **одну минимальную правку C++**: "presentation clock" в `Match` (2 поля + сеттер), потому что `PreparePutBuffers`/`FetchPutBuffers` берут время из `Scheduler` и `EnvironmentManager` (wall clock). Без этого все `TemporalSmoother` штампуются временем 0 и **вся сцена схлопывается в (0,0,0)** - проверено эмпирически (§9.3).

Ключевой вывод, который меняет архитектуру: **`Put` не является "чистой презентацией"**. `Match::Process()` читает AABB геометрий, которые двигаются только в `Put` (поза игрока), и по ним решает столкновения мяча с телом и подкаты. Поэтому `Put` обязателен в контуре паритета, и его каденция влияет на gameplay. Скининг (`UpdateFullbodyModel`) при этом можно не использовать для рендера - он не входит в обратную связь симуляции.

---

## 1. Что в оригинале обязано сохраниться

### 1.1. Четыре фазы и каденция

Матч живёт в двух `TaskSequence`, зарегистрированных в `src/main.cpp:189-223`:

- `"game"`, шаг `physics_frametime_ms` (по умолчанию 10 мс) - `MenuTask` Get/Process + `GameTask` Get/Process;
- `"graphics"`, frametime 0 (skippable, "как можно чаще") - `GameTask` Put + `GraphicsSystem` Get/Process/Put.

`GameTask::ProcessPhase()` (`src/gametask.cpp:129-198`) делает ровно:

```
RefreshGamepads()                                                  // 131
... hot-plug pause/controller-select (только если в sides есть геймпад)  // 135-180
for controllers: controller->Process()                             // 182-184
match->Process()                                                   // 187
matchPutBufferMutex.lock(); match->PreparePutBuffers(); unlock()   // 189-191
```

`GameTask::PutPhase()` (`src/gametask.cpp:200-283`):

```
match->FetchPutBuffers()                            // 211
match->Put()                                        // 214
собрать активных игроков + officials               // 216-227
TaskManager::EnqueueWork(UpdateFullbodyModel...)    // 232-245
match->UploadGoalNetting()                          // 247
Wait() всех UpdateFullbodyModel                     // 252-254
TaskManager::EnqueueWork(UploadFullbodyModel...)    // 260-273 -> Geometry::OnUpdateGeometryData(false)
```

`Match::Process()` - фиксированные 10 мс: `matchTime_ms += 10`, `actualTime_ms += 10` (`src/onthepitch/match.cpp:1015-1016`); счётчик тиков `iterations.data++` в конце (`:1184`). От реального времени он не зависит - это уже сделано для детерминизма (`:906-907`).

`Match::PreparePutBuffers()` (`:1188-1225`) штампует буферы временем `snapshotTime_ms = gameSequenceInfo.timesRan * gameSequenceInfo.sequenceTime_ms` (`:1196`), т.е. номером тика x 10. `Match::FetchPutBuffers()` (`:1227-1255`) считает `putTime_ms = EnvironmentManager::GetTime_ms() - gameSequenceInfo.startTime_ms` (`:1231-1234`), т.е. **реальным временем от старта sequence**.

### 1.2. Process читает presentation-состояние (главный сюрприз)

В `Match::Process()` есть три места, которые читают `Geometry::GetAABB()`:

- `CheckBallCollisions()` (`src/onthepitch/match.cpp:1978-2096`, вызов на `:922`): на `:2038-2045` перебирает **все** `Geometry` под `player->GetHumanoidNode()` и проверяет пересечение AABB с мячом; на `:2056-2061` считает направление и силу отскока, на `:2090` крутит мяч через `random(-30,30)`.
- `CheckHumanoidCollision()` (`:1602-1976`, вызов на `:982`): подкаты, `:1919-1944` берёт AABB "нападающего" и "жертвы" и при пересечении делает `TripMe()` + `Referee::TripNotice()` (`:1952-1963`).

`Geometry::GetAABB()` (`src/scene/objects/geometry.cpp:145-162`) лениво считает AABB из `geometryData->GetResource()->GetAABB() * GetDerivedRotation() + GetDerivedPosition()` и кеширует до `InvalidateBoundingVolume()`.

`player->GetHumanoidNode()` - это копия `media/objects/players/player.object` (`src/onthepitch/team.cpp:69-71`, `src/onthepitch/player/humanoid/humanoidbase.cpp:104-114`), т.е. 13 геометрий `pelvis/trunk/head/upperarm/lowerarm/upperleg/lowerleg/foot`. Их вершины **не** скинятся; но их `GetDerivedRotation()/GetDerivedPosition()` зависят от локальных поворотов узлов, а узлы пишутся только в `HumanoidBase::Put()`:

- `Animation::Apply()` ставит повороты лимбам и позицию только корню `"player"` (`src/utils/animation.cpp:710-716`);
- `HumanoidBase::Put()` применяет анимацию к `nodeMap`, затем `UpdateFullbodyNodes()` читает мировые трансформы (`src/onthepitch/player/humanoid/humanoidbase.cpp:759-800`).

Вывод: **поза, которую выставляет `Put`, на следующем `Process` становится геометрией столкновений**. Это не гипотеза: в коде прямо стоит `// todo: should not read geoms during process` (`src/onthepitch/match.cpp:922`, `:982`), но это работает именно так. Следствия:

- Нельзя "оптимизировать" и не вызывать `Put` - тогда поза навсегда останется bind/начальной и столкновения разойдутся.
- Нельзя менять каденцию `Put` относительно `Process`, если нужен тик-в-тик паритет.
- `Put` не потребляет RNG (см. §1.3), т.е. он меняет состояние не через RNG, а через AABB.

При этом **скининг** (`HumanoidBase::UpdateFullbodyModel`, `humanoidbase.cpp:437-561`) пишет только в `fullbody`-геометрию (одна сетка `media/objects/players/fullbody.object`), а не в 13 геометрий `player.object`. Поэтому `UpdateFullbodyModel` в обратную связь симуляции не входит: его можно не использовать для рендера, но в первом срезе его дешевле оставить (он вызывается из `PutPhase` и стоит ~0.7 мс/тик, §9.2).

### 1.3. RNG-потребители, которые нельзя убирать

RNG глобальный и не имеет отношения к "презентации":

- `blunted::random()` - `boost::mt19937` (`src/base/math/bluntmath.cpp:24-31`, `:99-108`);
- `randomize(seed)` сбрасывает сразу `srand`, boost-RNG и `fastrandseed` (`bluntmath.cpp:78-84`).

Потребители в игровом контуре (все должны выполняться ровно столько же раз и в том же порядке):

| Место | Что | Когда |
|---|---|---|
| `match.cpp:501-516` | `SetRandomSunParams()` - 6 вызовов | конструктор `Match`, и по F1 в `Process` |
| `match.cpp:571` | `RandomizeAdboards()` - по одному на adboard | конструктор `Match` |
| `match.cpp:759` | `UpdateIngameCamera()` - 2 вызова на **каждый** `Process` | всегда, пока `autoUpdateIngameCamera` |
| `match.cpp:2090` | `CheckBallCollisions` - 3 вызова | при контакте мяча с телом |
| `ball.cpp:553-556` | `TriggerBallTouchSound` - `random(0,0.2)` для pitch | при звуке касания |
| `player.cpp:495` | `Player::SendOff` - 1 вызов | при удалении |

Практические следствия:

- **`UpdateIngameCamera` нельзя отключать** (`SetAutoUpdateIngameCamera(false)`), иначе на следующем тике RNG-поток сдвинется на 2 значения. Камера в оригинале - часть `Process`, а не `Put`.
- `TriggerBallTouchSound` вызывается только если `gain * 0.6 * GetReal("audio_volume", 0.5) > 0.01` (`ball.cpp:553-556`). **`audio_volume` нельзя ставить в 0**: это не только громкость, это число вызовов RNG. Мьютить надо в audio-renderer'е (mock), а конфиг оставить 0.5.
- `ProceduralPitch::GeneratePitch` внутри конструктора `Match` делает один `random(0,1)` (`proceduralpitch.cpp:455`) - ещё одна причина не "пропускать тяжёлые шаги конструктора".
- `fastrandom()` используется только генерацией травы (`proceduralpitch.cpp:82-178`) и в геймплее не читается; его состояние не важно.
- `Put` (`match.cpp:1257-1370`) RNG не потребляет: `Put2D`, scoreboard, `UpdateGoalNetting`, `CaptureReplayFrame` - все без `random()`. Поэтому менять частоту `Put` можно без изменения RNG-потока, но нельзя без изменения позы -> AABB (§1.2).

### 1.4. Что действительно можно не рендерить

- Окно/OpenGL/аудио-устройство: `graphics3d_renderer=mock` -> `MockRenderer3D` (`src/systems/graphics/graphics_system.cpp:35-36`, `rendering/mock_renderer3d.hpp`), `audio_renderer=mock` -> `MockAudioRenderer` (`src/systems/audio/audio_system.cpp:32-33`). `CreateContext()` mock'ов возвращает `true`; окно не создаётся.
- Живой UI меню: `MenuTask` и `PageFactory` всё равно нужны (на них завязаны конструкторы `Match`, `Player`, `LoadingMatchPage`, `PageFactory::CreatePage`), но `MenuTask::ProcessPhase()` можно не вызывать - тогда страницы не живут как UI.
- Пиксели Blunted-рендера: ничего не нужно выводить; Godot рисует своё.

`SDL_Init(SDL_INIT_VIDEO)` в коде **нет**: инициализируется только `SDL_INIT_GAMEPAD` (`src/managers/usereventmanager.cpp:47`); `TTF_Init` - в `blunted::Initialize` (`src/blunted.cpp:122`). GUI работает на `SDL_Surface` + `TTF_RenderText_*`, видео-подсистема не нужна. Проверено: probe без окна доходит до `Put` (§9).

---

## 2. Состав runtime-модуля: CMake, исходники, Windows x64

### 2.1. Что уже есть в CMakeLists

Статические цели (`CMakeLists.txt:76-287`):

| Цель | Исходники | Нужна мосту |
|---|---|---|
| `blunted2` | `src/base`, `src/types`, `src/scene`, `src/systems`, `src/managers`, `src/framework`, `src/utils`, `src/utils/gui2`, `src/blunted.cpp` | да (движок) |
| `gamelib` | `src/onthepitch/**` (Match, Team, Player, Ball, Referee, Official, AI, proceduralpitch) | да |
| `menulib` | `src/menu/**` (MenuTask, PageFactory, scoreboard, radar, game pages, league pages) | да (`Match` включает `menutask.hpp`, `scoreboard.hpp`, `radar.hpp`) |
| `datalib` | `src/data/{matchdata,playerdata,teamdata}.cpp` | да |
| `leaguelib` | `src/league/leaguecode.cpp` | да (на него ссылается menulib) |
| `gamecontextlib` | `src/gamecontext.cpp` | да (глобалы + `InitGameContext`) |
| `hidlib` | `src/hid/{gamepad,keyboard}.cpp` | да |

`src/systems/physics/*` **не компилируется** - ODE не используется (`CMakeLists.txt:72-75`).

`determinism_runner` (`CMakeLists.txt:326-339`) - готовый шаблон компоновки: те же 7 библиотек + `tools/determinism/main.cpp` + `src/{gametask,utils,dbquery,gamedefines}.cpp` + `src/misc/{perlin.cpp,hungarian.c}`. Ровно этот набор (минус `main.cpp`) и есть содержимое runtime-модуля.

### 2.2. Предлагаемая цель

Добавить в `CMakeLists.txt` (или в отдельный `gdextension/CMakeLists.txt` через `add_subdirectory`) одну статическую цель:

```cmake
add_library(gpf_runtime STATIC
        src/gametask.cpp
        src/utils.cpp
        src/dbquery.cpp
        src/gamedefines.cpp
        src/misc/perlin.cpp
        src/misc/hungarian.c)
apply_common_includes(gpf_runtime)
target_link_libraries(gpf_runtime PUBLIC ${LIBRARIES})   # LIBRARIES уже есть на :288
```

и линковать её в GDExtension-DLL:

```cmake
add_library(open_football_gdext SHARED
        src/register_types.cpp
        src/match_node.cpp
        src/gpf_match.cpp          # новый мост
        src/procedural_pitch.cpp)
target_link_libraries(open_football_gdext PRIVATE godot-cpp gpf_runtime)
```

Не включать: `src/main.cpp` (там `main`/`WinMain` и `RunGame`), `tools/**`, `src/systems/physics`, `src/menu` **напрямую** (он уже в `menulib`).

Важно: `gpf_runtime` должен быть собран из **того же дерева/коммита**, что и остальные библиотеки. Ручная линковка "свежих заголовков со старыми .lib" ломается на ABI: в моём probe это дало `std::length_error`/heap corruption из `Lockable<QueuedFixture>` (у `SideSelection` появилось поле `confirmed`, `menutask.hpp:34`, а `.lib` был старее). См. §9.1.

### 2.3. Компилятор и линковка (Windows x64)

Из реальной CL-командной строки проекта (`build-x64/determinism_runner.dir/.../CL.command.1.tlog`):

- MSVC 19.44 (VS 17 2022), `-A x64`, C++17, `/MD` (динамический CRT; совпадает с Godot и `godot-cpp`), `/O2 /Ob2`, `/DNDEBUG`, `/GR` (RTTI **включён**), `/EHsc`.
- Boost-макросы обязательны и должны совпадать с библиотеками:
  `BOOST_FILESYSTEM_NO_LIB`, `BOOST_FILESYSTEM_DYN_LINK=1`,
  `BOOST_THREAD_NO_LIB`, `BOOST_THREAD_DYN_LINK`, `BOOST_THREAD_USE_DLL`,
  `BOOST_ATOMIC_NO_LIB`, `BOOST_ATOMIC_DYN_LINK`,
  `BOOST_CHRONO_NO_LIB`, `BOOST_CHRONO_DYN_LINK`,
  `BOOST_CONTAINER_NO_LIB`, `BOOST_CONTAINER_DYN_LINK`,
  `BOOST_DATE_TIME_NO_LIB`, `BOOST_DATE_TIME_DYN_LINK`.
  Без них boost-классы в моём TU получили другой ABI, чем в `.lib`, и probe падал ещё в конструкторе `MenuTask` - это не гипотетический риск, а воспроизведённый (§9.1).
- `WIN32`, `_WINDOWS`, `_MBCS` - как в проекте.
- Debug-сборка не годится: другой CRT (`/MDd`) + живые `assert` + debug-ветки с `exit(1)`.
- Внешние зависимости (`find_package`, `CMakeLists.txt:41-53`): SDL3, SDL3_image, SDL3_ttf, OpenAL, Boost (filesystem, thread), unofficial-sqlite3, OpenGL. Triplet - `x64-windows` (`build-x64/CMakeCache.txt`), toolchain `C:/dev/vcpkg/scripts/buildsystems/vcpkg.cmake`, `GAMEPLAYFOOTBALL_WINDOWS_SUBSYSTEM=OFF` влияет только на EXE, не на DLL.
- `blunted2` компилирует `opengl_renderer3d.cpp` и `openal_renderer.cpp` и линкует `opengl32`, `glu32`, `OpenAL32` - даже при mock-рендере DLL **требует** эти библиотеки при загрузке.

### 2.4. DLL и data

Минимальный набор DLL рядом с `open_football_gdext.dll` (или рядом с exe Godot / в PATH - проверить на первом срезе, как именно Godot ищет зависимости GDExtension):

```
SDL3.dll  SDL3_image.dll  SDL3_ttf.dll  OpenAL32.dll  sqlite3.dll
boost_filesystem-vc143-mt-x64-1_92.dll  boost_thread-vc143-mt-x64-1_92.dll
freetype.dll  fmt.dll  jpeg62.dll  libpng16.dll  z.dll  bz2.dll
brotlicommon.dll  brotlidec.dll
```

(это ровно то, что vcpkg кладёт в `build-x64/Release`; список снят с фактической сборки, а не из документации).

Data-файлы и CWD:

- Все пути в игре **относительные**: `football.config`, `databases/default/database.sqlite`, `media/...`, `log.txt`. Пример: `InitGameContext` (`src/gamecontext.cpp:197-199`), `ObjectLoader` (`src/utils/objectloader.cpp`), `AnimCollection::Load("media/animations")` (`src/onthepitch/match.cpp:83`).
- Полный `data/` **есть в репозитории**: 296 файлов в `data/media/animations` (293 `.anim` + 3 `.anim.util`), модели, текстуры, шрифты, `data/databases/default/database.sqlite` (587 КБ), пустой `data/football.config`. Не смешивать с `dist/GameplayFootball-data-*.zip` - там **другая** БД (193 МБ), это изменит состав команд и весь матч.
- `football.config` обязан **существовать** (пустой - нормально): `file_to_vector` делает `Log(e_FatalError)` при неудачном открытии (`src/base/utils.cpp:152`), а `LoadFile` вызывается до всего остального.
- Шрифт: `media/fonts/alegreya/AlegreyaSansSC-ExtraBold.ttf` (или ключ `font_filename`), иначе `TTF_OpenFont` -> `exit(1)` (`tools/determinism/main.cpp:76-78`).
- CWD нельзя оставлять "как получится": у редактора Godot CWD - не каталог проекта. Мост должен сам вычислить data-root (в редакторе `ProjectSettings::globalize_path("res://...")`, в экспорте - каталог exe, потому что `res://` внутри `.pck` и `std::ifstream`/boost его не прочитают) и вызвать `SetCurrentDirectoryW(root)` до `Initialize`. Data должна лежать **россыпью** рядом с exe, не в `.pck`.
- В каталог data стоит положить `.gdignore`, чтобы Godot не импортировал 293 `.anim`, `.ase`, `.object`, `.wav`.

---

## 3. Инициализация (точная копия `determinism_runner`)

`tools/determinism/main.cpp` - проверенный рецепт. По шагам, с объяснением, зачем каждый:

| Шаг | Код | Зачем |
|---|---|---|
| 1 | `Properties config; config.LoadFile("football.config");` | файл обязан существовать |
| 2 | `Set("graphics3d_renderer","mock"); Set("audio_renderer","mock");` (`:49-50`) | без окна/GL/audio |
| 3 | `Set("match_difficulty", 0.8f); Set("match_duration", 1.0f);` (`:55-56`) | настройки экрана пишут эти ключи в config; пиннинг сохраняет эталон стабильным |
| 4 | `blunted::Initialize(config)` (`:58`) | менеджеры, resource managers, загрузчики, `TTF_Init`, `Scheduler` (`src/blunted.cpp:73-131`) |
| 5 | `InitGameContext(config)` (`:71`) | `Database::Load("databases/default/database.sqlite")`, `GraphicsSystem`+`AudioSystem` (mock), `Scene2D`/`Scene3D`, debug-пилоны, `controllers` (keyboard + gamepads) (`src/gamecontext.cpp:177-312`) |
| 6 | `gameTask = new GameTask()` (`:74`) | нужен `GetGameTask()` для `PageFactory::CreatePage` (`pagefactory.cpp:37`); владеет `Match` |
| 7 | `TTF_OpenFont` x2 + `TTF_SetFontOutline` (`:76-81`) | стиль GUI |
| 8 | `menuTask = new MenuTask(5/4, 0, font, outlineFont)` (`:81`) | `Match` требует `GetMenuTask()` (`match.cpp:39`), создаёт `WindowManager`, `PageFactory`, scoreboard/radar/captions |
| 9 | `TaskSequence("game", 10, false)` + `AddUserTaskEntry(menuTask, e_TaskPhase_Get)` + `RegisterTaskSequence` (`:85-87`) | `RegisterTaskSequence` фатален при 0 entries (`scheduler.cpp:42`); `Match` читает `GetTaskSequenceInfo("game")` |
| 10 | `menuTask->SetTeamIDs("3","8")` (`:90`) | Release-сборка не делает QuickStart (`menutask.cpp:169-171`), поэтому team id не выставляются сами |
| 11 | `CreatePage(e_PageID_LoadingMatch, ...)` (`:92`) | конструктор `Match` в конце делает `GetMostRecentlyCreatedPage()` -> `LoadingMatchPage::Close()` (`match.cpp:398-400`); страница сама создаёт `MatchData` (`loadingmatch.cpp:21-22`) |
| 12 | `menuTask->SetMatchData(new MatchData(id0, id1))` (`:94-95`) | `Action(StartMatch)` берёт `GetMatchData()` |
| 13 | `randomize(42)` (`:97`) | **сразу перед** созданием матча: конструктор матча потребляет RNG (солнце, adboards, трава) |
| 14 | `gameTask->Action(e_GameTaskMessage_StartMatch)` (`:99`) - или `new Match(matchData, GetControllers())`, как в runner'е | нормальный путь игры: `Action` создаёт `Match`, кладёт в `GameTask::match`, сбрасывает sequence time (`gametask.cpp:53-71`) |

Для первого среза "один управляемый футболист" нужен ещё один шаг между 12 и 13 - синтетический controller setup:

```cpp
std::vector<SideSelection> sides;
SideSelection kb;
kb.controllerID = 0;        // controllers[0] == HIDKeyboard (gamecontext.cpp InitGameContext)
kb.joystickID  = 0;         // 0 == keyboard (menutask.hpp:31)
kb.controllerImage = 0;
kb.side = -1;               // -1 => team 0 (match.cpp:596-610: round(side*0.5+0.5))
sides.push_back(kb);
menuTask->SetControllerSetup(sides);
```

`side=-1` = Home, `side=+1` = Away, `0` = не играет. `Match::UpdateControllerSetup()` вызывается из конструктора (`match.cpp:242`) и создаёт `HumanGamer` + `HumanController` + `ElizaController` fallback.

Чего **не** вызывать: `MenuTask::ProcessPhase()`. Он обрабатывает GUI-ввод, `menuAction` и может дёрнуть `GameTask::Action(StopMatch/StartMatch)`, `windowManager->Process()`. Для отображения он не нужен; `Match` и `Put` работают без него.

Стоимость инициализации (эмпирически, §9.2): **~2.8 с** на `new Match` (загрузка 293 анимаций, стадион, генерация травы 2048x1024, звуки, GUI) - один раз, на главном потоке; в Godot это заметный hitch, его стоит показывать как загрузку.

---

## 4. Контур кадра: Process -> Prepare -> Fetch -> Put

### 4.1. Почему `Scheduler` не подходит

`Scheduler::Run()` (`src/framework/scheduler.cpp:154-...`) - **блокирующий** цикл по wall clock с `condition_variable`: он сам решает, когда запускать фазы, и увеличивает `timesRan` только внутри (`:225`). Публичного API "сделай один тик" нет; `PauseTaskSequence`/`ResetTaskSequenceTime` не помогают. Запускать `Run()` - это и есть новый sim-thread и реальное время, что тикет запрещает.

При этом `Match` нужны `TaskSequenceInfo` (`timesRan`, `startTime_ms`, `sequenceTime_ms`). Без запущенного `Run()` `timesRan` всегда 0 -> `snapshotTime_ms` всегда 0 -> `TemporalSmoother` не работает.

### 4.2. Минимальная правка C++: presentation clock

Единственное изменение в игровом коде - отвязать `Prepare`/`Fetch` от `Scheduler`/`EnvironmentManager`. Предлагается (по умолчанию выключено, поведение `determinism_runner` не меняется):

```cpp
// match.hpp
public:
  void SetPresentationClock(bool enabled, unsigned long snapshotTime_ms, unsigned long putTime_ms);
private:
  bool externalPresentationClock = false;
  unsigned long externalSnapshotTime_ms = 0;
  unsigned long externalPutTime_ms = 0;
```

```cpp
// match.cpp
void Match::SetPresentationClock(bool enabled, unsigned long snapshotTime_ms, unsigned long putTime_ms) {
  externalPresentationClock = enabled;
  externalSnapshotTime_ms = snapshotTime_ms;
  externalPutTime_ms = putTime_ms;
}

void Match::PreparePutBuffers() {
  unsigned long snapshotTime_ms;
  if (externalPresentationClock) {
    snapshotTime_ms = externalSnapshotTime_ms;          // bridge: k * 10
    timeSincePreviousPreparePut_ms = 0;                  // stats only
  } else {
    gameSequenceInfo = GetScheduler()->GetTaskSequenceInfo("game");
    ... существующий код (1190-1198) ...
    snapshotTime_ms = gameSequenceInfo.timesRan * gameSequenceInfo.sequenceTime_ms;
  }
  ... остальное без изменений ...
}

void Match::FetchPutBuffers() {
  if (GetIterations() < 1) return;
  unsigned long putTime_ms;
  if (externalPresentationClock) {
    putTime_ms = externalPutTime_ms;                     // bridge: snapshot + alpha*10
    timeSincePreviousPut_ms = (int)putTime_ms - (int)previousPutTime_ms;
    previousPutTime_ms = putTime_ms;                     // <-- это читает HumanoidBase::Put
    fetchedbuf_timeDelta = 0;
  } else {
    ... существующий код (1231-1237) ...
  }
  ... остальное без изменений ...
}
```

Почему именно так:

- `HumanoidBase::Put()` берёт время для `TemporalSmoother::GetValue()` из `match->GetPreviousPutTime_ms()` (`humanoidbase.cpp:794-795`). Это поле обновляется только в `Match::FetchPutBuffers` (`match.cpp:1233`), поэтому его нужно выставлять в внешнем режиме.
- `HumanoidBase::Put()` также считает `timeDiff_ms = snapshotTime_ms - fetchedbuf_previousSnapshotTime_ms` и клампит в 10..50 (`humanoidbase.cpp:764-766`). При равномерных 10 мс это всегда 10.
- `gameSequenceInfo` в `PreparePutBuffers` используется ещё в `timeSincePreviousPreparePut_ms` - это только геттеры статистики (`match.hpp:214-220`), на рендер не влияют.
- Ничто в `Process()` не читает эти поля -> симуляция и RNG не меняются.

Альтернатива - глобальные `Set/GetPresentationClock` в `gamecontext.cpp` (как остальные глобалы). Тогда правка не трогает `match.hpp`, но добавляет второй файл. Обе эквивалентны; вариант с методом `Match` самодостаточен.

### 4.3. Псевдокод кадра в Godot

```cpp
// GpfMatch::_process(double delta)
// realtime-режим: догоняем реальное время фиксированными шагами по 10 мс
accumulator_ms += delta * 1000.0;
if (accumulator_ms - simTime_ms > 250.0) accumulator_ms = simTime_ms + 250.0; // анти-спираль

int steps = 0;
while (simTime_ms + 10 <= (unsigned long)accumulator_ms && steps < MAX_CATCHUP) {
  simTime_ms += 10;
  match->SetPresentationClock(true, simTime_ms, simTime_ms);
  gameTask->ProcessPhase();          // controller Process + Match::Process + Match::PreparePutBuffers
  steps++;
}

// один Put на render-кадр; альфа - доля следующего тика, которую уже прожили
double alpha = clamp((accumulator_ms - (double)simTime_ms) / 10.0, 0.0, 0.999);
unsigned long putTime = simTime_ms + (unsigned long)(alpha * 10.0);
match->SetPresentationClock(true, simTime_ms, putTime);
gameTask->PutPhase();                // Match::FetchPutBuffers + Put + skinning + netting

// ТОЛЬКО ПОСЛЕ ЭТОГО читать Blunted-ноды (мяч, игроки, 14 костей)
```

Для детерминированной трассы (тикет 02) тот же цикл, но `steps = fixed_ticks_per_frame` и `alpha = 0` (или `alpha = 0.5` для проверки интерполяции). Тогда сторона сравнения должна прогонять `Put` с той же каденцией.

Порядок обязателен: `PutPhase` этого кадра должен пройти **до** `ProcessPhase` следующего кадра, иначе `CheckBallCollisions`/`CheckHumanoidCollision` прочитают AABB от более старой позы (в оригинале ровно такое отставание на 1 render-кадр и есть - не увеличивайте его произвольно).

Не вызывать `Match::Process()`/`PreparePutBuffers()` в обход `GameTask::ProcessPhase()`, если только не нужно убрать `RefreshGamepads()`: `ProcessPhase` - это и есть оригинальная фаза, меньше копипаста и меньше шансов разойтись.

### 4.4. Семантика временных буферов

- `TemporalSmoother` хранит `3 + ceil(20/10) = 5` снимков (`src/utils.cpp:613`), история - `temporalSmoother_history_ms = 20` (`src/gamedefines.hpp:76`).
- `GetValue(now)` ищет `now - 20` и линейно (для кватернионов - `GetLerped`) смешивает два соседних снимка (`utils.cpp:625-704`).
- `PreparePutBuffers` вызывается **после каждого** `Process` -> снимки идут через 10 мс.
- `putTime = snapshot + alpha*10` даёт target = `snapshot - 20 + alpha*10`, т.е. между снимками `k-2` и `k-1`: под-тиковая плавность при постоянном отставании 20 мс - как в оригинале.
- `if (value1.time_ms == 0) return value2.data;` (`utils.cpp:676`) - время 0 считается "пустым". Поэтому логический clock лучше начинать с 10, а не с 0; иначе первый снимок выбрасывается.
- `Ball::PreparePutBuffers` кладёт `positionBuffer` = `Predict(10)`, т.е. на тик вперёд (`ball.cpp:562-595`) - это часть оригинального сглаживания, не "чинить".
- `HumanoidBase` кормит `TemporalSmoother` **в `Put`, а не в `Prepare`** - в коде даже стоит комментарий-сомнение (`humanoidbase.cpp:789-792`). Практика: узлы получают столько снимков, сколько было `Put`, а шар/камера - сколько было `Prepare`. Это оригинальное поведение; не "исправлять" в первом срезе.

Буферы, которые реально существуют:

| Владелец | Буфер | Глубина |
|---|---|---|
| `Ball` | `buf_positionBuffer`, `buf_orientationBuffer` (`ball.hpp:103-104`) | 5 |
| `Match` | `buf_cameraOrientation/NodeOrientation/NodePosition/CameraFOV` | 5 |
| `HumanoidBase` | `buf_TemporalHumanoidNodes` - по одному `TemporalSmoother` на **каждый** из 14 узлов (`humanoidbase.cpp:27-44`) | 5 |
| `HumanoidBase` | `buf_animApplyBuffer` - **один** снимок (не temporal), копируется в `Prepare` (`:721`) | 1 |
| `Player` | caption-поля `buf_*`/`fetchedbuf_*` - GUI (`player.cpp:353-418`) | 1 |

### 4.5. Эмпирическое доказательство необходимости clock seam

Probe (§9) без правки `Match`, т.е. с `timesRan == 0`, после 1000 тиков и 500 `Put`:

```
[after-create]    nodeMap=14 nodesAtOrigin=1  player0root=(0 0 0) ball=(0 0 0)
[after-first-put] nodeMap=14 nodesAtOrigin=1  player0root=(0 0 0) ball=(0 0 0)
[end]             nodeMap=14 nodesAtOrigin=14 player0root=(0 0 0) ball=(0 0 0)
```

Все 14 узлов у всех игроков уезжают в начало координат, мяч тоже - ровно предсказанный эффект `snapshotTime == 0` + `GetValue` quirk. Т.е. без seam контур **технически работает**, но отдаёт мусор. С seam (`snapshot = k*10`) это обычная интерполяция.

### 4.6. Каденция `Put` и что считать эталоном

Существующий `determinism_runner` вызывает только `Match::Process()` (`tools/determinism/main.cpp:102-104`) и никогда - `Put`. Поэтому:

- его SHA-1 (`CaptureMatchState`, `tools/determinism/main.cpp:106`) - валидный эталон **только для Process-only** прогона;
- встроенный runtime с `Put` **не обязан** совпадать с этим хешем: `Put` двигает позы, а `Process` читает их AABB (§1.2), поэтому Process-only и Process+Put расходятся уже на первых тиках;
- для паритета первого среза нужен **новый эталон**, который гоняет тот же контур: N тиков `Process` + `Put` с фиксированной каденцией (например, 1 Put на каждые 2 тика) и пишет трассу (мяч, 22 позиции, 14 локальных поворотов, клип/кадр/нога/touchFrame). Это задача тикета 02; здесь важно зафиксировать, что старый хеш для этой цели не годится.

---

## 5. Откуда брать состояние для Godot

### 5.1. Мяч

```cpp
Geometry* ballGeom = match->GetBall()->GetBallGeom().get();      // ball.hpp:49
Vector3    pos     = ballGeom->GetDerivedPosition();             // после Put
Quaternion rot     = ballGeom->GetDerivedRotation();
```

`Ball::Put()` ставит позицию/поворот из `fetchedbuf_*` (`ball.cpp:597-600`). Узел мяча - `generic.object` с `localmode=absolute` (`data/media/objects/balls/generic.object`). Не использовать `Ball::GetPositionBuffer()`: он читает wall clock (`ball.hpp:67`). `Predict(0)` - это **симуляционное** положение, не интерполированное.

### 5.2. Игроки

```cpp
std::vector<Player*> players;
match->GetActiveTeamPlayers(0, players);   // match.cpp:640-643
match->GetActiveTeamPlayers(1, players);
for (Player* p : players) {
  int id = p->GetID();                                        // playerbase.hpp:22
  Vector3 interpPos = p->GetGeomPosition();                   // playerbase.hpp:41 - узел, интерполировано
  Vector3 simPos    = p->GetPosition();                       // playerbase.hpp:40 - симуляция, НЕ для рендера
}
```

`GetGeomPosition()` = `humanoidNode->GetPosition()`, а `humanoidNode` - один из 14 узлов, которому `HumanoidBase::Put` ставит temporal-сглаженную позицию (`humanoidbase.cpp:785-800`). Именно её и надо рисовать.

Официальные лица: `match->GetOfficialPlayers(vec)` (`match.cpp:644-647`), у них те же `GetNodeMap()`/`GetGeomPosition()`.

### 5.3. 14 костей

`PlayerBase::GetNodeMap()` (`playerbase.hpp:90`) -> `HumanoidBase::GetNodeMap()` (`humanoidbase.hpp:246`) - `const std::map<std::string, boost::intrusive_ptr<Node>>&`. Ровно 14 записей (проверено probe: `nodeMap=14`).

Из `data/media/objects/players/player.object` и `data/media/animations/base.anim.util`:

| # | Имя узла | Что анимируется |
|---|---|---|
| 0 | `player` | только позиция (root) |
| 1 | `body` | поворот |
| 2 | `middle` | поворот |
| 3 | `neck` | поворот |
| 4 | `left_shoulder` | поворот |
| 5 | `left_elbow` | поворот |
| 6 | `right_shoulder` | поворот |
| 7 | `right_elbow` | поворот |
| 8 | `left_thigh` | поворот |
| 9 | `left_knee` | поворот |
| 10 | `left_ankle` | поворот |
| 11 | `right_thigh` | поворот |
| 12 | `right_knee` | поворот |
| 13 | `right_ankle` | поворот |

Иерархия (из `player.object`): `player -> body -> {middle -> {neck, left_shoulder -> left_elbow, right_shoulder -> right_elbow}, left_thigh -> left_knee -> left_ankle, right_thigh -> right_knee -> right_ankle}`.

Факты, на которые можно опираться:

- `humanoidNode` имеет `e_LocalMode_Absolute` (`humanoidbase.cpp:106`), а дочерние узлы - `e_LocalMode_Relative` (дефолт загрузчика, `objectloader.cpp:102`). Значит локальные позиции детей - статичные rest-смещения из `player.object`, а `Animation::Apply` меняет только их локальные **повороты** (`animation.cpp:710-716`). Позиция анимируется только у корня `player`.
- `Animation::Apply` пишет локальные значения (`SetRotation/SetPosition`), поэтому для Godot-скелета нужны локальные трансформы, а не derived.
- Формат `.anim`: первая строка - `player`, далее по строке на узел, в каждой `имя, кадр, [quat x,y,z,w,] кадр, [pos x,y,z]`; у лимбов только кватернионы, у корня только позиция (`src/utils/animation.cpp:1076-1107`).

### 5.4. Формула для Godot `Skeleton3D`

Оригинальный скиннинг использует (см. `humanoidbase.cpp:471-555`):

```
resultVertex = Sum_b w_b * Rotate(orient_b) * (origVertex - origPos_b * zMultiplier)
                                                   + position_b * zMultiplier
```

где `joints[i].position = node->GetDerivedPosition() - fullbodyOffset` (`humanoidbase.cpp:409-412`), `fullbodyOffset = humanoidNode->GetPosition().Get2D()` (`:405-407`), `zMultiplier = playerHeight / 1.92` (`:101-102`, `defaultPlayerHeight = 1.92` в `gamedefines.hpp:74`).

Значит для визуального соответствия:

```
root_world = humanoidNode->GetPosition()                  // = fullbodyOffset (Z=0)
bone_world_pos(i) = root_world + (child_derived_pos(i) - root_world) * zMultiplier
bone_world_rot(i) = child_derived_rot(i)
zMultiplier = player->GetPlayerData()->GetHeight() / 1.92f
```

Локальный вариант для `Skeleton3D`: rest-позиции = локальные позиции из `player.object` x `zMultiplier`, поза = локальные повороты узлов (`node->GetRotation()`), корень - `humanoidNode->GetPosition()`. `zMultiplier` считается из публичного `GetPlayerData()->GetHeight()`; своего геттера у `zMultiplier` нет.

Для чтения на каждом кадре хватает публичного API:

```cpp
const NodeMap& nm = player->GetNodeMap();
nm.find("player")->second->GetPosition();          // root, локальная = мировая (Absolute)
nm.find("left_knee")->second->GetRotation();       // локальный поворот, анимирован
nm.find("left_knee")->second->GetDerivedPosition();// мировая позиция (для формулы выше)
nm.find("left_knee")->second->GetDerivedRotation();
```

Читать **после** `PutPhase` и на том же (главном) потоке.

---

## 6. Ограничения: `exit(1)`, глобальные менеджеры, повторный запуск, выгрузка

### 6.1. Process-fatal пути

`Log(e_FatalError, ...)` вызывает `exit(1)` (`src/base/log.cpp:47-52`). Поймать это нельзя. Достижимые из нашего контура фаталы:

| Источник | Триггер | Профилактика |
|---|---|---|
| `base/utils.cpp:152` `file_to_vector` | не открылся любой обязательный файл (включая `football.config`) | полный `data/`, правильный CWD, файл конфига существует |
| `gamedefines.cpp:30` `GetVertexColors` | нет `media/objects/players/models/fullbody.ase` | полный `data/` |
| `gamecontext.cpp:197-199` | не открылась `databases/default/database.sqlite` | полный `data/` |
| `scheduler.cpp:42` | `RegisterTaskSequence` с 0 entries | добавить хотя бы `menuTask/e_TaskPhase_Get` |
| `utils.cpp:118` `GetPositionName` | неизвестная позиция в БД | использовать штатную БД |
| `humanoid.cpp:250-265` | "NO APPLICABLE ANIM FOUND" и `!IsReleaseVersion()` -> `exit(1)` | `debug=false` (дефолт); в release-ветке там `ResetPosition`, не exit |
| `base/exception.cpp:12-18` | любой `BluntedException` -> fatal | не создавать исключений; валидные данные |
| `opengl_renderer3d.cpp` | ошибки GL | mock-рендерер |

`assert` в Release (`/DNDEBUG`) выключены - это ещё одна причина собирать только Release.

Если очень нужно переживать фаталы, единственный вариант - под `#ifdef` менять ветку `Log(e_FatalError)` на `throw`, но это **не** для первого среза: `Log` объявлен как обычная функция, но все вызывающие считают её noreturn, а исключение может пройти через C-код (`hungarian.c`) и через boost-колбэки. Правильнее - не допускать условий.

### 6.2. Глобальные менеджеры - one-shot

`blunted::Initialize` создаёт (`blunted.cpp:73-131`): `EnvironmentManager`, `SystemManager`, `TaskManager` (+ пул `hardware_concurrency()` worker-потоков, `taskmanager.cpp:21-30`), `SceneManager`, `ObjectFactory`, `UserEventManager`, `ResourceManagerPool`, `ASELoader/ImageLoader/WAVLoader`, `Scheduler`.

`gamecontext.cpp` добавляет глобалы: `graphicsSystem`, `audioSystem`, `scene2D`, `scene3D`, `gameTask`, `menuTask`, `db`, `config`, `controllers`, debug-пилоны (`gamecontext.cpp:35-59`).

- Повторный `Initialize`/`InitGameContext` невозможен: синглтоны уже созданы, `RegisterSystem` вернёт false.
- `blunted::Exit()` (`blunted.cpp:150-206`) разрушает всё, делает `SDL_Quit`, `TTF_Quit`, `LogClose`, спит 1 с - и тоже one-shot.
- `ShutdownGameContext()` (`gamecontext.cpp:313-321`) делает `delete config` - **`Properties` должен быть heap-объектом, живущим дольше рантайма**, иначе double-free; `db` тоже удаляется там.
- `config` хранится как сырой указатель (`gamecontext.cpp:54`), `InitGameSystems/InitGameContext` его только записывают. Держите `Properties` в куче и не уничтожайте.

### 6.3. `Match::Exit`, `GameTask::Exit`, teardown

- `Match::~Match()` пустой (`match.cpp:403-404`) - `delete match` без `Exit()` течёт.
- `Match::Exit()` (`:406-491`) удаляет `matchData` (`:423`), обнуляет `menuTask`'s указатель (`:424`), удаляет команды/мяч/судью, чистит scene-ноды, но `messageCaption` только `Hide()` - остаётся в GUI-root. Т.е. teardown неполный.
- `GameTask::Exit()` (`gametask.cpp:39-47`) делает `StopMatch` + `StopMenuScene` + `ResourceManagerPool::CleanUp()` + `scene3D.reset()`; вызывается из деструктора `GameTask`, т.е. при уничтожении глобала `gameTask`.
- `TaskManager::Exit()` ждёт пустую очередь и шлёт shutdown worker'ам; если что-то осталось - `Log(e_FatalError)` (`taskmanager.cpp:59`).

**Эмпирически:** probe после 1000 тиков + 500 `Put` вызвал `::exit(0)` и упал в `ntdll!TpWorkOnBehalfClearTicket` (0xC0000005) уже во время завершения процесса. Т.е. "просто выйти" после работы контура - небезопасно: живые потоки рендера/аудио/worker'ов и CRT-teardown пересекаются.

### 6.4. Явные ограничения первого среза

1. Один экземпляр runtime на процесс. Один `Match`. Никаких `StopMatch`/`StartMatch`.
2. Никогда не вызывать `blunted::Exit()`, `ShutdownGameContext()`, `GameTask::Exit()`, `Match::Exit()`, `exit()`.
3. Никогда не выгружать DLL вручную и не включать hot-reload GDExtension/DLL в Godot. Terminator `uninitialize_open_football_gdext` должен быть пустым (или только снимать флаги); между запусками - перезапуск Godot.
4. Второй матч/перезагрузка - вне среза. Теоретически возможны через `GameTask::Action(StopMatch)` + новый `MatchData` + новый `LoadingMatchPage`, но не проверены и трогают полу-сломанный teardown.
5. Не добавлять своих `random()` / `srand()` / `fastrandomseed()` - RNG общий и глобальный.
6. Не менять `audio_volume` (влияет на число RNG-вызовов, §1.3).
7. Не отключать `UpdateIngameCamera` (2 RNG-вызова на тик).
8. Не менять число и порядок шагов конструктора `Match` (солнце/adboards/трава расходуют RNG).

---

## 7. Точки подключения (сводка)

| Что | API | Файл:строка |
|---|---|---|
| Ввод | `UserEventManager::SetKeyboardState(SDL_Keycode, bool)` | `src/managers/usereventmanager.cpp:149` |
| Один тик | `GameTask::ProcessPhase()` | `src/gametask.cpp:129` |
| Один кадр | `GameTask::PutPhase()` | `src/gametask.cpp:200` |
| Время презентации | **новый** `Match::SetPresentationClock(bool, unsigned long, unsigned long)` | правка в `src/onthepitch/match.cpp` |
| Матч | `GameTask::Action(e_GameTaskMessage_StartMatch)` / `GetMatch()` | `src/gametask.cpp:53-71`, `gametask.hpp:84` |
| Мяч | `Match::GetBall()->GetBallGeom()` | `match.hpp:116`, `ball.hpp:49` |
| Игроки | `Match::GetActiveTeamPlayers/GetAllTeamPlayers/GetOfficialPlayers` | `match.cpp:636-647` |
| Кости | `PlayerBase::GetNodeMap()` | `playerbase.hpp:90` |
| Счёт/время/фаза | `GetScore`, `GetMatchTime_ms`, `GetActualTime_ms`, `GetMatchPhase`, `IsInPlay`, `IsGoalScored`, `GetIterations` | `match.hpp:115-168` |

---

## 8. Что не делать

- Не переписывать `Match`/`Team`/`Player`/`Ball`, не выносить `onthepitch` в отдельную библиотеку "без рендера": он уже отделяется от рендера **mock-системами**, а не переписыванием. Проверено: с mock всё считается.
- Не добавлять второй sim-thread и не запускать `Scheduler::Run()`.
- Не переносить `UpdateIngameCamera`/камеру в Godot "чтобы не считать" - это RNG.
- Не убирать `Put`/`Put2D`/`Player::Put2D` - поза и AABB.
- Не использовать `Player::GetPosition()`/`Ball::Predict(0)` для рендера (это симуляционные значения).
- Не заменять `UpdateFullbodyModel` на Godot-скининг **в цикле паритета** без проверки: он не в обратной связи, но `UploadFullbodyModel`/`OnUpdateGeometryData` - часть оригинального `PutPhase`; в первом срезе дешевле оставить.
- Не запускать с `debug=true` (QuickStart, `exit(1)` на missing anim, verbose).
- Не глушить звук через `audio_volume=0`.
- Не сравнивать с хешем старого `build-x64` артефакта: он собран раньше текущих исходников (§9.1).

---

## 9. Эмпирические проверки

Всё выполнялось в `%TEMP%\opencode`, исходники C++-репозитория не менялись.

### 9.1. Сборка

- Старый `build-x64` (20.10.2026) **старее** текущих исходников (23.10.2026) и даёт другой хеш: `d4df4524...` против `4e9ddb725d79013040e65df7dcf4aa16026bb55d` у свежей сборки из текущего дерева (HEAD `8b9df5c`). Для любых сравнений нужна сборка из текущего коммита.
- Ручная линковка probe со старыми `.lib` и новыми заголовками воспроизвела ABI-расхождение: `std::length_error` ("vector too long") в `Lockable<QueuedFixture>::GetData`, затем heap corruption. Причина - новое поле `SideSelection::confirmed` (`menutask.hpp:34`). Вывод: только CMake-сборка из одного дерева; никакой ручной линковки.
- При несовпадении boost-макросов (`BOOST_*_DYN_LINK`) probe падал уже в `MenuTask`; с макросами из реальной CL-строки - работает. Список макросов в §2.3 обязателен.

### 9.2. Прогон контура

Probe (Release x64, mock graphics/audio, no window):

```
match_create = 2773 ms
ProcessPhase = 1.405 ms/тик (n=1000)
PutPhase     = 1.365 ms/put (n=500)
nodeMap      = 14
```

- То есть оригинальный контур на 100 Гц стоит ~2.1 мс на 10 мс тика при 1 Put на 2 тика (~21% одного ядра на этой машине, 22 worker-потока).
- `determinism_runner` из свежей сборки: 13.0 с на конструктор + 5000 тиков; хеш `4e9ddb725d79013040e65df7dcf4aa16026bb55d`.
- `GameTask::ProcessPhase()` + `GameTask::PutPhase()` с mock **работают**: 1000 тиков, 500 put, `nodeMap=14`, без исключений.

### 9.3. Доказательство необходимости clock seam

Без правки `Match` (timesRan = 0) после 1000 тиков / 500 put: `nodesAtOrigin=14` у первого игрока, `player0root=(0,0,0)`, `ball=(0,0,0)` - то есть temporal-буферы возвращают default-значения. См. §4.5.

### 9.4. Завершение процесса

`::exit(0)` после работы контура -> 0xC0000005 в `ntdll!TpWorkOnBehalfClearTicket` при teardown. См. §6.3.

---

## Решение тикета

### Контур

Один процесс, один GDExtension-DLL, один экземпляр runtime на всё время жизни Godot. Godot - только дисплей и источник ввода.

```
[GDExtension init / первый _ready]
  SetCurrentDirectoryW(data_root)                  // data/ россыпью, не в .pck
  Properties* cfg = new Properties; LoadFile("football.config");
  cfg: graphics3d_renderer=mock, audio_renderer=mock,
       match_difficulty=0.8, match_duration=1.0, debug=false,
       audio_volume НЕ ТРОГАТЬ
  blunted::Initialize(*cfg)
  InitGameContext(*cfg)                            // Database, mock Graphics/Audio, Scene2D/3D
  gameTask = new GameTask()
  font = TTF_OpenFont(...AlegreyaSansSC-ExtraBold.ttf)
  menuTask = new MenuTask(5/4, 0, font, outline)
  RegisterTaskSequence(TaskSequence("game", 10, false, {menuTask/Get}))
  menuTask->SetTeamIDs("3","8")
  CreatePage(e_PageID_LoadingMatch)
  menuTask->SetMatchData(new MatchData(3, 8))
  menuTask->SetControllerSetup({ keyboard, side=-1 })   // для среза "один игрок"
  randomize(42)                                    // сразу перед матчем
  gameTask->Action(StartMatch)
  match->SetPresentationClock(true, 10, 10)
  // запомнить начальный hash/трассу для сверки

[каждый render-кадр _process]
  accumulator += delta*1000 (clamp)
  while (simTime+10 <= accumulator && steps < MAX_CATCHUP):
      simTime += 10
      match->SetPresentationClock(true, simTime, simTime)
      gameTask->ProcessPhase()                     // controllers + Match::Process + PreparePutBuffers
  alpha = clamp((accumulator-simTime)/10, 0, 0.999)
  match->SetPresentationClock(true, simTime, simTime + alpha*10)
  gameTask->PutPhase()                             // Fetch + Put + skinning + netting
  // только теперь читать:
  //   ball->GetBallGeom()->GetDerivedPosition/Rotation
  //   player->GetGeomPosition()
  //   player->GetNodeMap()  (14 узлов; локальные повороты + derived позиции)
  // перенести в Godot Node3D/Skeleton3D на этом же кадре

[никогда]
  MenuTask::ProcessPhase, Scheduler::Run, StopMatch/StartMatch,
  Exit/Shutdown/exit, выгрузка DLL, hot-reload
```

Ввод (тикет 02) подаётся в `UserEventManager::SetKeyboardState` до `ProcessPhase`; скриптовый `IHIDevice` тоже возможен, но это отдельное решение.

### Минимальные изменения C++

1. `src/onthepitch/match.hpp` + `match.cpp` - presentation clock: 3 поля, публичный сеттер, две ветки в `PreparePutBuffers`/`FetchPutBuffers` (§4.2). По умолчанию выключен -> `determinism_runner` и вся игра ведут себя байт-в-байт как раньше.
2. `CMakeLists.txt` - цель `gpf_runtime` (6 исходников + link на `${LIBRARIES}`) и цель GDExtension-DLL (§2.2). Это не игровая логика.
3. Больше **ничего**. Чтение состояния - через существующий публичный API (`GetNodeMap`, `GetBallGeom`, `GetGeomPosition`), никаких геттеров и рефакторингов не требуется.

Опционально (не в первый срез): `GpfMatch::SetScriptedInput(...)` и трассировка - тикет 02.

### Что не делать

- Не добавлять sim-thread, не запускать `Scheduler::Run`, не "упрощать" `Match`.
- Не вызывать `Put` реже/чаще, чем нужно для паритета: `Process` читает позу через AABB.
- Не выкидывать `UpdateIngameCamera` и `TriggerBallTouchSound` (RNG), не менять `audio_volume`.
- Не глушить `MenuTask`-объекты (они нужны конструкторам) - просто не вызывать их Process.
- Не использовать старые `build-x64` артефакты и не линковать вручную.
- Не делать teardown/повторный запуск/выгрузку DLL в первом срезе.

### Риски

| Риск | Вероятность | Митигация |
|---|---|---|
| `Match::Put()`/GUI-часть в headless ведёт себя иначе, чем в оконной игре | низкая (probe прошёл 500 put без исключений; GUI-объекты создаются в конструкторе) | первый срез: 22 капсулы + мяч, без костей; если что - `Put2D`/scoreboard можно временно обойти, но не `HumanoidBase::Put` |
| `exit(1)` из-за неполного `data/`/CWD/шрифта/БД | средняя | предварительная валидация путей в `_ready`, внятная ошибка Godot; полный `data/` из репозитория; `SetCurrentDirectoryW` |
| Падение при выгрузке DLL / `exit` | высокая, если пытаться | не выгружать, не выходить, перезапускать Godot |
| Расхождение с эталоном из-за каденции `Put` | высокая, если сравнивать со старым Process-only хешем | новый эталон с тем же контуром и фиксированной каденцией (тикет 02) |
| ABI/CRT/boost-макросы при сборке DLL | средняя | CMake из одного дерева, `/MD`, полный набор `BOOST_*_DYN_LINK`, только Release |
| Стоимость `PutPhase` (скининг + GUI) | низкая | 1.37 мс/put на этой машине; при необходимости позже измерить отключение `UpdateFullbodyModel` (он вне обратной связи) |
| `RefreshGamepads()` каждый тик в процессе Godot | низкая | входит в 1.4 мс; при желании - свой цикл из `Match`-методов вместо `ProcessPhase`, но это дублирование |
| Утечки/полу-сломанный teardown | высокая, но не влияет на первый срез | жить до конца процесса; не звать `Match::Exit`/`GameTask::Exit` |
