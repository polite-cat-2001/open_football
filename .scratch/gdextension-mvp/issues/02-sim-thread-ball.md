# 02: Sim thread + мяч

**What to build:** `MatchNode` при `_ready()` создаёт `Match*` (оригинальный `src/onthepitch/`) и запускает `boost::thread` на 100Hz. Мяч — `MeshInstance3D`, вертексы из C++ через `RenderingServer::mesh_surface_update_array_region()`. Физика мяча — оригинальный `ball.cpp` (drag, gravity, bounce). Camera3D следует за мячом (оригинальная логика `IngameCamera`). На экране — мяч катится по полю, камера следит.

**Blocked by:** 01 (GDExtension skeleton + статический стадион)

**Status:** superseded — новая карта: [Перенос GameplayFootball в Godot](../../godot-port/map.md)

- [ ] `boost::thread` запущен на 100Hz, `Match` тикает
- [ ] `TemporalSmoother` — мост между sim thread и Godot render thread
- [ ] Мяч — `MeshInstance3D`, вертексы обновляются из C++ каждый кадр
- [ ] Физика мяча: drag, gravity, bounce, ground friction — по оригиналу
- [ ] Camera3D следует за мячом (оригинальный `UpdateIngameCamera`)
- [ ] Мяч видно, он катится, камера за ним следит
