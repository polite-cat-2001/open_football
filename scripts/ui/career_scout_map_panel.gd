class_name CareerScoutMapPanel
extends Control
# Prototype career/scouting/ScoutMapPanel.svelte: the two steps of setting up a
# network — pick a region on the dotted world map, then a country — with the
# side list (the region's countries, or the country's leagues), the assigned
# scout card and the NEXT/ASSIGN action.
#
# The host owns the state; this panel reports focus/selection and rebuilds only
# when the step or the highlighted region changes.

signal region_focused(id: String)
signal region_selected(id: String)
signal country_focused(id: String)
signal country_selected(id: String)
signal next_requested

const GAP := 10.0
const PAD := 16.0
const ROW_H := 42.0
const HEAD_H := 40.0
const MINI_H := 128.0
const NEXT_H := 48.0
const DOT := 22.0
const FLAG_W := 34.0
const FLAG_H := 24.0


# The dotted map background.
class Surface extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(UiTokens.INK, 0.045), true)
		var color := Color(UiTokens.INK, 0.20)
		var y := 12.0
		while y < size.y:
			var x := 12.0
			while x < size.x:
				draw_rect(Rect2(x, y, 2.0, 2.0), color, true)
				x += 24.0
			y += 24.0


# A node on the map: a dot tile for regions, a flag tile for countries. The
# name plate under the tile appears on focus, like the prototype's hover label.
class MapNode extends Button:
	var id := ""
	var _bg: Panel
	var _dot: ColorRect
	var _flag: TextureRect
	var _label: Label
	var _normal: StyleBoxFlat
	var _focus: StyleBoxFlat

	func _ready() -> void:
		flat = true
		text = ""
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_normal = StyleBoxFlat.new()
		_normal.bg_color = UiTokens.TILE
		_normal.shadow_color = UiTokens.SHADOW
		_normal.shadow_size = 12
		_normal.anti_aliasing = true
		_focus = StyleBoxFlat.new()
		_focus.bg_color = UiTokens.FOCUS_FILL
		_focus.shadow_color = UiTokens.SHADOW_SELECTED
		_focus.shadow_size = 12
		_focus.anti_aliasing = true
		_bg = Panel.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		_dot = ColorRect.new()
		_dot.color = UiTokens.INK_2
		_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_dot)
		_flag = TextureRect.new()
		_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flag.visible = false
		add_child(_flag)
		_label = Label.new()
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_override(&"font", UiTheme.inter(600))
		_label.add_theme_font_size_override(&"font_size", 14)
		_label.visible = false
		add_child(_label)
		resized.connect(_layout_content)
		focus_entered.connect(_apply_state)
		focus_exited.connect(_apply_state)
		mouse_entered.connect(grab_focus)
		_apply_state()

	func setup(node_id: String, flag_texture: Texture2D, label_text: String) -> void:
		id = node_id
		_label.text = label_text
		if flag_texture != null:
			_flag.texture = flag_texture
			_flag.visible = true
			_dot.visible = false
			custom_minimum_size = Vector2(FLAG_W, FLAG_H)
		else:
			custom_minimum_size = Vector2(DOT, DOT)
		size = custom_minimum_size
		_layout_content()

	func _layout_content() -> void:
		_bg.position = Vector2.ZERO
		_bg.size = size
		_dot.position = ((size - Vector2(10.0, 10.0)) * 0.5).floor()
		_dot.size = Vector2(10.0, 10.0)
		_flag.position = Vector2.ZERO
		_flag.size = size
		var font := _label.get_theme_font(&"font")
		var width := font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_label.size = Vector2(width + 12.0, 20.0)
		_label.position = Vector2((size.x - _label.size.x) * 0.5, size.y + 4.0)

	func _apply_state() -> void:
		if _bg == null:
			return
		var focused := has_focus()
		_bg.add_theme_stylebox_override(&"panel", _focus if focused else _normal)
		_dot.color = UiTokens.RAIL if focused else UiTokens.INK_2
		_label.visible = focused
		_label.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK if focused else UiTokens.INK)


