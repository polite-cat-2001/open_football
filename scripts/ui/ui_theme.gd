class_name UiTheme
extends RefCounted

# Builds the UI Theme from UiTokens. The .tres is a generated artifact; keep
# this file as the editable source and re-run tools/build_ui_theme.gd after
# changing values.

const THEME_PATH := "res://assets/ui/theme/ui_theme.tres"

const BARLOW_PATHS := {
	600: "res://assets/ui/fonts/BarlowCondensed-SemiBold.ttf",
	700: "res://assets/ui/fonts/BarlowCondensed-Bold.ttf",
	800: "res://assets/ui/fonts/BarlowCondensed-ExtraBold.ttf",
}

static var _fonts: Dictionary = {}


static func load_or_build() -> Theme:
	if ResourceLoader.exists(THEME_PATH):
		var theme := load(THEME_PATH) as Theme
		if theme != null:
			return theme
	return build()


static func barlow(weight: int) -> Font:
	var key := "b%d" % weight
	if _fonts.has(key):
		return _fonts[key]
	var font := load(String(BARLOW_PATHS[weight])) as Font
	_fonts[key] = font
	return font


static func inter(weight: int) -> Font:
	var key := "i%d" % weight
	if _fonts.has(key):
		return _fonts[key]
	var base := load(UiTokens.FONT_INTER) as FontFile
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {"wght": weight}
	_fonts[key] = variation
	return variation


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = inter(400)
	theme.default_font_size = UiTokens.SIZE_PANEL_NOTE

	_label(theme, &"HeroTitle", barlow(800), UiTokens.SIZE_HERO_TITLE, UiTokens.INK)
	_label(theme, &"WideTitle", barlow(700), UiTokens.SIZE_WIDE_TITLE, UiTokens.INK)
	_label(theme, &"TileTitle", barlow(700), UiTokens.SIZE_TILE_TITLE, UiTokens.INK)
	_label(theme, &"TileSub", inter(500), UiTokens.SIZE_TILE_SUB, UiTokens.INK_2)
	_label(theme, &"TileSubWide", inter(500), UiTokens.SIZE_TILE_SUB_WIDE, UiTokens.INK_2)
	_label(theme, &"TileMeta", inter(600), UiTokens.SIZE_META, UiTokens.INK_2)
	_label(theme, &"MatchValue", barlow(700), UiTokens.SIZE_MATCH_VALUE, UiTokens.INK_2)
	_label(theme, &"LegendLabel", inter(500), UiTokens.SIZE_LEGEND, UiTokens.LEGEND_INK)
	_label(theme, &"Kbd", inter(600), UiTokens.SIZE_KBD, UiTokens.FOCUS_INK)
	_label(theme, &"Brand", _brand_font(), UiTokens.SIZE_BRAND, UiTokens.FOCUS_INK)
	_label(theme, &"BrandAccent", _brand_font(), UiTokens.SIZE_BRAND, UiTokens.FOCUS_MARK)
	_label(theme, &"RowTitle", barlow(700), UiTokens.SIZE_ROW_TITLE, UiTokens.INK)
	_label(theme, &"RowSub", inter(500), UiTokens.SIZE_ROW_SUB, UiTokens.INK_2)
	_label(theme, &"PanelNote", inter(400), UiTokens.SIZE_PANEL_NOTE, UiTokens.INK_2)
	_label(theme, &"Crumbs", barlow(600), UiTokens.SIZE_CRUMBS, Color(UiTokens.INK, 0.5))
	_label(theme, &"CrumbsCurrent", barlow(800), UiTokens.SIZE_CRUMBS, UiTokens.INK)
	_label(theme, &"SoonChipLabel", inter(600), UiTokens.SIZE_KBD, UiTokens.INK_2)

	_button(theme, &"TabButton", barlow(700), UiTokens.SIZE_TAB)

	_panel(theme, &"KbdBox", _kbd_box())
	_panel(theme, &"SoonChip", _chip_box())
	_panel(theme, &"PanelNoteBox", _note_box())

	return theme


static func _label(theme: Theme, type: StringName, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(type, &"Label")
	theme.set_font(&"font", type, font)
	theme.set_font_size(&"font_size", type, size)
	theme.set_color(&"font_color", type, color)


static func _button(theme: Theme, type: StringName, font: Font, size: int) -> void:
	theme.set_type_variation(type, &"Button")
	theme.set_font(&"font", type, font)
	theme.set_font_size(&"font_size", type, size)


static func _panel(theme: Theme, type: StringName, box: StyleBox) -> void:
	theme.set_type_variation(type, &"PanelContainer")
	theme.set_stylebox(&"panel", type, box)


static func _brand_font() -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = barlow(800)
	variation.spacing_glyph = 3
	return variation


static func _kbd_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.KBD_FILL
	box.border_color = UiTokens.KBD_BORDER
	box.set_border_width_all(1)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	return box


static func _chip_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.CHIP_FILL
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 3.0
	return box


static func _note_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.PANEL_NOTE
	box.content_margin_left = 24.0
	box.content_margin_right = 24.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	return box
