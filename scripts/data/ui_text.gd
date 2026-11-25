class_name UiText
extends RefCounted
# Flat text catalogue per locale: assets/data/locales/<language>.json. One key is
# one sentence; `{name}` placeholders are filled by the caller. A missing
# translation falls back to English, so a half-translated build still renders.

const PATH := "res://assets/data/locales/%s.json"
const FALLBACK := "en"

static var _catalogs: Dictionary = {}


static func locale() -> String:
	var current := TranslationServer.get_locale().replace("-", "_")
	var language := current.get_slice("_", 0).to_lower()
	return language if not language.is_empty() else FALLBACK


static func t(key: String, values: Dictionary = {}) -> String:
	var text := _lookup(locale(), key)
	if text.is_empty() and locale() != FALLBACK:
		text = _lookup(FALLBACK, key)
	if text.is_empty():
		push_warning("UiText: missing key %s (%s)" % [key, locale()])
		return key
	return text.format(values) if not values.is_empty() else text


static func _lookup(language: String, key: String) -> String:
	if not _catalogs.has(language):
		_catalogs[language] = {}
		var path := PATH % language
		if FileAccess.file_exists(path):
			var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
			if raw is Dictionary:
				_catalogs[language] = raw
	return str((_catalogs[language] as Dictionary).get(key, ""))
