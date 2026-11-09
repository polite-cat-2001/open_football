class_name SettingsStore
extends RefCounted
# Persistent system settings (user://settings.cfg) and the bridge that hands
# them to the original C++ runtime. Ported from GameplayFootball's
# menu/settings.cpp; defaults are the C++ gamedefines.hpp values.

const CONFIG_PATH := "user://settings.cfg"

# The slice's keyboard bindings cover the 16 gameplay functions; select/start
# stay on the shell keys (Tab opens the set-piece taker menu, Enter is Start).
const KEY_FUNCTION_LABELS := [
	"walk north", "walk east", "walk south", "walk west",
	"through pass", "high pass", "normal pass", "shoot",
	"keeper to ball", "sliding", "pressure", "team pressure",
	"switch", "special", "sprint", "dribble",
]
const KEY_DEFAULTS := [
	KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT,
	KEY_W, KEY_A, KEY_S, KEY_D,
	KEY_W, KEY_A, KEY_S, KEY_D,
	KEY_Q, KEY_Z, KEY_E, KEY_C,
]

const GAMEPAD_BUTTON_LABELS := [
	"up", "right", "down", "left", "Y", "B", "A", "X",
	"L1", "L2", "R1", "R2", "select", "start",
]
# C++ encoding: >= 0 is a button index, negative is an axis half
# (-(2*axis+1) = negative half, -(2*axis+2) = positive half).
const GAMEPAD_BUTTON_DEFAULTS := [-3, -2, -4, -1, 3, 1, 0, 2, 9, -10, 10, -12, 4, 6]

const GAMEPAD_FUNCTION_LABELS := [
	"through pass", "high pass", "normal pass", "shoot",
	"keeper to ball", "sliding", "pressure", "team pressure",
	"switch", "special", "sprint", "dribble", "select", "start",
]
const GAMEPAD_FUNCTION_DEFAULTS := [4, 5, 6, 7, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]

const GAMEPLAY_DEFAULTS := {
	"shortpass_direction": 0.4,
	"shortpass_power": 0.7,
	"throughpass_direction": 0.2,
	"throughpass_power": 0.7,
	"highpass_direction": 0.2,
	"highpass_power": 0.5,
	"shot_direction": 0.74,
	"curl_spin": 0.3,
	"curl_aim": 0.3333,
	"agility": 0.5,
	"acceleration": 0.5,
	"quantization": 0.0,
}
const GAMEPLAY_KEYS := {
	"shortpass_direction": "gameplay_shortpass_autodirection",
	"shortpass_power": "gameplay_shortpass_autopower",
	"throughpass_direction": "gameplay_throughpass_autodirection",
	"throughpass_power": "gameplay_throughpass_autopower",
	"highpass_direction": "gameplay_highpass_autodirection",
	"highpass_power": "gameplay_highpass_autopower",
	"shot_direction": "gameplay_shot_autodirection",
	"curl_spin": "gameplay_shot_curlspin",
	"curl_aim": "gameplay_shot_curlaimout",
	"agility": "gameplay_agilityfactor",
	"acceleration": "gameplay_accelerationfactor",
	"quantization": "gameplay_quantizeddirectionbias",
}
# Slider range: curl values are stored as 0..1 in the file and scaled here.
const CURL_SPIN_MAX := 300.0
const CURL_AIM_MAX := 0.3

const CAMERA_DEFAULTS := {"zoom": 0.5, "height": 0.3, "fov": 0.4, "angle": 0.0}
const AUDIO_DEFAULT := 0.5

static var config_path := CONFIG_PATH
static var _config: ConfigFile = null
static var _gameplay: Dictionary = {}
static var _camera: Dictionary = {}
static var _audio := AUDIO_DEFAULT
static var _graphics: Dictionary = {}
static var _graphics_saved := false
static var _keys: Array = []
static var _gp_buttons: Array = []
static var _gp_functions: Array = []
static var _function_keys: Dictionary = {}


