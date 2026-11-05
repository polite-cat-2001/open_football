class_name NetworkSettings
extends RefCounted
# Persistent LAN form values. The original kept host/join values in config.ini;
# the shell keeps them separate in user://network.cfg, written after a
# successful host/connect (never on every keystroke).

const CONFIG_PATH := "user://network.cfg"

const DEFAULT_HOST_PORT := 27015
const DEFAULT_HOST_NAME := "Host"
const DEFAULT_JOIN_ADDRESS := "127.0.0.1"
const DEFAULT_JOIN_PORT := 27015
const DEFAULT_JOIN_NAME := "Player"

# Tests point this at a disposable file and restore it afterwards.
static var config_path := CONFIG_PATH


static func load_host() -> Dictionary:
	var config := _load()
	var port := int(config.get_value("host", "port", DEFAULT_HOST_PORT))
	if not NetworkValidation.is_valid_port(str(port)):
		port = DEFAULT_HOST_PORT
	var name := str(config.get_value("host", "name", DEFAULT_HOST_NAME)).strip_edges()
	if not NetworkValidation.is_valid_name(name):
		name = DEFAULT_HOST_NAME
	return {"port": port, "name": name}


static func save_host(port: int, name: String) -> bool:
	var config := _load()
	config.set_value("host", "port", str(port))
	config.set_value("host", "name", name)
	return _save(config)


static func load_join() -> Dictionary:
	var config := _load()
	var address := str(config.get_value("join", "address", DEFAULT_JOIN_ADDRESS)).strip_edges()
	if not NetworkValidation.is_valid_address(address):
		address = DEFAULT_JOIN_ADDRESS
	var port := int(config.get_value("join", "port", DEFAULT_JOIN_PORT))
	if not NetworkValidation.is_valid_port(str(port)):
		port = DEFAULT_JOIN_PORT
	var name := str(config.get_value("join", "name", DEFAULT_JOIN_NAME)).strip_edges()
	if not NetworkValidation.is_valid_name(name):
		name = DEFAULT_JOIN_NAME
	return {"address": address, "port": port, "name": name}


static func save_join(address: String, port: int, name: String) -> bool:
	var config := _load()
	config.set_value("join", "address", address)
	config.set_value("join", "port", str(port))
	config.set_value("join", "name", name)
	return _save(config)


static func reset() -> void:
	if FileAccess.file_exists(config_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))


static func _load() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(config_path)
	return config


static func _save(config: ConfigFile) -> bool:
	return config.save(config_path) == OK
