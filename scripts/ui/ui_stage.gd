class_name UiStage
extends Control
# Shared static backdrop: stadium photo + scrim (+ the dim layer used by resume
# overlays). It lives outside the screen's transition target, so it is never
# faded or scaled by UiTransition — only the content panel animates.

const STADIUM_TEXTURE := "res://assets/ui/menu/stadium.jpg"

@onready var photo: TextureRect = $Photo
@onready var scrim: ColorRect = $Scrim
@onready var overlay: ColorRect = $Overlay

var overlay_mode := false

var _texture_ready := false


func _ready() -> void:
	_setup_photo()
	_apply_overlay_mode()


func layout(view_size: Vector2) -> void:
	if not _texture_ready:
		_setup_photo()
	photo.position = -view_size * UiTokens.STAGE_PHOTO_INSET
	photo.size = view_size * UiTokens.STAGE_PHOTO_SCALE
	photo.pivot_offset = photo.size * 0.5
	overlay.position = Vector2.ZERO
	overlay.size = view_size
	scrim.position = Vector2.ZERO
	scrim.size = view_size


func set_overlay_mode(enabled: bool) -> void:
	overlay_mode = enabled
	_apply_overlay_mode()


func _setup_photo() -> void:
	if photo == null:
		return
	photo.texture = load(STADIUM_TEXTURE)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_texture_ready = true


func _apply_overlay_mode() -> void:
	if photo == null:
		return
	photo.visible = not overlay_mode
	scrim.visible = not overlay_mode
	overlay.visible = overlay_mode