static func ensure_loaded() -> void:
	if _config != null:
		return
	_config = ConfigFile.new()
	_config.load(config_path)

	_gameplay = GAMEPLAY_DEFAULTS.duplicate(true)
	for key in GAMEPLAY_DEFAULTS:
		_gameplay[key] = clampf(float(_config.get_value("gameplay", key,
			GAMEPLAY_DEFAULTS[key])), 0.0, 1.0)

	_camera = CAMERA_DEFAULTS.duplicate(true)
	for key in CAMERA_DEFAULTS:
		_camera[key] = clampf(float(_config.get_value("camera", key,
			CAMERA_DEFAULTS[key])), 0.0, 1.0)

	_audio = clampf(float(_config.get_value("audio", "volume", AUDIO_DEFAULT)),
		0.0, 1.0)

	var size := DisplayServer.window_get_size()
	if size.x <= 0 or size.y <= 0:
		size = DisplayServer.screen_get_size()
	_graphics_saved = _config.has_section_key("graphics", "width")
	_graphics = {
		"width": int(_config.get_value("graphics", "width", size.x)),
		"height": int(_config.get_value("graphics", "height", size.y)),
		"fullscreen": bool(_config.get_value("graphics", "fullscreen",
			DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)),
	}
	if int(_graphics["width"]) <= 0 or int(_graphics["height"]) <= 0:
		_graphics["width"] = size.x
		_graphics["height"] = size.y
		_graphics_saved = false

	_keys = KEY_DEFAULTS.duplicate()
	for i in _keys.size():
		_keys[i] = int(_config.get_value("keyboard", str(i), KEY_DEFAULTS[i]))

	_gp_buttons = GAMEPAD_BUTTON_DEFAULTS.duplicate()
	for i in _gp_buttons.size():
		_gp_buttons[i] = int(_config.get_value("gamepad", "button%d" % i,
			GAMEPAD_BUTTON_DEFAULTS[i]))

	_gp_functions = GAMEPAD_FUNCTION_DEFAULTS.duplicate()
	for i in _gp_functions.size():
		_gp_functions[i] = int(_config.get_value("gamepad", "function%d" % i,
			GAMEPAD_FUNCTION_DEFAULTS[i]))
	_rebuild_function_keys()


static func reset_for_tests() -> void:
	_config = null
	_gameplay = {}
	_camera = {}
	_graphics = {}
	_graphics_saved = false
	_audio = AUDIO_DEFAULT
	_keys = []
	_gp_buttons = []
	_gp_functions = []
	_function_keys = {}
	config_path = CONFIG_PATH


static func save() -> void:
	ensure_loaded()
	# Headless checks must not overwrite the player's real settings.
	if DisplayServer.get_name() == "headless" and config_path == CONFIG_PATH:
		return
	for key in _gameplay:
		_config.set_value("gameplay", key, _gameplay[key])
	for key in _camera:
		_config.set_value("camera", key, _camera[key])
	_config.set_value("audio", "volume", _audio)
	for key in _graphics:
		_config.set_value("graphics", key, _graphics[key])
	for i in _keys.size():
		_config.set_value("keyboard", str(i), _keys[i])
	for i in _gp_buttons.size():
		_config.set_value("gamepad", "button%d" % i, _gp_buttons[i])
	for i in _gp_functions.size():
		_config.set_value("gamepad", "function%d" % i, _gp_functions[i])
	_config.save(config_path)


# Gameplay ---------------------------------------------------------------

static func gameplay() -> Dictionary:
	ensure_loaded()
	return _gameplay.duplicate(true)


# The runtime wants the real C++ values, not the 0..1 slider ratios.
static func gameplay_for_runtime() -> Dictionary:
	ensure_loaded()
	var values := _gameplay.duplicate(true)
	values["curl_spin"] = float(_gameplay["curl_spin"]) * CURL_SPIN_MAX
	values["curl_aim"] = float(_gameplay["curl_aim"]) * CURL_AIM_MAX
	var mapped := {}
	for key in values:
		mapped[String(GAMEPLAY_KEYS[key])] = float(values[key])
	return mapped


static func set_gameplay_value(key: String, value: float) -> void:
	ensure_loaded()
	if not _gameplay.has(key):
		return
	_gameplay[key] = clampf(value, 0.0, 1.0)


# Camera -----------------------------------------------------------------

static func camera() -> Dictionary:
	ensure_loaded()
	return _camera.duplicate(true)


static func set_camera_value(key: String, value: float) -> void:
	ensure_loaded()
	if _camera.has(key):
		_camera[key] = clampf(value, 0.0, 1.0)


# Audio / graphics -------------------------------------------------------

static func audio() -> float:
	ensure_loaded()
	return _audio


