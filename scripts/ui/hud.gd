class_name Hud
extends CanvasLayer
## In-game HUD: hearts, light (mana) bar, shard counter, toast hints, pause button, victory panel.

signal pause_pressed
signal menu_pressed

var _root: Control
var _canvas: Control
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _victory_layer: CenterContainer
var _victory_stats: Label
var _health: int = 5
var _max_health: int = 5
var _mana: float = 100.0
var _max_mana: float = 100.0
var _shards: int = 0
var _heart: PackedVector2Array


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_heart = _make_heart(1.0)

	_root = Control.new()
	_root.theme = UiTheme.make()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	_root.add_child(_canvas)

	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.custom_minimum_size = Vector2(76, 76)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.offset_left = -96
	pause_btn.offset_right = -20
	pause_btn.offset_top = 20
	pause_btn.offset_bottom = 96
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	_root.add_child(pause_btn)

	_toast_panel = PanelContainer.new()
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.offset_left = -380
	_toast_panel.offset_right = 380
	_toast_panel.offset_top = 24
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	_toast_label = Label.new()
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 24)
	_toast_panel.add_child(_toast_label)
	_root.add_child(_toast_panel)

	_build_victory()

	_health = GameState.health
	_max_health = GameState.max_health
	_mana = GameState.mana
	_max_mana = GameState.max_mana
	_shards = GameState.shards
	GameState.health_changed.connect(_on_health)
	GameState.mana_changed.connect(_on_mana)
	GameState.shards_changed.connect(_on_shards)
	GameState.toast.connect(show_toast)
	_canvas.queue_redraw()


func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.8)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(_toast_panel.hide)


func show_victory(shard_count: int) -> void:
	_victory_stats.text = "Glimmer Shards: %d\nThe Hollow is quiet. For now." % shard_count
	_victory_layer.visible = true


func _build_victory() -> void:
	_victory_layer = CenterContainer.new()
	_victory_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_layer.visible = false
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	var title := Label.new()
	title.text = "The Sun Sigil is yours"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", UiTheme.AMBER)
	_victory_stats = Label.new()
	_victory_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btn := Button.new()
	btn.text = "Main Menu"
	btn.pressed.connect(func() -> void: menu_pressed.emit())
	box.add_child(title)
	box.add_child(_victory_stats)
	box.add_child(btn)
	panel.add_child(box)
	_victory_layer.add_child(panel)
	_root.add_child(_victory_layer)


func _on_health(current: int, maximum: int) -> void:
	_health = current
	_max_health = maximum
	_canvas.queue_redraw()


func _on_mana(current: float, maximum: float) -> void:
	_mana = current
	_max_mana = maximum
	_canvas.queue_redraw()


func _on_shards(total: int) -> void:
	_shards = total
	_canvas.queue_redraw()


func _make_heart(scale_factor: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 28
	for i in steps:
		var t := TAU * float(i) / float(steps)
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(Vector2(x, y) * scale_factor)
	return pts


func _draw_hud() -> void:
	for i in _max_health:
		var c := Vector2(40 + i * 44, 40)
		var pts := PackedVector2Array()
		for p in _heart:
			pts.append(p + c)
		var full := i < _health
		_canvas.draw_colored_polygon(pts, Color("e8504a") if full else Color(0.15, 0.2, 0.22, 0.85))
		pts.append(pts[0])
		_canvas.draw_polyline(pts, Color("fff3e0") if full else Color("3a4a4e"), 2.0)

	var bar := Rect2(22, 74, 230, 16)
	_canvas.draw_rect(bar, Color(0.05, 0.1, 0.12, 0.85))
	var ratio := clampf(_mana / maxf(_max_mana, 1.0), 0.0, 1.0)
	var fill_col := Color("ffd27a") if _mana >= 25.0 else Color("a8802f")
	_canvas.draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * ratio, bar.size.y - 4)), fill_col)
	_canvas.draw_rect(bar, Color("a8802f"), false, 2.0)
	# marker where one Flare costs
	var mark_x := bar.position.x + (bar.size.x - 4) * (25.0 / maxf(_max_mana, 1.0)) + 2
	_canvas.draw_line(Vector2(mark_x, bar.position.y), Vector2(mark_x, bar.end.y), Color(1, 1, 1, 0.5), 1.0)

	var gem := Vector2(36, 120)
	_canvas.draw_colored_polygon(PackedVector2Array([gem + Vector2(0, -12), gem + Vector2(9, 0), gem + Vector2(0, 12), gem + Vector2(-9, 0)]), Color("f2b84b"))
	_canvas.draw_string(ThemeDB.fallback_font, Vector2(56, 130), str(_shards), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("fff3c9"))
