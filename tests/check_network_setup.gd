extends SceneTree
# Pure checks for LAN form validation/filtering and the user://network.cfg
# persistence seam. No runtime, no UI.
#
# Run:  godot --headless --path . -s res://tests/check_network_setup.gd

const TEST_CONFIG := "user://network_settings_test.cfg"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _run() -> void:
	_check_ports()
	_check_addresses()
	_check_names()
	_check_filters()
	_check_persistence()
	if failures.is_empty():
		print("== check_network_setup: PASS ==")
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		print("== check_network_setup: FAIL ==")
	quit(0 if failures.is_empty() else 1)


func _check_ports() -> void:
	for value in ["1", "27015", "65535"]:
		_check(NetworkValidation.is_valid_port(value), "valid port " + value)
	for value in ["", "0", "65536", "00000", "-1", "12a", "123456", " 27015 "]:
		_check(not NetworkValidation.is_valid_port(value), "invalid port " + value)


func _check_addresses() -> void:
	for value in ["127.0.0.1", "0.0.0.0", "255.255.255.255", "localhost",
			"my-host.example.com", "host_room"]:
		if value == "host_room":
			continue
		_check(NetworkValidation.is_valid_address(value), "valid address " + value)
	for value in ["", "256.1.1.1", "1.2.3", "1.2.3.4.5", "bad host", "-bad.com",
			"bad-.com", "host_room", "a..b", "a".repeat(65) + ".com"]:
		_check(not NetworkValidation.is_valid_address(value), "invalid address " + value)


func _check_names() -> void:
	for value in ["Host", "UI Host", "Player_1", " Egor "]:
		_check(NetworkValidation.is_valid_name(value), "valid name " + value)
	for value in ["", "   ", "bad!", "Player-1", "12345678901234567"]:
		_check(not NetworkValidation.is_valid_name(value), "invalid name " + value)


func _check_filters() -> void:
	_check(NetworkValidation.filter("12a3b", "port") == "123", "port filter keeps digits")
	_check(NetworkValidation.filter("a b_c!", "name") == "a b_c", "name filter keeps space/_")
	_check(NetworkValidation.filter("my host_1.", "address") == "myhost1.",
		"address filter keeps dot but drops space/_")
	_check(NetworkValidation.filter("123456789012345678901", "name").length()
		== NetworkValidation.NAME_MAX, "name filter truncates")
	_check(NetworkValidation.filter("123456789", "port").length() == 5,
		"port filter truncates")


func _check_persistence() -> void:
	NetworkSettings.config_path = TEST_CONFIG
	NetworkSettings.reset()
	var host := NetworkSettings.load_host()
	_check(int(host["port"]) == NetworkSettings.DEFAULT_HOST_PORT, "host defaults to port")
	_check(str(host["name"]) == NetworkSettings.DEFAULT_HOST_NAME, "host defaults to name")
	var join := NetworkSettings.load_join()
	_check(str(join["address"]) == NetworkSettings.DEFAULT_JOIN_ADDRESS,
		"join defaults to address")
	_check(int(join["port"]) == NetworkSettings.DEFAULT_JOIN_PORT, "join defaults to port")
	_check(str(join["name"]) == NetworkSettings.DEFAULT_JOIN_NAME, "join defaults to name")

	_check(NetworkSettings.save_host(28151, "UI Host"), "host config saves")
	_check(NetworkSettings.save_join("192.168.1.7", 28200, "Guest 1"), "join config saves")
	host = NetworkSettings.load_host()
	join = NetworkSettings.load_join()
	_check(int(host["port"]) == 28151 and str(host["name"]) == "UI Host",
		"host values round-trip")
	_check(str(join["address"]) == "192.168.1.7" and int(join["port"]) == 28200
		and str(join["name"]) == "Guest 1", "join values round-trip")
	_check(NetworkSettings.save_host(28152, "Other"), "host rewrite saves")
	_check(int(NetworkSettings.load_host()["port"]) == 28152, "host value updates")
	_check(str(NetworkSettings.load_join()["address"]) == "192.168.1.7",
		"rewriting host preserves join values")

	var file := FileAccess.open(TEST_CONFIG, FileAccess.WRITE)
	if file != null:
		file.store_string("[host]\nport=\"nope\"\nname=\"bad!\"\n")
		file.close()
	host = NetworkSettings.load_host()
	join = NetworkSettings.load_join()
	_check(int(host["port"]) == NetworkSettings.DEFAULT_HOST_PORT,
		"invalid config values fall back to defaults")
	_check(str(host["name"]) == NetworkSettings.DEFAULT_HOST_NAME,
		"invalid config name falls back to the default")
	_check(str(join["address"]) == NetworkSettings.DEFAULT_JOIN_ADDRESS,
		"an invalid host section keeps join defaults")


	NetworkSettings.reset()
	_check(not FileAccess.file_exists(TEST_CONFIG), "reset removes the test config")
	NetworkSettings.config_path = NetworkSettings.CONFIG_PATH

