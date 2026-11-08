extends Control
## Main menu: Continue, New Game, Settings, Credits, Exit. Built in code (no binary UI assets).

var _continue_btn: Button
var _panels: Array[Control] = []
var _main_box: Control
var _settings_panel: Control
var _credits_panel: Control


func _ready() -> void:
	theme = UiTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_main()
	_build_settings()
	_build_credits()
	_show(_main_box)
	Sfx.play_music("wilds")


func _show(panel: Control) -> void:
	for p in _panels:
		p.visible = (p == panel)
	if panel == _main_box:
		_continue_btn.disabled = not SaveSystem.has_save()


func _build_background() -> void:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color("08161e"), Color("1c5a52")])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 256
	var bg := TextureRect.new()
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var flies := CPUParticles2D.new()
	flies.position = Vector2(640, 420)
	flies.amount = 44
	flies.lifetime = 6.0
	flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flies.emission_rect_extents = Vector2(700, 340)
	flies.gravity = Vector2(0, -6)
	flies.initial_velocity_min = 4.0
	flies.initial_velocity_max = 14.0
	flies.scale_amount_min = 2.0
	flies.scale_amount_max = 4.0
	flies.color = Color(1.0, 0.82, 0.45, 0.8)
	add_child(flies)


func _title_block() -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := Label.new()
	t.text = "LANTERNFALL"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 84)
	t.add_theme_color_override("font_color", UiTheme.AMBER)
	t.add_theme_color_override("font_outline_color", Color("0b1a20"))
	t.add_theme_constant_override("outline_size", 10)
	var s := Label.new()
	s.text = "Echoes of the Sunken Crown"
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 30)
	s.add_theme_color_override("font_color", Color("bfe9df"))
	box.add_child(t)
	box.add_child(s)
	return box


func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 62)
	b.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		cb.call())
	return b


func _build_main() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_title_block())
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	v.add_child(gap)
	_continue_btn = _menu_button("Continue", _on_continue)
	v.add_child(_continue_btn)
	v.add_child(_menu_button("New Game", _on_new_game))
	v.add_child(_menu_button("Settings", func() -> void: _show(_settings_panel)))
	v.add_child(_menu_button("Credits", func() -> void: _show(_credits_panel)))
	if not OS.has_feature("web"):
		v.add_child(_menu_button("Exit", func() -> void: get_tree().quit()))
	add_child(v)
	_main_box = v
	_panels.append(v)


func _panel_shell(title: String) -> Array:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	center.add_child(panel)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", UiTheme.AMBER)
	v.add_child(t)
	add_child(center)
	_panels.append(center)
	return [center, v]


func _slider_row(label_text: String, value: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(160, 0)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(340, 40)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(on_change)
	s.drag_ended.connect(func(_changed: bool) -> void: Sfx.play("ui_click"))
	row.add_child(l)
	row.add_child(s)
	return row


func _build_settings() -> void:
	var shell := _panel_shell("Settings")
	_settings_panel = shell[0]
	var v: VBoxContainer = shell[1]
	v.add_child(_slider_row("Music", GameState.music_volume, func(x: float) -> void:
		GameState.music_volume = x
		Sfx.apply_volumes()))
	v.add_child(_slider_row("Effects", GameState.sfx_volume, func(x: float) -> void:
		GameState.sfx_volume = x
		Sfx.apply_volumes()))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var l := Label.new()
	l.text = "Touch controls"
	l.custom_minimum_size = Vector2(160, 0)
	var opt := OptionButton.new()
	opt.add_item("Auto", 0)
	opt.add_item("Always show", 1)
	opt.add_item("Never show", 2)
	opt.selected = GameState.touch_mode
	opt.item_selected.connect(func(i: int) -> void: GameState.touch_mode = i)
	row.add_child(l)
	row.add_child(opt)
	v.add_child(row)
	v.add_child(_menu_button("Back", func() -> void:
		GameState.save_settings()
		_show(_main_box)))


func _build_credits() -> void:
	var shell := _panel_shell("Credits")
	_credits_panel = shell[0]
	var v: VBoxContainer = shell[1]
	var body := Label.new()
	body.text = "Lanternfall\nAn original game by EJ.\n\nCode, placeholder art and audio: original, generated for this project.\nEngine: Godot (MIT License).\n\nThis is a vertical slice. Art and audio are temporary."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(620, 0)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)
	v.add_child(_menu_button("Back", func() -> void: _show(_main_box)))


func _on_new_game() -> void:
	GameState.new_game()
	get_tree().change_scene_to_file(GameState.LEVEL_PATH)


func _on_continue() -> void:
	if SaveSystem.load_game():
		get_tree().change_scene_to_file(GameState.LEVEL_PATH)
	else:
		_continue_btn.disabled = true
