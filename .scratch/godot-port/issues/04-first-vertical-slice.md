# Первый вертикальный срез

**Labels:** `wayfinder:task`

**Blocked by:** [Оригинальный скиннинг в Godot](03-original-skinning-in-godot.md)

**Status:** done

**Resolution:** `gdextension/src/gpf_runtime_node.*` + `scenes/gpf_slice.tscn` + `scripts/match/gpf_slice.gd`. Оригинальный C++ runtime собран в GDExtension, один футболист отрисован через `Skeleton3D`, мяч через `gpf_ball.glb`, ввод идёт в `UserEventManager`, срез стартует открытую игру. Проверено headless и скриншотами: ведение, короткий пас, удар; позиции костей/скиннинг совпали с C++ (25 мкм). Кнопка **GPF Gameplay Slice** добавлена в меню. Осталось: настоящий кикофф, потиковая трасса, полный матч.
