extends Node
## Global run state, input map registration and settings. Autoload: GameState.

signal shards_changed(total: int)
signal health_changed(current: int, maximum: int)
signal mana_changed(current: float, maximum: float)
signal toast(text: String)
signal level_completed

const LEVEL_PATH := "res://scenes/levels/lanternroot_hollow.tscn"
const MENU_PATH := "res://scenes/main_menu/main_menu.tscn"
const SETTINGS_PATH := "user://settings.cfg"

var max_health: int = 5
var health: int = 5
var max_mana: float = 100.0
var mana: float = 100.0
var shards: int = 0
var collected_ids: Array = []
var defeated_ids: Array = []
var checkpoint_ids: Array = []
var respawn_position: Vector2 = Vector2.ZERO
var has_respawn: bool = false
var level_done: bool = false

# Settings
var music_volume: float = 0.7
var sfx_volume: float = 0.9
var touch_mode: int = 0  # 0 = auto, 1 = always show, 2 = never show


func _ready() -> void:
	_register_inputs()
	load_settings()


func new_game() -> void:
	max_health = 5
	health = max_health
	max_mana = 100.0
	mana = max_mana
	shards = 0
	collected_ids.clear()
	defeated_ids.clear()
	checkpoint_ids.clear()
	respawn_position = Vector2.ZERO
	has_respawn = false
	level_done = false


func set_health(value: int) -> void:
	health = clampi(value, 0, max_health)
	health_changed.emit(health, max_health)


func set_mana(value: float) -> void:
	mana = clampf(value, 0.0, max_mana)
	mana_changed.emit(mana, max_mana)


func collect_shard(id: String) -> bool:
	if id in collected_ids:
		return false
	collected_ids.append(id)
	shards += 1
	shards_changed.emit(shards)
	return true


func set_checkpoint(id: String, pos: Vector2) -> void:
	if not (id in checkpoint_ids):
		checkpoint_ids.append(id)
	respawn_position = pos
	has_respawn = true


func touch_visible() -> bool:
	match touch_mode:
		1:
			return true
		2:
			return false
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


func to_dict() -> Dictionary:
	return {
		"version": 1,
		"max_health": max_health,
		"health": health,
		"max_mana": max_mana,
		"shards": shards,
		"collected_ids": collected_ids,
		"defeated_ids": defeated_ids,
		"checkpoint_ids": checkpoint_ids,
		"respawn": [respawn_position.x, respawn_position.y],
		"has_respawn": has_respawn,
	}


func from_dict(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != 1:
		return false
	for key in ["max_health", "health", "shards", "respawn", "collected_ids", "checkpoint_ids"]:
		if not d.has(key):
			return false
	var r: Variant = d["respawn"]
	if typeof(r) != TYPE_ARRAY or (r as Array).size() != 2:
		return false
	new_game()
	max_health = maxi(1, int(d["max_health"]))
	health = max_health  # always resume at full health from a checkpoint save
	max_mana = float(d.get("max_mana", 100.0))
	mana = max_mana
	shards = maxi(0, int(d["shards"]))
	collected_ids = (d["collected_ids"] as Array).duplicate()
	defeated_ids = (d.get("defeated_ids", []) as Array).duplicate()
	checkpoint_ids = (d["checkpoint_ids"] as Array).duplicate()
	respawn_position = Vector2(float(r[0]), float(r[1]))
	has_respawn = bool(d.get("has_respawn", false))
	return true


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("controls", "touch_mode", touch_mode)
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	touch_mode = clampi(int(cfg.get_value("controls", "touch_mode", touch_mode)), 0, 2)


# ---------------------------------------------------------------- input map

func _register_inputs() -> void:
	_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("jump", [KEY_SPACE, KEY_W, KEY_UP], [JOY_BUTTON_A], [])
	_action("attack", [KEY_J, KEY_X], [JOY_BUTTON_X], [])
	_action("magic", [KEY_K, KEY_C], [JOY_BUTTON_B], [])
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])


func _action(action_name: String, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name, 0.5)
	for k in keys:
		var ek := InputEventKey.new()
		ek.physical_keycode = k as Key
		InputMap.action_add_event(action_name, ek)
	for b in buttons:
		var eb := InputEventJoypadButton.new()
		eb.button_index = b as JoyButton
		InputMap.action_add_event(action_name, eb)
	for a in axes:
		var em := InputEventJoypadMotion.new()
		em.axis = a[0] as JoyAxis
		em.axis_value = a[1]
		InputMap.action_add_event(action_name, em)
