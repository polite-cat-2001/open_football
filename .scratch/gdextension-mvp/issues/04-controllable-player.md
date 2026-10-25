# 04: Один управляемый игрок

**What to build:** `IHIDevice`-адаптер поверх Godot Input — lock-free ring buffer: Godot пишет в `_input()`, sim thread читает в начале тика. Человек управляет одним игроком: бег (стрелки/left stick), пас (X/A), удар (D/gamepad-X), спринт (Shift/right trigger). Мяч реагирует на касания — дриблинг, пас, удар. На экране — управляемый игрок, мяч откликается на действия.

**Blocked by:** 02 (Sim thread + мяч), 03 (CPU-skinning pipeline)

**Status:** superseded — новая карта: [Перенос GameplayFootball в Godot](../../godot-port/map.md)

- [ ] `IHIDevice`-адаптер: Godot `Input` → lock-free ring buffer → sim thread
- [ ] Управление: бег (стрелки/left stick), пас, удар, спринт
- [ ] Игрок двигается по полю, камера следует
- [ ] Дриблинг: мяч ведётся за игроком (lead-follow)
- [ ] Пас: мяч летит к ближайшему партнёру (или в направлении стика)
- [ ] Удар: мяч летит в ворота с зарядом мощности
- [ ] Sprint: ускорение при удержании Shift/right trigger