# One row of the right-hand list (a country with its flag, or a league name).
class SideRow extends Button:
	var id := ""
	var _bg: Panel
	var _flag: TextureRect
	var _label: Label
	var _normal: StyleBoxFlat
	var _focus: StyleBoxFlat

	func _ready() -> void:
		flat = true
		text = ""
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_normal = StyleBoxFlat.new()
		_normal.bg_color = Color(UiTokens.INK, 0.05)
		_normal.anti_aliasing = true
		_focus = StyleBoxFlat.new()
		_focus.bg_color = UiTokens.FOCUS_FILL
		_focus.anti_aliasing = true
		_bg = Panel.new()
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		_flag = TextureRect.new()
		_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_flag.custom_minimum_size = Vector2(FLAG_W, FLAG_H)
		_flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_flag)
		_label = Label.new()
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.clip_text = true
		_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_override(&"font", UiTheme.inter(600))
		_label.add_theme_font_size_override(&"font_size", 16)
		add_child(_label)
		resized.connect(_layout_content)
		focus_entered.connect(_apply_state)
		focus_exited.connect(_apply_state)
		mouse_entered.connect(grab_focus)
		_apply_state()

	func setup(row_id: String, flag_texture: Texture2D, label_text: String) -> void:
		id = row_id
		_label.text = label_text
		_flag.texture = flag_texture
		_flag.visible = flag_texture != null
		_layout_content()
		_apply_state()

	func _layout_content() -> void:
		_bg.position = Vector2.ZERO
		_bg.size = size
		var x := 10.0
		if _flag.visible:
			_flag.position = Vector2(x, (size.y - FLAG_H) * 0.5)
			_flag.size = Vector2(FLAG_W, FLAG_H)
			x += FLAG_W + 10.0
		_label.position = Vector2(x, 0.0)
		_label.size = Vector2(maxf(0.0, size.x - x - 10.0), size.y)

	func _apply_state() -> void:
		if _bg == null:
			return
		var focused := has_focus()
		_bg.add_theme_stylebox_override(&"panel", _focus if focused else _normal)
		_label.add_theme_color_override(&"font_color",
			UiTokens.FOCUS_INK if focused else UiTokens.INK)


var _step := "region"
var _regions: Array = []
var _region: Dictionary = {}
var _country: Dictionary = {}
var _networks: Array = []
var _scouts: Array = []
var _assign_id := ""
var _leagues: Array = []
var _built_step := ""
var _built_region := ""

var _panel: Panel
var _head_title: Label
var _head_sub: Label
var _map: Surface
var _nodes: Array[MapNode] = []
var _region_label: Label
var _side: Control
var _list_panel: Panel
var _list_title: Label
var _list_scroll: ScrollContainer
var _list_box: VBoxContainer
var _mini: Panel
var _mini_flag: TextureRect
var _mini_name: Label
var _mini_country: Label
var _mini_exp: Label
var _mini_judge: Label
var _next: CareerScoutTaskPanel.ActionButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	resized.connect(_layout)
	call_deferred("_layout")


func setup(step: String, regions: Array, region: Dictionary, country: Dictionary,
		networks: Array, scouts: Array, assign_scout_id: String,
		leagues: Array = []) -> void:
	_step = step
	_regions = regions
	_region = region
	_country = country
	_networks = networks
	_scouts = scouts
	_assign_id = assign_scout_id
	_leagues = leagues
	if _panel == null:
		return
	# Rebuild only when the node set actually changes: focusing a region or a
	# country only refills the side list, so the focused node survives.
	var region_id := str(region.get("id", ""))
	var same := _built_step == step and not _nodes.is_empty() \
		and (step == "region" or _built_region == region_id)
	if not same:
		_build_nodes()
		_built_step = step
		_built_region = region_id
	select(region, country)
	_layout()


# Restyles the current selection and refills the side list.
func select(region: Dictionary, country: Dictionary) -> void:
	_region = region
	_country = country
	_head_title.text = str(region.get("name", "")).to_upper() \
		if _step == "country" else "SELECT REGION"
	_head_sub.text = "CHOOSE A COUNTRY TO SET UP THE NETWORK" if _step == "country" \
		else "PICK A REGION ON THE MAP TO SCAN"
	_region_label.visible = _step == "country"
	_region_label.text = str(region.get("name", "")).to_upper()
	_refresh_list()
	_refresh_mini()
	_next.set_copy("NEXT" if _step == "region" else "SET UP NETWORK")
	_layout_nodes()


func map_nodes() -> Array[Control]:
	var result: Array[Control] = []
	for node in _nodes:
		result.append(node)
	return result


func side_rows() -> Array[Control]:
	var result: Array[Control] = []
	for child in _list_box.get_children():
		if child is SideRow:
			result.append(child as Control)
	return result


func next_button() -> Button:
	return _next


func step() -> String:
	return _step