static func set_audio(value: float) -> void:
	ensure_loaded()
	_audio = clampf(value, 0.0, 1.0)
	apply_audio()


static func graphics() -> Dictionary:
	ensure_loaded()
	return _graphics.duplicate(true)


static func set_graphics(width: int, height: int, fullscreen: bool) -> void:
	ensure_loaded()
	_graphics = {"width": width, "height": height, "fullscreen": fullscreen}
	_graphics_saved = true


static func apply_audio() -> void:
	ensure_loaded()
	if DisplayServer.get_name() == "headless":
		return
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_audio, 0.001)))
	AudioServer.set_bus_mute(0, _audio <= 0.0)


static func apply_graphics() -> void:
	ensure_loaded()
	if not _graphics_saved or DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(_graphics["fullscreen"]) \
		else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	if not bool(_graphics["fullscreen"]):
		DisplayServer.window_set_size(Vector2i(int(_graphics["width"]),
			int(_graphics["height"])))


# Keyboard ---------------------------------------------------------------

static func key_for_function(index: int) -> int:
	ensure_loaded()
	return int(_keys[index]) if index >= 0 and index < _keys.size() else 0


static func key_name(index: int) -> String:
	var code := key_for_function(index)
	return OS.get_keycode_string(code) if code != 0 else "-"


static func set_key_for_function(index: int, keycode: int) -> void:
	ensure_loaded()
	if index < 0 or index >= _keys.size():
		return
	_keys[index] = keycode
	_rebuild_function_keys()


static func set_keys_for_defaults() -> void:
	ensure_loaded()
	_keys = KEY_DEFAULTS.duplicate()
	_rebuild_function_keys()


# keycode -> Array of function indices, the shape gpf_slice routes with.
static func functions_for_key(keycode: int) -> Array:
	ensure_loaded()
	return _function_keys.get(keycode, [])


static func _rebuild_function_keys() -> void:
	_function_keys = {}
	for index in _keys.size():
		var code := int(_keys[index])
		if not _function_keys.has(code):
			_function_keys[code] = []
		_function_keys[code].append(index)


# Gamepad ----------------------------------------------------------------

static func gamepad_buttons() -> Array:
	ensure_loaded()
	return _gp_buttons.duplicate()


static func gamepad_functions() -> Array:
	ensure_loaded()
	return _gp_functions.duplicate()


static func set_gamepad_buttons(values: Array) -> void:
	ensure_loaded()
	for i in mini(values.size(), _gp_buttons.size()):
		_gp_buttons[i] = int(values[i])


static func set_gamepad_buttons_at(index: int, value: int) -> void:
	ensure_loaded()
	if index >= 0 and index < _gp_buttons.size():
		_gp_buttons[index] = int(value)


static func set_gamepad_defaults() -> void:
	ensure_loaded()
	_gp_buttons = GAMEPAD_BUTTON_DEFAULTS.duplicate()
	_gp_functions = GAMEPAD_FUNCTION_DEFAULTS.duplicate()


static func set_gamepad_functions(values: Array) -> void:
	ensure_loaded()
	for i in mini(values.size(), _gp_functions.size()):
		_gp_functions[i] = int(values[i])


static func encode_button(button: int) -> int:
	return button


static func encode_axis(axis: int, positive: bool) -> int:
	return -(2 * axis + (2 if positive else 1))


static func controller_label(value: int) -> String:
	if value >= 0:
		return "B%d" % value
	var encoded := -value - 1
	return "A%d%s" % [encoded / 2, "+" if encoded % 2 == 1 else "-"]


static func gamepad_label(function_index: int) -> String:
	ensure_loaded()
	if function_index < 0 or function_index >= _gp_functions.size():
		return "-"
	return controller_label(int(_gp_functions[function_index]))


# Bridge -----------------------------------------------------------------

static func apply_to_runtime(runtime: Node) -> void:
	if runtime == null or not is_instance_valid(runtime):
		return
	ensure_loaded()
	if runtime.has_method("set_gameplay_settings"):
		runtime.set_gameplay_settings(gameplay_for_runtime())
	if runtime.has_method("set_camera_settings"):
		runtime.set_camera_settings(_camera)
	if runtime.has_method("set_gamepad_settings"):
		runtime.set_gamepad_settings({"buttons": _gp_buttons, "functions": _gp_functions})
	if runtime.has_method("set_audio_volume"):
		runtime.set_audio_volume(_audio)

