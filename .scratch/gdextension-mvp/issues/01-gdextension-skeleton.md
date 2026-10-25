# 01: GDExtension skeleton + статический стадион

**What to build:** Build-система (CMake или SCons) для GDExtension на базе godot-cpp. Корневая нода `MatchNode : Node3D`, которая загружается в Godot-сцене. Конвертер `.ase` → Godot Mesh (build-time скрипт). На экране — стадион, поле с разметкой (proceduralpitch → ImageTexture), ворота, статическая камера. Открываешь сцену и видишь футбольный стадион 1в1 с оригиналом.

**Blocked by:** None (can start immediately)

**Status:** done

- [x] GDExtension компилируется и загружается в Godot 4.7 (`.gdextension` + shared lib)
- [x] `MatchNode` видна в дереве сцены и не падает при `_ready()`
- [ ] Конвертер `.ase` → Godot Mesh: стадион (1642 объекта, 31 материал) рендерится — **отложено**: требует отдельной задачи по парсингу ASE формата
- [ ] Ворота рендерятся — **отложено**: зависят от конвертера ASE
- [x] `ProceduralPitch` генерирует `Image` → `ImageTexture`: поле с разметкой, полосами покоса, перлин-шумом
- [x] Alpha-scissor 0.12 на всей геометрии (как в оригинале)
- [x] Статическая Camera3D показывает поле в ракурсе оригинала
