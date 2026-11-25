extends Control
# Shared presentation for the in-match banners: the shell's fade+scale
# (150 ms in, 240 ms out) lives here once, so the goal/event banner and the
# pre-kickoff scoreboard cannot drift apart.

const IN_TIME := 0.15
const OUT_TIME := 0.24

var _tween: Tween
var _presented := false


func is_presented() -> bool:
	return _presented


func present(on: bool) -> void:
	if on == _presented:
		return
	_presented = on
	if _tween != null:
		_tween.kill()
	if on:
		visible = true
		modulate.a = 0.0
		pivot_offset = size * 0.5
		scale = Vector2(0.96, 0.96)
		_tween = create_tween().set_parallel()
		_tween.tween_property(self, "modulate:a", 1.0, IN_TIME)
		_tween.tween_property(self, "scale", Vector2.ONE, IN_TIME)
	else:
		_tween = create_tween().set_parallel()
		_tween.tween_property(self, "modulate:a", 0.0, OUT_TIME)
		_tween.tween_property(self, "scale", Vector2(0.97, 0.97), OUT_TIME)
		_tween.chain().tween_callback(func() -> void: visible = false)
