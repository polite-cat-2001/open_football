# 03: CPU-skinning pipeline (один игрок)

**What to build:** CPU-skinning в C++ — `HumanoidBase::UpdateFullbodyModel()` считает вертексы, пушит их в `RenderingServer`. Один игрок — `MeshInstance3D`, вертексы из C++. `AnimCollection::Load()` читает `.anim` файлы напрямую (293 штуки). На экране — один живой игрок на стадионе, анимируется (idle, run, sprint).

**Blocked by:** 01 (GDExtension skeleton + статический стадион)

**Status:** superseded — новая карта: [Перенос GameplayFootball в Godot](../../godot-port/map.md)

- [ ] `AnimCollection::Load()` читает все 293 `.anim` файла
- [ ] `HumanoidBase::UpdateFullbodyModel()` считает вертексы CPU-skinning
- [ ] Вертексы пушатся в `RenderingServer::mesh_surface_update_array_region()`
- [ ] Один игрок — `MeshInstance3D`, видим и анимирован
- [ ] Клипы: idle, run, sprint переключаются по скорости
- [ ] Текстуры тела и формы назначены (из `.png`/`.jpg`)
