extends RefCounted
class_name SideSelectFixture


static func rows_1p() -> Array:
	return [
		{
			"id": "keyboard:0",
			"kind": "keyboard",
			"device": 0,
			"name": "",
			"side": -1,
			"ready": false,
			"local": true,
			"tone_index": 0,
		},
	]


static func rows_2p() -> Array:
	return [
		{
			"id": "keyboard:0",
			"kind": "keyboard",
			"device": 0,
			"name": "",
			"side": -1,
			"ready": false,
			"local": true,
			"tone_index": 0,
		},
		{
			"id": "gamepad:1",
			"kind": "gamepad",
			"device": 1,
			"name": "",
			"side": 0,
			"ready": false,
			"local": true,
			"tone_index": 1,
		},
	]


static func rows_ready() -> Array:
	return [
		{
			"id": "keyboard:0",
			"kind": "keyboard",
			"device": 0,
			"name": "",
			"side": -1,
			"ready": true,
			"local": true,
			"tone_index": 0,
		},
		{
			"id": "gamepad:1",
			"kind": "gamepad",
			"device": 1,
			"name": "",
			"side": 1,
			"ready": true,
			"local": true,
			"tone_index": 1,
		},
	]


static func rows_network() -> Array:
	return [
		{
			"id": "player:0",
			"kind": "keyboard",
			"device": 0,
			"name": "ALEX",
			"side": -1,
			"ready": true,
			"local": true,
			"tone_index": 0,
		},
		{
			"id": "player:1",
			"kind": "gamepad",
			"device": 1,
			"name": "MARIA",
			"side": 0,
			"ready": false,
			"local": false,
			"tone_index": 1,
		},
		{
			"id": "player:2",
			"kind": "gamepad",
			"device": 2,
			"name": "SAM",
			"side": 1,
			"ready": false,
			"local": false,
			"tone_index": 2,
		},
	]
