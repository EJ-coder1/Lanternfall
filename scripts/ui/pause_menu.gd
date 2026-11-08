class_name PauseMenu
extends CanvasLayer
## Pause overlay: Resume, Save, Main Menu. Also owns the pause key/button handling.

signal opened

var _box: PanelContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.theme = UiTheme.make()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_box = PanelContainer.new()
	center.add_child(_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_box.add_child(v)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", UiTheme.AMBER)
	v.add_child(title)
	v.add_child(_button("Resume", close))
	v.add_child(_button("Save Game", _on_save))
	v.add_child(_button("Main Menu", _on_menu))


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 64)
	b.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		cb.call())
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not GameState.level_done:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if GameState.level_done:
		return
	visible = true
	get_tree().paused = true
	opened.emit()


func close() -> void:
	visible = false
	get_tree().paused = false


func _on_save() -> void:
	var ok := SaveSystem.save_game()
	GameState.toast.emit("Game saved." if ok else "Save failed.")
	close()


func _on_menu() -> void:
	close()
	get_tree().change_scene_to_file(GameState.MENU_PATH)
