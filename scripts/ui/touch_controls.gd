class_name TouchControls
extends Control
## On-screen controls: move left/right on the left, jump / attack / flare on the right.
## Feeds the same input actions as keyboard and gamepad, with real multi-touch.

const MARGIN := 56.0

# id -> {pos: Vector2, radius: float, action: String, label: String}
var _buttons: Dictionary = {}
var _finger_button: Dictionary = {}  # touch index -> button id
var _held: Dictionary = {}           # button id -> number of fingers


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout()
	get_viewport().size_changed.connect(_layout)
	visible = GameState.touch_visible()


func _layout() -> void:
	var s := get_viewport_rect().size
	_buttons = {
		"left": {"pos": Vector2(MARGIN + 70, s.y - MARGIN - 70), "radius": 62.0, "action": "move_left", "label": "<"},
		"right": {"pos": Vector2(MARGIN + 230, s.y - MARGIN - 70), "radius": 62.0, "action": "move_right", "label": ">"},
		"jump": {"pos": Vector2(s.x - MARGIN - 80, s.y - MARGIN - 80), "radius": 72.0, "action": "jump", "label": "JUMP"},
		"attack": {"pos": Vector2(s.x - MARGIN - 250, s.y - MARGIN - 60), "radius": 60.0, "action": "attack", "label": "SLASH"},
		"magic": {"pos": Vector2(s.x - MARGIN - 170, s.y - MARGIN - 215), "radius": 58.0, "action": "magic", "label": "FLARE"},
	}
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_assign(t.index, _hit(t.position))
		else:
			_assign(t.index, "")
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_assign(d.index, _hit(d.position))


func _hit(pos: Vector2) -> String:
	var best := ""
	var best_dist := INF
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		var dist := pos.distance_to(b["pos"])
		if dist <= float(b["radius"]) * 1.25 and dist < best_dist:
			best = id
			best_dist = dist
	return best


func _assign(finger: int, button_id: String) -> void:
	var current: String = _finger_button.get(finger, "")
	if current == button_id:
		return
	if current != "":
		_release(current)
	if button_id != "":
		_finger_button[finger] = button_id
		_press(button_id)
	else:
		_finger_button.erase(finger)
	queue_redraw()


func _press(id: String) -> void:
	_held[id] = int(_held.get(id, 0)) + 1
	if _held[id] == 1:
		Input.action_press(_buttons[id]["action"])


func _release(id: String) -> void:
	_held[id] = maxi(0, int(_held.get(id, 0)) - 1)
	if _held[id] == 0:
		Input.action_release(_buttons[id]["action"])


func release_all() -> void:
	_finger_button.clear()
	_held.clear()
	for id in _buttons:
		Input.action_release(_buttons[id]["action"])
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		var pos: Vector2 = b["pos"]
		var r: float = b["radius"]
		var down := int(_held.get(id, 0)) > 0
		draw_circle(pos, r, Color(1, 1, 1, 0.30 if down else 0.12))
		draw_arc(pos, r, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0)
		var label: String = b["label"]
		if label == "<":
			draw_colored_polygon(PackedVector2Array([pos + Vector2(-20, 0), pos + Vector2(14, -24), pos + Vector2(14, 24)]), Color(1, 1, 1, 0.8))
		elif label == ">":
			draw_colored_polygon(PackedVector2Array([pos + Vector2(20, 0), pos + Vector2(-14, -24), pos + Vector2(-14, 24)]), Color(1, 1, 1, 0.8))
		else:
			var size := 24 if r > 60.0 else 20
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			draw_string(font, pos + Vector2(-w * 0.5, size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.9))