func _build() -> void:
	_panel = Panel.new()
	_panel.name = "Map"
	var box := StyleBoxFlat.new()
	box.bg_color = UiTokens.TILE
	box.shadow_color = UiTokens.SHADOW
	box.shadow_size = 32
	box.shadow_offset = Vector2(0.0, 24.0)
	_panel.add_theme_stylebox_override(&"panel", box)
	add_child(_panel)

	_head_title = _label(UiTheme.barlow(700), 24)
	_head_title.text = "SELECT REGION"
	_panel.add_child(_head_title)
	_head_sub = _label(UiTheme.inter(500), 16)
	_head_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_head_sub.add_theme_color_override(&"font_color", UiTokens.INK_2)
	_panel.add_child(_head_sub)

	_map = Surface.new()
	_map.name = "Surface"
	_map.clip_contents = true
	_panel.add_child(_map)
	_region_label = _label(UiTheme.barlow(700), 22)
	_region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_label.add_theme_color_override(&"font_color", Color(UiTokens.INK, 0.12))
	_region_label.visible = false
	_map.add_child(_region_label)

	_side = Control.new()
	_side.name = "Side"
	add_child(_side)
	_list_panel = Panel.new()
	_list_panel.add_theme_stylebox_override(&"panel", box.duplicate())
	_side.add_child(_list_panel)
	_list_title = _label(UiTheme.barlow(700), 20)
	_list_title.add_theme_color_override(&"font_color", UiTokens.INK_2)
	_list_panel.add_child(_list_title)
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_panel.add_child(_list_scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override(&"separation", 2)
	_list_scroll.add_child(_list_box)

	_mini = Panel.new()
	_mini.add_theme_stylebox_override(&"panel", box.duplicate())
	_side.add_child(_mini)
	_mini_flag = TextureRect.new()
	_mini_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mini_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mini.add_child(_mini_flag)
	_mini_name = _label(UiTheme.barlow(700), 22)
	_mini_name.clip_text = true
	_mini.add_child(_mini_name)
	_mini_country = _label(UiTheme.inter(500), 16)
	_mini_country.add_theme_color_override(&"font_color", UiTokens.INK_2)
	_mini.add_child(_mini_country)
	_mini_exp = _label(UiTheme.inter(500), 16)
	_mini.add_child(_mini_exp)
	_mini_judge = _label(UiTheme.inter(500), 16)
	_mini.add_child(_mini_judge)

	_next = CareerScoutTaskPanel.ActionButton.new()
	_next.custom_minimum_size.y = NEXT_H
	_next.pressed.connect(func() -> void: next_requested.emit())
	_side.add_child(_next)


func _label(font: Font, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", UiTokens.INK)
	return label


func _build_nodes() -> void:
	for node in _nodes:
		node.queue_free()
	_nodes.clear()
	if _step == "region":
		var locked := {}
		for entry in _networks:
			if entry is Dictionary:
				locked[str((entry as Dictionary).get("region_id", ""))] = true
		for region in _regions:
			if not (region is Dictionary):
				continue
			var data: Dictionary = region
			var node := MapNode.new()
			node.name = "Region_" + str(data.get("id", ""))
			_map.add_child(node)
			node.setup(str(data.get("id", "")), null, str(data.get("name", "")))
			node.modulate.a = 0.55 if locked.has(str(data.get("id", ""))) else 1.0
			node.pressed.connect(func() -> void: region_selected.emit(node.id))
			node.focus_entered.connect(func() -> void: region_focused.emit(node.id))
			_nodes.append(node)
	else:
		var countries: Array = _region.get("countries", []) \
			if _region.get("countries") is Array else []
		for index in countries.size():
			var data: Dictionary = countries[index]
			var node := MapNode.new()
			node.name = "Country_" + str(data.get("id", ""))
			_map.add_child(node)
			node.setup(str(data.get("id", "")),
				UiAssets.usable_texture(UiAssets.country_flag({"tm_id": str(data.get("id", ""))})),
				str(data.get("name", "")))
			node.pressed.connect(func() -> void: country_selected.emit(node.id))
			node.focus_entered.connect(func() -> void: country_focused.emit(node.id))
			_nodes.append(node)
	_layout_nodes()


func _refresh_list() -> void:
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()
	_list_title.text = str(_region.get("name", "")).to_upper() \
		if _step == "region" else str(_country.get("name", "")).to_upper()
	if _step == "region":
		var countries: Array = _region.get("countries", []) \
			if _region.get("countries") is Array else []
		for country in countries:
			if not (country is Dictionary):
				continue
			var data: Dictionary = country
			var row := SideRow.new()
			row.custom_minimum_size.y = ROW_H
			_list_box.add_child(row)
			row.setup(str(data.get("id", "")),
				UiAssets.usable_texture(UiAssets.country_flag({"tm_id": str(data.get("id", ""))})),
				str(data.get("name", "")))
			row.pressed.connect(func() -> void: country_selected.emit(row.id))
	else:
		for league in _leagues:
			if not (league is Dictionary):
				continue
			var label := _label(UiTheme.inter(500), 16)
			label.text = str((league as Dictionary).get("name", ""))
			label.custom_minimum_size.y = ROW_H
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_list_box.add_child(label)


func _refresh_mini() -> void:
	var scout: Dictionary = {}
	for item in _scouts:
		if item is Dictionary and str((item as Dictionary).get("id", "")) == _assign_id:
			scout = item
			break
	_mini_flag.texture = null if scout.is_empty() else CareerScoutCard.flag_texture(scout)
	_mini_flag.visible = _mini_flag.texture != null
	_mini_name.text = str(scout.get("name", "")).to_upper()
	_mini_country.text = str(scout.get("nationality", ""))
	_mini_exp.text = "EXPERIENCE %d / 5" % int(scout.get("experience", 0))
	_mini_judge.text = "JUDGEMENT %d / 5" % int(scout.get("judgement", 0))


# Layout ---------------------------------------------------------------------

func _layout() -> void:
	if _panel == null or size.x <= 0.0:
		return
	var left_w := floorf((size.x - GAP) * 1.58 / 2.36)
	var right_w := maxf(0.0, size.x - left_w - GAP)
	_panel.position = Vector2.ZERO
	_panel.size = Vector2(left_w, size.y)
	_side.position = Vector2(left_w + GAP, 0.0)
	_side.size = Vector2(right_w, size.y)
	var inner := maxf(0.0, left_w - PAD * 2.0)
	_head_title.position = Vector2(PAD, 8.0)
	_head_title.size = Vector2(inner, 28.0)
	_head_sub.position = Vector2(PAD, 34.0)
	_head_sub.size = Vector2(inner, 20.0)
	var map_top := PAD + HEAD_H + GAP
	_map.position = Vector2(PAD, map_top)
	_map.size = Vector2(inner, maxf(80.0, size.y - map_top - PAD))
	if _region_label.visible:
		_region_label.position = Vector2(0.0, float(_region.get("y", 50)) * 0.01
			* _map.size.y - 15.0)
		_region_label.size = Vector2(_map.size.x, 30.0)

	var list_h := maxf(120.0, size.y - MINI_H - NEXT_H - GAP * 2.0)
	_list_panel.position = Vector2.ZERO
	_list_panel.size = Vector2(right_w, list_h)
	_list_title.position = Vector2(PAD, 8.0)
	_list_title.size = Vector2(maxf(0.0, right_w - PAD * 2.0), 24.0)
	_list_scroll.position = Vector2(8.0, 38.0)
	_list_scroll.size = Vector2(maxf(0.0, right_w - 16.0), maxf(0.0, list_h - 46.0))
	_mini.position = Vector2(0.0, list_h + GAP)
	_mini.size = Vector2(right_w, MINI_H)
	_mini_flag.position = Vector2(PAD, 12.0)
	_mini_flag.size = Vector2(40.0, 26.0)
	_mini_name.position = Vector2(PAD + 52.0, 10.0)
	_mini_name.size = Vector2(maxf(0.0, right_w - PAD - 52.0), 24.0)
	_mini_country.position = Vector2(PAD + 52.0, 34.0)
	_mini_country.size = Vector2(maxf(0.0, right_w - PAD - 52.0), 20.0)
	_mini_exp.position = Vector2(PAD, 66.0)
	_mini_exp.size = Vector2(maxf(0.0, right_w - PAD * 2.0), 20.0)
	_mini_judge.position = Vector2(PAD, 88.0)
	_mini_judge.size = Vector2(maxf(0.0, right_w - PAD * 2.0), 20.0)
	_next.position = Vector2(0.0, size.y - NEXT_H)
	_next.size = Vector2(right_w, NEXT_H)
	_layout_nodes()


func _layout_nodes() -> void:
	if _map == null or _map.size.x <= 0.0:
		return
	if _step == "region":
		for node in _nodes:
			var region: Dictionary = {}
			for item in _regions:
				if item is Dictionary and str((item as Dictionary).get("id", "")) == node.id:
					region = item
					break
			node.position = Vector2(
				float(region.get("x", 50)) * 0.01 * _map.size.x,
				float(region.get("y", 50)) * 0.01 * _map.size.y) - node.size * 0.5
	else:
		for index in _nodes.size():
			var point := country_position(index)
			_nodes[index].position = Vector2(
				point.x * 0.01 * _map.size.x, point.y * 0.01 * _map.size.y) \
				- _nodes[index].size * 0.5


# The prototype's three rings of country nodes around the region label.
static func country_position(index: int) -> Vector2:
	var rings := [[8, 19.0], [12, 32.0], [12, 43.0]]
	var rest := index
	var size := 8
	var radius := 19.0
	for ring in rings:
		if rest < int(ring[0]):
			size = int(ring[0])
			radius = float(ring[1])
			break
		rest -= int(ring[0])
	var angle := TAU * float(rest) / float(maxi(1, size)) - PI * 0.5
	return Vector2(50.0 + cos(angle) * radius, 50.0 + sin(angle) * radius)
