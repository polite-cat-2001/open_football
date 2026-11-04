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
	_label(theme, &"SideTitle", _spaced_barlow(700, 3), UiTokens.SIZE_SIDE_TITLE,
		UiTokens.SIDE_HEAD_INK)
	_label(theme, &"SideName", _spaced_barlow(800, 4), UiTokens.SIZE_SIDE_NAME,
		UiTokens.SIDE_LABEL)
	_label(theme, &"SidePlayerName", inter(500), UiTokens.SIZE_SIDE_PLAYER, UiTokens.INK_2)
	theme.set_color(&"font_outline_color", &"SidePlayerName", UiTokens.FOCUS_INK)
	theme.set_constant(&"outline_size", &"SidePlayerName", UiTokens.SIDE_NAME_OUTLINE)
	_label(theme, &"SideStatus", inter(500), UiTokens.SIZE_SIDE_STATUS, UiTokens.LEGEND_INK)
	_label(theme, &"SideStatusError", inter(500), UiTokens.SIZE_SIDE_STATUS,
		UiTokens.ERROR_PINK)
	_label(theme, &"TeamCountry", barlow(700), UiTokens.SIZE_TEAM_COUNTRY, UiTokens.INK)
	_label(theme, &"TeamClub", barlow(800), UiTokens.SIZE_TEAM_CLUB, UiTokens.INK)
	_label(theme, &"TeamCompetition", barlow(700), UiTokens.SIZE_TEAM_COMPETITION,
		UiTokens.INK)
	_label(theme, &"TeamMark", _spaced_barlow(700, 2), UiTokens.SIZE_TEAM_MARK,
		UiTokens.FOCUS_INK)
	_label(theme, &"TeamMarkReady", _spaced_barlow(800, 3), UiTokens.SIZE_TEAM_MARK_READY,
		UiTokens.FOCUS_INK)
	_label(theme, &"TeamOwner", inter(500), UiTokens.SIZE_TEAM_OWNER, UiTokens.INK_2)
	_label(theme, &"TeamStatLabel", inter(600), UiTokens.SIZE_TEAM_STAT_LABEL,
		UiTokens.INK_2)
	_label(theme, &"TeamStatValue", barlow(700), UiTokens.SIZE_TEAM_STAT_VALUE,
		UiTokens.INK)
	_label(theme, &"KitTeam", _spaced_inter(600, 1), UiTokens.SIZE_KIT_TEAM, UiTokens.INK_2)
	_label(theme, &"KitCount", _spaced_barlow(600, 1), UiTokens.SIZE_KIT_COUNT,
		UiTokens.INK_2)
	_label(theme, &"KitName", barlow(800), UiTokens.SIZE_KIT_NAME, UiTokens.INK)
	_label(theme, &"KitReady", _spaced_barlow(800, 2), UiTokens.SIZE_KIT_READY,
		UiTokens.FOCUS_INK)
	_label(theme, &"KitPreviewTitle", _spaced_barlow(700, 2),
		UiTokens.SIZE_KIT_PREVIEW_TITLE, UiTokens.INK)
	_label(theme, &"KitPreviewSub", _spaced_inter(600, 1), UiTokens.SIZE_KIT_PREVIEW_SUB,
		UiTokens.INK_2)
	_label(theme, &"KitPreviewTeam", _spaced_barlow(700, 1),
		UiTokens.SIZE_KIT_PREVIEW_TEAM, UiTokens.INK)
	_label(theme, &"KitPreviewVs", _spaced_inter(600, 2), UiTokens.SIZE_KIT_PREVIEW_VS,
		UiTokens.INK_2)

	_button(theme, &"TabButton", barlow(700), UiTokens.SIZE_TAB)

	_panel(theme, &"KbdBox", _kbd_box())
	_panel(theme, &"SoonChip", _chip_box())
	_panel(theme, &"PanelNoteBox", _note_box())
	_panel(theme, &"SideHead", _side_head_box())

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
	return _spaced_barlow(800, 3)


static func _spaced_barlow(weight: int, spacing: int) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = barlow(weight)
	variation.spacing_glyph = spacing
	return variation


static func _spaced_inter(weight: int, spacing: int) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = inter(weight)
	variation.spacing_glyph = spacing
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


static func _side_head_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.SIDE_HEAD
	box.shadow_color = UiTokens.SHADOW
	box.shadow_size = 22
	box.shadow_offset = Vector2(0.0, 18.0)
	return box
